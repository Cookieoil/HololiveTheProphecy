# res://Scenes/GameUI/GraphicalUI/HUD/SkillTooltipPopup.gd
class_name SkillTooltipPopup
extends Control

const CARD_WIDTH: float = 310.0
const MIN_CARD_HEIGHT: float = 88.0
const ARROW_SIZE: float = 11.0
const PAD_X: int = 14
const PAD_Y: int = 11
const SCREEN_MARGIN: float = 12.0

var icon_catalog: IconCatalog

var _accent_color: Color = Color(0.49, 0.83, 0.99)
var _arrow_on_left: bool = true
var _arrow_local_y: float = 40.0
var _open_tween: Tween

var _margin: MarginContainer
var _vbox: VBoxContainer
var _header_label: Label
var _icons_box: HBoxContainer
var _subtitle_label: Label
var _body_rtl: RichTextLabel
var _footer_sep: ColorRect
var _footer_rtl: RichTextLabel


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	custom_minimum_size = Vector2(CARD_WIDTH, MIN_CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, MIN_CARD_HEIGHT)
	_build_ui()


func _build_ui() -> void:
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content_w := _apply_side_margins()

	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", 5)
	_margin.add_child(_vbox)

	# Top row: "Skill 1 (Odd) (Unmerged)" + Category Icons
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(top_row)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_font_size_override("font_size", 14)
	_header_label.add_theme_color_override("font_color", Color.WHITE)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_header_label)

	_icons_box = HBoxContainer.new()
	_icons_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons_box.add_theme_constant_override("separation", 4)
	top_row.add_child(_icons_box)

	# Subtitle: Skill Display Name + Effective Value
	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.custom_minimum_size = Vector2(content_w, 0.0)
	_subtitle_label.size = Vector2(content_w, 0.0)
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_subtitle_label)

	var sep1 := ColorRect.new()
	sep1.custom_minimum_size = Vector2(0, 1)
	sep1.color = Color(1.0, 1.0, 1.0, 0.14)
	sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(sep1)

	# Body ("Deal 6 damage to all enemies.")
	_body_rtl = RichTextLabel.new()
	_body_rtl.bbcode_enabled = true
	_body_rtl.fit_content = true
	_body_rtl.scroll_active = false
	_body_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_rtl.custom_minimum_size = Vector2(content_w, 0.0)
	_body_rtl.size = Vector2(content_w, 0.0)
	_body_rtl.add_theme_font_size_override("normal_font_size", 13)
	_body_rtl.add_theme_font_size_override("bold_font_size", 14)
	_body_rtl.add_theme_color_override("default_color", Color(0.93, 0.95, 0.98))
	_body_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_body_rtl)

	_footer_sep = ColorRect.new()
	_footer_sep.custom_minimum_size = Vector2(0, 1)
	_footer_sep.color = Color(1.0, 1.0, 1.0, 0.10)
	_footer_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_footer_sep)

	# Footer (Moxie transition / Ready cue)
	_footer_rtl = RichTextLabel.new()
	_footer_rtl.bbcode_enabled = true
	_footer_rtl.fit_content = true
	_footer_rtl.scroll_active = false
	_footer_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer_rtl.custom_minimum_size = Vector2(content_w, 0.0)
	_footer_rtl.size = Vector2(content_w, 0.0)
	_footer_rtl.add_theme_font_size_override("normal_font_size", 12)
	_footer_rtl.add_theme_font_size_override("bold_font_size", 12)
	_footer_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_footer_rtl)


## Applies outer margins and returns the exact inner content width available to wrapped text.
func _apply_side_margins() -> float:
	var left_pad := PAD_X + (int(ARROW_SIZE) if _arrow_on_left else 0)
	var right_pad := PAD_X + (0 if _arrow_on_left else int(ARROW_SIZE))
	if _margin != null:
		_margin.add_theme_constant_override("margin_left", left_pad)
		_margin.add_theme_constant_override("margin_right", right_pad)
		_margin.add_theme_constant_override("margin_top", PAD_Y)
		_margin.add_theme_constant_override("margin_bottom", PAD_Y)
	return CARD_WIDTH - float(left_pad + right_pad)


func _sync_wrap_widths(content_w: float) -> void:
	for ctrl: Control in [_subtitle_label, _body_rtl, _footer_rtl]:
		if ctrl == null:
			continue
		ctrl.custom_minimum_size.x = content_w
		if absf(ctrl.size.x - content_w) > 0.5:
			ctrl.size.x = content_w


