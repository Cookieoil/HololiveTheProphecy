class_name HudTooltipTest
extends GdUnitTestSuite
## Locks the top-bar hover tooltips (HudTooltip) and the slab they are drawn on (the
## tooltip theme in HudTooltipTheme.tres).
##
## Every icon in the bar is the same placeholder logo, so each stat and each icon-only
## action button describes itself in a tooltip instead of printing a word on the button.
## HudTooltip builds the content, but the hammer comes from the engine: it puts that
## content inside its own TooltipPanel popup and paints the popup's own `TooltipPanel`
## theme panel behind it. Left as the built-in theme that panel is 50% black with 8 px
## horizontal and 2 px vertical content margins, so the slab appeared to sit on a dark
## band that leaked past its outline - worse on the sides than on the top and bottom.
## The project theme replaces that panel with the debug menu's chrome, which is what
## these tests protect: same palette, square, evenly padded and never expanded.
##
## @author TheGreatJellyfish
## @version 11/20/2026

const SCENE_PATH: String = "res://Scenes/BattleScene/BattleScene.tscn"
const SCRIPT_PATH: String = "res://Scenes/HUD/HudTooltip.gd"
const THEME_PATH: String = "res://Scenes/HUD/HudTooltipTheme.tres"
## Project setting that puts the theme in charge of the engine's tooltip popup.
const THEME_SETTING: String = "gui/theme/custom"
## Project setting for how long a hover has to last before the tooltip appears.
const TOOLTIP_DELAY_SETTING: String = "gui/timers/tooltip_delay_sec"
## Theme type and item the engine's tooltip popup asks for its background.
const THEME_TYPE: String = "TooltipPanel"
const THEME_ITEM: String = "panel"
## Top-bar widgets that must show a hover tooltip, in bar order.
const TOOLTIP_WIDGETS: Array[String] = [
	"HUD/TopBar/Margin/HBox/LeftGroup/WaveStat",
	"HUD/TopBar/Margin/HBox/LeftGroup/DiceStat",
	"HUD/TopBar/Margin/HBox/CenterGroup/ActionsStat",
	"HUD/TopBar/Margin/HBox/CenterGroup/MergesStat",
	"HUD/TopBar/Margin/HBox/CenterGroup/DeckStat",
	"HUD/TopBar/Margin/HBox/CenterGroup/DiscardStat",
	"HUD/TopBar/Margin/HBox/RightGroup/ConvertButton",
	"HUD/TopBar/Margin/HBox/RightGroup/EndTurnButton",
]


## Builds the tooltip content for one payload and hands it to the test tree, so the
## suite frees it with the test instead of leaking an orphan.
func _make_content(tooltip_text: String) -> Control:
	var content: Control = HudTooltip.build_tooltip_content(tooltip_text)
	add_child(content)
	return content


## The battle scene's nodes carry the tooltip wiring, so a check has to read them.
## Like the debug menu's scene checks, the real scene is mounted and released again by
## the suite.
func _instantiate_battle_scene() -> Node:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()
	if packed == null:
		return null
	var scene: Node = packed.instantiate()
	add_child(scene)
	auto_free(scene)
	return scene


## Labels of a tooltip, in tree order (the title first).
func _labels(panel: Control) -> Array[Label]:
	var labels: Array[Label] = []
	for node: Node in panel.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			labels.append(label)
	return labels


## The slab the engine's tooltip popup paints behind the tooltip content.
func _tooltip_slab() -> StyleBoxFlat:
	var theme: Theme = load(THEME_PATH) as Theme
	assert_object(theme).is_not_null()
	if theme == null:
		return null
	return theme.get_stylebox(THEME_ITEM, THEME_TYPE) as StyleBoxFlat


## `SkillTooltipPopup` builds its whole panel in `_init()`, so its node tree is the thing a
## refactor of that builder has to preserve: `show_callout` writes into these nodes by
## reference, and a missing slot would silently drop a line of the skill description.
## These live in this suite because it is the tooltip suite: what a hover says, and what a
## callout says, are the same question asked about two different panels.
func _make_callout() -> SkillTooltipPopup:
	var popup: SkillTooltipPopup = SkillTooltipPopup.new()
	add_child(popup)
	return popup


