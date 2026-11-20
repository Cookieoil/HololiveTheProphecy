class_name SpinePortrait
extends Control

signal action_finished(anim_name: StringName)
signal action_started(anim_name: StringName)
## Emitted once per lead-armed action when the caller may hand control to the
## next actor, i.e. the action played far enough to overlap with it. It also
## fires when an armed action ends early (death, queue clear, watchdog), so an
## awaiting caller can never hang.
signal action_lead_reached(anim_name: StringName)

const FALLBACK_ICON: Texture2D = preload("res://Scenes/BattleScene/Assets/icon.svg")
const PORTRAIT_SHADER: Shader = preload("res://Scenes/BattleUnit/SpinePortrait.gdshader")
const BASE_TRACK: int = 0
const ACTION_COMPLETION_GRACE: float = 0.25
const FALLBACK_ACTION_DURATION: float = 2.0

@export var skeleton_data: Resource
@export_group("Animations")
@export var anim_idle: StringName = &"idle"
@export var anim_sleep: StringName = &"sleep"
@export var anim_born: StringName = &"born"
@export var anim_change: StringName = &"change"
@export var anim_die: StringName = &"die"
@export var anim_freeze: StringName = &"freeze"
@export var anim_giddy: StringName = &"giddy"
@export var anim_hit: StringName = &"hit"
@export var anim_idle_special: StringName = &"idle_special1"
@export var anim_posture: StringName = &"posture"
@export var anim_skill1: StringName = &"skill1"
@export var anim_skill1_1: StringName = &"skill1_1"
@export var anim_skill1_2: StringName = &"skill1_2"
@export var anim_skill2_1: StringName = &"skill2_1"
@export var anim_unique: StringName = &"unique"
@export var anim_unique_1: StringName = &"unique_1"

@export_group("Visuals")
@export var source_art_bounds: Vector2 = Vector2(220.0, 420.0)
@export_range(0.5, 1.0, 0.01) var viewport_fill: float = 0.96
@export var bottom_padding: float = 2.0
@export var horizontal_offset: float = 0.0

@export_group("Bloom")
@export_range(0.0, 4.0, 0.05) var bloom_intensity: float = 1.0
@export_range(0.0, 1.0, 0.01) var bloom_threshold: float = 0.35
@export_range(0.0, 1.0, 0.01) var bloom_tint: float = 0.0
## Enable only if a WorldEnvironment glow + HDR 2D is set up (see below).
@export var hdr_bloom: bool = false
## 0 normal, 1 R, 2 G, 3 B, 4 mask
@export_range(0, 4) var bloom_debug_view: int = 0

@export_group("Timing")
@export_range(0.0, 3.0, 0.05) var hit_reaction_delay: float = 0.35
@export_range(0.0, 3.0, 0.05) var death_animation_delay: float = 0.35

var _canvas_group: CanvasGroup
var _spine: Node2D
var _animation_state: Object
var _material: ShaderMaterial
var _fallback: TextureRect
var _facing_left: bool = false
var _dead: bool = false

var _action_queue: Array[Dictionary] = []
var _action_running: bool = false
var _action_pump_scheduled: bool = false
var _active_action: StringName = &""
var _next_action_order: int = 0
var _action_watchdog: float = 0.0

## Seconds left until the running action reaches its overlap beat.
var _action_lead: float = 0.0
## True while an overlap wait is armed for the running action. Kept separate from
## the counter so "already elapsed" (negative time) can never be confused with
## "no lead requested".
var _action_lead_armed: bool = false

## Cancels pending hit reactions when the queue is cleared (death/reload).
var _hit_cancel_token: int = 0

enum ActionBeat {
	REACTION = 0, # Hit reactions and other minor responses.
	SETUP = 50,   # Posture, transformation, buff preparation, etc.
	ATTACK = 100, # The dramatic payoff; therefore played last.
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_create_spine_sprite()
	resized.connect(_fit_sprite)

func _process(delta: float) -> void:
	if not _action_running:
		return

