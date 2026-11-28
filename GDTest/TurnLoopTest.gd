class_name TurnLoopTest
extends GdUnitTestSuite
## Locks the turn machine in Managers/GameManager.gd: the eight round steps in order,
## where each side's shields and the once-per-turn Ultimate lock are cleared, what each
## wave transition (FULL_TURN / IMMEDIATE_SKIP) does, and the places a board can end a
## battle - each with its own telemetry reason and its own turn-record timing.
##
## Characterisation, not aspiration: it was written against the loop as it stands, so it
## pins the behaviour a flattening refactor has to preserve rather than the behaviour
## that refactor happens to land on. The three outcome checkpoints in particular look
## alike and are not - they differ in which death they check first, in the reason they
## report, and in whether the round tick has already run when they fire.
##
## @author TheGreatJellyfish
## @version 11/28/2026

const TEMP_ROOT: String = "user://turn_loop_test"
var _temp_dir: String = ""
var _run_index: int = 0


## In-memory sink, so a characterisation run never writes a spool file.
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


## Test double: plays a scripted action per turn and records every time the loop
## touches the presentation, with the board snapshot taken at that moment.
class TurnUI extends GameUI:
	## The board the loop is driving, so a record can name the turn it was taken on.
	var state: GameState = null
	## Turn_number -> Array of actions to hand back in order. A turn whose queue runs
	## empty answers "end_turn", so a test only scripts the turns it cares about.
	var scripted: Dictionary = {}
	## Every observation point the loop hit, in call order.
	var trace: Array[Dictionary] = []
	## Intent counts handed to `show_enemy_intents`, in call order. A mid-phase wave
	## advance shows an empty preview.
	var intent_counts: Array[int] = []
	var battle_results: Array[bool] = []
	var messages: Array[String] = []

	func show_message(msg: String) -> void:
		messages.append(msg)

	func show_game_state(_state: GameState) -> void:
		pass

	func show_hand_and_resources(_state: GameState) -> void:
		pass

	func show_enemy_intents(intents: Array[EnemyIntent]) -> void:
		intent_counts.append(intents.size())
		_record("intents")

	func get_player_action(current: GameState) -> Dictionary:
		_record("ask")
		var queued: Array = scripted.get(current.turn_number, [])
		if queued.is_empty():
			return {"type": "end_turn"}
		var action: Dictionary = queued.pop_front()
		return action

	func play_unit_skill(unit: Unit, _skill_index: int, _rank: int = 0, _lead: float = 1.0) -> void:
		_record("skill", unit)

	func play_unit_ultimate(unit: Unit) -> void:
		_record("ultimate", unit)

	func ask_pick_targets(_units: Array[Unit], _count: int) -> Array[Unit]:
		return []

	func ask_pick_cards(_cards: Array[Card], _count: int) -> Array[Card]:
		return []

	func show_battle_result(victory: bool) -> void:
		battle_results.append(victory)

	## Snapshots the board at one observation point, tagged with the round step phase,
	## the turn the loop is on and (for an animation) the unit it belonged to. Shields
	## are the interesting part: they say which of the loop's two shield resets has
	## already run by the time the loop got here.
	func _record(phase: String, actor: Unit = null) -> void:
		trace.append({
			"phase": phase,
			"turn": state.turn_number,
			"actor": actor,
			"ally_shields": _shields(state.allies),
			"enemy_shields": _shields(state.enemies),
		})

	func _shields(units: Array[Unit]) -> Array[int]:
		var values: Array[int] = []
		for unit: Unit in units:
			values.append(unit.shield)
		return values


#region Skill fixtures
## A skill that hits every enemy for a fixed amount. From an enemy caster the same
## mode resolves to the player's allies, so one fixture is both sides' attack.
func _damage_skill(amount: int, skill_name: String) -> SkillData:
	var block: EffectBlock = EffectBlock.new()
	block.action_type = EffectBlock.Action.DEAL_DAMAGE
	block.target_mode = EffectBlock.TargetMode.ALL_ENEMIES
	block.value_source = EffectBlock.ValueSource.FIXED
	block.fixed_amount = amount
	block.condition = EffectBlock.Condition.NONE
	return _wrap_skill(skill_name, block)


