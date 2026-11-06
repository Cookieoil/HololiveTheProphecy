class_name UnitUI
extends PanelContainer

signal card_dropped_on_unit(card: Card, unit: Unit)
signal unit_clicked(unit: Unit)

const PLACEHOLDER_ICON: Texture2D = preload("res://Trash/icon.svg")
const STAGGER_OFFSET_Y: float = 65.0
const SPINE_BASE_DIR = "res://Scenes/GameUI/GraphicalUI/BattleUnit/Spine/"

@export var icon_catalog: IconCatalog
@export var status_icon_catalog: StatusIconCatalog

@export_group("Spine Override")
## Toggle this on to manually assign a .tres file below.
@export var use_override_spine: bool = false
@export var override_spine_data: Resource

@export_group("Hit Flash Timing")
@export_range(0.0, 3.0, 0.05) var hit_flash_delay: float = 0.0

@export_group("Skill HUD Fade")
@export_range(0.0, 1.0, 0.01) var hud_fade_out_time: float = 0.12
@export_range(0.0, 1.0, 0.01) var hud_fade_in_time: float = 0.25

var _hud_tween: Tween
var _hud_hidden: bool = false

@export_group("Intent Label")
@export_range(0.0, 1.0, 0.01) var intent_fade_in_time: float = 0.25
@export_range(0.0, 1.0, 0.01) var intent_fade_out_time: float = 0.2

var _intent_tween: Tween
## Whether the label should end up shown, even mid-fade
var _intent_visible: bool = false

@export_group("Intro Fade")
## Extra wait after the born animation ends. Negative = start fading before born ends.
@export_range(-2.0, 2.0, 0.05) var intro_extra_delay: float = 0.0
@export_range(0.0, 2.0, 0.01) var intro_fade_in_time: float = 0.35

var _intro_active: bool = false
var _intro_tween: Tween
var _pending_intent: Dictionary = {}
var _skill_hud_active: bool = false

var unit: Unit

@onready var intent_label: Label = $VBox/IntentLabel
@onready var status_icons_grid: GridContainer = $VBox/StatusSection/StatusIconsGrid
@onready var skill_preview_box: VBoxContainer = $VBox/StatusSection/SkillPreview
@onready var skill_1_row: HBoxContainer = $VBox/StatusSection/SkillPreview/Skill1Row
@onready var skill_1_icons: HBoxContainer = $VBox/StatusSection/SkillPreview/Skill1Row/Icons
@onready var skill_2_row: HBoxContainer = $VBox/StatusSection/SkillPreview/Skill2Row
@onready var skill_2_icons: HBoxContainer = $VBox/StatusSection/SkillPreview/Skill2Row/Icons

@onready var health_bar_canvas: Control = $VBox/HealthShieldContainer/LoLBarCanvas
@onready var health_shield_container: Control = $VBox/HealthShieldContainer
@onready var hp_bar: ProgressBar = $VBox/HealthShieldContainer/HpBar
@onready var shield_bar: ProgressBar = $VBox/HealthShieldContainer/ShieldBar

@onready var oval_body: PanelContainer = $VBox/OvalBody
@onready var sprite: Control = $VBox/OvalBody/BodyVBox/CharacterSprite
@onready var name_label: Label = $VBox/OvalBody/BodyVBox/NameLabel
@onready var hover_glow: Panel = $HoverGlow

var _stagger_style: StyleBoxEmpty
var _is_target_highlighted: bool = false
var _is_drag_hovering: bool = false

#region Health Bar State
const HIT_FLASH_TIME: float = 0.4
const CHIP_HOLD_TIME: float = 0.35     ## How long the lost chunk lingers before draining
const CHIP_DRAIN_SPEED: float = 9.0
const HEAL_FILL_SPEED: float = 10.0
const SHIELD_GAIN_SPEED: float = 14.0
const SHIELD_DECAY_SPEED: float = 9.0  ## Expiry shrink (not a hit)
const SHIELD_FLASH_TIME: float = 0.28
const CAP_EXPAND_SPEED: float = 18.0
const CAP_SHRINK_SPEED: float = 6.0

const SHATTER_DURATION: float = 0.28
const SHATTER_WAVE_TIME: float = 0.14
const SHATTER_SHARD_LIFE: float = 0.16

## What the bar currently shows (lags behind the Unit on purpose).
var _display_hp: float = 0.0
var _display_shield: float = 0.0
## Where the bar is heading: real values + damage that hasn't landed yet.
var _target_hp: float = 0.0
var _target_shield: float = 0.0
var _prev_target_shield: float = 0.0

## Right edge of the "recently lost" chip, in HP units (HP + shield).
var _chip_total: float = 0.0
var _chip_hold_timer: float = 0.0
var _display_max_cap: float = 1.0

var _hit_flash_timer: float = 0.0
var _shield_flash_timer: float = 0.0

## Hits that already happened in the model but haven't landed visually.
var _pending_hits: Array[Dictionary] = []
## Sum of pending losses. Added back so the bar keeps showing pre-hit values.
var _withheld_hp: float = 0.0
var _withheld_shield: float = 0.0

