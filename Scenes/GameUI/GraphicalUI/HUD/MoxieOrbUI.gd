# res://Scenes/GameUI/GraphicalUI/HUD/MoxieOrbUI.gd
class_name MoxieOrbUI
extends Control

signal orb_activated(unit: Unit)
signal orb_hover_started(orb: MoxieOrbUI, unit: Unit)
signal orb_hover_ended(orb: MoxieOrbUI, unit: Unit)

const ORB_SCALE: float = 1.3

const MEDALLION_SIZE := Vector2(64.0, 64.0) * ORB_SCALE
const ORB_RADIUS: float = 25.5 * ORB_SCALE
const INNER_RADIUS: float = 18.0 * ORB_SCALE
const ORB_GLOW_BLEED: float = 13.0 * ORB_SCALE
const SEGMENT_DIVIDERS: int = 10 # Matches 10-wedge crystal socket bezel

const PORTRAIT_SHADER: Shader = preload(
	"res://Scenes/GameUI/GraphicalUI/HUD/MoxieOrbPortrait.gdshader"
)
const RING_SHADER: Shader = preload(
	"res://Scenes/GameUI/GraphicalUI/HUD/MoxieOrbRing.gdshader"
)
const PLACEHOLDER_PORTRAIT: Texture2D = preload(
	"res://Scenes/GameUI/GraphicalUI/BattleScene/Assests/icon.svg"
)

# === Outer Glow (Enemy override; Ally uses ready_glow_preset) ===
const ENEMY_GLOW_CORE := Color(0.976, 0.408, 0.0, 1.0)
const ENEMY_GLOW_MID  := Color(0.96, 0.26, 0.18, 1.0)
const ENEMY_GLOW_DEEP := Color(0.52, 0.05, 0.08, 1.0)

# === Recessed Empty Socket Colors ===
const SOCKET_GROOVE_COLOR      := Color(0.025, 0.032, 0.045) # #06080B dark divider groove
const ALLY_SOCKET_FLOOR_COLOR  := Color(0.075, 0.105, 0.155) # #131B28 cold slate socket floor
const ENEMY_SOCKET_FLOOR_COLOR := Color(0.115, 0.068, 0.082) # #1D1115 dark iron socket floor

# === Ally LoR Crystal Ramps (Deep Rim -> Electric Mid -> Incandescent Core) ===
const ALLY_CRYSTAL_CHARGING_DEEP := Color("#0A2463") # Midnight sapphire rim
const ALLY_CRYSTAL_CHARGING_MID  := Color("#1D70E8") # Royal Hextech cobalt
const ALLY_CRYSTAL_CHARGING_CORE := Color("#8AF0FF") # Luminous sky-cyan center

const ALLY_CRYSTAL_READY_DEEP    := Color("#1248A8") # Deep sapphire socket border
const ALLY_CRYSTAL_READY_MID     := Color("#2ED4FF") # Blazing electric cyan
const ALLY_CRYSTAL_READY_CORE    := Color("#F0FFFF") # Incandescent white-ice core

# === Enemy Crystal Ramps ===
const ENEMY_CRYSTAL_NORMAL_DEEP  := Color("#420711") # Dark blood-garnet rim
const ENEMY_CRYSTAL_NORMAL_MID   := Color("#BD1928") # Rich crimson-ruby
const ENEMY_CRYSTAL_NORMAL_CORE  := Color("#FF7A6B") # Glowing scarlet-coral core

const ENEMY_CRYSTAL_WARN_DEEP    := Color("#6E0F14") # Molten ruby rim
const ENEMY_CRYSTAL_WARN_MID     := Color("#FA3D22") # Blazing vermilion
const ENEMY_CRYSTAL_WARN_CORE    := Color("#FFE6B8") # White-hot ember core

