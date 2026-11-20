class_name HudTooltipTest
extends GdUnitTestSuite
## Locks the top-bar hover tooltips (HudTooltip).
##
## Every icon in the bar is the same placeholder logo, so each stat and each
## icon-only action button describes itself in a slab instead of printing a word on
## the button. The slab has to reuse the debug menu's chrome, must stay mouse
## transparent, and the battle scene has to actually hand it to every widget.
##
## @author TheGreatJellyfish
## @version 11/20/2026

const SCENE_PATH: String = "res://Scenes/BattleScene/BattleScene.tscn"
const SCRIPT_PATH: String = "res://Scenes/HUD/HudTooltip.gd"
## Top-bar widgets that must show a hover tooltip, in bar order.
const TOOLTIP_WIDGETS: Array[String] = [
	"HUD/TopBar/Margin/HBox/LeftGroup/WaveStat",
	"HUD/TopBar/Margin/HBox/LeftGroup/DiceStat",
	"HUD/TopBar/Margin/HBox/CenterGroup/ActionsStat",
	"HUD/TopBar/Margin/HBox/CenterGroup/MergesStat",
	"HUD/TopBar/Margin/HBox/RightGroup/ConvertButton",
	"HUD/TopBar/Margin/HBox/RightGroup/EndTurnButton",
]


## Builds the slab for one payload and hands it to the test tree, so the suite frees it
## with the test instead of leaking an orphan.
func _make_slab(tooltip_text: String) -> Control:
	var panel: Control = HudTooltip.build_tooltip_panel(tooltip_text)
	add_child(panel)
	return panel


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


## Labels of a slab, in tree order (the title first).
func _labels(panel: Control) -> Array[Label]:
	var labels: Array[Label] = []
	for node: Node in panel.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null:
			labels.append(label)
	return labels


func test_two_lines_become_a_title_and_a_description() -> void:
	var panel: Control = _make_slab("End Turn\nEnd your turn to start the enemy turn.")
	assert_bool(panel is PanelContainer).is_true()

	var labels: Array[Label] = _labels(panel)
	assert_int(labels.size()).is_equal(2)
	assert_str(labels[0].text).is_equal("End Turn")
	assert_str(labels[1].text).is_equal("End your turn to start the enemy turn.")


func test_one_line_is_a_description_only() -> void:
	var panel: Control = _make_slab("Convert 1 action into 1 merge.")
	var labels: Array[Label] = _labels(panel)
	assert_int(labels.size()).is_equal(1)
	assert_str(labels[0].text).is_equal("Convert 1 action into 1 merge.")


## The requested background: the debug menu's chrome, not Godot's default tooltip look.
func test_slab_reuses_the_debug_menu_background() -> void:
	var panel: Control = _make_slab("Wave\nEnemy wave you are fighting.")
	var box: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_bool(box != null).is_true()
	if box == null:
		return

	assert_bool(box.bg_color.is_equal_approx(DebugMenuPopup.PANEL_BG)).is_true()
	assert_bool(box.border_color.is_equal_approx(DebugMenuPopup.PANEL_BORDER)).is_true()
	assert_int(box.border_width_left).is_equal(HudTooltip.BORDER_WIDTH)
	assert_int(int(box.content_margin_left)).is_equal(HudTooltip.PADDING)
	# Square corners on all four edges, like the debug menu itself.
	assert_int(box.corner_radius_top_left).is_equal(0)
	assert_int(box.corner_radius_top_right).is_equal(0)
	assert_int(box.corner_radius_bottom_left).is_equal(0)
	assert_int(box.corner_radius_bottom_right).is_equal(0)


## The engine hook: returning a Control is what makes Godot show this slab instead of
## its own tooltip popup.
func test_hover_hook_returns_the_slab() -> void:
	var widget: HudTooltip = auto_free(HudTooltip.new())
	var tooltip: Object = widget._make_custom_tooltip("Actions\nActions left this turn.")

	var slab: Control = tooltip as Control
	assert_bool(slab != null).is_true()
	if slab == null:
		return
	add_child(slab)
	assert_int(_labels(slab).size()).is_equal(2)
	assert_int(slab.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## The slab is opened *by* a hover, so neither it nor its children may take that hover.
func test_slab_never_eats_the_hover() -> void:
	var panel: Control = _make_slab("Merges\nMerges left this turn.")
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for node: Node in panel.find_children("*", "Control", true, false):
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
		var slab: Control = tooltip as Control
		assert_bool(slab != null).is_true()
		if slab == null:
			continue
		add_child(slab)
		assert_bool(_labels(slab).size() >= 2).is_true()


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
