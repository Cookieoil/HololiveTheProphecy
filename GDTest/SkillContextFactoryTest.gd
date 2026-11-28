class_name SkillContextFactoryTest
extends GdUnitTestSuite
## Locks Managers/SkillContextFactory.gd directly: the callables a skill resolves through.
## The extraction is what makes these cheap to test - no GameManager, no board wiring, just
## the factory and a UI double - so this is where the factory's own contract is pinned:
##   - a merged Buff's turn-wide bonus lands on the card value, and is spent by doing so
##   - a prompt offers every candidate the filter let through and returns the answer
##   - an empty candidate list never reaches the UI at all
##   - an enemy is never prompted, and its silent targeting is seeded
##   - what a prompt offered reaches the recorder (the pick-rate denominator)
##
## @author TheGreatJellyfish
## @version 11/28/2026

const TEMP_ROOT: String = "user://skill_context_test"
var _temp_dir: String = ""
var _run_index: int = 0


## In-memory sink, so the recorder assertions never write a spool file.
class MemorySink extends TelemetrySink:
	var events: Array = []
	var opened: bool = false

	func open(_run_id: String) -> void:
		opened = true

	func write_event(event: Dictionary) -> void:
		events.append(event)

	func is_open() -> bool:
		return opened

	func close() -> void:
		opened = false


## UI double: answers prompts from a script and counts what it was asked for.
class PromptUI extends GameUI:
	var target_answers: Array[Unit] = []
	var card_answers: Array[Card] = []
	var target_prompts: int = 0
	var card_prompts: int = 0
	var flashes: int = 0
	var last_flash_hostile: bool = false
	var last_card_candidates: Array = []
	var last_target_candidates: Array = []
	var messages: Array[String] = []

	func show_message(msg: String) -> void:
		messages.append(msg)

	func ask_pick_targets(units: Array[Unit], _count: int) -> Array[Unit]:
		target_prompts += 1
		last_target_candidates = units.duplicate()
		return target_answers

	func ask_pick_cards(cards: Array[Card], _count: int) -> Array[Card]:
		card_prompts += 1
		last_card_candidates = cards.duplicate()
		return card_answers

	func flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void:
		flashes += 1
		last_flash_hostile = hostile
		last_card_candidates = cards.duplicate()


#region Harness
## A UI double that is freed with the test, so a run never leaves a node behind.
func _make_ui() -> PromptUI:
	var ui: PromptUI = PromptUI.new()
	auto_free(ui)
	return ui


func before() -> void:
	_temp_dir = "%s/%s" % [TEMP_ROOT, TelemetrySchema.new_id()]


func after() -> void:
	# Launch flags are process-wide, so they are cleared between suites.
	TelemetryConsent.reset_launch_flag()
	TelemetryConsentPopup.reset_launch_flag()
	_remove_tree(_temp_dir)
	_remove_tree(TEMP_ROOT)