# === Preview / Overcharge Crystal Ramps (Built around #8EC5F5 & #E89BA0) ===
const ALLY_PREVIEW_DEEP  := Color("#1F4B85")
const ALLY_PREVIEW_COLOR := Color("#8EC5F5")
const ALLY_PREVIEW_CORE  := Color("#EEFAFF")

const ENEMY_PREVIEW_DEEP  := Color("#6B222C")
const ENEMY_PREVIEW_COLOR := Color("#E89BA0")
const ENEMY_PREVIEW_CORE  := Color("#FFF0F2")

# === Bezel Colors (RGB only — alpha is applied in _draw) ===
const ALLY_BEZEL_DEFAULT  := Color(0.36, 0.44, 0.52)  # #5C7085 cool gunmetal steel
const ALLY_BEZEL_HOVER    := Color(0.58, 0.70, 0.82)  # #94B3D1 frosted steel
const ALLY_BEZEL_READY    := Color(0.84, 0.96, 1.00)  # #D6F5FF incandescent ice
const ENEMY_BEZEL_DEFAULT := Color(0.42, 0.23, 0.25)  # #6B3B40 dark blood-iron
const ENEMY_BEZEL_HOVER   := Color(0.68, 0.34, 0.35)  # #AD5759 burnished crimson-copper
const ENEMY_BEZEL_WARNING := Color(1.00, 0.74, 0.58)  # #FFBD94 hot ember filament

const BEZEL_DEFAULT_ALPHA := 0.94

# === Spark Flare Colors (glowing / ready states) ===
const ALLY_SPARK_HALO  := Color(0.14, 0.72, 1.00)   # outer blue bloom
const ALLY_SPARK_MID   := Color(0.68, 0.95, 1.00)   # cyan body
const ALLY_SPARK_CORE  := Color(0.95, 0.99, 1.00)   # near-white hot center

const ENEMY_SPARK_HALO := Color(0.98, 0.26, 0.16)   # outer red bloom
const ENEMY_SPARK_MID  := Color(1.00, 0.68, 0.44)   # orange body
const ENEMY_SPARK_CORE := Color(1.00, 0.96, 0.90)   # warm-white hot center

# === Spark Flare Preview Modifiers ===
const PREVIEW_SPARK_HALO_DARKEN := 0.18
const PREVIEW_SPARK_MID_LIGHTEN := 0.28
const PREVIEW_SPARK_CORE        := Color(0.97, 0.99, 1.00)

# === Spark Flare Alphas & Sizes ===
const SPARK_HALO_ALPHA  := 0.45
const SPARK_MID_ALPHA   := 0.88
const SPARK_HALO_RADIUS := 5.6 * ORB_SCALE
const SPARK_MID_RADIUS  := 3.1 * ORB_SCALE
const SPARK_CORE_RADIUS := 1.5 * ORB_SCALE
const SPARK_PULSE_BASE  := 0.85
const SPARK_PULSE_AMP   := 0.15
const SPARK_PULSE_SPEED := 5.0

@export var ready_glow_preset: OutlineGlow.Preset = OutlineGlow.Preset.RUNETERRA_BLUE

var unit: Unit
var badge_code: String = "A1"
var interactable: bool = true

var _orb_bounds: Control
var _glow: OutlineGlow
var _glow_active: bool = false
var _glow_is_ally: bool = true
var _has_cached_ally_colors: bool = false
var _enemy_colors_applied: bool = false
var _ally_glow_core: Color
var _ally_glow_mid: Color
var _ally_glow_deep: Color

var _portrait_rect: ColorRect
var _portrait_mat: ShaderMaterial
var _has_portrait: bool = false

var _ring_rect: ColorRect
var _ring_mat: ShaderMaterial

var _display_moxie: float = 0.0
var _ready_blend: float = 0.0
var _hover_blend: float = 0.0
var _preview_gain: int = 0
var _is_hovered: bool = false
var _is_pressed: bool = false
var _burst_timer: float = 0.0
var _anim_time: float = 0.0