func test_the_callout_builds_one_slot_per_line_of_text() -> void:
	var popup: SkillTooltipPopup = _make_callout()
	# The pad holds the column, and nothing else.
	assert_int(popup.get_child_count()).is_equal(1)
	assert_object(popup.get_child(0)).is_equal(popup._margin)
	assert_int(popup._margin.get_child_count()).is_equal(1)
	assert_object(popup._margin.get_child(0)).is_equal(popup._vbox)

	# In the order the player reads them: title row, subtitle, rule, body, rule, footer.
	var slots: Array[Node] = popup._vbox.get_children()
	assert_int(slots.size()).is_equal(6)
	assert_bool(slots[0] is HBoxContainer).is_true()
	assert_object(slots[1]).is_equal(popup._subtitle_label)
	assert_bool(slots[2] is ColorRect).is_true()
	assert_object(slots[3]).is_equal(popup._body_rtl)
	assert_object(slots[4]).is_equal(popup._footer_sep)
	assert_object(slots[5]).is_equal(popup._footer_rtl)

	# The title row holds the header and the (currently hidden) category icons.
	var title_row: HBoxContainer = slots[0]
	assert_int(title_row.get_child_count()).is_equal(2)
	assert_object(title_row.get_child(0)).is_equal(popup._header_label)
	assert_object(title_row.get_child(1)).is_equal(popup._icons_box)
	assert_bool(popup._icons_box.visible).is_false()


## The two rich-text slots have to stay plain wrappers: no scrollbar, a height that
## follows the text, and the line spacing that keeps an inline keyword icon off the line
## above it.
func test_the_callout_body_wraps_its_text_instead_of_scrolling() -> void:
	var popup: SkillTooltipPopup = _make_callout()
	for rtl: RichTextLabel in [popup._body_rtl, popup._footer_rtl]:
		assert_bool(rtl.bbcode_enabled).is_true()
		assert_bool(rtl.fit_content).is_true()
		assert_bool(rtl.scroll_active).is_false()
		assert_int(rtl.autowrap_mode).is_equal(TextServer.AUTOWRAP_WORD_SMART)
		assert_bool(rtl.mouse_filter == Control.MOUSE_FILTER_IGNORE).is_true()
	# The body is the larger of the two, and only it carries the icon breathing room.
	assert_int(popup._body_rtl.get_theme_font_size("normal_font_size")).is_equal(13)
	assert_int(popup._body_rtl.get_theme_font_size("bold_font_size")).is_equal(14)
	assert_int(popup._body_rtl.get_theme_constant("line_separation")).is_equal(3)
	assert_int(popup._footer_rtl.get_theme_font_size("normal_font_size")).is_equal(12)
	assert_int(popup._header_label.get_theme_font_size("font_size")).is_equal(14)
	assert_int(popup._subtitle_label.get_theme_font_size("font_size")).is_equal(12)


## Empty optional lines collapse instead of leaving a gap or an orphaned rule, which is
## what makes the same panel serve a skill with and without a footer.
func test_an_empty_subtitle_or_footer_collapses_its_slot() -> void:
	var popup: SkillTooltipPopup = _make_callout()
	popup.show_callout({
		"header": "Skill 1 (Odd)",
		"subtitle": "",
		"body": "Deal 6 damage.",
		"footer": "",
		"accent": Color(1.0, 0.34, 0.32),
	}, Rect2(Vector2(100.0, 100.0), Vector2(40.0, 40.0)))
	assert_str(popup._header_label.text).is_equal("Skill 1 (Odd)")
	assert_bool(popup._subtitle_label.visible).is_false()
	assert_bool(popup._footer_rtl.visible).is_false()
	assert_bool(popup._footer_sep.visible).is_false()
	assert_str(popup._body_rtl.text).is_equal("Deal 6 damage.")

	popup.show_callout({
		"header": "Ultimate",
		"subtitle": "20 Moxie",
		"body": "Deal 13 damage.",
		"footer": "Moxie: 0 / 20",
	}, Rect2(Vector2(100.0, 100.0), Vector2(40.0, 40.0)))
	assert_bool(popup._subtitle_label.visible).is_true()
	assert_bool(popup._footer_rtl.visible).is_true()
	assert_bool(popup._footer_sep.visible).is_true()
	popup.hide_callout()
	assert_bool(popup.visible).is_false()


func test_two_lines_become_a_title_and_a_description() -> void:
	var content: Control = _make_content("End Turn\nEnd your turn to start the enemy turn.")
	assert_bool(content is VBoxContainer).is_true()

	var labels: Array[Label] = _labels(content)
	assert_int(labels.size()).is_equal(2)
	assert_str(labels[0].text).is_equal("End Turn")
	assert_str(labels[1].text).is_equal("End your turn to start the enemy turn.")


