class_name MessageLogTest
extends GdUnitTestSuite
## Locks the battle message log: the game authors it in BBCode (`ColorUtils.colorize`
## and the HOW TO PLAY block), so it must render rich text instead of leaking
## `[color=...]` tags as literal characters - which is what a plain Label does.
##
## @author TheGreatJellyfish
## @version 11/27/2026

const SCENE_PATH: String = "res://Scenes/BattleScene/BattleScene.tscn"


func _mount() -> BattleScene:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()
	if packed == null:
		return null
	var scene: BattleScene = packed.instantiate() as BattleScene
	assert_object(scene).is_not_null()
	if scene == null:
		return null
	add_child(scene)
	auto_free(scene)
	return scene


func test_message_log_is_a_bbcode_rich_text_label() -> void:
	var scene: BattleScene = _mount()
	assert_bool(scene.log_label is RichTextLabel).is_true()
	if not (scene.log_label is RichTextLabel):
		return
	var rich: RichTextLabel = scene.log_label
	assert_bool(rich.bbcode_enabled).is_true()
	assert_bool(rich.scroll_active).is_false()


func test_coloured_message_renders_as_text_not_tags() -> void:
	var scene: BattleScene = _mount()
	var rich: RichTextLabel = scene.log_label
	scene.show_message(ColorUtils.colorize("Drew 7 card(s).", ColorUtils.COLOR_CARD))

	var parsed: String = rich.get_parsed_text()
	assert_str(parsed).is_equal("Drew 7 card(s).")
	assert_bool(parsed.contains("[color")).is_false()
	assert_bool(parsed.contains("[/color]")).is_false()