func _init() -> void:
	custom_minimum_size = MEDALLION_SIZE
	size = MEDALLION_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = MEDALLION_SIZE * 0.5
	_build_glow_node()
	_build_portrait_node()
	_build_ring_node()
	_layout_subrects()
	_sync_ring_shader()


func _ready() -> void:
	_layout_subrects()
	_glow = OutlineGlow.attach_to(_orb_bounds, ORB_RADIUS, ORB_GLOW_BLEED)
	_sync_glow()
	_sync_ring_shader()


func _build_glow_node() -> void:
	_orb_bounds = Control.new()
	_orb_bounds.name = "OrbGlowBounds"
	_orb_bounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_bounds.show_behind_parent = true
	add_child(_orb_bounds)


func _build_portrait_node() -> void:
	_portrait_mat = ShaderMaterial.new()
	_portrait_mat.shader = PORTRAIT_SHADER

	_portrait_rect = ColorRect.new()
	_portrait_rect.name = "PortraitRect"
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.show_behind_parent = true
	_portrait_rect.material = _portrait_mat
	add_child(_portrait_rect)

	set_portrait(PLACEHOLDER_PORTRAIT)


func _build_ring_node() -> void:
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING_SHADER
	_ring_mat.set_shader_parameter("outer_radius", ORB_RADIUS)
	_ring_mat.set_shader_parameter("inner_radius", INNER_RADIUS)
	_ring_mat.set_shader_parameter("segments", SEGMENT_DIVIDERS)
	_ring_mat.set_shader_parameter("socket_groove_col", SOCKET_GROOVE_COLOR)

	_ring_rect = ColorRect.new()
	_ring_rect.name = "MoxieRingRect"
	_ring_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_rect.show_behind_parent = true
	_ring_rect.material = _ring_mat
	add_child(_ring_rect)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_subrects()
	elif what == NOTIFICATION_MOUSE_ENTER:
		_is_hovered = true
		_update_cursor()
		if unit != null:
			orb_hover_started.emit(self, unit)
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_is_hovered = false
		_is_pressed = false
		if unit != null:
			orb_hover_ended.emit(self, unit)
		queue_redraw()


func _layout_subrects() -> void:
	var c := size * 0.5
	if _orb_bounds != null:
		_orb_bounds.position = c - Vector2(ORB_RADIUS, ORB_RADIUS)
		_orb_bounds.size = Vector2(ORB_RADIUS * 2.0, ORB_RADIUS * 2.0)
	if _portrait_rect != null:
		var r := INNER_RADIUS + (0.8 * ORB_SCALE)
		_portrait_rect.position = c - Vector2(r, r)
		_portrait_rect.size = Vector2(r * 2.0, r * 2.0)
	if _ring_rect != null:
		var rr := ORB_RADIUS + (1.5 * ORB_SCALE)
		_ring_rect.position = c - Vector2(rr, rr)
		_ring_rect.size = Vector2(rr * 2.0, rr * 2.0)
		_ring_mat.set_shader_parameter("rect_half_size", rr)


func bind_unit(p_unit: Unit, p_badge_code: String, p_portrait: Texture2D = null) -> void:
	if unit != null and unit.moxie_changed.is_connected(_on_unit_moxie_changed):
		unit.moxie_changed.disconnect(_on_unit_moxie_changed)

	unit = p_unit
	badge_code = p_badge_code
	_preview_gain = 0

	if unit != null:
		_display_moxie = float(unit.moxie)
		_ready_blend = 1.0 if _should_show_glow() else 0.0
		if not unit.moxie_changed.is_connected(_on_unit_moxie_changed):
			unit.moxie_changed.connect(_on_unit_moxie_changed)
	else:
		_display_moxie = 0.0
		_ready_blend = 0.0

	set_portrait(p_portrait)
	_layout_subrects()
	_update_cursor()
	_sync_glow()
	_sync_ring_shader()
	queue_redraw()


