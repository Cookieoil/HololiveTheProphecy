# res://Scenes/HUD/HudTooltip.gd
class_name HudTooltip
extends Control
## Content of the hover tooltip for one top-bar widget.
##
## Every icon in the top bar is the same placeholder logo, so the icon alone cannot say
## what the number beside it means. Instead of printing a word inside the widget, each
## stat and each icon-only button carries a short `tooltip_text` and this script turns it
## into a tooltip:
##
## [codeblock]
## tooltip_text = "End Turn\nEnd your turn to start the enemy turn."
## [endcodeblock]
##
## The first line becomes the title (accent colour), every following line the short
## description. A description is never wrapped, so it stays on one line that fits.
##
## Only the *content* is built here. `_make_custom_tooltip()` hands it to the engine,
## which owns the hover timing, the placement and the lifetime
## (`Viewport::_gui_show_tooltip` wraps it in its own tooltip popup), so this script
## holds no state, needs no signals and can never show a tooltip the cursor does not
## own. That popup paints the slab behind this content, so the dark background, the
## accent border and the padding are the tooltip theme's
## (`Scenes/HUD/HudTooltipTheme.tres`, wired up as the project theme) instead of this
## script's: the popup resolves that theme where a scene-level theme would not reach.
##
## @author TheGreatJellyfish
## @version 11/20/2026

#region Constants
const TITLE_FONT_SIZE: int = 13
const BODY_FONT_SIZE: int = 12
## Space between the title and the description.
const LINE_SEPARATION: int = 2

## Text colours. The slab itself is the tooltip theme's (HudTooltipTheme.tres).
const TITLE_COLOR: Color = Color(0.55, 0.86, 1.0)
const BODY_COLOR: Color = Color(0.80, 0.85, 0.93)
#endregion


#region Lifecycle Methods
## Engine hover hook: a Control that returns a Control here replaces the default theme
## tooltip. The engine calls it every time it wants to show this widget's tooltip, so
## the content is built fresh and is freed with the tooltip itself.
func _make_custom_tooltip(for_text: String) -> Object:
	return build_tooltip_content(for_text)
#endregion


#region Public Methods
## Builds the tooltip content for one `tooltip_text` payload: the first line is the
## title, every following line the description. A payload without a line break renders
## as a description only. Static so the layout can be checked without a scene tree.
## @param for_text - the widget's `tooltip_text`
## @return a display-only Control the engine shows inside its tooltip popup
static func build_tooltip_content(for_text: String) -> Control:
	var body: String = for_text.strip_edges()
	var title: String = ""
	var line_break: int = body.find("\n")
	if line_break >= 0:
		title = body.substr(0, line_break).strip_edges()
		body = body.substr(line_break + 1).strip_edges()

	var column := VBoxContainer.new()
	column.name = "HudTooltipContent"
	# Display-only: the tooltip must never steal the hover it was opened for.
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", LINE_SEPARATION)

	if not title.is_empty():
		column.add_child(_build_label(title, TITLE_FONT_SIZE, TITLE_COLOR))
	if not body.is_empty():
		column.add_child(_build_label(body, BODY_FONT_SIZE, BODY_COLOR))
	return column
#endregion


#region Private Methods
## One line of the tooltip content. Deliberately not wrapped: a wrapping Label reports
## the wrong minimum height before it has been laid out, and the engine sizes the
## tooltip from that minimum, so a long line would be clipped instead of wrapped.
static func _build_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
#endregion