	# Deterministic delta counter instead of a timer: the overlap beat is a
	# slice of the animation itself, so it follows Engine.time_scale for free.
	# It keeps counting while dying, so a chained caller is released instead of
	# waiting for the death delay to clear the queue.
	if _action_lead_armed:
		_action_lead -= delta
		if _action_lead <= 0.0:
			_emit_action_lead()

	if _dead:
		return

	_action_watchdog -= delta

	if _action_watchdog <= 0.0:
		# Prevents a missing/mismatched Spine completion signal from
		# permanently blocking every subsequent action.
		_finish_active_action()
		
## Dynamically update the skeleton data (e.g., if assigned at runtime)
func set_skeleton_data(new_data: Resource) -> void:
	if skeleton_data == new_data: return
	skeleton_data = new_data
	_reload_spine()

func _reload_spine() -> void:
	_clear_action_queue()
	
	if _spine != null:
		_spine.queue_free()
		_spine = null
	_animation_state = null
	_create_spine_sprite()

func configure_from_unit(_display_name: String, is_enemy: bool) -> void:
	_facing_left = is_enemy
	_fit_sprite()

func set_hit_flash(strength: float) -> void:
	if _material != null:
		_material.set_shader_parameter("hit_flash", clampf(strength, 0.0, 1.0))

## Requests an animation without immediately interrupting another action.
## Lower beat values play first. Requests with the same beat remain FIFO.
## @param lead_seconds - seconds into the action after which `action_lead_reached`
##                       fires. -1 (default) never arms a lead, so callers wait
##                       for the action to finish in full.
func request_action(
	anim_name: StringName,
	beat: ActionBeat = ActionBeat.ATTACK,
	lead_seconds: float = -1.0
) -> bool:
	if _dead or _animation_state == null or anim_name.is_empty():
		return false
	if not has_animation(anim_name):
		push_warning("SpinePortrait '%s': requested animation '%s' does not exist." % [name, anim_name])
		return false

	_action_queue.append({
		"anim": anim_name,
		"beat": int(beat),
		"order": _next_action_order,
		"lead": lead_seconds,
	})
	_next_action_order += 1

	_action_queue.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var beat_a: int = a["beat"]
			var beat_b: int = b["beat"]
			if beat_a == beat_b:
				var order_a: int = a["order"]
				var order_b: int = b["order"]
				return order_a < order_b
			return beat_a < beat_b
	)
	
	if not _action_running:
		_schedule_action_pump()
	
	return true


func play_hit(delay: float = -1.0) -> void:
	var d: float = delay if delay >= 0.0 else hit_reaction_delay
	if d <= 0.0:
		request_action(anim_hit, ActionBeat.REACTION)
		return
	_schedule_delayed_hit(d)

func _schedule_delayed_hit(delay: float) -> void:
	var token: int = _hit_cancel_token
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		# Superseded by a death, skeleton reload, or explicit queue clear.
		if token != _hit_cancel_token:
			return
		if _dead or _animation_state == null:
			return
		request_action(anim_hit, ActionBeat.REACTION)
	)
	
## skill_index: 1 or 2
## rank: 0 = normal, 1 = merged/condition met, 2 = double merged
func _get_skill_anim(skill_index: int, rank: int) -> StringName:
	if skill_index == 1:
		match rank:
			0: return anim_skill1
			1: return anim_skill1_1
			_: return anim_skill1_2
	else:
		match rank:
			0: return anim_skill2_1
			1: return anim_skill2_1
			_: return anim_skill2_1
	
func play_skill(skill_index: int, rank: int = 0) -> void:
	request_action(_get_skill_anim(skill_index, rank), ActionBeat.ATTACK)

## Plays a skill action and waits for the caller's turn to continue.
## @param lead - fraction of the animation the caller waits for. 1.0 (default)
##               waits for the whole animation plus its blend back to idle, which
##               is what the player's own turn needs. Lower values return once the
##               attack has passed its impact beat, so the next actor can start
##               while this one plays out its wind-down (chained enemy turns).
func play_skill_and_wait(skill_index: int, rank: int = 0, lead: float = 1.0) -> void:
	var anim := _get_skill_anim(skill_index, rank)
	var lead_seconds: float = lead_wait_seconds(_get_animation_duration(anim), lead)
	if not request_action(anim, ActionBeat.ATTACK, lead_seconds):
		return
	if lead_seconds < 0.0:
		while (await action_finished) != anim:
			pass
		return
	while (await action_lead_reached) != anim:
		pass