func set_portrait(tex: Texture2D = null) -> void:
	var resolved: Texture2D = tex if tex != null else PLACEHOLDER_PORTRAIT
	if resolved == null:
		_has_portrait = false
		_portrait_rect.visible = false
		return

	_has_portrait = true
	_portrait_rect.visible = true

	if resolved is AtlasTexture:
		var at := resolved as AtlasTexture
		if at.atlas != null:
			var atlas_sz := at.atlas.get_size()
			var reg := at.region
			_portrait_mat.set_shader_parameter("portrait_tex", at.atlas)
			_portrait_mat.set_shader_parameter("atlas_uv_rect", Vector4(
				reg.position.x / maxf(1.0, atlas_sz.x),
				reg.position.y / maxf(1.0, atlas_sz.y),
				reg.size.x / maxf(1.0, atlas_sz.x),
				reg.size.y / maxf(1.0, atlas_sz.y)
			))
			_portrait_mat.set_shader_parameter("tex_aspect", reg.size)
			return

	_portrait_mat.set_shader_parameter("portrait_tex", resolved)
	_portrait_mat.set_shader_parameter("atlas_uv_rect", Vector4(0.0, 0.0, 1.0, 1.0))
	_portrait_mat.set_shader_parameter("tex_aspect", resolved.get_size())


func set_preview_gain(amount: int) -> void:
	var clamped := maxi(0, amount)
	if _preview_gain != clamped:
		_preview_gain = clamped
		_sync_glow()
		_sync_ring_shader()
		queue_redraw()


func set_interactable(enabled: bool) -> void:
	interactable = enabled
	_update_cursor()
	_sync_ring_shader()
	queue_redraw()


func play_cast_burst() -> void:
	_burst_timer = 0.50
	queue_redraw()


func _on_unit_moxie_changed(_cur: int, _max: int) -> void:
	_update_cursor()
	_sync_glow()
	_sync_ring_shader()
	queue_redraw()


func _can_click_cast() -> bool:
	return unit != null and unit.is_ally and interactable and unit.can_cast_ultimate


func _should_show_glow() -> bool:
	if unit == null or unit.is_dead:
		return false
	if unit.is_ally:
		return unit.can_cast_ultimate
	var has_ult := unit.data != null and unit.data.ultimate != null
	return unit.can_cast_ultimate or (has_ult and (unit.moxie + _preview_gain >= unit.max_moxie))