## A skill that raises the caster's own side's shields.
func _shield_skill(amount: int) -> SkillData:
	var block: EffectBlock = EffectBlock.new()
	block.action_type = EffectBlock.Action.GAIN_SHIELD
	block.target_mode = EffectBlock.TargetMode.ALL_ALLIES
	block.value_source = EffectBlock.ValueSource.FIXED
	block.fixed_amount = amount
	block.condition = EffectBlock.Condition.NONE
	return _wrap_skill("Test Shield", block)


## A skill that costs the caster its own life, so a wave can be cleared during the
## enemy turn instead of during the player's.
func _self_destruct_skill() -> SkillData:
	var block: EffectBlock = EffectBlock.new()
	block.action_type = EffectBlock.Action.DEAL_TRUE_DAMAGE
	block.target_mode = EffectBlock.TargetMode.CASTER
	block.value_source = EffectBlock.ValueSource.FIXED
	block.fixed_amount = 999
	block.condition = EffectBlock.Condition.NONE
	return _wrap_skill("Test Self Destruct", block)


func _wrap_skill(skill_name: String, block: EffectBlock) -> SkillData:
	var effects: Array[SkillEffect] = [block]
	var skill: SkillData = SkillData.new()
	skill.skill_name = skill_name
	skill.base_effects = effects
	return skill


## The player: one ally whose odd-card and even-card skills the caller chooses, so a
## single test can shield first and nuke later with the two cards it holds.
func _ally_data(hp: int, odd_card_skill: SkillData, even_card_skill: SkillData) -> UnitData:
	var data: UnitData = UnitData.new()
	data.display_name = "Ally"
	data.max_hp = hp
	data.max_moxie = 20
	data.skill_1 = odd_card_skill
	data.skill_2 = even_card_skill
	return data


## An enemy whose two skills are identical, so its dice roll never changes what it
## does. No Ultimate: a full gauge must not add an unpredicted second action.
func _enemy_data(display_name: String, hp: int, attack: int, skill: SkillData = null) -> UnitData:
	var data: UnitData = UnitData.new()
	data.display_name = display_name
	data.is_enemy = true
	data.max_hp = hp
	data.max_moxie = 20
	var pair: SkillData = skill if skill != null else _damage_skill(attack, display_name + " Hit")
	data.skill_1 = pair
	data.skill_2 = pair
	return data


## One wave, or two when a successor is given.
func _waves(wave_zero: UnitData, wave_one: UnitData = null) -> Array:
	var first: Array[UnitData] = [wave_zero]
	var waves: Array = [first]
	if wave_one != null:
		var second: Array[UnitData] = [wave_one]
		waves.append(second)
	return waves
#endregion


#region Harness
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


## Builds a consented manager with a memory sink, a scripted UI and the given waves.
## The board is spawned through `_spawn_wave(0)`, exactly as `setup_game` does it, and
## the hand holds one odd card (skill 1) and one even card (skill 2).
func _prepare(
	waves: Array,
	ally_data: UnitData,
	sink: MemorySink,
	ui: TurnUI,
	mode: int = GameState.WaveTransition.FULL_TURN
) -> GameManager:
	_run_index += 1
	var run_id: String = "run%d" % _run_index
	var consent_path: String = "%s/consent_%s.json" % [_temp_dir, run_id]
	TelemetryConsent.new(consent_path).decide(true)

	var manager: GameManager = GameManager.new()
	add_child(manager)
	auto_free(manager)
	manager.state = GameState.new()
	manager.state.wave_transition_mode = mode
	manager.state.wave_definitions = waves
	var allies: Array[Unit] = [Unit.new(ally_data, 0)]
	manager.state.allies = allies
	var hand: Array[Card] = [Card.new(1), Card.new(2)]
	manager.state.hand = hand
	manager.telemetry = TelemetryManager.new(
		consent_path, _temp_dir, "%s/player_%s.txt" % [_temp_dir, run_id], sink
	)

	ui.state = manager.state
	add_child(ui)
	auto_free(ui)
	manager.ui = ui

	manager.telemetry.start_run(manager.state)
	manager._spawn_wave(0)
	manager.game_running = true
	return manager