## Seconds the caller waits before the next actor may start, for an action that
## lasts `duration` and an overlap request of `lead_fraction`.
##
## -1.0 means "wait for the whole animation" (a fraction of 1.0 or more). Below
## that the wait is a slice of the animation itself, so longer or slower
## animations keep their natural proportions instead of a fixed wall-clock gap.
##
## Static and pure, so the overlap policy stays unit-testable without a Spine
## setup and stays independent of any timer.
static func lead_wait_seconds(duration: float, lead_fraction: float) -> float:
	if lead_fraction >= 1.0:
		return -1.0
	return maxf(0.0, duration) * clampf(lead_fraction, 0.0, 1.0)

func _get_ultimate_anim() -> StringName:
	for candidate: StringName in [anim_unique_1, anim_unique, anim_skill1_2, anim_skill1]:
		if has_animation(candidate):
			return candidate
	return &""

func play_ultimate_and_wait() -> void:
	var anim := _get_ultimate_anim()
	if anim.is_empty() or not request_action(anim, ActionBeat.ATTACK):
		return
	while (await action_finished) != anim:
		pass
		
func _schedule_action_pump() -> void:
	if _action_pump_scheduled:
		return

	_action_pump_scheduled = true
	call_deferred("_pump_action_queue")


func _pump_action_queue() -> void:
	_action_pump_scheduled = false

	if _dead or _action_running or _animation_state == null:
		return

	if _action_queue.is_empty():
		_play_base_animation(anim_idle, true)
		return

	var next_action: Dictionary = _action_queue.pop_front()
	var next_anim: StringName = next_action["anim"]
	var next_lead: float = next_action["lead"]
	_active_action = next_anim
	_action_running = true
	_action_lead = maxf(0.0, next_lead)
	_action_lead_armed = next_lead >= 0.0

	_animation_state.call(
		"set_animation",
		_active_action,
		false,
		BASE_TRACK
	)

	# The completion signal normally advances the route sooner.
	# This timeout guarantees advancement even without that signal.
	_action_watchdog = (
		_get_animation_duration(_active_action)
		+ ACTION_COMPLETION_GRACE
	)
	
	action_started.emit(_active_action)


func _on_spine_animation_completed(
	_sprite: Object,
	_state: Object,
	track_entry: Object
) -> void:
	if not _action_running or _dead or track_entry == null:
		return

	var track_idx: int = track_entry.call("get_track_index")
	if track_idx != BASE_TRACK:
		return

	# Ignore completion notifications from older/interrupted track entries.
	var raw_anim: Variant = track_entry.call("get_animation")
	if not (raw_anim is Object):
		return
	var animation: Object = raw_anim

	var raw_name: String = str(animation.call("get_name"))
	if StringName(raw_name) != _active_action:
		return

	_finish_active_action()


func _clear_action_queue() -> void:
	var cancelled: Array[StringName] = []
	if _action_running:
		cancelled.append(_active_action)
	for a: Dictionary in _action_queue:
		var q_anim: StringName = a["anim"]
		cancelled.append(q_anim)
	_action_queue.clear()
	_action_running = false
	_active_action = &""
	_action_watchdog = 0.0
	_action_lead = 0.0
	_action_lead_armed = false
	_hit_cancel_token += 1
	for anim: StringName in cancelled:
		action_finished.emit(anim)
		# Overlap waiters of a cancelled action must not be left hanging.
		action_lead_reached.emit(anim)
		
## Check if the current skeleton actually has the animation
func has_animation(anim_name: StringName) -> bool:
	if _spine == null: return false
	var raw_skeleton: Variant = _spine.call("get_skeleton")
	if raw_skeleton is Object:
		var skeleton: Object = raw_skeleton
		var raw_data: Variant = skeleton.call("get_data")
		if raw_data is Object:
			var data: Object = raw_data
			# find_animation returns null if not found
			return data.call("find_animation", anim_name) != null
	return false

