# res://Scenes/HUD/HudTooltip.gd
class_name HudTooltip
extends Control
## Hover tooltip for one top-bar widget.
##
## Every icon in the top bar is the same placeholder logo, so the icon alone cannot say
## what the number beside it means. Instead of printing a word inside the widget, each
## stat and each icon-only button carries a short `tooltip_text` and this script renders
## it as a HUD slab:
##
## [codeblock]
## tooltip_text = "End Turn\nEnd your turn to start the enemy turn."
## [endcodeblock]
##
## The first line becomes the title (accent colour), every following line the short
## description. A description is never wrapped, so it stays on one line that fits.
##
## The slab reuses the debug menu's chrome (DebugMenuPopup: dark background, accent
## border, square corners, 10 px padding), so a hover tooltip and the tester palette
## read as the same surface; HudTooltipTest locks the two palettes together.
##
## `_make_custom_tooltip()` hands the slab to the engine, which owns the hover timing,
## the placement and the lifetime (`Viewport::_gui_show_tooltip` adds it to its tooltip
## popup), so this script holds no state, needs no signals and can never show a tooltip
## the cursor does not own.
##
## @author TheGreatJellyfish
## @version 11/20/2026

#region Constants
## Inner padding of the slab, in pixels. Matches DebugMenuPopup.PADDING.
const PADDING: int = 10
## Square corners (0 px): the slab and the debug menu are one flat HUD surface.
const CORNER_RADIUS: int = 0
## Border width of the slab, matching DebugMenuPopup._apply_chrome().
const BORDER_WIDTH: int = 1
const TITLE_FONT_SIZE: int = 13
const BODY_FONT_SIZE: int = 12

## Palette, kept identical to DebugMenuPopup's chrome so the hover tooltip and the
## tester debug menu can never drift apart.
const PANEL_BG: Color = Color(0.07, 0.08, 0.11, 0.97)
const PANEL_BORDER: Color = Color(0.45, 0.78, 0.95, 0.5)
const TITLE_COLOR: Color = Color(0.55, 0.86, 1.0)
const BODY_COLOR: Color = Color(0.80, 0.85, 0.93)
#endregion


#region Lifecycle Methods
## Engine hover hook: a Control that returns a Control here replaces the default theme
## tooltip. The engine calls it every time it wants to show this widget's tooltip, so
## the slab is built fresh and is freed with the tooltip itself.
func _make_custom_tooltip(for_text: String) -> Object:
	return build_tooltip_panel(for_text)
#endregion


#region Public Methods
## Builds the slab for one `tooltip_text` payload: the first line is the title, every
## following line the description. A payload without a line break renders as a
## description only. Static so the layout can be checked without a scene tree.
## @param for_text - the widget's `tooltip_text`
## @return a display-only Control the engine shows instead of its own tooltip
static func build_tooltip_panel(for_text: String) -> Control:
	var body: String = for_text.strip_edges()
	var title: String = ""
	var line_break: int = body.find("\n")
	if line_break >= 0:
		title = body.substr(0, line_break).strip_edges()
		body = body.substr(line_break + 1).strip_edges()

	var panel := PanelContainer.new()
	panel.name = "HudTooltipPanel"
	# Display-only: the slab must never steal the hover it was opened for.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _build_chrome())

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	if not title.is_empty():
		column.add_child(_build_label(title, TITLE_FONT_SIZE, TITLE_COLOR))
	if not body.is_empty():
		column.add_child(_build_label(body, BODY_FONT_SIZE, BODY_COLOR))
	return panel
#endregion


#region Private Methods
## The debug menu's chrome: dark slab, accent border, square corners, inner padding.
static func _build_chrome() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_BORDER
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.content_margin_left = float(PADDING)
	box.content_margin_right = float(PADDING)
	box.content_margin_top = float(PADDING)
	box.content_margin_bottom = float(PADDING)
	return box


## One line of the slab. Deliberately not wrapped: a wrapping Label reports the wrong
## minimum height before it has been laid out, and the engine sizes the tooltip from
## that minimum, so a long line would be clipped instead of wrapped.
static func _build_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
#endregion