func test_one_line_is_a_description_only() -> void:
	var content: Control = _make_content("Convert 1 action into 1 merge.")
	var labels: Array[Label] = _labels(content)
	assert_int(labels.size()).is_equal(1)
	assert_str(labels[0].text).is_equal("Convert 1 action into 1 merge.")


## The requested background: the debug menu's chrome, not Godot's built-in tooltip look.
## Because the engine paints its own tooltip popup behind the content, the slab lives in
## that popup's theme entry, so this is what the player actually sees behind a hover.
func test_slab_reuses_the_debug_menu_background() -> void:
	var box: StyleBoxFlat = _tooltip_slab()
	assert_bool(box != null).is_true()
	if box == null:
		return

	assert_bool(box.bg_color.is_equal_approx(DebugMenuPopup.PANEL_BG)).is_true()
	# The outline has to *look* like the debug menu's, and the engine draws a
	# semi-transparent border far fainter inside the tooltip's popup window than a plain
	# panel draws it (measured: a fifth of the intensity). So the theme carries the
	# colour the debug menu's border renders as - its own border over its own background
	# - and carries it opaque, which the popup renders exactly.
	var border: Color = DebugMenuPopup.PANEL_BORDER
	var backdrop: Color = DebugMenuPopup.PANEL_BG
	var outline := Color(
		border.r * border.a + backdrop.r * (1.0 - border.a),
		border.g * border.a + backdrop.g * (1.0 - border.a),
		border.b * border.a + backdrop.b * (1.0 - border.a),
		1.0
	)
	assert_bool(box.border_color.is_equal_approx(outline)).is_true()
	assert_bool(box.border_color.a == 1.0).is_true()
	# Same outline weight as the debug menu, so the two surfaces stay one chrome.
	assert_int(box.border_width_left).is_equal(DebugMenuPopup.BORDER_WIDTH)
	assert_int(box.border_width_top).is_equal(DebugMenuPopup.BORDER_WIDTH)
	assert_int(box.border_width_right).is_equal(DebugMenuPopup.BORDER_WIDTH)
	assert_int(box.border_width_bottom).is_equal(DebugMenuPopup.BORDER_WIDTH)
	# Square corners on all four edges, like the debug menu itself.
	assert_int(box.corner_radius_top_left).is_equal(0)
	assert_int(box.corner_radius_top_right).is_equal(0)
	assert_int(box.corner_radius_bottom_left).is_equal(0)
	assert_int(box.corner_radius_bottom_right).is_equal(0)
	# Even padding on all four edges (the built-in panel was 8 px across and 2 px down,
	# which is what made the background look longer than the outline).
	assert_int(int(box.content_margin_left)).is_equal(DebugMenuPopup.PADDING)
	assert_int(int(box.content_margin_top)).is_equal(DebugMenuPopup.PADDING)
	assert_int(int(box.content_margin_right)).is_equal(DebugMenuPopup.PADDING)
	assert_int(int(box.content_margin_bottom)).is_equal(DebugMenuPopup.PADDING)


## The leak itself: an expand margin grows the background past the slab's own border, so
## the slab must never carry one.
func test_slab_never_grows_past_its_own_border() -> void:
	var box: StyleBoxFlat = _tooltip_slab()
	assert_bool(box != null).is_true()
	if box == null:
		return

	assert_int(int(box.expand_margin_left)).is_equal(0)
	assert_int(int(box.expand_margin_top)).is_equal(0)
	assert_int(int(box.expand_margin_right)).is_equal(0)
	assert_int(int(box.expand_margin_bottom)).is_equal(0)


## Wiring: the theme only reaches the engine's tooltip popup as the *project* theme (a
## theme on the scene or on the main window does not get that far), so the project
## setting has to point at it and the slab has to resolve for any control.
func test_project_theme_reaches_the_tooltip_panel() -> void:
	assert_str(str(ProjectSettings.get_setting(THEME_SETTING, ""))).is_equal(THEME_PATH)

	var probe: Control = auto_free(Control.new())
	var box: StyleBoxFlat = probe.get_theme_stylebox(THEME_ITEM, THEME_TYPE) as StyleBoxFlat
	assert_bool(box != null).is_true()
	if box == null:
		return
	assert_bool(box.bg_color.is_equal_approx(DebugMenuPopup.PANEL_BG)).is_true()
	assert_int(int(box.content_margin_left)).is_equal(DebugMenuPopup.PADDING)
	assert_int(int(box.expand_margin_top)).is_equal(0)


