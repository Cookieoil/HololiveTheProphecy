# res://Scenes/HUD/BattleResultPrompt.gd
class_name BattleResultPrompt
extends MarginContainer
## The end screen's action prompt, drawn the way big-budget menus do it: no box,
## no border and no fill at rest - just wide-tracked lettering flanked by two small
## diamonds, with a softly feathered wash that breathes in on hover and presses.
##
## It is a MarginContainer so it sizes itself from its label; the chrome is painted
## in `_draw()` underneath the text, and the text stays a real themed Label with a
## `FontVariation` for the tracking.
##
## @author TheGreatJellyfish
## @version 11/25/2026

#region Signals
signal pressed()
#endregion

#region Constants
const LABEL_TEXT: String = "PLAY AGAIN"
const FONT_SIZE: int = 15
## Letter spacing in pixels. The tracking is what makes the prompt read as
## typography instead of a form control.
const GLYPH_SPACING: int = 6

const PAD_X: int = 34
const PAD_Y: int = 13

const MARKER_HALF: float = 4.0
const MARKER_REST: float = 15.0
const MARKER_HOVER: float = 21.0
const MARKER_ALPHA_REST: float = 0.45
const MARKER_ALPHA_HOVER: float = 0.95

## The hover wash is painted as a coarse grid of rects, so both of its edges can
## fall off smoothly without a shader. Cheap, and only redrawn while the hover
## blend is moving.
const WASH_COLS: int = 26
const WASH_ROWS: int = 5
const WASH_PEAK: float = 0.42
const WASH_PRESS_BOOST: float = 1.25
const WASH_H_FEATHER: float = 0.26
const WASH_V_FEATHER: float = 0.42

const HOVER_TIME: float = 0.18

const TEXT_REST: Color = Color(0.82, 0.85, 0.90, 0.90)
const TEXT_HOVER: Color = Color(0.98, 0.95, 0.86, 1.0)
const WASH_COLOR: Color = Color(0.02, 0.02, 0.03, 1.0)
const MARKER_COLOR: Color = Color(0.94, 0.88, 0.72, 1.0)
#endregion

#region Public Variables
## False while the cutscene is still playing: a disabled prompt takes no clicks.
var interactive: bool = true
#endregion

#region Private Variables
var _label: Label
var _font_variation: FontVariation
var _hover_blend: float = 0.0
var _hover_tween: Tween
var _is_hovered: bool = false
var _is_pressed: bool = false
#endregion


#region Lifecycle Methods
func _init() -> void:
	name = "BattleResultPrompt"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_constant_override("margin_left", PAD_X)
	add_theme_constant_override("margin_right", PAD_X)
	add_theme_constant_override("margin_top", PAD_Y)
	add_theme_constant_override("margin_bottom", PAD_Y)

	_font_variation = FontVariation.new()
	_font_variation.spacing_glyph = GLYPH_SPACING

	_label = Label.new()
	_label.name = "PromptLabel"
	_label.text = LABEL_TEXT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", _font_variation)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_REST)
	add_child(_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
#endregion

#region Public Methods
## Gates the prompt: a disabled prompt takes no clicks and stops pointing.
func set_interactive(enabled: bool) -> void:
	interactive = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	if not enabled:
		_is_pressed = false
		_set_hovered(false)
#endregion

#region Private Methods
func _draw() -> void:
	var marker_alpha: float = lerpf(MARKER_ALPHA_REST, MARKER_ALPHA_HOVER, _hover_blend)
	var marker_x: float = lerpf(MARKER_REST, MARKER_HOVER, _hover_blend)
	if _is_pressed:
		marker_x -= 2.0
	var centre_y: float = size.y * 0.5
	var tint: Color = Color(MARKER_COLOR.r, MARKER_COLOR.g, MARKER_COLOR.b, marker_alpha)
	_draw_marker(Vector2(marker_x, centre_y), tint)
	_draw_marker(Vector2(size.x - marker_x, centre_y), tint)

	var wash: float = WASH_PEAK * _hover_blend * (WASH_PRESS_BOOST if _is_pressed else 1.0)
	if wash > 0.002:
		_draw_wash(wash)


## A soft horizontal band: the alpha falls off towards all four edges, so nothing
## about it reads as a filled rectangle.
func _draw_wash(peak: float) -> void:
	var cell_w: float = size.x / float(WASH_COLS)
	var cell_h: float = size.y / float(WASH_ROWS)
	for row: int in WASH_ROWS:
		var v: float = (float(row) + 0.5) / float(WASH_ROWS)
		var vertical: float = smoothstep(0.0, WASH_V_FEATHER, v) \
			* smoothstep(1.0, 1.0 - WASH_V_FEATHER, v)
		for col: int in WASH_COLS:
			var u: float = (float(col) + 0.5) / float(WASH_COLS)
			var horizontal: float = smoothstep(0.0, WASH_H_FEATHER, u) \
				* smoothstep(1.0, 1.0 - WASH_H_FEATHER, u)
			var alpha: float = peak * horizontal * vertical
			if alpha <= 0.002:
				continue
			var cell := Rect2(
				Vector2(float(col) * cell_w, float(row) * cell_h),
				Vector2(cell_w + 1.0, cell_h + 1.0)
			)
			draw_rect(cell, Color(WASH_COLOR.r, WASH_COLOR.g, WASH_COLOR.b, alpha), true)


func _draw_marker(centre: Vector2, tint: Color) -> void:
	var points := PackedVector2Array([
		centre + Vector2(0.0, -MARKER_HALF),
		centre + Vector2(MARKER_HALF, 0.0),
		centre + Vector2(0.0, MARKER_HALF),
		centre + Vector2(-MARKER_HALF, 0.0),
	])
	draw_colored_polygon(points, tint)


func _set_hovered(hovered: bool) -> void:
	if _is_hovered == hovered:
		return
	_is_hovered = hovered
	_kill_hover_tween()
	_hover_tween = create_tween()
	_hover_tween.tween_method(
		_set_hover_blend,
		_hover_blend,
		1.0 if hovered else 0.0,
		HOVER_TIME
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _set_hover_blend(value: float) -> void:
	_hover_blend = value
	_label.add_theme_color_override("font_color", TEXT_REST.lerp(TEXT_HOVER, value))
	queue_redraw()


func _kill_hover_tween() -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = null
#endregion

#region Signal Handlers
func _on_mouse_entered() -> void:
	if interactive:
		_set_hovered(true)


func _on_mouse_exited() -> void:
	_is_pressed = false
	_set_hovered(false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_is_pressed = true
		queue_redraw()
		return
	if _is_pressed:
		_is_pressed = false
		queue_redraw()
		pressed.emit()
#endregion