## The action that plays one card from the hand on the first ally.
func _play(manager: GameManager, hand_index: int = 0) -> Dictionary:
	return {
		"type": "play",
		"card": manager.state.hand[hand_index],
		"target_ally": manager.state.allies[0],
	}
#endregion


#region Observation helpers
## The first trace entry the loop recorded at `phase` while on `turn`, or { }.
func _first_at(ui: TurnUI, phase: String, turn: int) -> Dictionary:
	for entry: Dictionary in ui.trace:
		var entry_turn: int = entry.get("turn", -1)
		if entry_turn == turn and str(entry.get("phase", "")) == phase:
			return entry
	return {}


## The shield a trace entry recorded for one side. -1 means "no reading", so a missing
## observation can never be mistaken for a real shield of 0.
func _shield_of(entry: Dictionary, side: String, index: int = 0) -> int:
	if entry.is_empty():
		return -1
	var values: Array = entry.get(side, [])
	if index >= values.size():
		return -1
	var value: int = values[index]
	return value


## How many times the loop asked the player for an action during one turn.
func _asks_on(ui: TurnUI, turn: int) -> int:
	var count: int = 0
	for entry: Dictionary in ui.trace:
		var entry_turn: int = entry.get("turn", -1)
		if entry_turn == turn and str(entry.get("phase", "")) == "ask":
			count += 1
	return count


## How many animations (a skill or an Ultimate) the loop played for `unit`. Pass a
## turn to count one round only, or -1 for the whole run.
func _animations_for(ui: TurnUI, unit: Unit, turn: int = -1) -> int:
	var count: int = 0
	for entry: Dictionary in ui.trace:
		var actor: Variant = entry.get("actor", null)
		if actor != unit:
			continue
		var entry_turn: int = entry.get("turn", -1)
		if turn < 0 or entry_turn == turn:
			count += 1
	return count


## The board snapshot taken while `unit`'s own animation was playing, or { }. This is
## how a test reads the board *during* a turn rather than after it.
func _while_acting(ui: TurnUI, unit: Unit) -> Dictionary:
	for entry: Dictionary in ui.trace:
		var actor: Variant = entry.get("actor", null)
		if actor == unit:
			return entry
	return {}


## How many logged lines contain `needle`.
func _messages_with(ui: TurnUI, needle: String) -> int:
	var count: int = 0
	for message: String in ui.messages:
		if message.contains(needle):
			count += 1
	return count


## True when the loop announced the round-end status tick, i.e. Step 8 ran.
func _ticked(ui: TurnUI) -> bool:
	for message: String in ui.messages:
		if message.contains("End of Round"):
			return true
	return false


func _events_of(sink: MemorySink, type_name: String) -> Array:
	var rows: Array = []
	for event: Dictionary in sink.events:
		if str(event.get("type", "")) == type_name:
			rows.append(event)
	return rows


## The turn_ended record for one turn ({ } when it was never written).
func _turn_ended(sink: MemorySink, turn_number: int) -> Dictionary:
	for event: Dictionary in _events_of(sink, "turn_ended"):
		var number: int = event.get("turn_number", -1)
		if number == turn_number:
			return event
	return {}


## The single run_ended record ({ } when the run never closed).
func _run_ended(sink: MemorySink) -> Dictionary:
	var rows: Array = _events_of(sink, "run_ended")
	if rows.is_empty():
		return {}
	var only: Dictionary = rows[0]
	return only


func _victory(sink: MemorySink) -> bool:
	var won: bool = _run_ended(sink).get("victory", false)
	return won


func _reason(sink: MemorySink) -> String:
	return str(_run_ended(sink).get("end_reason", ""))
#endregion