## Deletes a directory tree under user:// (tests only).
func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	for sub_name: String in dir.get_directories():
		_remove_tree(path + "/" + sub_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _make_unit(display_name: String, is_enemy: bool, hp: int, slot: int = 0) -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = display_name
	data.is_enemy = is_enemy
	data.max_hp = hp
	data.max_moxie = 20
	return Unit.new(data, slot)


## A board of full-HP units, slotted from 0, with no deck and no hand.
func _make_state(ally_count: int, enemy_count: int) -> GameState:
	var state: GameState = GameState.new()
	var allies: Array[Unit] = []
	for i: int in ally_count:
		allies.append(_make_unit("Ally %d" % i, false, 20, i))
	var enemies: Array[Unit] = []
	for i: int in enemy_count:
		enemies.append(_make_unit("Enemy %d" % i, true, 30, i))
	state.allies = allies
	state.enemies = enemies
	return state


## A consented recorder writing into `sink`, so a prompt's record can be read back.
func _make_recorder(sink: MemorySink) -> TelemetryManager:
	_run_index += 1
	var run_id: String = "run%d" % _run_index
	var consent_path: String = "%s/consent_%s.json" % [_temp_dir, run_id]
	TelemetryConsent.new(consent_path).decide(true)
	return TelemetryManager.new(
		consent_path, _temp_dir, "%s/player_%s.txt" % [_temp_dir, run_id], sink
	)


## A filter that accepts every unit a target prompt offers.
func _accept_units() -> Callable:
	return func(_unit: Variant) -> bool: return true


## A card filter that accepts one value only, so the offered list is easy to count.
func _only_value(value: int) -> Callable:
	return func(card: Variant) -> bool:
		var typed: Card = card
		return typed.get_effective_value() == value


## The slot indices one enemy targets, three at a time, on a freshly seeded board.
func _enemy_pick_order(seed_value: int) -> Array[int]:
	var state: GameState = _make_state(5, 1)
	state.set_run_seed(seed_value)
	var ui: PromptUI = _make_ui()
	var enemy: Unit = state.enemies[0]
	var ctx: SkillContext = SkillContextFactory.build_enemy_context(
		enemy, EnemyIntent.new(enemy, 3), state, ui
	)
	var picked: Array[Unit] = await ctx.pick_n_target.call(3, _accept_units())
	var slots: Array[int] = []
	for unit: Unit in picked:
		slots.append(unit.slot_index)
	return slots


## The first decision event written to the sink ({ } when there is none).
func _first_decision(sink: MemorySink) -> Dictionary:
	for event: Dictionary in sink.events:
		if str(event.get("type", "")) == "decision":
			return event
	return {}
#endregion


#region Ally context
## A merged Buff sets a turn-wide bonus on the state. It belongs to the next card played
## and is consumed by that card, so a turn cannot collect the same bonus twice.
func test_a_turn_wide_bonus_lands_on_the_card_value_and_is_spent() -> void:
	var state: GameState = _make_state(1, 1)
	var ui: PromptUI = _make_ui()
	state.next_skill_bonus = 4

	var ctx: SkillContext = SkillContextFactory.build_ally_context(
		state.allies[0], Card.new(3), state, ui, TelemetryManager.new()
	)

	assert_int(ctx.card_value).is_equal(7)
	assert_int(state.next_skill_bonus).is_equal(0)
	assert_int(ui.messages.size()).is_equal(1)

	# The next card of the same turn starts clean.
	var next: SkillContext = SkillContextFactory.build_ally_context(
		state.allies[0], Card.new(3), state, ui, TelemetryManager.new()
	)
	assert_int(next.card_value).is_equal(3)
	assert_int(ui.messages.size()).is_equal(1)


## The prompt offers exactly what the filter let through - the alternatives the player
## chose between - and hands back whatever the UI answered.
func test_a_card_prompt_offers_the_filtered_hand_and_returns_the_answer() -> void:
	var state: GameState = _make_state(1, 1)
	var ui: PromptUI = _make_ui()
	var hand: Array[Card] = [Card.new(3), Card.new(5), Card.new(3)]
	state.hand = hand
	ui.card_answers = [hand[0]]
	var ctx: SkillContext = SkillContextFactory.build_ally_context(
		state.allies[0], null, state, ui, TelemetryManager.new()
	)

	var picked: Array[Card] = await ctx.pick_n_card.call(1, _only_value(3))

	assert_int(ui.card_prompts).is_equal(1)
	assert_int(ui.last_card_candidates.size()).is_equal(2)
	assert_int(picked.size()).is_equal(1)
	assert_bool(picked[0] == hand[0]).is_true()


## Nothing to choose from is not a prompt: an empty list short-circuits before the UI.
func test_an_empty_candidate_list_never_prompts() -> void:
	var state: GameState = _make_state(1, 1)
	var ui: PromptUI = _make_ui()
	var hand: Array[Card] = [Card.new(3)]
	state.hand = hand
	var ctx: SkillContext = SkillContextFactory.build_ally_context(
		state.allies[0], null, state, ui, TelemetryManager.new()
	)

	var picked: Array[Card] = await ctx.pick_n_card.call(1, _only_value(9))

	assert_bool(picked.is_empty()).is_true()
	assert_int(ui.card_prompts).is_equal(0)


## A target prompt searches the whole board: a skill that may name an ally or an enemy
## sees both sides, not just the caster's own.
func test_a_target_prompt_offers_both_sides_of_the_board() -> void:
	var state: GameState = _make_state(2, 1)
	var ui: PromptUI = _make_ui()
	ui.target_answers = [state.enemies[0]]
	var ctx: SkillContext = SkillContextFactory.build_ally_context(
		state.allies[0], null, state, ui, TelemetryManager.new()
	)

	var picked: Array[Unit] = await ctx.pick_n_target.call(1, _accept_units())

	assert_int(ui.target_prompts).is_equal(1)
	assert_int(ui.last_target_candidates.size()).is_equal(3)
	assert_bool(picked[0] == state.enemies[0]).is_true()


## Revealing auto-picked cards is a flourish, not a prompt; revealing nothing is not even
## that. A player-caused reveal is friendly, so it is never flashed as hostile.
func test_a_reveal_reaches_the_ui_and_an_empty_reveal_never_does() -> void:
	var state: GameState = _make_state(1, 1)
	var ui: PromptUI = _make_ui()
	var ctx: SkillContext = SkillContextFactory.build_ally_context(
		state.allies[0], null, state, ui, TelemetryManager.new()
	)
	var nothing: Array[Card] = []

	await ctx.flash_cards.call(nothing)
	assert_int(ui.flashes).is_equal(0)

	var cards: Array[Card] = [Card.new(3)]
	await ctx.flash_cards.call(cards)
	assert_int(ui.flashes).is_equal(1)
	assert_bool(ui.last_flash_hostile).is_false()


## The log callback is the skill's voice in the battle log, and it is indented under the
## action line the turn loop already printed.
func test_a_log_line_is_indented_under_the_action_line() -> void:
	var state: GameState = _make_state(1, 1)
	var ui: PromptUI = _make_ui()
	var ctx: SkillContext = SkillContextFactory.build_ally_context(
		state.allies[0], null, state, ui, TelemetryManager.new()
	)

	ctx.log_message.call("Gains 3 Shield")

	assert_int(ui.messages.size()).is_equal(1)
	assert_str(ui.messages[0]).is_equal("  Gains 3 Shield")
#endregion


#region Enemy context
## An enemy action is never a prompt: the roll and the merged flag come from the intent,
## targeting is chosen silently (on the player's side, which is what it attacks) and every
## card change flashes red, because an enemy caused it.
func test_an_enemy_is_never_prompted_and_flashes_hostile() -> void:
	var state: GameState = _make_state(2, 1)
	var ui: PromptUI = _make_ui()
	var enemy: Unit = state.enemies[0]
	var intent: EnemyIntent = EnemyIntent.new(enemy, 3)
	var ctx: SkillContext = SkillContextFactory.build_enemy_context(enemy, intent, state, ui)

	assert_bool(ctx.caster == enemy).is_true()
	assert_int(ctx.card_value).is_equal(3)
	assert_bool(ctx.is_merged).is_equal(intent.condition_met)

	var picked: Array[Unit] = await ctx.pick_n_target.call(1, _accept_units())
	assert_int(ui.target_prompts).is_equal(0)
	assert_int(picked.size()).is_equal(1)
	assert_bool(picked[0].is_ally).is_true()

	var cards: Array[Card] = [Card.new(3)]
	await ctx.flash_cards.call(cards)
	assert_int(ui.flashes).is_equal(1)
	assert_bool(ui.last_flash_hostile).is_true()

	await ctx.flash_cards.call(cards)
	assert_int(ui.card_prompts).is_equal(0)


## Silent targeting still has to be reproducible: the same seed picks the same ally, so a
## run replays exactly. It is a real shuffle too, not slot order in disguise.
func test_enemy_targeting_is_seeded_and_not_a_fixed_slot_order() -> void:
	var replay: Array[int] = await _enemy_pick_order(4242)
	var again: Array[int] = await _enemy_pick_order(4242)
	assert_bool(replay == again).is_true()

	var orders: Dictionary = {}
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var order: Array[int] = await _enemy_pick_order(seed_value)
		orders[str(order)] = true
	assert_int(orders.size()).is_greater(1)
#endregion


#region The recorder seam
## The recorder is passed in for one reason: a prompt has to record the alternatives it
## was chosen over, or the pick-rate report has no denominator. This drives the real
## recorder through a decision window to prove the whole path lands.
func test_a_prompt_reaches_the_recorder_with_the_alternatives_it_was_chosen_over() -> void:
	var sink: MemorySink = MemorySink.new()
	var state: GameState = _make_state(1, 1)
	var ui: PromptUI = _make_ui()
	var hand: Array[Card] = [Card.new(3), Card.new(3)]
	state.hand = hand
	ui.card_answers = [hand[0]]
	var recorder: TelemetryManager = _make_recorder(sink)
	recorder.start_run(state)
	recorder.begin_decision(state, [])

	var ctx: SkillContext = SkillContextFactory.build_ally_context(
		state.allies[0], hand[0], state, ui, recorder
	)
	await ctx.pick_n_card.call(1, _only_value(3))
	recorder.end_decision({"type": "play"}, state)

	var prompts: Array = _first_decision(sink).get("sub_prompts", [])
	assert_int(prompts.size()).is_equal(1)
	var prompt: Dictionary = prompts[0]
	assert_str(str(prompt.get("prompt", ""))).is_equal("pick_card")
	var candidates: Array = prompt.get("candidates", [])
	var picked: Array = prompt.get("picked", [])
	assert_int(candidates.size()).is_equal(2)
	assert_int(picked.size()).is_equal(1)
	assert_int(prompt.get("thinking_time_ms", -1)).is_greater(-1)
#endregion
