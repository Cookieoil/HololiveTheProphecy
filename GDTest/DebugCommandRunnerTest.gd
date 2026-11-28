class_name DebugCommandRunnerTest
extends GdUnitTestSuite
## Locks the seams of Managers/DebugCommandRunner.gd that the turn-loop suite cannot
## reach. GDTest/DebugMenuTest.gd drives every tool through GameManager, so what is
## asserted here is the part that only exists because of the split:
##
## - the target resolver's safety rule (a payload with no usable target selects the
##   ally row, never the whole board),
## - argument coercion across the float / bool / string shapes a UI control hands over,
## - and the two tools that must *ask* the turn loop for its machinery instead of
##   calling back into the manager.
##
## @author TheGreatJellyfish
## @version 11/28/2026


## The tools only ever log and repaint through GameUI.
class SilentUI extends GameUI:
	var messages: Array[String] = []

	func show_message(msg: String) -> void:
		messages.append(msg)


func _unit(display_name: String, is_enemy: bool, max_hp: int = 20) -> Unit:
	var data: UnitData = UnitData.new()
	data.display_name = display_name
	data.is_enemy = is_enemy
	data.max_hp = max_hp
	data.max_moxie = 20
	return Unit.new(data)


func _state() -> GameState:
	var state: GameState = GameState.new()
	var allies: Array[Unit] = [_unit("Striker", false), _unit("Healer", false)]
	state.allies = allies
	var enemies: Array[Unit] = [_unit("Enemy", true), _unit("Boss", true)]
	state.enemies = enemies
	return state


func _ui() -> SilentUI:
	var ui: SilentUI = SilentUI.new()
	add_child(ui)
	auto_free(ui)
	return ui


## The doc comment on `_targets` promises this: a malformed command must never sweep
## the whole board. An unparsable `args` therefore resolves to the ally row only.
func test_a_malformed_payload_can_never_sweep_the_whole_board() -> void:
	var state: GameState = _state()
	var runner: DebugCommandRunner = DebugCommandRunner.new()

	runner.apply({"command": "kill", "args": "not a dictionary"}, state, _ui())

	for ally: Unit in state.allies:
		assert_bool(ally.is_dead).is_true()
	for enemy: Unit in state.enemies:
		assert_bool(enemy.is_dead).is_false()


## slot >= 0 means one specific slot of its own row, so a slot past the end of the row
## is simply nothing - it must not fall through to "the whole row".
func test_a_slot_beyond_the_row_selects_nothing() -> void:
	var state: GameState = _state()

	DebugCommandRunner.new().apply(
		{"command": "damage", "args": {"scope": DebugCommandRunner.SCOPE_ENEMIES, "slot": 9, "amount": 5}},
		state,
		_ui()
	)

	for enemy: Unit in state.enemies:
		assert_int(enemy.current_hp).is_equal(enemy.max_hp)


func test_scope_all_selects_both_rows() -> void:
	var state: GameState = _state()

	DebugCommandRunner.new().apply(
		{"command": "damage", "args": {"scope": DebugCommandRunner.SCOPE_ALL, "slot": -1, "amount": 3}},
		state,
		_ui()
	)

	for ally: Unit in state.allies:
		assert_int(ally.current_hp).is_equal(ally.max_hp - 3)
	for enemy: Unit in state.enemies:
		assert_int(enemy.current_hp).is_equal(enemy.max_hp - 3)


## A UI control hands its value over as a float, a bool or a string, depending on the
## widget, so the runner has to coerce all three.
func test_arguments_arrive_as_floats_bools_and_strings() -> void:
	var state: GameState = _state()
	var runner: DebugCommandRunner = DebugCommandRunner.new()
	var ui: SilentUI = _ui()

	runner.apply({"command": "grant_actions", "args": {"amount": "3"}}, state, ui)
	assert_int(state.actions_left).is_equal(3)
	runner.apply({"command": "grant_merges", "args": {"amount": 2.0}}, state, ui)
	assert_int(state.merges_left).is_equal(2)
	runner.apply({"command": "grant_next_bonus", "args": {"amount": true}}, state, ui)
	assert_int(state.next_skill_bonus).is_equal(1)


func test_the_hand_cap_stepper_clamps_at_the_limit() -> void:
	var state: GameState = _state()

	DebugCommandRunner.new().apply({"command": "step_max_hand", "args": {"delta": 999}}, state, _ui())

	assert_int(state.max_hand_size).is_equal(DebugCommandRunner.HAND_CAP_LIMIT)


## The runner cannot re-roll the intents or re-spawn a wave itself without desyncing
## the loop, so it raises a request and GameManager connects the handler.
func test_reroll_and_respawn_are_requests_not_calls() -> void:
	var state: GameState = _state()
	var runner: DebugCommandRunner = DebugCommandRunner.new()
	var ui: SilentUI = _ui()
	var seen: Array[String] = []
	runner.intents_reroll_requested.connect(func() -> void: seen.append("reroll"))
	runner.wave_respawn_requested.connect(func() -> void: seen.append("respawn"))

	runner.apply({"command": "reroll_intents"}, state, ui)
	runner.apply({"command": "respawn_wave"}, state, ui)

	assert_int(seen.size()).is_equal(2)
	assert_str(seen[0]).is_equal("reroll")
	assert_str(seen[1]).is_equal("respawn")
	# The request is not silent: the tester sees what happened.
	assert_int(ui.messages.size()).is_equal(2)


func test_a_result_preview_is_remembered_for_the_turn_loop() -> void:
	var runner: DebugCommandRunner = DebugCommandRunner.new()

	runner.apply({"command": "show_defeat"}, _state(), _ui())

	assert_int(runner.result_request).is_equal(DebugCommandRunner.RESULT_DEFEAT)


func test_an_unknown_command_is_reported_instead_of_crashing() -> void:
	var ui: SilentUI = _ui()

	DebugCommandRunner.new().apply({"command": "does_not_exist"}, _state(), ui)

	assert_int(ui.messages.size()).is_equal(1)
	assert_bool(ui.messages[0].contains("Unknown debug command")).is_true()
