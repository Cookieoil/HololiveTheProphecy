class_name UiSnapshotTest
extends GdUnitTestSuite
## Locks the seams the UI snapshot pipeline (Tools/snapshot_runner.tscn) relies on:
## a fixed seed must reproduce the deal, and the overlay must expose a bounded,
## callable tooltip seam instead of demanding synthesised mouse hover.
##
## @author TheGreatJellyfish
## @version 11/27/2026

const SCENE_PATH: String = "res://Scenes/BattleScene/BattleScene.tscn"
## Enough frames for the seeded board to deal and reach the player-action phase.
const MAX_BOARD_FRAMES: int = 900
const SEED_PINNED: int = 1337


func _mount(seed_value: int) -> BattleScene:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()
	if packed == null:
		return null
	var scene: BattleScene = packed.instantiate() as BattleScene
	assert_object(scene).is_not_null()
	if scene == null:
		return null
	scene.fixed_seed_override = seed_value
	add_child(scene)
	auto_free(scene)
	return scene


func _wait_for_board(scene: BattleScene) -> bool:
	for i: int in range(MAX_BOARD_FRAMES):
		await get_tree().process_frame
		if scene.game_manager == null or scene.game_manager.state == null:
			continue
		if scene.game_manager.state.hand.size() > 0:
			return true
	return false


## The dealt cards in hand order, value by value: identical seeds must agree.
func _hand_signature(scene: BattleScene) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for card: Card in scene.game_manager.state.hand:
		parts.append("%d/%d" % [card.base_value, card.get_effective_value()])
	return ",".join(parts)


func _release(scene: BattleScene) -> void:
	scene.queue_free()
	for i: int in range(3):
		await get_tree().process_frame


func test_fixed_seed_reproduces_the_dealt_hand() -> void:
	var first: BattleScene = _mount(SEED_PINNED)
	assert_bool(await _wait_for_board(first)).is_true()
	var first_hand: String = _hand_signature(first)
	assert_bool(first_hand.is_empty()).is_false()
	await _release(first)

	var second: BattleScene = _mount(SEED_PINNED)
	assert_bool(await _wait_for_board(second)).is_true()
	assert_str(_hand_signature(second)).is_equal(first_hand)


func test_ultimate_callout_seam_is_bounded_and_exposes_the_tooltip() -> void:
	var scene: BattleScene = _mount(SEED_PINNED)
	assert_bool(await _wait_for_board(scene)).is_true()
	assert_object(scene.battle_overlay.get_skill_tooltip()).is_not_null()
	assert_bool(scene.battle_overlay.show_ally_ultimate_callout(-1)).is_false()
	assert_bool(scene.battle_overlay.show_ally_ultimate_callout(99)).is_false()

	var shown: bool = false
	for i: int in range(MAX_BOARD_FRAMES):
		if scene.battle_overlay.show_ally_ultimate_callout(0):
			shown = true
			break
		await get_tree().process_frame
	assert_bool(shown).is_true()
	scene.battle_overlay.get_skill_tooltip().hide_callout()