#region The intro gate
## The how-to-play block is a first-run courtesy, not a per-turn banner: it is shown on
## the first turn only, however many turns the run lasts.
func test_the_intro_is_shown_once_across_turns() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 30, 1)), _ally_data(20, nuke, nuke), sink, ui
	)
	# Turn 0 ends on the default End Turn, so the run reaches a second round; turn 1
	# nukes the boss and wins.
	ui.scripted = {1: [_play(manager)]}

	await manager._run_game_loop()

	assert_int(_messages_with(ui, "HOW TO PLAY")).is_equal(1)
	assert_bool(manager.instructions_shown).is_true()
	# Two rounds really ran, so "once" above is not just a one-turn battle.
	assert_int(_events_of(sink, "turn_started").size()).is_equal(2)
	assert_int(_messages_with(ui, "TURN 1")).is_equal(1)
	assert_int(_messages_with(ui, "TURN 2")).is_equal(1)
#endregion


#region Round order
## Every round opens by rolling and previewing the enemy intents, before the player is
## asked for anything: the preview is the first thing the loop touches.
func test_a_round_opens_with_the_intent_preview() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 30, 1)), _ally_data(20, nuke, nuke), sink, ui
	)
	ui.scripted = {1: [_play(manager)]}

	await manager._run_game_loop()

	assert_bool(ui.trace.is_empty()).is_false()
	assert_str(str(ui.trace[0].get("phase", ""))).is_equal("intents")
	assert_int(ui.intent_counts[0]).is_equal(1)
	assert_int(_asks_on(ui, 0)).is_greater(0)
#endregion


#region Shield and Ultimate-lock lifecycle
## An ally's shield is spent defending the enemy turn and cleared at the start of the
## player's *next* turn - not at the end of the turn it was raised in.
func test_an_ally_shield_survives_the_enemy_turn_and_clears_at_the_next_turn_start() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var shield: SkillData = _shield_skill(5)
	# skill_1 is the odd card's, skill_2 the even card's: hand[1] shields, hand[0] nukes.
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 30, 1)), _ally_data(20, nuke, shield), sink, ui
	)
	var boss: Unit = manager.state.enemies[0]
	ui.scripted = {0: [_play(manager, 1)], 1: [_play(manager, 0)]}

	await manager._run_game_loop()

	var ally: Unit = manager.state.allies[0]
	# The shield is still up while the boss swings at the end of turn 0 - and it has
	# already soaked the 1 point (the effect resolves before the animation plays), which
	# is what leaves the ally on full HP...
	assert_int(_shield_of(_while_acting(ui, boss), "ally_shields")).is_equal(4)
	assert_int(ally.current_hp).is_equal(20)
	# ...and it is gone before the player acted on turn 1. Step 1 (the preview) runs
	# before Step 2 (the clear), so the two observation points differ on purpose.
	assert_int(_shield_of(_first_at(ui, "intents", 1), "ally_shields")).is_equal(4)
	assert_int(_shield_of(_first_at(ui, "ask", 1), "ally_shields")).is_equal(0)
	assert_int(ally.shield).is_equal(0)


## An enemy's shield covers the player phase and is cleared right before the enemy turn
## (Step 6), so what the player saw while choosing is what the shield actually soaked.
func test_an_enemy_shield_survives_the_player_phase_and_clears_before_the_enemy_acts() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 30, 1)), _ally_data(20, nuke, nuke), sink, ui
	)
	var boss: Unit = manager.state.enemies[0]
	boss.shield = 5
	ui.scripted = {1: [_play(manager)]}

	await manager._run_game_loop()

	# The player phase still saw the shield...
	assert_int(_shield_of(_first_at(ui, "ask", 0), "enemy_shields")).is_equal(5)
	# ...and it was gone by the time the boss acted (Step 6 resets, Step 7 acts).
	assert_int(_shield_of(_while_acting(ui, boss), "enemy_shields")).is_equal(0)


## The once-per-turn Ultimate lock is released for both sides at the start of the round,
## so a lock left behind by the previous round can never strand an Ultimate.
func test_both_sides_release_the_ultimate_lock_at_the_turn_start() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 30, 1)), _ally_data(20, nuke, nuke), sink, ui
	)
	var ally: Unit = manager.state.allies[0]
	var boss: Unit = manager.state.enemies[0]
	ally.ult_used_this_turn = true
	boss.ult_used_this_turn = true
	ui.scripted = {1: [_play(manager)]}

	await manager._run_game_loop()

	assert_int(_asks_on(ui, 0)).is_greater(0)
	assert_bool(ally.ult_used_this_turn).is_false()
	assert_bool(boss.ult_used_this_turn).is_false()
