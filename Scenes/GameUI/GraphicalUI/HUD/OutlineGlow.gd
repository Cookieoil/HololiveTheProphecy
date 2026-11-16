# res://Scenes/GameUI/GraphicalUI/HUD/OutlineGlow.gd
class_name OutlineGlow
extends ColorRect
## outer light border with scrolling sub-surface energy texture.

enum Preset {
	RUNETERRA_BLUE, # Classic LoR playable / orb-linked sky-blue
	ARCANE_GOLD,    # Merge / Ultimate ready gold
	THREAT_CRIMSON, # Enemy Ultimate warning
}

const GLOW_SHADER: Shader = preload(
	"res://Scenes/GameUI/GraphicalUI/HUD/OutlineGlow.gdshader"
)
const GROUP_GLOW_SHADER: Shader = preload(
	"res://Scenes/GameUI/GraphicalUI/HUD/OutlineGlowGroup.gdshader"
)

static var _shared_flow_tex: NoiseTexture2D
static var _silhouette_mipmap_cache: Dictionary[Variant, Texture2D] = {}

var glow_bleed: float = 15.0
var frame_corner_radius: float = 8.0

var _mat: ShaderMaterial
var _canvas_group: CanvasGroup
var _fade_tween: Tween
var _active: bool = false


static func attach_to(target_control: Control, p_corner_radius: float = 8.0, p_bleed: float = 15.0) -> OutlineGlow:
	var glow := OutlineGlow.new()
	glow.frame_corner_radius = p_corner_radius
	glow.glow_bleed = p_bleed
	if target_control != null and target_control.has_method("get_canvas_group"):
		var raw_group: Variant = target_control.call("get_canvas_group")
		if raw_group is CanvasGroup:
			var group: CanvasGroup = raw_group
			glow.bind_canvas_group(group)
	target_control.add_child(glow)
	return glow


func _init() -> void:
	name = "OutlineGlow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	visible = false
	_ensure_shared_resources()

	_mat = ShaderMaterial.new()
	_mat.shader = GLOW_SHADER
	_mat.set_shader_parameter("flow_tex", _shared_flow_tex)
	_mat.set_shader_parameter("intensity", 0.0)
	material = _mat


func bind_canvas_group(group: CanvasGroup) -> void:
	_canvas_group = group
	material = null
	color = Color.TRANSPARENT

	_mat.shader = GROUP_GLOW_SHADER
	_mat.set_shader_parameter("flow_tex", _shared_flow_tex)
	_mat.set_shader_parameter("glow_margin", glow_bleed)
	_mat.set_shader_parameter("intensity", 0.0)

	if _active and is_instance_valid(_canvas_group):
		_apply_group_active_margins()
		_canvas_group.material = _mat


func _ready() -> void:
	_mat.set_shader_parameter("glow_margin", glow_bleed)
	if _canvas_group != null:
		material = null
		color = Color.TRANSPARENT
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = -glow_bleed
	offset_top = -glow_bleed
	offset_right = glow_bleed
	offset_bottom = glow_bleed
	_mat.set_shader_parameter("corner_radius", frame_corner_radius)
	_sync_size()
	resized.connect(_sync_size)
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(_sync_size)


func _exit_tree() -> void:
	if is_instance_valid(_canvas_group) and _canvas_group.material == _mat:
		_canvas_group.material = null
		_canvas_group.use_mipmaps = false


func _apply_group_active_margins() -> void:
	if is_instance_valid(_canvas_group):
		_canvas_group.use_mipmaps = true
		_canvas_group.fit_margin = glow_bleed + 8.0
		# Extra clear padding prevents mipmap blur from sampling outside the cleared rect
		_canvas_group.clear_margin = glow_bleed * 2.5 + 24.0


func _on_fade_out_finished() -> void:
	hide()
	if is_instance_valid(_canvas_group):
		if _canvas_group.material == _mat:
			_canvas_group.material = null
		_canvas_group.use_mipmaps = false
		_canvas_group.fit_margin = 2.0
		_canvas_group.clear_margin = 4.0