var _was_dead: bool = false
var _pending_death_timer: float = -1.0
var _shatter_timer: float = 0.0
var _shatter_shards: Array[Dictionary] = []

var _last_status_signature: String = ""
var _manual_statuses: Array[Dictionary] = []
#endregion

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ignore_mouse_recursively(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if status_icon_catalog == null:
		status_icon_catalog = StatusIconCatalog.new()

	_stagger_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", _stagger_style)

	oval_body.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	name_label.visible = false
	skill_preview_box.visible = false

	_setup_glow_style()
	if health_bar_canvas:
		health_bar_canvas.draw.connect(_draw_health_bar)
		
	clear_intent()
	
	# Use connect() by name: `sprite` is typed as Control, so
	# `sprite.action_started` would not pass the static type check.
	if sprite.has_signal("action_started"):
		sprite.connect("action_started", _on_sprite_action_started)
	if sprite.has_signal("action_finished"):
		sprite.connect("action_finished", _on_sprite_action_finished)
		
	_set_hud_hidden(true, true)

func _setup_glow_style() -> void:
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	glow_style.border_width_left = 2
	glow_style.border_width_top = 2
	glow_style.border_width_right = 2
	glow_style.border_width_bottom = 2
	glow_style.border_color = Color(1.0, 0.9, 0.4, 0.95)
	glow_style.corner_radius_top_left = 8
	glow_style.corner_radius_top_right = 8
	glow_style.corner_radius_bottom_left = 8
	glow_style.corner_radius_bottom_right = 8
	hover_glow.add_theme_stylebox_override("panel", glow_style)

func set_staggered(is_lower: bool) -> void:
	if _stagger_style == null:
		_stagger_style = StyleBoxEmpty.new()
		add_theme_stylebox_override("panel", _stagger_style)
	if is_lower:
		_stagger_style.content_margin_top = STAGGER_OFFSET_Y
		_stagger_style.content_margin_bottom = 0.0
	else:
		_stagger_style.content_margin_top = 0.0
		_stagger_style.content_margin_bottom = STAGGER_OFFSET_Y

func setup(p_unit: Unit, p_card_catalog: IconCatalog, p_status_catalog: StatusIconCatalog = null) -> void:
	_bind_unit(p_unit)
	icon_catalog = p_card_catalog
	if p_status_catalog != null:
		status_icon_catalog = p_status_catalog
	elif status_icon_catalog == null:
		status_icon_catalog = StatusIconCatalog.new()

	name_label.text = unit.data.display_name
	name_label.visible = false

	_was_dead = unit.is_dead
	_shatter_shards.clear()
	_pending_death_timer = -1.0
	_reset_bar_state()

	_load_unit_texture(sprite, unit.data.display_name)
	_render_skill_preview_icons(skill_1_icons, unit.data.skill_1, false)
	_render_skill_preview_icons(skill_2_icons, unit.data.skill_2, false)

	_last_status_signature = ""
	_refresh_status_icons()
	_refresh_display(0.0)

	# Play born animation
	if sprite.has_method("play_animation"):
		sprite.play_animation(&"born")
		
	_skill_hud_active = false
	play_intro()

func _process(delta: float) -> void:
	if _is_drag_hovering:
		if not get_viewport().gui_is_dragging() or not get_global_rect().has_point(get_global_mouse_position()):
			_reset_preview()

	if unit == null or unit.data == null: return

	_refresh_status_icons()
	_refresh_display(delta)

func _refresh_display(delta: float) -> void:
	var max_hp := maxf(1.0, float(unit.max_hp))
	var real_hp := clampf(float(unit.current_hp), 0.0, max_hp)
	var real_shield := maxf(0.0, float(unit.shield))

	if sprite.has_method("set_dead"):
		sprite.set_dead(unit.is_dead)

	# --- Death visual scheduling (same delay as anim_die + shader tint) -----
	if unit.is_dead and not _was_dead and _pending_death_timer < 0.0:
		_pending_death_timer = _get_effective_death_delay()

	if _pending_death_timer >= 0.0:
		_pending_death_timer -= delta
		if _pending_death_timer <= 0.0:
			_pending_death_timer = -1.0
			_was_dead = true
			_clear_pending_hits()
			_cancel_intro()
			_skill_hud_active = false
			_set_hud_hidden(false, true)
			_trigger_death_shatter()
			clear_intent(true)

	# --- Revival: refill from empty ------------------------------------------
	if not unit.is_dead:
		_pending_death_timer = -1.0
		if _was_dead:
			_was_dead = false
			_shatter_shards.clear()
			_display_hp = 0.0
			_display_shield = 0.0
			_prev_target_shield = 0.0
			_chip_total = 0.0
			_chip_hold_timer = 0.0

	# --- 1. Land matured hits (FIFO, they all share the same delay) --------
	var landed := false
	for h in _pending_hits:
		h["delay"] = float(h["delay"]) - delta
	while not _pending_hits.is_empty() and float(_pending_hits[0]["delay"]) <= 0.0:
		var hit: Dictionary = _pending_hits.pop_front()
		_withheld_hp -= float(hit["hp"])
		_withheld_shield -= float(hit["shield"])
		landed = true
	if _pending_hits.is_empty():
		_withheld_hp = 0.0      # clears float drift
		_withheld_shield = 0.0

	# Heals/shield gains during the delay still apply right away.
	_target_hp = clampf(real_hp + _withheld_hp, 0.0, max_hp)
	_target_shield = maxf(0.0, real_shield + _withheld_shield)

	if landed and not _was_dead:
		# The whole lost chunk (shield + HP) becomes one chip, LoL-style.
		_chip_total = maxf(_chip_total, _display_hp + _display_shield)
		_chip_hold_timer = CHIP_HOLD_TIME
		_hit_flash_timer = HIT_FLASH_TIME
		_display_hp = minf(_display_hp, _target_hp)
		_display_shield = minf(_display_shield, _target_shield)

	# --- 2. Push flash to the shader ---------------------------------------
	if sprite.has_method("set_hit_flash"):
		sprite.set_hit_flash(clampf(_hit_flash_timer / HIT_FLASH_TIME, 0.0, 1.0))

	# --- 3. Dead: only the shatter animates --------------------------------
	if _was_dead:
		if _shatter_timer > 0.0:
			_shatter_timer = maxf(0.0, _shatter_timer - delta)
			var elapsed := SHATTER_DURATION - _shatter_timer
			var drag := exp(-10.5 * delta)
			for shard in _shatter_shards:
				if elapsed < float(shard["delay"]): continue
				shard["vel"] *= drag
				shard["vel"].y += 380.0 * delta
				shard["pos"] += shard["vel"] * delta
				shard["rot"] += float(shard["ang_vel"]) * delta
		if health_bar_canvas:
			health_bar_canvas.queue_redraw()
		sprite.modulate = sprite.modulate.lerp(Color(0.35, 0.35, 0.35, 0.55), delta * 8.0)
		return

	sprite.modulate = Color.WHITE

	# --- 4. HP: heals fill up; loss without a damage event snaps + chips ---
	if _display_hp < _target_hp:
		_display_hp = lerpf(_target_hp, _display_hp, exp(-HEAL_FILL_SPEED * delta))
		if _target_hp - _display_hp < 0.05: _display_hp = _target_hp
	elif _display_hp > _target_hp:
		_chip_total = maxf(_chip_total, _display_hp + _display_shield)
		_chip_hold_timer = maxf(_chip_hold_timer, CHIP_HOLD_TIME * 0.5)
		_display_hp = _target_hp

	# --- 5. Shield: gain grows with a flash; expiry shrinks (no chip) ------
	if _target_shield > _prev_target_shield + 0.01:
		_shield_flash_timer = SHIELD_FLASH_TIME
	_prev_target_shield = _target_shield

	if _display_shield < _target_shield:
		_display_shield = lerpf(_target_shield, _display_shield, exp(-SHIELD_GAIN_SPEED * delta))
		if _target_shield - _display_shield < 0.05: _display_shield = _target_shield
	elif _display_shield > _target_shield:
		_display_shield = lerpf(_target_shield, _display_shield, exp(-SHIELD_DECAY_SPEED * delta))
		if _display_shield - _target_shield < 0.05: _display_shield = _target_shield

	# --- 6. Timers & chip drain --------------------------------------------
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	_shield_flash_timer = maxf(0.0, _shield_flash_timer - delta)

	var total_now := _display_hp + _display_shield
	if _chip_hold_timer > 0.0:
		_chip_hold_timer = maxf(0.0, _chip_hold_timer - delta)
	elif _chip_total > total_now:
		_chip_total = lerpf(total_now, _chip_total, exp(-CHIP_DRAIN_SPEED * delta))
		if _chip_total - total_now < 0.05: _chip_total = total_now
	_chip_total = maxf(_chip_total, total_now)

	# --- 7. Bar scale: max(max HP, HP + shield, lingering chip) ------------
	var hp_edge := maxf(_display_hp, _target_hp)
	var target_cap := maxf(max_hp, maxf(hp_edge + maxf(_display_shield, _target_shield), _chip_total))
	var cap_speed := CAP_EXPAND_SPEED if target_cap > _display_max_cap else CAP_SHRINK_SPEED
	_display_max_cap = lerpf(target_cap, _display_max_cap, exp(-cap_speed * delta))

	if health_bar_canvas:
		health_bar_canvas.queue_redraw()

func _trigger_death_shatter() -> void:
	_shatter_shards.clear()
	_shatter_timer = SHATTER_DURATION
	if health_bar_canvas == null: return

	var sz := health_bar_canvas.size
	var center := sz * 0.5
	var half_w := maxf(1.0, sz.x * 0.5)
	var cols := 12
	var rows := 2
	var cell_w := sz.x / float(cols)
	var cell_h := sz.y / float(rows)

	for r in range(rows):
		for c in range(cols):
			for sub in range(2):
				var origin := Vector2((c + randf_range(0.15, 0.85)) * cell_w, (r + randf_range(0.15, 0.85)) * cell_h)
				var offset := origin - center
				var dist_norm := clampf(absf(offset.x) / half_w, 0.0, 1.0)

				var rx := randf_range(2.6, 5.2)
				var ry := randf_range(2.2, 4.2)
				var poly := PackedVector2Array([
					Vector2(-rx, -ry * 0.6), Vector2(0.0, -ry), Vector2(rx, -ry * 0.4), Vector2(rx * 0.75, ry), Vector2(-rx * 0.8, ry * 0.85)
				])

				var dir_x := -1.0 if offset.x < 0.0 else 1.0
				var dir_y := -1.0 if (r == 0 and randf() < 0.72) or (r == 1 and randf() < 0.28) else 1.0
				var vel := Vector2(
					dir_x * randf_range(26.0, 72.0) + randf_range(-12.0, 12.0),
					dir_y * randf_range(38.0, 92.0) - randf_range(8.0, 28.0)
				)

				_shatter_shards.append({
					"poly": poly, "pos": origin, "vel": vel, "rot": randf_range(0.0, TAU),
					"ang_vel": randf_range(-11.0, 11.0), "delay": clampf(dist_norm * SHATTER_WAVE_TIME + randf_range(-0.012, 0.012), 0.0, SHATTER_WAVE_TIME),
					"life": SHATTER_SHARD_LIFE * randf_range(0.85, 1.15)
				})

func _draw_health_bar() -> void:
	if unit == null or health_bar_canvas == null: return

	if _was_dead:
		var elapsed := SHATTER_DURATION - _shatter_timer
		if elapsed >= SHATTER_DURATION: return

		var sz := health_bar_canvas.size
		var center := sz * 0.5
		var half_w := sz.x * 0.5
		var wave_p := clampf(elapsed / SHATTER_WAVE_TIME, 0.0, 1.0)
		var gap_half_w := half_w * wave_p
		var accent := Color(0.95, 0.24, 0.28) if not unit.is_ally else Color(0.28, 0.90, 0.42)

		if elapsed < 0.18:
			var beam_t := 1.0 - (elapsed / 0.18)
			var beam_w := lerpf(4.0, 14.0, beam_t)
			health_bar_canvas.draw_rect(Rect2(center.x - beam_w * 0.5, -6.0, beam_w, sz.y + 12.0), Color(accent.r, accent.g, accent.b, beam_t * 0.65), true)

		if wave_p < 1.0:
			var left_w := center.x - gap_half_w
			if left_w > 1.0:
				var l_rect := Rect2(0.0, 0.0, left_w, sz.y)
				health_bar_canvas.draw_rect(l_rect, Color(0.06, 0.05, 0.07, 0.95), true)
				health_bar_canvas.draw_rect(l_rect, Color(0.45, 0.35, 0.38, 0.9), false, 1.0)
				health_bar_canvas.draw_rect(Rect2(left_w - 3.0, -1.0, 3.5, sz.y + 2.0), Color(1.0, 0.85, 0.85, 0.9), true)

			var right_x := center.x + gap_half_w
			var right_w := sz.x - right_x
			if right_w > 1.0:
				var r_rect := Rect2(right_x, 0.0, right_w, sz.y)
				health_bar_canvas.draw_rect(r_rect, Color(0.06, 0.05, 0.07, 0.95), true)
				health_bar_canvas.draw_rect(r_rect, Color(0.45, 0.35, 0.38, 0.9), false, 1.0)
				health_bar_canvas.draw_rect(Rect2(right_x - 0.5, -1.0, 3.5, sz.y + 2.0), Color(1.0, 0.85, 0.85, 0.9), true)

		for shard in _shatter_shards:
			var local_age := elapsed - float(shard["delay"])
			var life := float(shard["life"])
			if local_age < 0.0 or local_age >= life: continue

			var t := local_age / life
			var scale_f := lerpf(0.75, 1.15, t / 0.25) if t < 0.25 else lerpf(1.15, 0.15, (t - 0.25) / 0.75)
			var alpha := 1.0 if t < 0.35 else (1.0 - ease((t - 0.35) / 0.65, 1.8))

			health_bar_canvas.draw_set_transform(shard["pos"], float(shard["rot"]), Vector2(scale_f, scale_f))

			var poly: PackedVector2Array = shard["poly"]
			var core_col := Color(1.0, 0.98, 0.96, alpha).lerp(accent.lerp(Color(0.85, 0.70, 0.75, alpha), 0.5), clampf(t * 1.4, 0.0, 1.0))
			core_col.a = alpha

			health_bar_canvas.draw_colored_polygon(poly, core_col)
			health_bar_canvas.draw_polyline(poly, Color(0.05, 0.03, 0.06, alpha * 0.95), 1.4, true)

		health_bar_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var rect := Rect2(Vector2.ZERO, health_bar_canvas.size)
	var inner := rect.grow(-2.0)

	health_bar_canvas.draw_rect(rect, Color(0.05, 0.06, 0.08, 0.98), true)
	health_bar_canvas.draw_rect(rect, Color(0.28, 0.31, 0.36, 1.0), false, 1.0)
	health_bar_canvas.draw_rect(inner, Color(0.11, 0.13, 0.16, 0.95), true)

	var cap := maxf(1.0, _display_max_cap)
	var px := inner.size.x / cap   # pixels per HP point

	# Layout in HP units, left → right:  [HP][heal][shield][shield gain][chip]
	var hp_end := maxf(_display_hp, _target_hp)
	var sh_disp_end := hp_end + _display_shield
	var sh_end := hp_end + maxf(_display_shield, _target_shield)

	# 1. HP
	var hp_rect := _bar_rect(inner, px, 0.0, _display_hp)
	if hp_rect.size.x > 0.0:
		var base_col := Color(0.20, 0.80, 0.26, 1.0) if unit.is_ally else Color(0.86, 0.21, 0.21, 1.0)
		var top_bevel := Color(0.50, 0.96, 0.52, 0.45) if unit.is_ally else Color(1.0, 0.52, 0.50, 0.40)
		health_bar_canvas.draw_rect(hp_rect, base_col, true)
		health_bar_canvas.draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x, hp_rect.size.y * 0.38)), top_bevel, true)

	# 2. Heal preview (fills toward the real HP)
	if _target_hp > _display_hp + 0.01:
		health_bar_canvas.draw_rect(_bar_rect(inner, px, _display_hp, _target_hp), Color(0.55, 1.0, 0.48, 0.92), true)

	# 3. Shield: sits on top of HP's right edge
	if _display_shield > 0.001:
		var sh_flash := clampf(_shield_flash_timer / SHIELD_FLASH_TIME, 0.0, 1.0)
		var pulse := sin(sh_flash * PI) * 1.4
		var sh_rect := _bar_rect(inner, px, hp_end, sh_disp_end, pulse)
		var sh_col := Color(0.88, 0.91, 0.96, 1.0).lerp(Color(0.78, 0.98, 1.0, 1.0), sh_flash)
		health_bar_canvas.draw_rect(sh_rect, sh_col, true)
		health_bar_canvas.draw_rect(Rect2(sh_rect.position, Vector2(sh_rect.size.x, sh_rect.size.y * 0.4)), Color(1, 1, 1, 0.75), true)
		if sh_flash > 0.01:
			health_bar_canvas.draw_rect(sh_rect.grow(1.0), Color(0.65, 0.95, 1.0, sh_flash * 0.85), false, 1.2)

	# 4. Shield gain lead
	if _target_shield > _display_shield + 0.01:
		health_bar_canvas.draw_rect(_bar_rect(inner, px, sh_disp_end, sh_end), Color(0.65, 0.95, 1.0, 0.85), true)

	# 5. Damage chip: everything just lost (shield + HP), drains after a hold
	if _chip_total > sh_end + 0.01:
		var flash_t := clampf(_hit_flash_timer / HIT_FLASH_TIME, 0.0, 1.0)
		var chip_col := Color(0.92, 0.25, 0.18, 0.95).lerp(Color(1.0, 0.92, 0.75, 1.0), flash_t)
		health_bar_canvas.draw_rect(_bar_rect(inner, px, sh_end, _chip_total), chip_col, true)

	# 6. HP | shield divider
	if _display_shield > 0.001 and hp_end > 0.0:
		var dx := inner.position.x + hp_end * px
		health_bar_canvas.draw_line(Vector2(dx, inner.position.y), Vector2(dx, inner.end.y), Color(0.05, 0.06, 0.08, 0.9), 1.0, true)

	# 7. Ticks (span the whole scaled bar, like LoL)
	var minor_step: float = _get_tick_step(cap)
	var tick_index: int = 1
	var tick_hp: float = minor_step
	while tick_hp < cap - 0.05:
		var x := inner.position.x + tick_hp * px
		var is_major := (tick_index % 5 == 0)
		var tick_h := inner.size.y if is_major else inner.size.y * 0.58
		var tick_w := 1.6 if is_major else 1.0
		var tick_col := Color(0.03, 0.04, 0.05, 0.92) if is_major else Color(0.04, 0.05, 0.07, 0.75)
		health_bar_canvas.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.position.y + tick_h), tick_col, tick_w, true)
		tick_index += 1
		tick_hp += minor_step