## Plays a one-shot by default, then automatically returns to idle.
## Pass loop = true for persistent states such as sleep, freeze, or giddy.
func play_animation(anim_name: StringName, loop: bool = false) -> void:
	# Death is a terminal, latched state. Hits, skills, etc. cannot interrupt it.
	if _dead:
		return

	# Idle should always be a persistent looping state.
	if anim_name == anim_idle:
		loop = true

	_play_base_animation(anim_name, loop)


func _play_base_animation(
	anim_name: StringName,
	loop: bool = false,
	hold_on_end: bool = false
) -> void:
	if _animation_state == null or anim_name.is_empty():
		return

	if not has_animation(anim_name):
		return

	# set_animation replaces the current action and its old queued return-to-idle.
	# This also makes interrupting one action with another safe.
	_animation_state.call(
		"set_animation",
		anim_name,
		loop,
		BASE_TRACK
	)

	# Looping animations continue indefinitely. Terminal animations such as
	# death remain on their final frame.
	if loop or hold_on_end:
		return

	# delay = 0 means "when the previous entry finishes", not "immediately".
	# No timers, completion signals, or per-frame animation checks are needed.
	if has_animation(anim_idle):
		_animation_state.call(
			"add_animation",
			anim_idle,
			0.0,
			true,
			BASE_TRACK
		)

func _play_death_animation() -> void:
	# Darken the shader at the exact instant the death animation starts,
	# so the black tint never appears before the sprite is actually dying.
	if _material != null:
		_material.set_shader_parameter("death_mix", 1.0)

	if has_animation(anim_die):
		_play_base_animation(anim_die, false, true)
	elif has_animation(anim_sleep):
		_play_base_animation(anim_sleep, true)
	else:
		_play_base_animation(anim_idle, true)


func set_dead(value: bool) -> void:
	if _dead == value:
		return

	_dead = value

	if _dead:
		if death_animation_delay > 0.0:
			_schedule_delayed_death(death_animation_delay)
		else:
			_clear_action_queue()
			_play_death_animation()
	else:
		# Resurrection: clear the tint immediately — that's fine, it's the
		# "be alive again" cue.
		if _material != null:
			_material.set_shader_parameter("death_mix", 0.0)
		_clear_action_queue()
		_play_base_animation(anim_idle, true)

func _schedule_delayed_death(delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		# Resurrection or skeleton reload cancelled it.
		if not _dead:
			return
		_clear_action_queue()
		_play_death_animation()
	)

func _create_spine_sprite() -> void:
	if skeleton_data == null:
		# Not having a rig yet is a normal configuration: a unit without a
		# Spine/<char_id>/ export just shows the placeholder art.
		_show_fallback("SpinePortrait: skeleton_data is not assigned", false)
		return

	if not ClassDB.class_exists("SpineSprite"):
		_show_fallback("SpinePortrait: SpineSprite is unavailable.")
		return

	var raw_spine: Variant = ClassDB.instantiate("SpineSprite")
	if raw_spine is Node2D:
		_spine = raw_spine
	else:
		_spine = null
	if _spine == null:
		_show_fallback("SpinePortrait: failed to construct SpineSprite")
		return

	if _fallback != null:
		_fallback.queue_free()
		_fallback = null

	_spine.set("skeleton_data_res", skeleton_data)
	_ensure_canvas_group().add_child(_spine)

	if _spine.has_signal("animation_completed"):
		_spine.connect(
			"animation_completed",
			_on_spine_animation_completed
		)

	_create_material()
	_spine.set("normal_material", _material)

	_animation_state = _spine.call("get_animation_state")

	if _dead:
		_play_death_animation()
	elif has_animation(anim_born):
		_play_base_animation(anim_born)
	else:
		_play_base_animation(anim_idle, true)

	_fit_sprite()


