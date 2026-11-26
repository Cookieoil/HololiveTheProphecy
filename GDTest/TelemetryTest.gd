class_name TelemetryTest
extends GdUnitTestSuite
## Locks the gameplay recorder end to end: a real battle through GameManager must
## produce run / wave / turn / decision / run-ended events, every decision must
## carry the alternatives it was chosen over (the "pick rate" denominator), and
## tester tools must taint the run.
##
## @author TheGreatJellyfish
## @version 11/26/2026

const TEMP_ROOT: String = "user://telemetry_test"
var _temp_dir: String = ""


## In-memory sink so a test never writes a spool file.
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


## A UI that plays a fixed script per turn: play, merge, convert, then Ultimate.
class ScriptedUI extends GameUI:
	var _seen: Dictionary = {}
	## When >= 0, turn `send_debug_on_turn` issues one tester command instead of
	## its scripted action, so the taint path is exercised through the real loop.
	var send_debug_on_turn: int = -1

	func show_message(_msg: String) -> void:
		pass

	func show_game_state(_state: GameState) -> void:
		pass

	func show_enemy_intents(_intents: Array[EnemyIntent]) -> void:
		pass

	func show_hand_and_resources(_state: GameState) -> void:
		pass

	func play_unit_skill(_unit: Unit, _skill_index: int, _rank: int = 0, _lead: float = 1.0) -> void:
		pass

	func play_unit_ultimate(_unit: Unit) -> void:
		pass

	func show_battle_result(_victory: bool) -> void:
		pass

	func get_player_action(state: GameState) -> Dictionary:
		var turn: int = state.turn_number
		var index: int = _seen.get(turn, 0)
		_seen[turn] = index + 1
		if index == 0:
			if turn == send_debug_on_turn:
				return {"type": "debug", "command": "grant_actions", "args": {"amount": 1}}
			match turn:
				0:
					return _play_first(state)
				1:
					return _merge_pair(state)
				2:
					return {"type": "convert"}
				3:
					return _cast_ultimate(state)
		return {"type": "end_turn"}

	func ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]:
		var picked: Array[Unit] = []
		for i: int in mini(count, units.size()):
			picked.append(units[i])
		return picked

	func ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]:
		var picked: Array[Card] = []
		for i: int in mini(count, cards.size()):
			picked.append(cards[i])
		return picked

	func _play_first(state: GameState) -> Dictionary:
		var target: Unit = null
		for unit: Unit in state.allies:
			if not unit.is_dead:
				target = unit
				break
		if target != null and not state.hand.is_empty():
			return {"type": "play", "card": state.hand[0], "target_ally": target}
		return {"type": "end_turn"}

	func _merge_pair(state: GameState) -> Dictionary:
		if state.hand.size() >= 2:
			return {"type": "merge", "card_a": state.hand[0], "card_b": state.hand[1]}
		return {"type": "end_turn"}

	func _cast_ultimate(state: GameState) -> Dictionary:
		if state.allies.is_empty():
			return {"type": "end_turn"}
		var caster: Unit = state.allies[0]
		caster.set_moxie(caster.max_moxie)
		return {"type": "ultimate", "caster": caster}


#region Helpers
func before() -> void:
	_temp_dir = "%s/%s" % [TEMP_ROOT, TelemetrySchema.new_id()]


func after() -> void:
	_remove_tree(_temp_dir)
	_remove_tree(TEMP_ROOT)