## Converts an HP range into a clamped rect inside the bar.
func _bar_rect(inner: Rect2, px: float, from_hp: float, to_hp: float, grow_y: float = 0.0) -> Rect2:
	var x1 := clampf(inner.position.x + from_hp * px, inner.position.x, inner.end.x)
	var x2 := clampf(inner.position.x + to_hp * px, inner.position.x, inner.end.x)
	return Rect2(x1, inner.position.y - grow_y * 0.5, maxf(0.0, x2 - x1), inner.size.y + grow_y)

func _get_tick_step(effective_max: float) -> float:
	if effective_max <= 30.0: return 5.0
	elif effective_max <= 150.0: return 10.0
	elif effective_max <= 400.0: return 25.0
	else: return 100.0

## skill_index: 1 for odd, 2 for even.
## rank: 0 normal, 1 merged/condition met, 2 double merged.
func play_skill_animation(skill_index: int, rank: int = 0) -> void:
	if sprite == null:
		return
	if sprite.has_method("play_skill_and_wait"):
		await sprite.play_skill_and_wait(skill_index, rank)
	elif sprite.has_method("play_skill"):
		sprite.play_skill(skill_index, rank)
		
# --- Skill HUD fade ----------------------------------------------------------

func _is_skill_anim(anim: StringName) -> bool:
	return sprite != null \
		and sprite.has_method("is_skill_animation") \
		and bool(sprite.call("is_skill_animation", anim))