## Hovering a widget has to name it straight away: the engine's tooltip timer defaults to
## half a second, so the project overrides it. The setting is asserted explicitly (an
## absent setting would fall back to that 0.5 s default, not to 0).
func test_tooltip_has_no_hover_delay() -> void:
	var delay: Variant = ProjectSettings.get_setting(TOOLTIP_DELAY_SETTING, -1.0)
	assert_bool(delay is float).is_true()
	if not delay is float:
		return
	var seconds: float = delay
	assert_bool(seconds == 0.0).is_true()


## The engine hook: returning a Control from `_make_custom_tooltip()` is what makes
## Godot show our content inside its tooltip popup.
func test_hover_hook_returns_the_tooltip_content() -> void:
	var widget: HudTooltip = auto_free(HudTooltip.new())
	var tooltip: Object = widget._make_custom_tooltip("Actions\nActions left this turn.")

	var content: Control = tooltip as Control
	assert_bool(content != null).is_true()
	if content == null:
		return
	add_child(content)
	assert_int(_labels(content).size()).is_equal(2)
	assert_int(content.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## The tooltip is opened *by* a hover, so neither it nor its children may take that hover.
func test_tooltip_never_eats_the_hover() -> void:
	var content: Control = _make_content("Merges\nMerges left this turn.")
	assert_int(content.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for node: Node in content.find_children("*", "Control", true, false):
		var child: Control = node as Control
		if child != null:
			assert_int(child.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_top_bar_widgets_carry_the_hover_tooltip() -> void:
	var scene: Node = _instantiate_battle_scene()
	assert_object(scene).is_not_null()
	if scene == null:
		return

	var script: Script = load(SCRIPT_PATH) as Script
	for path: String in TOOLTIP_WIDGETS:
		var widget: Control = scene.get_node_or_null(path) as Control
		assert_object(widget).is_not_null()
		if widget == null:
			continue
		assert_bool(widget.get_script() == script).is_true()
		# Title on the first line, short description after it.
		assert_bool(widget.tooltip_text.contains("\n")).is_true()

		# Exactly what the engine asks the widget for on hover.
		var tooltip: Object = widget._make_custom_tooltip(widget.tooltip_text)
		var content: Control = tooltip as Control
		assert_bool(content != null).is_true()
		if content == null:
			continue
		add_child(content)
		assert_bool(_labels(content).size() >= 2).is_true()


## The word moved out of the buttons: they are icon-only squares now that the tooltip
## names them.
func test_action_buttons_are_labelless_icons() -> void:
	var scene: Node = _instantiate_battle_scene()
	assert_object(scene).is_not_null()
	if scene == null:
		return

	for button_name: String in ["ConvertButton", "EndTurnButton"]:
		var path: String = "HUD/TopBar/Margin/HBox/RightGroup/%s" % button_name
		var button: Button = scene.get_node_or_null(path) as Button
		assert_object(button).is_not_null()
		if button == null:
			continue
		assert_str(button.text).is_empty()
		assert_bool(button.icon != null).is_true()
		assert_bool(button.expand_icon).is_true()
		assert_bool(button.custom_minimum_size.x <= 34.0).is_true()
		# No button chrome: the default styleboxes' padding would shrink the 28 px icon to
		# a 14 px glyph, while every other icon draws its glyph at 20 px inside the same
		# 28 px box. Padding stays at zero in every state, so hovering cannot resize it.
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBox = button.get_theme_stylebox(state)
			assert_int(int(box.get_margin(SIDE_LEFT))).is_equal(0)
			assert_int(int(box.get_margin(SIDE_TOP))).is_equal(0)


## Flat icon buttons need another cue that they are clickable: hovering brightens the
## icon (self_modulate above white) and leaving restores it, like the ultimate orbs.
func test_action_buttons_light_up_on_hover() -> void:
	var scene: Node = _instantiate_battle_scene()
	assert_object(scene).is_not_null()
	if scene == null:
		return

	for button_name: String in ["ConvertButton", "EndTurnButton"]:
		var path: String = "HUD/TopBar/Margin/HBox/RightGroup/%s" % button_name
		var button: Button = scene.get_node_or_null(path) as Button
		assert_object(button).is_not_null()
		if button == null:
			continue
		assert_bool(button.self_modulate.is_equal_approx(Color.WHITE)).is_true()

		button.mouse_entered.emit()
		assert_bool(button.self_modulate.r > 1.0).is_true()
		assert_bool(button.self_modulate.g > 1.0).is_true()
		assert_bool(button.self_modulate.b > 1.0).is_true()

		button.mouse_exited.emit()
		assert_bool(button.self_modulate.is_equal_approx(Color.WHITE)).is_true()