func show_callout(data: Dictionary, anchor_rect: Rect2) -> void:
	if data.is_empty():
		hide_callout()
		return

	var vp_size := get_viewport_rect().size
	# Place callout to the right of anchor if it fits; flip left near right edge
	var space_right := vp_size.x - anchor_rect.end.x - SCREEN_MARGIN
	_arrow_on_left = space_right >= (CARD_WIDTH + 10.0)
	var content_w := _apply_side_margins()
	_sync_wrap_widths(content_w)

	_accent_color = data.get("accent", Color(0.49, 0.83, 0.99))
	_header_label.text = str(data.get("header", ""))
	_header_label.add_theme_color_override("font_color", _accent_color.lightened(0.25))

	var sub := str(data.get("subtitle", ""))
	_subtitle_label.text = sub
	_subtitle_label.visible = sub != ""

	_body_rtl.text = str(data.get("body", ""))

	var foot := str(data.get("footer", ""))
	var has_foot := foot != ""
	_footer_rtl.text = foot
	_footer_rtl.visible = has_foot
	_footer_sep.visible = has_foot

	_rebuild_category_icons(data.get("categories", PackedStringArray()))

	# Make visible before measuring so Container sorting is active on the very first hover
	var was_visible := visible
	if not was_visible:
		size = Vector2(CARD_WIDTH, MIN_CARD_HEIGHT)
		visible = true

	var min_sz := _margin.get_combined_minimum_size()
	var final_size := Vector2(CARD_WIDTH, maxf(MIN_CARD_HEIGHT, ceilf(min_sz.y)))
	size = final_size
	_margin.size = final_size

	var target_x := anchor_rect.end.x + 8.0 if _arrow_on_left else anchor_rect.position.x - size.x - 8.0
	target_x = clampf(target_x, SCREEN_MARGIN, vp_size.x - size.x - SCREEN_MARGIN)

	var anchor_mid_y := anchor_rect.get_center().y
	var target_y := clampf(anchor_mid_y - size.y * 0.38, SCREEN_MARGIN, vp_size.y - size.y - SCREEN_MARGIN)
	_arrow_local_y = clampf(anchor_mid_y - target_y, 20.0, size.y - 20.0)

	queue_redraw()

	if not was_visible:
		if _open_tween != null and _open_tween.is_valid():
			_open_tween.kill()
		var slide_offset := -7.0 if _arrow_on_left else 7.0
		position = Vector2(target_x + slide_offset, target_y)
		modulate.a = 0.0
		_open_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_open_tween.tween_property(self, "position", Vector2(target_x, target_y), 0.11)
		_open_tween.tween_property(self, "modulate:a", 1.0, 0.10)
	else:
		position = Vector2(target_x, target_y)
		modulate.a = 1.0


func hide_callout() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	visible = false


func _rebuild_category_icons(categories: PackedStringArray) -> void:
	for c in _icons_box.get_children():
		_icons_box.remove_child(c)
		c.queue_free()
	if icon_catalog == null:
		return
	for cat in categories:
		var tex := icon_catalog.get_icon(cat)
		if tex == null:
			continue
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(16, 16)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icons_box.add_child(rect)


func _draw() -> void:
	var box_x := ARROW_SIZE if _arrow_on_left else 0.0
	var box_w := size.x - ARROW_SIZE
	var box_rect := Rect2(box_x, 0.0, box_w, size.y)

	# Drop shadow
	draw_rect(Rect2(box_rect.position + Vector2(0, 5), box_rect.size), Color(0, 0, 0, 0.48), true)

	# Main slate panel + subtle top accent bar
	var bg_col := Color(0.08, 0.09, 0.13, 0.97)
	draw_rect(box_rect, bg_col, true)
	draw_rect(Rect2(box_rect.position, Vector2(box_rect.size.x, 3.0)), _accent_color, true)
	draw_rect(box_rect.grow(-1.0), Color(1.0, 1.0, 1.0, 0.06), false, 1.0)
	draw_rect(box_rect, _accent_color * Color(1, 1, 1, 0.85), false, 1.5)

	# Pointer beak facing the hovered unit / card / dice / orb
	var ay := _arrow_local_y
	if _arrow_on_left:
		var tri := PackedVector2Array([
			Vector2(0.0, ay),
			Vector2(box_x + 1.0, ay - 8.5),
			Vector2(box_x + 1.0, ay + 8.5),
		])
		draw_colored_polygon(tri, bg_col)
		draw_line(Vector2(box_x, ay - 8.5), Vector2(0.0, ay), _accent_color, 1.6, true)
		draw_line(Vector2(0.0, ay), Vector2(box_x, ay + 8.5), _accent_color, 1.6, true)
	else:
		var rx := box_rect.end.x
		var tri := PackedVector2Array([
			Vector2(size.x, ay),
			Vector2(rx - 1.0, ay - 8.5),
			Vector2(rx - 1.0, ay + 8.5),
		])
		draw_colored_polygon(tri, bg_col)
		draw_line(Vector2(rx, ay - 8.5), Vector2(size.x, ay), _accent_color, 1.6, true)
		draw_line(Vector2(size.x, ay), Vector2(rx, ay + 8.5), _accent_color, 1.6, true)