func _on_sprite_action_started(anim: StringName) -> void:
	if _is_skill_anim(anim):
		_set_hud_hidden(true)


func _on_sprite_action_finished(anim: StringName) -> void:
	if _is_skill_anim(anim):
		_set_hud_hidden(false)


func _get_hud_nodes() -> Array[Control]:
	var nodes: Array[Control] = []
	if is_instance_valid(health_shield_container):
		nodes.append(health_shield_container)
	if is_instance_valid(status_icons_grid):
		nodes.append(status_icons_grid)
	return nodes


## Single source of truth: hidden while the intro OR a skill is running.
func _update_hud_visibility(instant: bool = false, duration: float = -1.0) -> void:
	_set_hud_hidden(_intro_active or _skill_hud_active, instant, duration)


## Fades the health bar and status icons. Uses modulate (not visible)
## so the VBox layout, and therefore the character, never shifts.
func _set_hud_hidden(hidden: bool, instant: bool = false, duration_override: float = -1.0) -> void:
	if _hud_hidden == hidden and not instant:
		return
	_hud_hidden = hidden

	if _hud_tween != null and _hud_tween.is_valid():
		_hud_tween.kill()
	_hud_tween = null

	var nodes := _get_hud_nodes()
	if nodes.is_empty():
		return

	var target_alpha: float = 0.0 if hidden else 1.0
	if instant:
		for n in nodes:
			n.modulate.a = target_alpha
		return

	var duration: float = duration_override if duration_override >= 0.0 \
		else (hud_fade_out_time if hidden else hud_fade_in_time)
	_hud_tween = create_tween().set_parallel(true)
	_hud_tween.set_trans(Tween.TRANS_SINE)
	_hud_tween.set_ease(Tween.EASE_IN if hidden else Tween.EASE_OUT)
	for n in nodes:
		_hud_tween.tween_property(n, "modulate:a", target_alpha, duration)

