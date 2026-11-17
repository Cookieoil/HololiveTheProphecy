class_name CardUITest
extends GdUnitTestSuite
## Tests for CardUI's runtime card feedback:
## the delayed value-label refresh after a skill buff/debuff and the hostile
## (enemy-caused) red glow preset.
##
## @author TheGreatJellyfish
## @version 11/16/2026

const CARD_UI_SCENE_PATH: String = "res://Scenes/GameUI/GraphicalUI/Cards/CardUI.tscn"

## Mid colours of the OutlineGlow presets a hand card picks between.
const CRIMSON_MID: Color = Color(0.98, 0.26, 0.24)        # THREAT_CRIMSON
const RUNETERRA_BLUE_MID: Color = Color(0.18, 0.70, 1.00) # RUNETERRA_BLUE


## Instantiates a real CardUI for a card and puts it in the test scene tree.
## gdUnit4's add_child() frees the node again after the test case.
func _make_card_ui(card: Card) -> CardUI:
	var scene: PackedScene = load(CARD_UI_SCENE_PATH) as PackedScene
	var node: Node = scene.instantiate()
	add_child(node)
	var ui: CardUI = node as CardUI
	ui.setup(card, null)
	return ui


## Reads a shader parameter off the card's glow, so a test can verify which
## OutlineGlow preset is currently live.
func _glow_param(ui: CardUI, param: String) -> Variant:
	var glow: OutlineGlow = ui._glow
	if glow == null:
		return null
	var mat: ShaderMaterial = glow._mat
	if mat == null:
		return null
	return mat.get_shader_parameter(param)


func _glow_is_active(ui: CardUI) -> bool:
	var glow: OutlineGlow = ui._glow
	if glow == null:
		return false
	return glow._active


func test_value_label_refreshes_after_runtime_value_change() -> void:
	var card: Card = Card.new(4)
	var ui: CardUI = _make_card_ui(card)
	ui.value_change_delay = 0.2
	assert_str(ui.value_label.text).is_equal("4 V")

	# The model mutates first: the label must not jump on the same frame.
	card.value_debuff = 2
	EventBus.card_value_changed.emit(card, 4, 2)
	assert_str(ui.value_label.text).is_equal("4 V")

	# ...but it must catch up once the reaction delay has elapsed.
	await await_millis(600)
	assert_str(ui.value_label.text).is_equal("2 V")


func test_unrelated_card_change_is_ignored() -> void:
	var card: Card = Card.new(3)
	var other: Card = Card.new(5)
	var ui: CardUI = _make_card_ui(card)
	ui.value_change_delay = 0.05

	other.value_debuff = 2
	EventBus.card_value_changed.emit(other, 5, 3)
	await await_millis(300)

	assert_str(ui.value_label.text).is_equal("3 V")


func test_hostile_flash_uses_the_crimson_preset() -> void:
	var card: Card = Card.new(3)
	var ui: CardUI = _make_card_ui(card)

	# Player-caused reveal keeps the friendly blue.
	ui.set_flash_active(true, false)
	var friendly: Variant = _glow_param(ui, "color_mid")
	assert_bool(friendly is Color).is_true()
	var friendly_col: Color = friendly
	assert_bool(friendly_col.is_equal_approx(RUNETERRA_BLUE_MID)).is_true()
	ui.set_flash_active(false)

	# Enemy-caused reveal switches to crimson.
	ui.set_flash_active(true, true)
	var hostile: Variant = _glow_param(ui, "color_mid")
	assert_bool(hostile is Color).is_true()
	var hostile_col: Color = hostile
	assert_bool(hostile_col.is_equal_approx(CRIMSON_MID)).is_true()

	# Clearing the flash also clears the hostile flag and the glow.
	ui.set_flash_active(false)
	assert_bool(ui._flash_hostile).is_false()
	assert_bool(_glow_is_active(ui)).is_false()