#endregion


#region Wave transitions: FULL_TURN
## A FULL_TURN clear ends the round there: the next wave is spawned at the start of the
## following turn, so the cleared wave's enemy turn *and* the round-end status tick are
## both skipped, and the player opens the new wave with a fresh turn.
func test_a_full_turn_advance_skips_the_enemy_turn_and_the_round_tick() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var waves: Array = _waves(
		_enemy_data("Wave 0 Boss", 10, 1), _enemy_data("Wave 1 Boss", 30, 1)
	)
	var manager: GameManager = _prepare(waves, _ally_data(20, nuke, nuke), sink, ui)
	var ally: Unit = manager.state.allies[0]
	var first_boss: Unit = manager.state.enemies[0]
	# Gloom costs 3 HP the moment the round tick runs - exactly what the advance skips.
	ally.apply_status(Unit.STATUS_GLOOM, 3)
	ui.scripted = {0: [_play(manager)], 1: [_play(manager)]}

	await manager._run_game_loop()

	assert_int(manager.state.current_wave).is_equal(1)
	assert_bool(_victory(sink)).is_true()
	assert_str(_reason(sink)).is_equal(TelemetryManager.REASON_FINAL_WAVE)
	# Wave 0 never acted (its turn was skipped) and wave 1 died before it could.
	assert_int(_animations_for(ui, first_boss)).is_equal(0)
	assert_int(_animations_for(ui, ally)).is_equal(2)
	# Step 8 never ran, so the Gloom is still sitting on the ally, unfired.
	assert_bool(_ticked(ui)).is_false()
	assert_int(ally.current_hp).is_equal(20)
	assert_bool(ally.has_status(Unit.STATUS_GLOOM)).is_true()
	# Turn 0's record was closed *before* the wave advanced (Step 5), so it still names
	# the wave the turn was played in rather than the one that replaced it.
	var closed: Dictionary = _turn_ended(sink, 0)
	var closed_wave: int = closed.get("wave_index", -1)
	assert_int(closed_wave).is_equal(0)
	assert_int(_events_of(sink, "turn_started").size()).is_equal(2)


## The skipped turn belongs to the cleared wave only: a wave spawned by a FULL_TURN
## advance acts normally from the next turn, and losing there is reported as an ally
## wipe rather than a wave clear.
func test_a_full_turn_advance_lets_the_new_wave_act_on_the_next_turn() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var waves: Array = _waves(
		_enemy_data("Wave 0 Boss", 10, 1), _enemy_data("Wave 1 Boss", 30, 999)
	)
	var manager: GameManager = _prepare(waves, _ally_data(20, nuke, nuke), sink, ui)
	var first_boss: Unit = manager.state.enemies[0]
	ui.scripted = {0: [_play(manager)]}

	await manager._run_game_loop()

	var second_boss: Unit = manager.state.enemies[0]
	assert_int(_animations_for(ui, first_boss)).is_equal(0)
	assert_int(_animations_for(ui, second_boss, 1)).is_equal(1)
	assert_bool(_victory(sink)).is_false()
	assert_str(_reason(sink)).is_equal(TelemetryManager.REASON_ALL_ALLIES_DEAD)
	assert_int(_events_of(sink, "turn_started").size()).is_equal(2)
#endregion


