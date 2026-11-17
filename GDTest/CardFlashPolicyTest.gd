class_name CardFlashPolicyTest
extends GdUnitTestSuite
## Locks in *who caused it* when the game reveals hand cards it picked on its own:
##   - an enemy acting on the player's hand flashes hostile (crimson)
##   - the player's own skill flashes friendly (blue)
##
## The interactive pick prompt never flashes: its cards stay lit until the player
## clicks (see BattleScene.ask_pick_cards).
##
## @author TheGreatJellyfish
## @version 11/17/2026


## Test double that records the flash requests GameManager makes.
class RecordingUI extends GameUI:
	var flash_calls: int = 0
	var last_count: int = 0
	var last_hostile: bool = false

	func flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void:
		flash_calls += 1
		last_count = cards.size()
		last_hostile = hostile


## Builds a manager with a hand of the given card values plus a recording UI.
func _make_manager(hand_values: Array[int]) -> GameManager:
	var manager: GameManager = GameManager.new()
	add_child(manager)

	var hand: Array[Card] = []
	for value: int in hand_values:
		hand.append(Card.new(value))

	manager.state = GameState.new()
	manager.state.hand = hand

	var recorder: RecordingUI = RecordingUI.new()
	add_child(recorder)
	manager.ui = recorder
	return manager


func _recorder(manager: GameManager) -> RecordingUI:
	return manager.ui as RecordingUI


func _make_enemy() -> Unit:
	var data: UnitData = UnitData.new()
	data.is_enemy = true
	return Unit.new(data)


func _accept_all() -> Callable:
	return func(_c: Card) -> bool: return true


func test_enemy_auto_pick_flashes_hostile() -> void:
	var manager: GameManager = _make_manager([5, 3])
	var enemy: Unit = _make_enemy()
	var ctx: SkillContext = manager._build_enemy_context(enemy, EnemyIntent.new(enemy, 3))

	var picked: Array[Card] = await ctx.pick_n_card.call(2, _accept_all())

	assert_int(picked.size()).is_equal(2)
	var recorder: RecordingUI = _recorder(manager)
	assert_int(recorder.flash_calls).is_equal(1)
	assert_int(recorder.last_count).is_equal(2)
	assert_bool(recorder.last_hostile).is_true()


func test_enemy_auto_pick_with_empty_hand_does_not_flash() -> void:
	var manager: GameManager = _make_manager([])
	var enemy: Unit = _make_enemy()
	var ctx: SkillContext = manager._build_enemy_context(enemy, EnemyIntent.new(enemy, 3))

	var picked: Array[Card] = await ctx.pick_n_card.call(1, _accept_all())

	assert_bool(picked.is_empty()).is_true()
	assert_int(_recorder(manager).flash_calls).is_equal(0)


func test_enemy_effect_flash_is_hostile() -> void:
	var manager: GameManager = _make_manager([5, 3])
	var enemy: Unit = _make_enemy()
	var ctx: SkillContext = manager._build_enemy_context(enemy, EnemyIntent.new(enemy, 3))

	var cards: Array[Card] = [manager.state.hand[0]]
	await ctx.flash_cards.call(cards)

	var recorder: RecordingUI = _recorder(manager)
	assert_int(recorder.flash_calls).is_equal(1)
	assert_int(recorder.last_count).is_equal(1)
	assert_bool(recorder.last_hostile).is_true()


func test_player_effect_flash_is_friendly() -> void:
	var manager: GameManager = _make_manager([5, 3])
	var ally: Unit = Unit.new(UnitData.new())
	var ctx: SkillContext = manager._build_ally_context(ally, Card.new(2))

	var cards: Array[Card] = [manager.state.hand[0], manager.state.hand[1]]
	await ctx.flash_cards.call(cards)

	var recorder: RecordingUI = _recorder(manager)
	assert_int(recorder.flash_calls).is_equal(1)
	assert_int(recorder.last_count).is_equal(2)
	assert_bool(recorder.last_hostile).is_false()