func _sync_ring_shader() -> void:
	if _ring_mat == null:
		return

	var is_dead := unit == null or unit.is_dead
	var is_ally := unit == null or unit.is_ally
	var max_m := maxi(1, unit.max_moxie if unit != null else 20)
	var alpha_mul := 0.35 if is_dead else 1.0
	var fill_ratio := clampf(_display_moxie / float(max_m), 0.0, 1.0)

	var prev_start := 0.0
	var prev_end := 0.0
	var over_ratio := 0.0
	if not is_dead and _preview_gain > 0 and unit != null:
		var gain_ratio := float(_preview_gain) / float(max_m)
		var total_ratio := fill_ratio + gain_ratio
		if fill_ratio < 1.0:
			prev_start = fill_ratio
			prev_end = minf(1.0, total_ratio)
		if total_ratio > 1.0:
			over_ratio = clampf(total_ratio - 1.0, 0.0, 1.0)

	var c_deep: Color
	var c_mid: Color
	var c_core: Color
	if is_ally:
		c_deep = ALLY_CRYSTAL_CHARGING_DEEP.lerp(ALLY_CRYSTAL_READY_DEEP, _ready_blend)
		c_mid  = ALLY_CRYSTAL_CHARGING_MID.lerp(ALLY_CRYSTAL_READY_MID, _ready_blend)
		c_core = ALLY_CRYSTAL_CHARGING_CORE.lerp(ALLY_CRYSTAL_READY_CORE, _ready_blend)
		_ring_mat.set_shader_parameter("socket_floor_col", ALLY_SOCKET_FLOOR_COLOR)
		_ring_mat.set_shader_parameter("preview_deep", ALLY_PREVIEW_DEEP)
		_ring_mat.set_shader_parameter("preview_mid", ALLY_PREVIEW_COLOR)
		_ring_mat.set_shader_parameter("preview_core", ALLY_PREVIEW_CORE)
	else:
		c_deep = ENEMY_CRYSTAL_NORMAL_DEEP.lerp(ENEMY_CRYSTAL_WARN_DEEP, _ready_blend)
		c_mid  = ENEMY_CRYSTAL_NORMAL_MID.lerp(ENEMY_CRYSTAL_WARN_MID, _ready_blend)
		c_core = ENEMY_CRYSTAL_NORMAL_CORE.lerp(ENEMY_CRYSTAL_WARN_CORE, _ready_blend)
		_ring_mat.set_shader_parameter("socket_floor_col", ENEMY_SOCKET_FLOOR_COLOR)
		_ring_mat.set_shader_parameter("preview_deep", ENEMY_PREVIEW_DEEP)
		_ring_mat.set_shader_parameter("preview_mid", ENEMY_PREVIEW_COLOR)
		_ring_mat.set_shader_parameter("preview_core", ENEMY_PREVIEW_CORE)

	_ring_mat.set_shader_parameter("fill_ratio", fill_ratio)
	_ring_mat.set_shader_parameter("preview_start", prev_start)
	_ring_mat.set_shader_parameter("preview_end", prev_end)
	_ring_mat.set_shader_parameter("overcharge_ratio", over_ratio)
	_ring_mat.set_shader_parameter("ready_blend", _ready_blend)
	_ring_mat.set_shader_parameter("hover_boost", _hover_blend)
	_ring_mat.set_shader_parameter("alpha_mul", alpha_mul)
	_ring_mat.set_shader_parameter("fill_deep", c_deep)
	_ring_mat.set_shader_parameter("fill_mid", c_mid)
	_ring_mat.set_shader_parameter("fill_core", c_core)


func _sync_glow() -> void:
	if _glow == null:
		return

	var active := _should_show_glow()
	var is_ally := unit == null or unit.is_ally
	if active == _glow_active and (not active or is_ally == _glow_is_ally):
		return

	_glow_active = active
	_glow_is_ally = is_ally
	_glow.set_active(active, ready_glow_preset)

	if not active:
		return

	var mat := _glow.material as ShaderMaterial
	if mat == null:
		return

	if not is_ally:
		if not _has_cached_ally_colors:
			_ally_glow_core = mat.get_shader_parameter("color_core")
			_ally_glow_mid = mat.get_shader_parameter("color_mid")
			_ally_glow_deep = mat.get_shader_parameter("color_deep")
			_has_cached_ally_colors = true
		mat.set_shader_parameter("color_core", ENEMY_GLOW_CORE)
		mat.set_shader_parameter("color_mid", ENEMY_GLOW_MID)
		mat.set_shader_parameter("color_deep", ENEMY_GLOW_DEEP)
		_enemy_colors_applied = true
	elif _enemy_colors_applied and _has_cached_ally_colors:
		mat.set_shader_parameter("color_core", _ally_glow_core)
		mat.set_shader_parameter("color_mid", _ally_glow_mid)
		mat.set_shader_parameter("color_deep", _ally_glow_deep)
		_enemy_colors_applied = false


func _update_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_click_cast() else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if _can_click_cast():
				_is_pressed = true
				accept_event()
				queue_redraw()
		else:
			var was_pressed := _is_pressed
			_is_pressed = false
			queue_redraw()
			if was_pressed and _is_hovered and _can_click_cast():
				play_cast_burst()
				orb_activated.emit(unit)
				accept_event()