#region Wave transitions: IMMEDIATE_SKIP
## An IMMEDIATE_SKIP clear spawns the next wave inside the player phase and empties the
## intent row, so the new enemies stand still for the rest of the turn - but the round
## itself finishes normally: the player keeps acting and Step 8 still ticks statuses.
func test_an_immediate_skip_advance_spawns_the_next_wave_inside_the_player_phase() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var waves: Array = _waves(
		_enemy_data("Wave 0 Boss", 10, 1), _enemy_data("Wave 1 Boss", 30, 1)
	)
	var manager: GameManager = _prepare(
		waves, _ally_data(20, nuke, nuke), sink, ui, GameState.WaveTransition.IMMEDIATE_SKIP
	)
	var ally: Unit = manager.state.allies[0]
	ally.apply_status(Unit.STATUS_GLOOM, 3)
	ui.scripted = {0: [_play(manager)], 1: [_play(manager)]}

	await manager._run_game_loop()

	var second_boss: Unit = manager.state.enemies[0]
	assert_int(manager.state.current_wave).is_equal(1)
	# The advance happened mid-phase: the player was asked twice that turn (the nuke,
	# then the End Turn the test never scripted) and the intent row was cleared.
	assert_int(_asks_on(ui, 0)).is_equal(2)
	assert_bool(ui.intent_counts.has(0)).is_true()
	# The wave that skipped its turn never acts, and it dies on the next turn - but the
	# round did not skip anything: the Gloom ticked 3 HP off the ally at Step 8.
	assert_int(_animations_for(ui, second_boss)).is_equal(0)
	assert_bool(_ticked(ui)).is_true()
	assert_int(ally.current_hp).is_equal(17)
	assert_bool(_victory(sink)).is_true()
	assert_str(_reason(sink)).is_equal(TelemetryManager.REASON_FINAL_WAVE)
#endregion


#region Endings: an enemy-turn wipe
## A wipe during the enemy turn closes the turn record and ends the battle on the spot:
## the round tick never runs, so a status that was about to fire does not get to.
func test_an_enemy_turn_wipe_ends_the_battle_before_the_round_tick() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 30, 999)), _ally_data(20, nuke, nuke), sink, ui
	)
	var boss: Unit = manager.state.enemies[0]
	boss.apply_status(Unit.STATUS_GLOOM, 4) # 4 HP the skipped tick never gets to take

	await manager._run_game_loop()

	assert_bool(_victory(sink)).is_false()
	assert_str(_reason(sink)).is_equal(TelemetryManager.REASON_ALL_ALLIES_DEAD)
	assert_bool(_ticked(ui)).is_false()
	assert_int(boss.current_hp).is_equal(30)
	assert_bool(boss.has_status(Unit.STATUS_GLOOM)).is_true()
	# The turn record was still closed, exactly once, on the way out.
	assert_int(_events_of(sink, "turn_ended").size()).is_equal(1)
	assert_int(ui.battle_results.size()).is_equal(1)
	assert_bool(ui.battle_results[0]).is_false()
#endregion


#region Endings: a round-end status tick
## A tick that kills the last ally reports a *status* death, not an ally wipe: the two
## share the defeat outcome but not the reason the balance report reads.
func test_a_round_end_tick_that_kills_the_last_ally_reports_a_status_death() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 30, 1)), _ally_data(3, nuke, nuke), sink, ui
	)
	# 3 HP, one point of chip damage from the boss, then a 3-point Gloom tick: the ally
	# survives the enemy turn and dies to the round.
	manager.state.allies[0].apply_status(Unit.STATUS_GLOOM, 3)

	await manager._run_game_loop()

	assert_bool(_ticked(ui)).is_true()
	assert_bool(_victory(sink)).is_false()
	assert_str(_reason(sink)).is_equal(TelemetryManager.REASON_STATUS_TICK)
	assert_int(_events_of(sink, "turn_ended").size()).is_equal(1)


## A tick that kills the last enemy on the final wave wins the battle: a win is not
## reserved for a played card.
func test_a_round_end_tick_that_kills_the_last_enemy_wins_the_battle() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 2, 1)), _ally_data(20, nuke, nuke), sink, ui
	)
	var boss: Unit = manager.state.enemies[0]
	boss.apply_status(Unit.STATUS_GLOOM, 2) # exactly its HP

	await manager._run_game_loop()

	assert_int(_animations_for(ui, boss)).is_equal(1) # it acted first, then died to the tick
	assert_bool(boss.is_dead).is_true()
	assert_bool(_victory(sink)).is_true()
	assert_str(_reason(sink)).is_equal(TelemetryManager.REASON_FINAL_WAVE)
	assert_int(_events_of(sink, "turn_ended").size()).is_equal(1)