#region Intro fade

## Hides HUD + intent, then fades them in once the born animation ends.
## Called automatically by setup(). Call again with extra_delay to stagger units.
func play_intro(extra_delay: float = 0.0) -> void:
	_kill_intro_tween()

	# If an intent is already on screen (replayed intro), save it so it fades back in.
	if _intent_visible and not _intro_active and intent_label.text != "":
		_pending_intent = {
			"text": intent_label.text,
			"categories": PackedStringArray(),
			"delay": 0.0,
		}
	_intro_active = true

	_kill_intent_tween()
	_intent_visible = false
	intent_label.modulate.a = 0.0
	_update_hud_visibility(true)

	var delay: float = maxf(0.0, _get_intro_duration() + intro_extra_delay + extra_delay)
	_intro_tween = create_tween()
	_intro_tween.tween_interval(delay)
	_intro_tween.tween_callback(_finish_intro)


func _finish_intro() -> void:
	_intro_tween = null
	if not _intro_active:
		return
	_intro_active = false
	_update_hud_visibility(false, intro_fade_in_time)

	if not _pending_intent.is_empty():
		var p: Dictionary = _pending_intent
		_pending_intent = {}
		# The original stagger delay still applies, so intents cascade in.
		show_intent(p["text"], p["categories"], float(p["delay"]))