func _create_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = PORTRAIT_SHADER
	_material.set_shader_parameter("bloom_intensity", bloom_intensity)
	_material.set_shader_parameter("bloom_threshold", bloom_threshold)
	_material.set_shader_parameter("bloom_tint", bloom_tint)
	_material.set_shader_parameter("hdr_bloom", hdr_bloom)
	_material.set_shader_parameter("debug_view", bloom_debug_view)

	if skeleton_data != null and not skeleton_data.resource_path.is_empty():
		var bloom_path := skeleton_data.resource_path.get_basename() + "_bloom.png"
		if ResourceLoader.exists(bloom_path):
			var bloom_tex := load(bloom_path) as Texture2D
			_material.set_shader_parameter("bloom_texture", bloom_tex)
		else:
			_material.set_shader_parameter("bloom_intensity", 0.0)


func _fit_sprite() -> void:
	if _fallback != null:
		_fallback.position = Vector2.ZERO
		_fallback.size = size
	if _spine == null or source_art_bounds.x <= 0.0 or source_art_bounds.y <= 0.0:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var fit_scale: float = minf(size.x / source_art_bounds.x, size.y / source_art_bounds.y) * viewport_fill
	var direction: float = -1.0 if _facing_left else 1.0
	_spine.scale = Vector2(fit_scale * direction, fit_scale)
	_spine.position = Vector2(size.x * 0.5 + horizontal_offset, size.y - bottom_padding)


## Falls back to the placeholder icon art. `fatal = false` downgrades the log to
## a warning, for cases the game is expected to run in (a unit with no rig yet).
func _show_fallback(reason: String, fatal: bool = true) -> void:
	if fatal:
		push_error(reason)
	else:
		push_warning(reason)
	if _fallback != null:
		return

	_fallback = TextureRect.new()
	_fallback.texture = FALLBACK_ICON
	_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.position = Vector2.ZERO
	_fallback.size = size
	_ensure_canvas_group().add_child(_fallback)
	
func _get_animation_duration(anim_name: StringName) -> float:
	if _spine == null:
		return FALLBACK_ACTION_DURATION

	var raw_skeleton: Variant = _spine.call("get_skeleton")
	if not (raw_skeleton is Object):
		return FALLBACK_ACTION_DURATION
	var skeleton: Object = raw_skeleton

	var raw_data: Variant = skeleton.call("get_data")
	if not (raw_data is Object):
		return FALLBACK_ACTION_DURATION
	var data: Object = raw_data

	var raw_animation: Variant = data.call("find_animation", anim_name)
	if not (raw_animation is Object):
		return FALLBACK_ACTION_DURATION
	var animation: Object = raw_animation

	var dur: float = animation.call("get_duration")
	return maxf(0.05, dur)


func _finish_active_action() -> void:
	if not _action_running:
		return
	var finished := _active_action

	# A chained caller may still be waiting on this action's overlap beat (a very
	# short animation can end before the lead elapses), so release it first.
	_emit_action_lead()

	_action_running = false
	_active_action = &""
	_action_watchdog = 0.0
	_schedule_action_pump()
	action_finished.emit(finished)


## Releases a pending overlap wait. Safe to call when nothing is armed, and it
## never fires twice for the same action because it always disarms first.
func _emit_action_lead() -> void:
	if not _action_lead_armed:
		return
	_action_lead_armed = false
	_action_lead = 0.0
	action_lead_reached.emit(_active_action)

## True for animations where the character leaves its idle spot.
func is_skill_animation(anim_name: StringName) -> bool:
	return anim_name in [
		anim_skill1, anim_skill1_1, anim_skill1_2,
		anim_skill2_1, anim_unique, anim_unique_1,
	]
	
## How long the spawn animation lasts. UnitUI fades its HUD in after this.
func get_intro_duration() -> float:
	if _dead or not has_animation(anim_born):
		return 0.0
	return _get_animation_duration(anim_born)

#region Helper methods
func get_canvas_group() -> CanvasGroup:
	return _ensure_canvas_group()


func _ensure_canvas_group() -> CanvasGroup:
	if _canvas_group == null:
		_canvas_group = CanvasGroup.new()
		_canvas_group.name = "SilhouetteGroup"
		_canvas_group.fit_margin = 2.0
		_canvas_group.clear_margin = 4.0
		add_child(_canvas_group)
	return _canvas_group
#endregion