func _process(delta: float) -> void:
	if unit == null:
		return

	_anim_time += delta
	var target_moxie := float(unit.moxie)
	var moxie_moving := absf(_display_moxie - target_moxie) > 0.01
	if moxie_moving:
		_display_moxie = lerpf(target_moxie, _display_moxie, exp(-10.0 * delta))
	else:
		_display_moxie = target_moxie

	var target_ready := 1.0 if _should_show_glow() else 0.0
	var target_hover := 1.0 if (_is_hovered and not unit.is_dead) else 0.0
	var blend_moving := absf(_ready_blend - target_ready) > 0.005 or absf(_hover_blend - target_hover) > 0.005
	_ready_blend = move_toward(_ready_blend, target_ready, delta * 5.5)
	_hover_blend = move_toward(_hover_blend, target_hover, delta * 8.0)

	if _burst_timer > 0.0:
		_burst_timer = maxf(0.0, _burst_timer - delta)

	# Update portrait mood
	if _has_portrait:
		if unit.is_dead:
			_portrait_mat.set_shader_parameter("saturation", 0.0)
			_portrait_mat.set_shader_parameter("brightness", 0.45)
		elif unit.can_cast_ultimate:
			_portrait_mat.set_shader_parameter("saturation", 1.08)
			_portrait_mat.set_shader_parameter("brightness", 1.06 if _is_hovered else 1.0)
		else:
			_portrait_mat.set_shader_parameter("saturation", 0.88)
			_portrait_mat.set_shader_parameter("brightness", 0.94)

	var target_scale := Vector2.ONE
	if _is_pressed:
		target_scale = Vector2(0.94, 0.94)
	elif _is_hovered and not unit.is_dead:
		target_scale = Vector2(1.06, 1.06) if _can_click_cast() else Vector2(1.03, 1.03)
	pivot_offset = size * 0.5
	scale = scale.lerp(target_scale, clampf(delta * 14.0, 0.0, 1.0))

	_sync_glow()
	if moxie_moving or blend_moving:
		_sync_ring_shader()

	var enemy_threat := (not unit.is_ally) and (unit.moxie + _preview_gain >= unit.max_moxie) and not unit.is_dead
	if unit.can_cast_ultimate or enemy_threat or _preview_gain > 0 or _burst_timer > 0.0 or moxie_moving:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var is_dead := unit == null or unit.is_dead
	var is_ally := unit != null and unit.is_ally
	var max_m := maxi(1, unit.max_moxie if unit != null else 20)
	var cur_m := unit.moxie if unit != null else 0
	var is_ready := unit != null and unit.can_cast_ultimate
	var enemy_will_ult := unit != null and not is_ally and not is_dead \
		and unit.data != null and unit.data.ultimate != null and (cur_m + _preview_gain >= max_m)
	var glowing := (is_ready or enemy_will_ult) and not is_dead

	var alpha_mul := 0.35 if is_dead else 1.0
	var ring_mid_r := (ORB_RADIUS + INNER_RADIUS) * 0.5
	var start_ang := -PI * 0.5

	# 1. Cast ripple
	if _burst_timer > 0.0:
		var t := 1.0 - (_burst_timer / 0.50)
		var ripple_rgb := ALLY_BEZEL_READY if is_ally else ENEMY_BEZEL_WARNING
		draw_arc(
			center,
			lerpf(ORB_RADIUS, ORB_RADIUS + (16.0 * ORB_SCALE), ease(t, 0.35)),
			0.0, TAU, 40,
			_tint(ripple_rgb, (1.0 - t) * 0.75),
			2.2 * ORB_SCALE,
			true
		)

	# 2. Fallback dark center + monogram ONLY if no portrait texture was found
	if not _has_portrait:
		draw_circle(center, INNER_RADIUS, Color(0.07, 0.09, 0.11, 0.96 * alpha_mul))
		var font := ThemeDB.fallback_font
		if font != null:
			var f_size := int(13 * ORB_SCALE)
			var tw := font.get_string_size(badge_code, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size).x
			var tc := Color(0.82, 0.88, 0.95, 0.85 * alpha_mul)
			draw_string(font, Vector2(center.x - tw * 0.5, center.y + (5.0 * ORB_SCALE)),
				badge_code, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, tc)

	# 3. Inner & Outer Metallic Bezels (Moxie sockets & crystals render right underneath via _ring_rect)
	var bezel_rgb: Color
	var bezel_alpha: float = alpha_mul
	if is_ally:
		if is_ready:
			bezel_rgb = ALLY_BEZEL_READY.lightened(0.25) if (_is_hovered and interactable) else ALLY_BEZEL_READY
		elif _is_hovered and not is_dead:
			bezel_rgb = ALLY_BEZEL_HOVER
		else:
			bezel_rgb = ALLY_BEZEL_DEFAULT
			bezel_alpha = BEZEL_DEFAULT_ALPHA * alpha_mul
	else:
		if enemy_will_ult:
			bezel_rgb = ENEMY_BEZEL_WARNING
		elif _is_hovered and not is_dead:
			bezel_rgb = ENEMY_BEZEL_HOVER
		else:
			bezel_rgb = ENEMY_BEZEL_DEFAULT
			bezel_alpha = BEZEL_DEFAULT_ALPHA * alpha_mul

	draw_arc(center, ORB_RADIUS + (0.9 * ORB_SCALE), 0.0, TAU, 48,
		Color(0.03, 0.04, 0.05, 0.85 * alpha_mul), 1.2 * ORB_SCALE, true)
	draw_arc(center, ORB_RADIUS, 0.0, TAU, 48,
		_tint(bezel_rgb, bezel_alpha), 1.15 * ORB_SCALE, true)

	var inner_dim := 0.82 if glowing else 0.70
	draw_arc(center, INNER_RADIUS, 0.0, TAU, 48,
		_tint(bezel_rgb * inner_dim, bezel_alpha * 0.90), 1.0 * ORB_SCALE, true)

	# 4. Leading-Edge Spark Flare (sits on top of bezels & crystals)
	var spark_angle: float = NAN
	var spark_is_preview: bool = false
	if not is_dead and _preview_gain > 0:
		var fill_ratio := clampf(_display_moxie / float(max_m), 0.0, 1.0)
		var total_ratio := fill_ratio + float(_preview_gain) / float(max_m)
		if total_ratio > 1.0:
			spark_angle = start_ang + clampf(total_ratio - 1.0, 0.0, 1.0) * TAU
		else:
			spark_angle = start_ang + minf(1.0, total_ratio) * TAU
		spark_is_preview = true
	elif glowing:
		spark_angle = start_ang

	if not is_nan(spark_angle):
		var pulse := SPARK_PULSE_BASE + SPARK_PULSE_AMP * sin(_anim_time * SPARK_PULSE_SPEED)
		var tip := center + Vector2(cos(spark_angle), sin(spark_angle)) * ring_mid_r

		var halo_rgb: Color
		var mid_rgb: Color
		var core_rgb: Color
		if spark_is_preview:
			var p_rgb := ALLY_PREVIEW_COLOR if is_ally else ENEMY_PREVIEW_COLOR
			halo_rgb = p_rgb.darkened(PREVIEW_SPARK_HALO_DARKEN)
			mid_rgb  = p_rgb.lightened(PREVIEW_SPARK_MID_LIGHTEN)
			core_rgb = PREVIEW_SPARK_CORE
		elif is_ally:
			halo_rgb = ALLY_SPARK_HALO
			mid_rgb  = ALLY_SPARK_MID
			core_rgb = ALLY_SPARK_CORE
		else:
			halo_rgb = ENEMY_SPARK_HALO
			mid_rgb  = ENEMY_SPARK_MID
			core_rgb = ENEMY_SPARK_CORE

#region Helper Methods
static func _tint(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
#endregion