func _cancel_intro() -> void:
	_kill_intro_tween()
	_intro_active = false
	_pending_intent = {}


func _kill_intro_tween() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null


func _get_intro_duration() -> float:
	if sprite != null and sprite.has_method("get_intro_duration"):
		return float(sprite.call("get_intro_duration"))
	return 0.0  # Fallback TextureRect: fade in right away.
	
#endregion

func set_manual_statuses(statuses: Array[Dictionary]) -> void:
	_manual_statuses = statuses
	_last_status_signature = ""
	_refresh_status_icons()

func _refresh_status_icons() -> void:
	if status_icons_grid == null or unit == null: return

	var statuses: Array[Dictionary] = _manual_statuses.duplicate()
	if statuses.is_empty() and status_icon_catalog != null:
		statuses = status_icon_catalog.extract_unit_statuses(unit)

	var sig := str(statuses)
	if sig == _last_status_signature: return
	_last_status_signature = sig

	for child in status_icons_grid.get_children():
		child.queue_free()

	for st in statuses:
		var badge := _create_e7_status_badge(st.get("icon", PLACEHOLDER_ICON), int(st.get("count", 1)), bool(st.get("is_debuff", false)))
		status_icons_grid.add_child(badge)

func _create_e7_status_badge(tex: Texture2D, count: int, is_debuff: bool) -> Control:
	var box := Panel.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.10, 0.14, 0.94)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.85, 0.25, 0.25, 0.9) if is_debuff else Color(0.20, 0.72, 1.0, 0.9)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	box.add_theme_stylebox_override("panel", bg)

	var icon_rect := TextureRect.new()
	icon_rect.texture = tex if tex != null else PLACEHOLDER_ICON
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 3
	icon_rect.offset_top = 3
	icon_rect.offset_right = -3
	icon_rect.offset_bottom = -3
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = Color(1.0, 0.38, 0.38) if is_debuff else Color(0.22, 0.78, 1.0)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_rect)

	var count_lbl := Label.new()
	count_lbl.text = str(maxi(1, count))
	count_lbl.position = Vector2(1, -3)
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color.WHITE)
	count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	count_lbl.add_theme_constant_override("outline_size", 4)
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(count_lbl)

	return box