## A tick that clears a wave with a successor advances the run instead of ending it. That
## record is closed before the advance is attempted (Step 8 closes, then checks), so turn
## 0 names the wave it was played in - same ordering as the Step 5 advance.
func test_a_round_end_tick_on_a_non_final_wave_advances_the_run() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var waves: Array = _waves(
		_enemy_data("Wave 0 Boss", 2, 1), _enemy_data("Wave 1 Boss", 30, 1)
	)
	var manager: GameManager = _prepare(waves, _ally_data(20, nuke, nuke), sink, ui)
	var first_boss: Unit = manager.state.enemies[0]
	first_boss.apply_status(Unit.STATUS_GLOOM, 2)
	ui.scripted = {1: [_play(manager)]}

	await manager._run_game_loop()

	assert_int(manager.state.current_wave).is_equal(1)
	assert_int(_animations_for(ui, first_boss)).is_equal(1)
	assert_bool(_ticked(ui)).is_true()
	# Closed before the tick's own outcome check, so turn 0 still reads as wave 0.
	var closed: Dictionary = _turn_ended(sink, 0)
	var closed_wave: int = closed.get("wave_index", -1)
	assert_int(closed_wave).is_equal(0)
	assert_bool(_victory(sink)).is_true()


## When the round tick kills both sides the run is a defeat: the ally check comes first,
## so a mutual wipe can never be recorded as a win.
func test_a_mutual_round_end_wipe_resolves_as_a_defeat() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var manager: GameManager = _prepare(
		_waves(_enemy_data("Boss", 1, 1)), _ally_data(2, nuke, nuke), sink, ui
	)
	# One stack each: the boss chips the ally down to 1, then the tick takes the last
	# point off both of them in the same round.
	manager.state.allies[0].apply_status(Unit.STATUS_GLOOM, 1)
	manager.state.enemies[0].apply_status(Unit.STATUS_GLOOM, 1)

	await manager._run_game_loop()

	assert_bool(manager.state.all_allies_dead()).is_true()
	assert_bool(manager.state.all_enemies_dead()).is_true()
	assert_bool(_victory(sink)).is_false()
	assert_str(_reason(sink)).is_equal(TelemetryManager.REASON_STATUS_TICK)
#endregion


#region Endings: a wave cleared during the enemy turn
## A wave can be cleared by the enemy turn too - the last enemy dies to its own skill.
## That path advances the wave and then *falls through* to Step 8, so the round still
## ticks (unlike the Step 5 advance, which skips it).
func test_a_wave_cleared_during_the_enemy_turn_still_ticks_the_round() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: TurnUI = TurnUI.new()
	var nuke: SkillData = _damage_skill(99, "Nuke")
	var waves: Array = _waves(
		_enemy_data("Wave 0 Boss", 30, 0, _self_destruct_skill()),
		_enemy_data("Wave 1 Boss", 30, 1)
	)
	var manager: GameManager = _prepare(waves, _ally_data(20, nuke, nuke), sink, ui)
	var ally: Unit = manager.state.allies[0]
	var first_boss: Unit = manager.state.enemies[0]
	ally.apply_status(Unit.STATUS_GLOOM, 2)
	ui.scripted = {1: [_play(manager)]}

	await manager._run_game_loop()

	assert_int(manager.state.current_wave).is_equal(1)
	assert_bool(first_boss.is_dead).is_true()
	assert_int(_animations_for(ui, first_boss)).is_equal(1)
	# The ally's Gloom ticked at Step 8 of turn 0: the enemy-turn clear fell through
	# instead of short-circuiting the round.
	assert_bool(_ticked(ui)).is_true()
	assert_int(ally.current_hp).is_equal(18)
	var closed: Dictionary = _turn_ended(sink, 0)
	var closed_wave: int = closed.get("wave_index", -1)
	assert_int(closed_wave).is_equal(1)
	assert_bool(_victory(sink)).is_true()
	assert_str(_reason(sink)).is_equal(TelemetryManager.REASON_FINAL_WAVE)
#endregion
#endregion