func _sync_size() -> void:
	if _canvas_group == null and _mat != null and size.x > 1.0 and size.y > 1.0:
		_mat.set_shader_parameter("rect_size", size)


func set_active(enabled: bool, preset: Preset = Preset.RUNETERRA_BLUE) -> void:
	if enabled:
		apply_preset(preset)
	if _active == enabled:
		return
	_active = enabled

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if enabled:
		if is_instance_valid(_canvas_group):
			_apply_group_active_margins()
			_canvas_group.material = _mat
		else:
			visible = true
			_sync_size()
		_fade_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_fade_tween.tween_method(_set_intensity, _get_intensity(), 1.0, 0.14)
	else:
		_fade_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_fade_tween.tween_method(_set_intensity, _get_intensity(), 0.0, 0.12)
		_fade_tween.tween_callback(_on_fade_out_finished)


func apply_preset(preset: Preset) -> void:
	match preset:
		Preset.RUNETERRA_BLUE:
			_mat.set_shader_parameter("color_core", Color(0.80, 0.97, 1.00))
			_mat.set_shader_parameter("color_mid", Color(0.18, 0.70, 1.00))
			_mat.set_shader_parameter("color_deep", Color(0.06, 0.36, 0.92))
		Preset.ARCANE_GOLD:
			_mat.set_shader_parameter("color_core", Color(1.00, 0.97, 0.80))
			_mat.set_shader_parameter("color_mid", Color(0.96, 0.76, 0.24))
			_mat.set_shader_parameter("color_deep", Color(0.68, 0.38, 0.06))
		Preset.THREAT_CRIMSON:
			_mat.set_shader_parameter("color_core", Color(1.00, 0.82, 0.78))
			_mat.set_shader_parameter("color_mid", Color(0.98, 0.26, 0.24))
			_mat.set_shader_parameter("color_deep", Color(0.56, 0.05, 0.10))


func set_custom_flow_texture(tex: Texture2D) -> void:
	if _mat != null and tex != null:
		_mat.set_shader_parameter("flow_tex", tex)


func _set_intensity(val: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("intensity", val)


func _get_intensity() -> float:
	if _mat != null:
		var v: Variant = _mat.get_shader_parameter("intensity")
		if v is float:
			return v
	return 0.0


static func _ensure_shared_resources() -> void:
	if _shared_flow_tex == null:
		var noise := FastNoiseLite.new()
		noise.seed = 42
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 2
		noise.fractal_lacunarity = 2.1
		noise.fractal_gain = 0.35

		_shared_flow_tex = NoiseTexture2D.new()
		_shared_flow_tex.width = 128
		_shared_flow_tex.height = 128
		_shared_flow_tex.seamless = true
		_shared_flow_tex.seamless_blend_skirt = 0.25
		_shared_flow_tex.noise = noise


static func _ensure_mipmapped_silhouette(tex: Texture2D) -> Texture2D:
	if tex == null:
		return tex
	var key: Variant = tex.resource_path if not tex.resource_path.is_empty() else tex.get_rid()
	if _silhouette_mipmap_cache.has(key):
		var cached: Texture2D = _silhouette_mipmap_cache[key]
		if cached != null:
			return cached
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.has_mipmaps():
		return tex
	if img.is_compressed():
		img.decompress()
	if img.generate_mipmaps() != OK:
		return tex
	var mip_tex: ImageTexture = ImageTexture.create_from_image(img)
	_silhouette_mipmap_cache[key] = mip_tex
	return mip_tex


func set_silhouette(tex: Texture2D) -> void:
	if _canvas_group != null or _mat == null:
		return
	if tex == null:
		show_behind_parent = false
		_mat.set_shader_parameter("use_silhouette", false)
		return
	var mip_tex := _ensure_mipmapped_silhouette(tex)
	show_behind_parent = true
	_mat.set_shader_parameter("silhouette_tex", mip_tex)
	_mat.set_shader_parameter("silhouette_uv_rect_size", Vector2(mip_tex.get_width(), mip_tex.get_height()))
	_mat.set_shader_parameter("use_silhouette", true)
