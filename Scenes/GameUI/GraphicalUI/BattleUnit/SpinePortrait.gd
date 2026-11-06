class_name SpinePortrait
extends Control

signal action_finished(anim_name: StringName)
signal action_started(anim_name: StringName)

const FALLBACK_ICON: Texture2D = preload("res://Trash/icon.svg")
const PORTRAIT_SHADER: Shader = preload("res://Scenes/GameUI/GraphicalUI/BattleUnit/SpinePortrait.gdshader")
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
	if not _action_running or _dead:
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
func request_action(anim_name: StringName, beat: ActionBeat = ActionBeat.ATTACK) -> bool:
	if _dead or _animation_state == null or anim_name.is_empty():
		return false
	if not has_animation(anim_name):
		push_warning("SpinePortrait '%s': requested animation '%s' does not exist." % [name, anim_name])
		return false

	_action_queue.append({
		"anim": anim_name,
		"beat": int(beat),
		"order": _next_action_order,
	})
	_next_action_order += 1

	_action_queue.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["beat"]) == int(b["beat"]):
				return int(a["order"]) < int(b["order"])
			return int(a["beat"]) < int(b["beat"])
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
	var token := _hit_cancel_token
	await get_tree().create_timer(delay).timeout
	
	# Superseded by a death, skeleton reload, or explicit queue clear.
	if token != _hit_cancel_token:
		return
	if _dead or _animation_state == null:
		return
	
	request_action(anim_hit, ActionBeat.REACTION)
	
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

func play_skill_and_wait(skill_index: int, rank: int = 0) -> void:
	var anim := _get_skill_anim(skill_index, rank)
	if not request_action(anim, ActionBeat.ATTACK):
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
	_active_action = next_action["anim"] as StringName
	_action_running = true

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
	_sprite: Variant,
	_state: Variant,
	track_entry: Variant
) -> void:
	if not _action_running or _dead or track_entry == null:
		return

	if int(track_entry.call("get_track_index")) != BASE_TRACK:
		return

	# Ignore completion notifications from older/interrupted track entries.
	var animation: Variant = track_entry.call("get_animation")
	if animation == null:
		return

	if StringName(animation.call("get_name")) != _active_action:
		return

	_finish_active_action()


func _clear_action_queue() -> void:
	var cancelled: Array[StringName] = []
	if _action_running:
		cancelled.append(_active_action)
	for a in _action_queue:
		cancelled.append(a["anim"])
	_action_queue.clear()
	_action_running = false
	_active_action = &""
	_action_watchdog = 0.0
	_hit_cancel_token += 1
	for anim in cancelled:
		action_finished.emit(anim)
		
## Check if the current skeleton actually has the animation
func has_animation(anim_name: StringName) -> bool:
	if _spine == null: return false
	var skeleton = _spine.call("get_skeleton")
	if skeleton:
		var data = skeleton.call("get_data")
		if data:
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
	await get_tree().create_timer(delay).timeout

	# Resurrection or skeleton reload cancelled it.
	if not _dead:
		return

	_clear_action_queue()
	_play_death_animation()

func _create_spine_sprite() -> void:
	if skeleton_data == null:
		_show_fallback("SpinePortrait: skeleton_data is not assigned")
		return
	
	if not ClassDB.class_exists("SpineSprite"):
		_show_fallback("SpinePortrait: SpineSprite is unavailable.")
		return
	
	_spine = ClassDB.instantiate("SpineSprite") as Node2D
	if _spine == null:
		_show_fallback("SpinePortrait: failed to construct SpineSprite")
		return
	
	_spine.set("skeleton_data_res", skeleton_data)
	add_child(_spine)
	
	if _spine.has_signal("animation_completed"):
		_spine.connect(
			"animation_completed",
			_on_spine_animation_completed
		)
	
	_create_material()
	_spine.set("normal_material", _material)
	
	for property_info: Dictionary in _spine.get_property_list():
		var property_name: String = property_info.get("name", "")
		if property_name in ["normal_material", "additive_material", "multiply_material"]:
			_spine.set(property_name, _material)
	
	_animation_state = _spine.call("get_animation_state")
	
	if _dead:
		# Preserve the terminal state when skeleton data is reloaded.
		_play_death_animation()
	elif has_animation(anim_born):
		# Born plays once, then the queued idle takes over.
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
			_material.set_shader_parameter("bloom_texture", load(bloom_path))
		else:
			# No mask means no glow at all, rather than glowing everywhere.
			_material.set_shader_parameter("bloom_intensity", 0.0)

func _fit_sprite() -> void:
	if _spine == null or source_art_bounds.x <= 0.0 or source_art_bounds.y <= 0.0: return
	if size.x <= 0.0 or size.y <= 0.0: return

	var fit_scale: float = minf(size.x / source_art_bounds.x, size.y / source_art_bounds.y) * viewport_fill
	var direction: float = -1.0 if _facing_left else 1.0
	_spine.scale = Vector2(fit_scale * direction, fit_scale)
	_spine.position = Vector2(size.x * 0.5 + horizontal_offset, size.y - bottom_padding)

func _show_fallback(reason: String) -> void:
	push_error(reason)
	if _fallback != null: return

	_fallback = TextureRect.new()
	_fallback.texture = FALLBACK_ICON
	_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fallback)
	
func _get_animation_duration(anim_name: StringName) -> float:
	if _spine == null:
		return FALLBACK_ACTION_DURATION

	var skeleton: Variant = _spine.call("get_skeleton")
	if skeleton == null:
		return FALLBACK_ACTION_DURATION

	var data: Variant = skeleton.call("get_data")
	if data == null:
		return FALLBACK_ACTION_DURATION

	var animation: Variant = data.call("find_animation", anim_name)
	if animation == null:
		return FALLBACK_ACTION_DURATION

	return maxf(0.05, float(animation.call("get_duration")))


func _finish_active_action() -> void:
	if not _action_running:
		return
	var finished := _active_action
	
	_action_running = false
	_active_action = &""
	_action_watchdog = 0.0
	_schedule_action_pump()
	action_finished.emit(finished)

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