## Deletes a directory tree under user:// (tests only).
func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir != null:
		for file_name: String in dir.get_files():
			dir.remove(file_name)
		for sub_name: String in dir.get_directories():
			_remove_tree(path + "/" + sub_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _nuke_skill(skill_id: String, target_mode: int, amount: int) -> SkillData:
	var block: EffectBlock = EffectBlock.new()
	block.action_type = EffectBlock.Action.DEAL_DAMAGE
	block.target_mode = target_mode
	block.value_source = EffectBlock.ValueSource.FIXED
	block.fixed_amount = amount
	block.condition = EffectBlock.Condition.NONE
	var effects: Array[SkillEffect] = [block]
	var skill: SkillData = SkillData.new()
	skill.skill_id = skill_id
	skill.skill_name = skill_id
	skill.base_effects = effects
	return skill


func _ally_data() -> UnitData:
	var data: UnitData = UnitData.new()
	data.unit_id = "striker"
	data.display_name = "Striker"
	data.is_enemy = false
	data.max_hp = 100
	data.max_moxie = 20
	data.skill_1 = _nuke_skill("striker_1", EffectBlock.TargetMode.ALL_ENEMIES, 99)
	data.skill_2 = _nuke_skill("striker_2", EffectBlock.TargetMode.ALL_ENEMIES, 99)
	data.ultimate = _nuke_skill("striker_ult", EffectBlock.TargetMode.ALL_ENEMIES, 99)
	return data


func _enemy_data(unit_id: String) -> UnitData:
	var data: UnitData = UnitData.new()
	data.unit_id = unit_id
	data.display_name = unit_id
	data.is_enemy = true
	data.max_hp = 10
	data.max_moxie = 20
	# From an enemy caster ALL_ENEMIES resolves to the player's allies (see
	# EffectBlock's target resolution), so this is the enemy's attack.
	data.skill_1 = _nuke_skill("normal_enemy_1", EffectBlock.TargetMode.ALL_ENEMIES, 2)
	data.skill_2 = _nuke_skill("normal_enemy_2", EffectBlock.TargetMode.ALL_ENEMIES, 2)
	data.ultimate = _nuke_skill("normal_enemy_ult", EffectBlock.TargetMode.ALL_ENEMIES, 2)
	return data


func _events_of(sink: MemorySink, type_name: String) -> Array:
	var rows: Array = []
	for event: Dictionary in sink.events:
		if str(event.get("type", "")) == type_name:
			rows.append(event)
	return rows


func _first_decision(sink: MemorySink, decision_type: String) -> Dictionary:
	for event: Dictionary in _events_of(sink, "decision"):
		if str(event.get("decision_type", "")) == decision_type:
			return event
	return {}


func _turn_ended(sink: MemorySink, turn_number: int) -> Dictionary:
	for event: Dictionary in _events_of(sink, "turn_ended"):
		var number: int = event.get("turn_number", -1)
		if number == turn_number:
			return event
	return {}


## Builds a consented GameManager + scripted UI writing into `sink`.
func _prepare(sink: MemorySink, ui: ScriptedUI, run_id: String) -> GameManager:
	var consent_path: String = "%s/consent_%s.json" % [_temp_dir, run_id]
	var player_path: String = "%s/player_%s.txt" % [_temp_dir, run_id]
	TelemetryConsent.new(consent_path).decide(true)

	var manager: GameManager = GameManager.new()
	add_child(manager)
	auto_free(manager)
	manager.telemetry = TelemetryManager.new(consent_path, _temp_dir, player_path, sink)
	add_child(ui)
	auto_free(ui)
	manager.ui = ui
	return manager


func _waves() -> Array:
	var wave0: Array[UnitData] = [_enemy_data("wave0_enemy")]
	var wave1: Array[UnitData] = [_enemy_data("boss_enemy")]
	var waves: Array = [wave0, wave1]
	return waves


func _config() -> Dictionary:
	return {
		"hand_size": 7,
		"actions_per_turn": 3,
		"merges_per_turn": 2,
		"decklist": [[3, 8], [5, 7]],
		"dice_progression": [6, 8, 10, 12],
		"wave_transition_mode": "full_turn",
	}
#endregion


#region Run events
func test_a_full_battle_records_run_wave_turn_and_decision_events() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: ScriptedUI = ScriptedUI.new()
	var manager: GameManager = _prepare(sink, ui, "full")
	var allies: Array[UnitData] = [_ally_data()]

	await manager.setup_game(allies, _waves(), ui, _config())

	# Run envelope.
	var run_started: Array = _events_of(sink, "run_started")
	assert_int(run_started.size()).is_equal(1)
	var started_event: Dictionary = run_started[0]
	assert_int(str(started_event.get("balance_hash", "")).length()).is_equal(64)
	var lineup: Array = started_event.get("ally_lineup", [])
	assert_int(lineup.size()).is_equal(1)
	assert_str(str(lineup[0])).is_equal("striker")

	var run_ended: Array = _events_of(sink, "run_ended")
	assert_int(run_ended.size()).is_equal(1)
	var end_event: Dictionary = run_ended[0]
	var victory: bool = end_event.get("victory", false)
	var tainted: bool = end_event.get("was_debug_tainted", true)
	var total_decisions: int = end_event.get("total_decisions", 0)
	assert_bool(victory).is_true()
	assert_str(str(end_event.get("end_reason", ""))).is_equal(TelemetryManager.REASON_FINAL_WAVE)
	assert_bool(tainted).is_false()
	assert_int(total_decisions).is_greater(3)

	# Both waves and every turn were captured.
	assert_int(_events_of(sink, "wave_started").size()).is_equal(2)
	assert_int(_events_of(sink, "turn_started").size()).is_greater(1)
	assert_int(_events_of(sink, "turn_ended").size()).is_greater(1)

	# One decision of each kind the script performed.
	assert_bool(_first_decision(sink, TelemetryManager.DECISION_PLAY).is_empty()).is_false()
	assert_bool(_first_decision(sink, TelemetryManager.DECISION_MERGE).is_empty()).is_false()
	assert_bool(_first_decision(sink, TelemetryManager.DECISION_CONVERT).is_empty()).is_false()
	assert_bool(_first_decision(sink, TelemetryManager.DECISION_ULTIMATE).is_empty()).is_false()


func test_a_play_decision_carries_its_alternatives_and_outcome() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: ScriptedUI = ScriptedUI.new()
	var manager: GameManager = _prepare(sink, ui, "play")
	var allies: Array[UnitData] = [_ally_data()]

	await manager.setup_game(allies, _waves(), ui, _config())

	var play: Dictionary = _first_decision(sink, TelemetryManager.DECISION_PLAY)
	assert_bool(play.is_empty()).is_false()

	# Offered = the denominator of a pick-rate metric.
	var offered: Dictionary = play.get("offered", {})
	var cards_offered: Array = offered.get("cards_in_hand", [])
	assert_int(cards_offered.size()).is_greater(0)
	assert_bool(offered.has("legal_merge_pairs")).is_true()
	var pairs: Array = offered.get("legal_merge_pairs", [])
	assert_int(pairs.size()).is_greater(0)
	var pair: Dictionary = pairs[0]
	assert_bool(pair.has("kind")).is_true()
	# The living lineup, the exact plays that were legal, the card identities and
	# the enemy actually being faced: the denominators the reports divide by.
	var living: Array = offered.get("living_ally_ids", [])
	assert_int(living.size()).is_equal(1)
	assert_str(str(living[0])).is_equal("striker")
	assert_bool(offered.has("dead_ally_ids")).is_true()
	var card_keys: Array = offered.get("offered_card_keys", [])
	assert_int(card_keys.size()).is_equal(cards_offered.size())
	var playable_ids: Array = offered.get("playable_skill_ids", [])
	assert_bool(playable_ids.has("striker_1")).is_true()
	var playable: Array = offered.get("playable_skills", [])
	assert_int(playable.size()).is_greater(0)
	var option: Dictionary = playable[0]
	assert_str(str(option.get("ally_id", ""))).is_equal("striker")
	assert_bool(str(option.get("skill_id", "")).is_empty()).is_false()
	var facing: Array = offered.get("active_enemy_ids", [])
	assert_int(facing.size()).is_greater(0)
	assert_bool(offered.has("intent_max_roll")).is_true()

	# Chosen = the card, the ally and the skill it unlocked.
	var chosen: Dictionary = play.get("chosen", {})
	var applied: bool = chosen.get("applied", false)
	var skill_slot: int = chosen.get("skill_slot", 0)
	assert_bool(applied).is_true()
	assert_str(str(chosen.get("target_ally_id", ""))).is_equal("striker")
	assert_str(str(chosen.get("skill_id", ""))).is_equal("striker_1")
	assert_int(skill_slot).is_equal(1)
	var card: Dictionary = chosen.get("card", {})
	assert_str(str(card.get("parity", ""))).is_equal(TelemetrySchema.PARITY_ODD)

	# Pre-decision board state, the anti-selection-bias context.
	var context: Dictionary = play.get("context", {})
	var metrics: Dictionary = context.get("metrics", {})
	assert_bool(metrics.has("ally_hp_pct")).is_true()
	var hp_pct: float = metrics.get("ally_hp_pct", 0.0)
	assert_bool(absf(hp_pct - 1.0) < 0.01).is_true()
	var intents: Array = context.get("intents", [])
	assert_int(intents.size()).is_greater(0)

	# Outcome deltas collected from the EventBus.
	var outcome: Dictionary = play.get("outcome", {})
	var damage: int = outcome.get("damage_dealt", 0)
	assert_int(damage).is_greater(0)
	var damage_events: Array = outcome.get("damage_events", [])
	assert_int(damage_events.size()).is_greater(0)
	var first_damage: Dictionary = damage_events[0]
	assert_str(str(first_damage.get("source_id", ""))).is_equal("striker")


func test_a_merge_decision_names_the_result_card() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: ScriptedUI = ScriptedUI.new()
	var manager: GameManager = _prepare(sink, ui, "merge")
	var allies: Array[UnitData] = [_ally_data()]

	await manager.setup_game(allies, _waves(), ui, _config())

	var merge: Dictionary = _first_decision(sink, TelemetryManager.DECISION_MERGE)
	assert_bool(merge.is_empty()).is_false()
	var chosen: Dictionary = merge.get("chosen", {})
	var applied: bool = chosen.get("applied", false)
	assert_bool(applied).is_true()
	var result: Dictionary = chosen.get("result", {})
	assert_bool(result.is_empty()).is_false()
	var rank: int = result.get("merge_rank", 0)
	assert_int(rank).is_equal(1)
	var offered: Dictionary = merge.get("offered", {})
	var pairs: Array = offered.get("legal_merge_pairs", [])
	assert_int(pairs.size()).is_greater(0)
#endregion


#region Tester tools taint the run
func test_a_debug_command_taints_the_run() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: ScriptedUI = ScriptedUI.new()
	ui.send_debug_on_turn = 1
	var manager: GameManager = _prepare(sink, ui, "debug")
	var allies: Array[UnitData] = [_ally_data()]

	await manager.setup_game(allies, _waves(), ui, _config())

	var run_ended: Array = _events_of(sink, "run_ended")
	assert_int(run_ended.size()).is_equal(1)
	var end_event: Dictionary = run_ended[0]
	var tainted: bool = end_event.get("was_debug_tainted", false)
	assert_bool(tainted).is_true()
	assert_bool(_first_decision(sink, TelemetryManager.DECISION_DEBUG).is_empty()).is_false()
#endregion


#region Turn strategy and enemy attribution
## Every turn records what the player did (skills / Ultimates / merges / converts)
## and the damage the enemy dealt back, attributed to the enemy *and* its skill.
func test_turn_ended_records_strategy_and_enemy_damage() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: ScriptedUI = ScriptedUI.new()
	var manager: GameManager = _prepare(sink, ui, "turns")
	var allies: Array[UnitData] = [_ally_data()]

	await manager.setup_game(allies, _waves(), ui, _config())

	# Every turn that started is closed, including the lethal final one that never
	# reaches Step 8 of the loop.
	assert_int(_events_of(sink, "turn_ended").size()).is_equal(_events_of(sink, "turn_started").size())

	# Turn 1 was a merge turn.
	var merge_turn: Dictionary = _turn_ended(sink, 1)
	assert_bool(merge_turn.is_empty()).is_false()
	var merge_outcome: Dictionary = merge_turn.get("outcome", {})
	var merges_made: int = merge_outcome.get("merges_made", 0)
	assert_int(merges_made).is_equal(1)

	# The enemy attack in Step 7 is attributed to the enemy and its skill, and to
	# the ally it hit - the row the situational matchup table is built from.
	var enemy_rows: Array = merge_outcome.get("enemy_damage_events", [])
	assert_int(enemy_rows.size()).is_greater(0)
	var row: Dictionary = enemy_rows[0]
	assert_str(str(row.get("enemy_unit_id", ""))).is_equal("boss_enemy")
	assert_bool(str(row.get("enemy_skill_id", "")).is_empty()).is_false()
	assert_str(str(row.get("target_id", ""))).is_equal("striker")
	var target_is_ally: bool = row.get("target_is_ally", false)
	var hp_lost: int = row.get("hp_lost", 0)
	assert_bool(target_is_ally).is_true()
	assert_int(hp_lost).is_greater(0)

	# Turn 2 was a convert turn.
	var convert_outcome: Dictionary = _turn_ended(sink, 2).get("outcome", {})
	var converts_made: int = convert_outcome.get("converts_made", 0)
	assert_int(converts_made).is_equal(1)

	# Turn 3 was the Ultimate turn and it ended the battle.
	var ult_turn: Dictionary = _turn_ended(sink, 3)
	assert_bool(ult_turn.is_empty()).is_false()
	var ult_outcome: Dictionary = ult_turn.get("outcome", {})
	var ults: Array = ult_outcome.get("player_ultimates_cast", [])
	assert_bool(ults.has("striker_ult")).is_true()
#endregion


#region Abandoned runs
func test_an_abandoned_run_is_flagged_and_closed_once() -> void:
	var sink: MemorySink = MemorySink.new()
	var consent_path: String = "%s/consent_abandon.json" % _temp_dir
	var player_path: String = "%s/player_abandon.txt" % _temp_dir
	TelemetryConsent.new(consent_path).decide(true)
	var recorder: TelemetryManager = TelemetryManager.new(consent_path, _temp_dir, player_path, sink)
	var state: GameState = GameState.new()

	recorder.start_run(state)
	assert_bool(recorder.enabled).is_true()
	assert_bool(FileAccess.file_exists(player_path)).is_true()

	recorder.abandon_run(state)
	var ended: Array = _events_of(sink, "run_ended")
	assert_int(ended.size()).is_equal(1)
	var end_event: Dictionary = ended[0]
	var abandoned: bool = end_event.get("abandoned", false)
	var victory: bool = end_event.get("victory", true)
	assert_bool(abandoned).is_true()
	assert_bool(victory).is_false()
	assert_str(str(end_event.get("end_reason", ""))).is_equal(TelemetryManager.REASON_ABANDONED)

	# Idempotent: closing again must not write a second run_ended.
	recorder.abandon_run(state)
	assert_int(_events_of(sink, "run_ended").size()).is_equal(1)


## Leaving the tree while the battle is still running (a restart or a quit) closes
## the run instead of losing it.
func test_leaving_the_tree_mid_battle_abandons_the_run() -> void:
	var sink: MemorySink = MemorySink.new()
	var ui: ScriptedUI = ScriptedUI.new()
	var manager: GameManager = _prepare(sink, ui, "quit")
	manager.state = GameState.new()
	manager.game_running = true
	manager.telemetry.start_run(manager.state)
	assert_bool(manager.telemetry.enabled).is_true()

	remove_child(manager)

	var ended: Array = _events_of(sink, "run_ended")
	assert_int(ended.size()).is_equal(1)
	var end_event: Dictionary = ended[0]
	var abandoned: bool = end_event.get("abandoned", false)
	assert_bool(abandoned).is_true()
	assert_bool(manager.telemetry.enabled).is_false()
#endregion



#region Stage 2 upload plumbing
## The Stage 2 sink must spool into the upload outbox (never the local-only spool),
## so TelemetryUploader can find it.
func test_http_batch_sink_spools_into_the_outbox() -> void:
	var sink: HttpBatchSink = HttpBatchSink.new("test-run-%s" % TelemetrySchema.new_id())
	assert_bool(sink.file_path.begins_with(HttpBatchSink.OUTBOX_DIR)).is_true()
	sink.write_event({"type": "run_started", "schema_version": 1})
	assert_int(sink.event_count).is_equal(1)
	var events: Array = sink.read_all()
	assert_int(events.size()).is_equal(1)
	sink.close()
	if FileAccess.file_exists(sink.file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sink.file_path))
	# Removes the directories only when they are empty, so a real outbox is safe.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HttpBatchSink.OUTBOX_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://telemetry"))


## With no endpoint configured the uploader must be completely inert: a local-only
## build never opens a socket.
func test_uploader_is_inert_without_an_endpoint() -> void:
	var uploader: TelemetryUploader = TelemetryUploader.new()
	uploader.name = "TestTelemetryUploader"
	add_child(uploader)
	auto_free(uploader)
	assert_bool(uploader.endpoint().is_empty()).is_true()
	assert_bool(uploader.is_enabled()).is_false()
#endregion