## delay: seconds to wait before fading in (used to stagger enemies).
func show_intent(text: String, _categories: PackedStringArray, delay: float = 0.0) -> void:
	# During the intro, save the request. _finish_intro() replays it.
	if _intro_active:
		_pending_intent = {"text": text, "categories": _categories, "delay": delay}
		return
		
	# Already showing (or fading in) this exact text, so don't restart and flicker.
	if _intent_visible and intent_label.text == text:
		return

	_kill_intent_tween()
	_intent_visible = true

	# Different text is still on screen: fade the old text out before swapping.
	var needs_swap := intent_label.text != text and intent_label.modulate.a > 0.01

	_intent_tween = create_tween()
	if delay > 0.0:
		_intent_tween.tween_interval(delay)

	if needs_swap:
		_intent_tween.tween_property(intent_label, "modulate:a", 0.0, intent_fade_out_time * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_intent_tween.tween_callback(func() -> void: intent_label.text = text)
	else:
		intent_label.text = text

	# Fades from the current alpha, so an interrupted fade-out turns back smoothly.
	_intent_tween.tween_property(intent_label, "modulate:a", 1.0, intent_fade_in_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## animated = true fades out; false hides instantly.
func clear_intent(animated: bool = false) -> void:
	_pending_intent = {}
	_intent_visible = false
	_kill_intent_tween()

	if not animated or intent_label.modulate.a <= 0.01:
		intent_label.text = ""
		intent_label.modulate.a = 0.0
		return

	# Text stays (invisible) so the layout doesn't jump mid-attack.
	_intent_tween = create_tween()
	_intent_tween.tween_property(intent_label, "modulate:a", 0.0, intent_fade_out_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _kill_intent_tween() -> void:
	if _intent_tween and _intent_tween.is_valid():
		_intent_tween.kill()
	_intent_tween = null

func set_target_highlight(highlight: bool) -> void:
	_is_target_highlighted = highlight
	_update_glow_visibility()

func _update_glow_visibility() -> void:
	if _is_target_highlighted:
		hover_glow.visible = true
		hover_glow.modulate = Color(1.0, 0.35, 0.35, 1.0)
	elif _is_drag_hovering:
		hover_glow.visible = true
		hover_glow.modulate = Color.WHITE
	else:
		hover_glow.visible = false
		hover_glow.modulate = Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		unit_clicked.emit(unit)

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	var drag: CardDrag = data as CardDrag
	if drag == null or unit == null or unit.is_dead or not unit.is_ally:
		if _is_drag_hovering: _reset_preview()
		return false

	_is_drag_hovering = true
	_update_glow_visibility()
	skill_preview_box.visible = true

	var is_merged: bool = drag.card.is_merged or drag.card.is_double_merged
	if drag.card.is_odd():
		skill_1_row.modulate = Color(1.3, 1.3, 1.0, 1.0)
		skill_2_row.modulate = Color(0.5, 0.5, 0.5, 0.5)
		_render_skill_preview_icons(skill_1_icons, unit.data.skill_1, is_merged)
	else:
		skill_2_row.modulate = Color(1.3, 1.3, 1.0, 1.0)
		skill_1_row.modulate = Color(0.5, 0.5, 0.5, 0.5)
		_render_skill_preview_icons(skill_2_icons, unit.data.skill_2, is_merged)

	return true

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var drag: CardDrag = data as CardDrag
	_reset_preview()
	if drag != null:
		card_dropped_on_unit.emit(drag.card, unit)

func _play_skill_animation_for_card(card: Card) -> void:
	if not sprite or not sprite.has_method("play_animation"): return

	if card.is_odd():
		if card.is_double_merged:
			sprite.play_animation(&"skill1_2")
		elif card.is_merged:
			sprite.play_animation(&"skill1_1")
		else:
			sprite.play_animation(&"skill1")
	else:
		sprite.play_animation(&"skill2_1")

func play_character_animation(anim_name: StringName) -> void:
	if sprite and sprite.has_method("play_animation"):
		sprite.play_animation(anim_name)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if _is_drag_hovering: _reset_preview()

func _reset_preview() -> void:
	_is_drag_hovering = false
	_update_glow_visibility()
	skill_preview_box.visible = false
	skill_1_row.modulate = Color.WHITE
	skill_2_row.modulate = Color.WHITE
	if unit and unit.data:
		_render_skill_preview_icons(skill_1_icons, unit.data.skill_1, false)
		_render_skill_preview_icons(skill_2_icons, unit.data.skill_2, false)

func _render_skill_preview_icons(container: HBoxContainer, skill: SkillData, is_merged: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	if skill == null or icon_catalog == null: return

	var categories: PackedStringArray = skill.get_active_categories(is_merged)
	for cat in categories:
		var tex := icon_catalog.get_icon(cat)
		if tex == null: tex = PLACEHOLDER_ICON
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(16, 16)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(rect)

func _load_unit_texture(target_sprite: Control, unit_display_name: String) -> void:
	if target_sprite.has_method("configure_from_unit"):
		target_sprite.configure_from_unit(unit_display_name, not unit.is_ally)
		
		if target_sprite.has_method("set_skeleton_data"):
			# 1. OVERRIDE SYSTEM (The "Tickle Toggle")
			if use_override_spine and override_spine_data != null:
				target_sprite.set_skeleton_data(override_spine_data)
				return
				
			# 2. AUTOMATED FOLDER SEARCH
			var regex := RegEx.new()
			regex.compile("[^a-zA-Z0-9]")
			var normalized_target := regex.sub(unit_display_name, "", true).to_lower()
			
			var spine_dir := SPINE_BASE_DIR + normalized_target + "/"
			if DirAccess.dir_exists_absolute(spine_dir):
				var dir := DirAccess.open(spine_dir)
				if dir:
					dir.list_dir_begin()
					var file_name := dir.get_next()
					while file_name != "":
						if file_name.ends_with(".tres"):
							var loaded_tres := load(spine_dir + file_name)
							if loaded_tres:
								target_sprite.set_skeleton_data(loaded_tres)
								break
						file_name = dir.get_next()
					dir.list_dir_end()
		return

	var texture_rect := target_sprite as TextureRect
	if texture_rect == null: return

	texture_rect.texture = PLACEHOLDER_ICON
	var dir_path := "res://Scenes/GameUI/Textures/sampleUnits/"
	var dir := DirAccess.open(dir_path)
	if dir == null: return

	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9]")
	var normalized_target := regex.sub(unit_display_name, "", true).to_lower()

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			var base_name := file_name.get_basename()
			var normalized_file := regex.sub(base_name, "", true).to_lower()
			if normalized_file == normalized_target:
				var clean_path := dir_path + file_name.trim_suffix(".import")
				var loaded := load(clean_path) as Texture2D
				if loaded != null: texture_rect.texture = loaded
				dir.list_dir_end()
				return
		file_name = dir.get_next()
	dir.list_dir_end()

func _ignore_mouse_recursively(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_recursively(child)
		
func _get_effective_hit_flash_delay() -> float:
	if hit_flash_delay > 0.0:
		return hit_flash_delay
	if sprite != null:
		var v: Variant = sprite.get("hit_reaction_delay")
		if v != null:
			return float(v)
	return 0.0
	
func _get_effective_death_delay() -> float:
	if sprite != null:
		var v: Variant = sprite.get("death_animation_delay")
		if v != null:
			return float(v)
	return 0.0
	
func _bind_unit(p_unit: Unit) -> void:
	if unit != null and unit.damaged.is_connected(_on_unit_damaged):
		unit.damaged.disconnect(_on_unit_damaged)
	unit = p_unit
	if unit != null and not unit.damaged.is_connected(_on_unit_damaged):
		unit.damaged.connect(_on_unit_damaged)


func _reset_bar_state() -> void:
	_display_hp = clampf(float(unit.current_hp), 0.0, float(unit.max_hp))
	_display_shield = maxf(0.0, float(unit.shield))
	_target_hp = _display_hp
	_target_shield = _display_shield
	_prev_target_shield = _display_shield
	_chip_total = _display_hp + _display_shield
	_chip_hold_timer = 0.0
	_display_max_cap = maxf(float(unit.max_hp), _chip_total)
	_hit_flash_timer = 0.0
	_shield_flash_timer = 0.0
	_clear_pending_hits()


func _clear_pending_hits() -> void:
	_pending_hits.clear()
	_withheld_hp = 0.0
	_withheld_shield = 0.0


## The model already changed. Hold the bar at its pre-hit values until the
## hit animation connects, then drop everything in one go.
func _on_unit_damaged(hp_lost: int, shield_lost: int) -> void:
	if _was_dead or (hp_lost <= 0 and shield_lost <= 0):
		return

	_pending_hits.append({
		"delay": _get_effective_hit_flash_delay(),
		"hp": float(hp_lost),
		"shield": float(shield_lost),
	})
	_withheld_hp += float(hp_lost)
	_withheld_shield += float(shield_lost)

	# Fires for shield-only hits too.
	if sprite.has_method("play_hit"):
		sprite.play_hit()
	elif sprite.has_method("play_animation"):
		sprite.play_animation(&"hit", false)
