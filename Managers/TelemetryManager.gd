class_name TelemetryManager
extends RefCounted
## Records every decision a player makes, for game design and balancing.
##
## It is a passive observer: GameManager (or a test) calls the `begin_*` /
## `record_*` hooks at the points where the player commits, and this class turns
## the pre-decision board, the offered alternatives, the chosen action and the
## outcome into one JSON object per event. Combat outcome deltas are collected
## from the EventBus, so the call sites stay tiny.
##
## Collection is gated three ways and default OFF:
##   1. the player must have explicitly agreed (TelemetryConsent),
##   2. a headless run never collects (CI, the validator, gdUnit4),
##   3. `enabled_override` is the test seam used by GDTest/TelemetryTest.gd.
##
## @author TheGreatJellyfish
## @version 11/26/2026

#region Constants
const SCHEMA_VERSION: int = 1

const DEFAULT_SPOOL_DIR: String = "user://telemetry/spool"
const PLAYER_ID_PATH: String = "user://telemetry/player_id.txt"
## Counts the battles this player has started, kept beside the player id, so the
## reports can slice "still learning" runs from veteran runs without any identity.
const RUN_COUNT_FILE: String = "run_count.txt"

## Decision types. Deliberately readable strings, never numeric ordinals.
const DECISION_PLAY: String = "play_card"
const DECISION_MERGE: String = "merge_cards"
const DECISION_CONVERT: String = "convert_action"
const DECISION_ULTIMATE: String = "cast_ultimate"
const DECISION_END_TURN: String = "end_turn"
const DECISION_DEBUG: String = "debug_command"
const DECISION_DRAFT: String = "draft_pick"
const DECISION_UNKNOWN: String = "unknown"

## Where a decision ended a battle (mirrors GameManager's call sites).
const REASON_FINAL_WAVE: String = "final_wave_cleared"
const REASON_ALL_ALLIES_DEAD: String = "all_allies_dead"
const REASON_STATUS_TICK: String = "status_tick_defeat"
const REASON_DEBUG_PREVIEW: String = "debug_preview"
## The battle never finished: the player restarted or quit mid-run.
const REASON_ABANDONED: String = "abandoned"
const REASON_UNKNOWN: String = "unknown"
#endregion

#region Public Variables
## When supplied (tests only), the recorder writes into this sink and ignores the
## headless rule instead of opening a spool file. Deliberately per-instance: a
## global override could leak out of a test suite into a real run.
var sink_override: TelemetrySink = null
var consent: TelemetryConsent
var sink: TelemetrySink = null
var enabled: bool = false
var run_id: String = ""
var player_anon_id: String = ""
var balance_hash: String = ""
var game_version: String = ""
var was_debug_tainted: bool = false
var total_turns: int = 0
var total_decisions: int = 0
## How many battles this player has started, including this one.
var player_run_number: int = 0
var start_ms: int = 0
#endregion

#region Private Variables
var _spool_dir: String = DEFAULT_SPOOL_DIR
var _player_id_path: String = PLAYER_ID_PATH
## Where the consent answer is read from (and re-read at `start_run`, because the
## disclosure can be answered after this recorder was constructed).
var _consent_path: String = TelemetryConsent.DEFAULT_PATH
var _state: GameState = null
var _owns_sink: bool = false
var _connected: bool = false

var _intents: Array[EnemyIntent] = []
var _turn_outcome: Dictionary = {}
var _decision_outcome: Dictionary = {}
var _decision_ctx: Dictionary = {}
var _decision_offered: Dictionary = {}
var _decision_sub: Array = []
var _decision_start_ms: int = 0
var _action_received_ms: int = 0
var _decision_counter: int = 0
var _merge_result: Dictionary = {}
## The enemy currently resolving its skill, so the damage it deals can be
## attributed to the enemy *and* the skill that caused it. Empty when no enemy is
## acting (every player-phase damage row is player-caused).
var _active_enemy: Dictionary = {}
## The status currently ticking (a damage-over-time round tick), so a death it
## causes is attributed to that status instead of an unknown source.
var _active_status: String = ""
## Every ally death this run with its cause. The last one is what ended a defeat.
var _ally_deaths: Array = []
## Last turn number already closed, so `record_turn_ended` may be called on every
## exit path of the loop while still writing exactly one turn_ended per turn.
var _last_closed_turn: int = -1
#endregion

#region Lifecycle Methods
func _init(
	consent_path: String = TelemetryConsent.DEFAULT_PATH,
	spool_dir: String = DEFAULT_SPOOL_DIR,
	player_id_path: String = PLAYER_ID_PATH,
	p_sink_override: TelemetrySink = null
) -> void:
	_consent_path = consent_path
	consent = TelemetryConsent.load_from(consent_path)
	_spool_dir = spool_dir
	_player_id_path = player_id_path
	sink_override = p_sink_override
	_turn_outcome = _new_outcome()
	_decision_outcome = _new_outcome()
#endregion

#region Public Methods
## True when this recorder may collect at all: a real (non-headless) session, or
## a test that supplied its own sink. Consent is checked on top in `start_run`.
func may_collect() -> bool:
	if sink_override != null:
		return true
	return DisplayServer.get_name() != "headless"


## Opens a run: creates the spool file, a player id and the `run_started` event.
## A no-op (leaving every buffer empty) when collection is not allowed.
func start_run(state: GameState, version: String = "") -> void:
	shutdown()
	_state = state
	was_debug_tainted = false
	total_turns = 0
	total_decisions = 0
	_decision_counter = 0
	_intents = []
	_active_enemy = {}
	_active_status = ""
	_ally_deaths = []
	_last_closed_turn = -1
	_turn_outcome = _new_outcome()
	_decision_outcome = _new_outcome()
	# Re-read the answer from disk: the disclosure is shown once per launch, so the
	# answer given a moment ago must win over the one loaded when this recorder was
	# constructed (which may be from a previous session).
	consent.load_from_path(_consent_path)
	# And require that answer to come from *this* launch: a stored "granted" left
	# over from an earlier session must never start collection on its own.
	enabled = may_collect() and consent.is_granted() and TelemetryConsent.answered_this_launch()
	if not enabled:
		return
	run_id = TelemetrySchema.new_id()
	player_anon_id = _load_or_create_player_id()
	player_run_number = _load_and_bump_run_number()
	game_version = version if not version.is_empty() else _project_version()
	balance_hash = _current_balance_hash()
	start_ms = Time.get_ticks_msec()
	if sink_override != null:
		sink = sink_override
		_owns_sink = false
		if not sink.is_open():
			sink.open(run_id)
	else:
		# With a metric server configured, spool into the upload outbox so
		# TelemetryUploader can drain it; otherwise stay fully local.
		if _upload_endpoint().is_empty():
			var file_sink: JsonlFileSink = JsonlFileSink.new(_spool_dir, run_id)
			sink = file_sink
		else:
			var batch_sink: HttpBatchSink = HttpBatchSink.new(run_id)
			sink = batch_sink
		_owns_sink = true
	_connect_bus()
	_emit("run_started", {
		"game_version": game_version,
		"balance_hash": balance_hash,
		"is_debug_build": OS.is_debug_build(),
		"run_seed": state.run_seed,
		"player_run_number": player_run_number,
		"config": {
			"hand_size": state.max_hand_size,
			"actions_per_turn": state.actions_per_turn,
			"merges_per_turn": state.merges_per_turn,
			"dice_progression": state.turn_dice_progression,
			"wave_transition_mode": state.wave_transition_mode,
		},
		"decklist": state.CURRENT_DECKLIST,
		"ally_lineup": _ally_lineup(state),
		"wave_count": state.wave_definitions.size(),
	})


## Closes a run with its result. Safe to call twice. `abandoned` marks a run the
## player never finished (restart / quit), so it is reported separately instead of
## being counted as a loss.
func end_run(victory: bool, reason: String, state: GameState, abandoned: bool = false) -> void:
	if not enabled:
		return
	var survivors: Array = []
	for unit: Unit in state.allies:
		if not unit.is_dead:
			survivors.append(TelemetrySchema.unit_snapshot(unit))
	_emit("run_ended", {
		"victory": victory,
		"abandoned": abandoned,
		"end_reason": reason if not reason.is_empty() else REASON_UNKNOWN,
		"final_wave": state.current_wave,
		"total_turns": maxi(total_turns, state.turn_number + 1),
		"total_decisions": total_decisions,
		"survivors": survivors,
		"was_debug_tainted": was_debug_tainted,
		"run_seed": state.run_seed,
		"killed_by": _killed_by(victory),
		"ally_deaths": _ally_deaths,
		"duration_ms": maxi(0, Time.get_ticks_msec() - start_ms),
	})
	shutdown()


## What ended a defeat: the cause of the last ally death. Empty on a victory,
## because then nothing killed the run.
func _killed_by(victory: bool) -> Dictionary:
	if victory or _ally_deaths.is_empty():
		return {}
	var last: Dictionary = _ally_deaths[_ally_deaths.size() - 1]
	return last


## Closes an unfinished run when the battle scene goes away (a restart or a quit).
## Idempotent: a buttoned-up run has already stopped recording, so this is a no-op.
func abandon_run(state: GameState) -> void:
	if not enabled or state == null:
		return
	# Close the partial turn first, so the turns written match the run's turn count
	# even though the battle never reached the end of the round.
	record_turn_ended(state)
	end_run(false, REASON_ABANDONED, state, true)


## Disconnects the bus and closes an owned sink. Always safe to call.
func shutdown() -> void:
	_disconnect_bus()
	if sink != null:
		sink.flush()
		if _owns_sink:
			sink.close()
	sink = null
	_owns_sink = false
	enabled = false
	_state = null


## Flags the whole run as tester-tainted so balance views can ignore it.
func mark_debug_tainted() -> void:
	was_debug_tainted = true


## True while a live run is being recorded.
func is_recording() -> bool:
	return enabled and sink != null and sink.is_open()
#endregion

#region Decision Recording
## Records a wave spawn (subscribed to EventBus.wave_started).
func record_wave_started(wave_index: int) -> void:
	if not enabled or _state == null:
		return
	_emit("wave_started", {
		"wave_index": wave_index,
		"turn_number": _state.turn_number,
		"enemies": TelemetrySchema.units_snapshot(_state.enemies),
		"allies": TelemetrySchema.units_snapshot(_state.allies),
	})


## Records the start-of-turn state: intents rolled, hand dealt, board snapshot.
func record_turn_started(state: GameState, intents: Array[EnemyIntent], dice_sides: int) -> void:
	if not enabled:
		return
	# A fresh dictionary per turn: emitted events keep the outcome they recorded
	# instead of aliasing a buffer that the next turn would overwrite.
	_turn_outcome = _new_outcome()
	_decision_counter = 0
	total_turns = maxi(total_turns, state.turn_number + 1)
	_intents = intents
	_emit("turn_started", {
		"turn_number": state.turn_number,
		"wave_index": state.current_wave,
		"dice_sides": dice_sides,
		"deck_count": state.deck.size(),
		"discard_count": state.discard.size(),
		"hand": TelemetrySchema.cards_snapshot(state.hand),
		"intents": TelemetrySchema.intents_snapshot(intents),
		"active_enemy_ids": _living_enemy_ids(state),
		"board": TelemetrySchema.board_snapshot(state),
		"metrics": TelemetrySchema.battlefield_metrics(state, intents),
	})


## Records the end of a turn, including everything that happened in it.
##
## Idempotent per turn: GameManager closes the turn on every way out of the loop
## (including a lethal final turn that never reaches Step 8), and only one
## turn_ended may be written per turn number.
func record_turn_ended(state: GameState) -> void:
	if not enabled:
		return
	if state.turn_number == _last_closed_turn:
		return
	_last_closed_turn = state.turn_number
	_emit("turn_ended", {
		"turn_number": state.turn_number,
		"wave_index": state.current_wave,
		"unused_actions": maxi(0, state.actions_left),
		"unused_merges": maxi(0, state.merges_left),
		"hand": TelemetrySchema.cards_snapshot(state.hand),
		"board": TelemetrySchema.board_snapshot(state),
		"outcome": _turn_outcome,
	})


## Opens a decision window: snapshots everything the player can see *before* they
## choose, and starts the thinking clock. Every `record_*` outcome lands in this
## decision until `end_decision`.
func begin_decision(state: GameState, intents: Array[EnemyIntent]) -> void:
	if not enabled:
		return
	_intents = intents
	_decision_outcome = _new_outcome()
	_merge_result = {}
	_decision_sub = []
	_active_enemy = {} # the player phase never has an enemy mid-skill
	_decision_start_ms = Time.get_ticks_msec()
	_action_received_ms = _decision_start_ms
	_decision_ctx = {
		"turn_number": state.turn_number,
		"wave_index": state.current_wave,
		"actions_left": state.actions_left,
		"merges_left": state.merges_left,
		"next_skill_bonus": state.next_skill_bonus,
		"deck_count": state.deck.size(),
		"discard_count": state.discard.size(),
		"hand": TelemetrySchema.cards_snapshot(state.hand),
		"board": TelemetrySchema.board_snapshot(state),
		"intents": TelemetrySchema.intents_snapshot(intents),
		"metrics": TelemetrySchema.battlefield_metrics(state, intents),
	}
	_decision_offered = _build_offered(state)


## Marks the moment the player's answer arrived (thinking time ends here, before
## any animation plays).
func note_action_received() -> void:
	if not enabled:
		return
	_action_received_ms = Time.get_ticks_msec()


## Remembers a merge result so the decision can name the card it produced.
func note_merge_result(result: Card) -> void:
	if not enabled or result == null:
		return
	_merge_result = TelemetrySchema.card_snapshot(result)


## Closes the decision window and writes the event.
func end_decision(action: Dictionary, state: GameState) -> void:
	if not enabled:
		return
	var action_type: String = str(action.get("type", ""))
	var mapped: String = _decision_type(action_type)
	# "stats" / "hand" are information lookups, not decisions: they must not count
	# as a choice or dilute a pick-rate denominator.
	if mapped == DECISION_UNKNOWN:
		return
	var chosen: Dictionary = _chosen(action_type, action, state)
	_emit("decision", {
		"decision_type": mapped,
		"decision_index": _decision_counter,
		"turn_number": _int(_decision_ctx.get("turn_number", 0)),
		"wave_index": _int(_decision_ctx.get("wave_index", 0)),
		"thinking_time_ms": maxi(0, _action_received_ms - _decision_start_ms),
		"context": _decision_ctx,
		"offered": _decision_offered,
		"chosen": chosen,
		"sub_prompts": _decision_sub,
		"outcome": _decision_outcome,
	})
	_note_turn_action(mapped, chosen)
	_decision_counter += 1
	total_decisions += 1
	_decision_sub = []
	_merge_result = {}
	_decision_outcome = _new_outcome()


## Mirrors what the player did into the turn buffer, so `turn_ended` can describe
## the turn's strategy (which skills / Ultimates were used, merges, converts)
## without a consumer having to replay every decision event.
func _note_turn_action(decision_type: String, chosen: Dictionary) -> void:
	var applied: bool = chosen.get("applied", false)
	if not applied:
		return
	match decision_type:
		DECISION_PLAY:
			var skill_id: String = str(chosen.get("skill_id", ""))
			if not skill_id.is_empty():
				var skills: Array = _turn_outcome["player_skills_used"]
				skills.append(skill_id)
		DECISION_ULTIMATE:
			var ult_id: String = str(chosen.get("ultimate_skill_id", ""))
			if not ult_id.is_empty():
				var ults: Array = _turn_outcome["player_ultimates_cast"]
				ults.append(ult_id)
		DECISION_MERGE:
			_turn_outcome["merges_made"] = _int(_turn_outcome.get("merges_made", 0)) + 1
		DECISION_CONVERT:
			_turn_outcome["converts_made"] = _int(_turn_outcome.get("converts_made", 0)) + 1
		_:
			pass


## Records a target prompt inside a skill: every candidate and what was picked.
func note_pick_target(candidates: Array[Unit], count: int, picked: Array[Unit], thinking_ms: int) -> void:
	if not enabled:
		return
	_decision_sub.append({
		"prompt": "pick_target",
		"count": count,
		"candidates": TelemetrySchema.unit_refs(candidates),
		"picked": TelemetrySchema.unit_refs(picked),
		"skipped": picked.size() < count,
		"thinking_time_ms": maxi(0, thinking_ms),
	})


## Records a card prompt inside a skill: every candidate and what was picked.
func note_pick_card(candidates: Array[Card], count: int, picked: Array[Card], thinking_ms: int) -> void:
	if not enabled:
		return
	_decision_sub.append({
		"prompt": "pick_card",
		"count": count,
		"candidates": TelemetrySchema.cards_snapshot(candidates),
		"picked": TelemetrySchema.cards_snapshot(picked),
		"skipped": picked.size() < count,
		"thinking_time_ms": maxi(0, thinking_ms),
	})


## Opens the window in which one enemy resolves its skill, so the damage it deals
## can be attributed to that enemy and that skill (see `_on_damage_dealt`).
func begin_enemy_action(enemy: Unit, skill: SkillData, intent: EnemyIntent) -> void:
	if not enabled:
		return
	_active_enemy = {
		"unit_id": TelemetrySchema.unit_id_of(enemy),
		"slot": enemy.slot_index if enemy != null else -1,
		"skill_id": TelemetrySchema.skill_id_of(skill),
		"raw_roll": intent.raw_dice_value if intent != null else 0,
		"effective_value": intent.effective_value if intent != null else 0,
		"condition_met": intent.condition_met if intent != null else false,
	}


func end_enemy_action() -> void:
	_active_enemy = {}


## Opens the window in which one status ticks, so a death it causes is attributed
## to that status instead of being recorded as an unknown source.
func begin_status_tick(status_id: String) -> void:
	if not enabled:
		return
	_active_status = status_id


func end_status_tick() -> void:
	_active_status = ""


## Records an explicit reward / draft choice (card reward, ally recruit, skill
## upgrade). Documents the offer so pick rate works for future progression, even
## though the current build uses a fixed deck.
func record_draft_decision(
	category: String,
	offered_ids: Array[String],
	picked_id: String,
	state: GameState
) -> void:
	if not enabled:
		return
	_decision_ctx = {
		"turn_number": state.turn_number,
		"wave_index": state.current_wave,
		"hand": TelemetrySchema.cards_snapshot(state.hand),
		"board": TelemetrySchema.board_snapshot(state),
		"metrics": TelemetrySchema.battlefield_metrics(state, _intents),
	}
	_decision_offered = {"category": category, "offered_ids": offered_ids}
	_merge_result = {}
	_decision_sub = []
	_active_enemy = {}
	_emit("decision", {
		"decision_type": DECISION_DRAFT,
		"decision_index": _decision_counter,
		"turn_number": state.turn_number,
		"wave_index": state.current_wave,
		"thinking_time_ms": 0,
		"context": _decision_ctx,
		"offered": _decision_offered,
		"chosen": {"applied": not picked_id.is_empty(), "picked_id": picked_id, "category": category},
		"sub_prompts": [],
		"outcome": _new_outcome(),
	})
	_decision_counter += 1
	total_decisions += 1
#endregion

#region Private Methods
## Serialises one event with its envelope and hands it to the sink.
func _emit(event_type: String, payload: Dictionary) -> void:
	if not enabled or sink == null:
		return
	var event: Dictionary = {
		"type": event_type,
		"schema_version": SCHEMA_VERSION,
		"event_id": TelemetrySchema.new_id(),
		"run_id": run_id,
		"player_anon_id": player_anon_id,
		"balance_hash": balance_hash,
		"t": TelemetrySchema.now_unix(),
	}
	for key: Variant in payload:
		event[key] = payload[key]
	sink.write_event(event)


func _new_outcome() -> Dictionary:
	return {
		"damage_dealt": 0,
		"hp_lost": 0,
		"shield_gained": 0,
		"shield_reduced": 0,
		"healed": 0,
		# Directional splits of the same events, so a report never has to guess
		# which side a total belongs to (the keys above stay as combined totals).
		"ally_hp_lost": 0,
		"enemy_hp_lost": 0,
		"ally_shield_gained": 0,
		"enemy_shield_gained": 0,
		"ally_shield_lost": 0,
		"enemy_shield_lost": 0,
		"cards_drawn": 0,
		"cards_discarded": 0,
		"kills": [],
		"card_value_changes": [],
		"damage_events": [],
		# Enemy -> ally damage rows, tagged with the enemy and the skill that caused
		# them. Only the turn buffer ever fills this (enemies act in Step 7).
		"enemy_damage_events": [],
		# What the player actually did this turn, so turn_ended can answer "what
		# strategy was used" without replaying every decision.
		"player_skills_used": [],
		"player_ultimates_cast": [],
		"merges_made": 0,
		"converts_made": 0,
	}


func _accumulate(key: String, amount: int) -> void:
	_turn_outcome[key] = _int(_turn_outcome.get(key, 0)) + amount
	_decision_outcome[key] = _int(_decision_outcome.get(key, 0)) + amount


func _append_damage_event(entry: Dictionary) -> void:
	var turn_rows: Array = _turn_outcome["damage_events"]
	if turn_rows.size() < TelemetrySchema.MAX_ROWS:
		turn_rows.append(entry)
	var decision_rows: Array = _decision_outcome["damage_events"]
	if decision_rows.size() < TelemetrySchema.MAX_ROWS:
		decision_rows.append(entry.duplicate())


## Everything the player could have done at this instant: the full hand, every
## legal (ally, card) play, every legal merge pair, the ready Ultimates, the living
## enemies and how threatening their intents are. This is what makes a "pick rate"
## metric meaningful - the denominator, not just the choice.
func _build_offered(state: GameState) -> Dictionary:
	var living_ally_ids: Array = []
	var dead_ally_ids: Array = []
	var ready_ultimates: Array = []
	var ready_ultimate_skills: Array = []
	for unit: Unit in state.allies:
		if unit.is_dead:
			dead_ally_ids.append(TelemetrySchema.unit_id_of(unit))
			continue
		living_ally_ids.append(TelemetrySchema.unit_id_of(unit))
		if unit.can_cast_ultimate:
			ready_ultimates.append(TelemetrySchema.unit_ref(unit))
			var ult: SkillData = unit.data.ultimate if unit.data != null else null
			var ult_id: String = TelemetrySchema.skill_id_of(ult)
			if not ult_id.is_empty() and not ready_ultimate_skills.has(ult_id):
				ready_ultimate_skills.append(ult_id)

	var card_keys: Array = []
	for card: Card in state.hand:
		if card_keys.size() >= TelemetrySchema.MAX_ROWS:
			break
		card_keys.append(TelemetrySchema.card_key(card))

	var options: Array = _playable_skill_options(state)
	var playable_skill_ids: Array = []
	for option: Dictionary in options:
		var skill_id: String = str(option.get("skill_id", ""))
		if not skill_id.is_empty() and not playable_skill_ids.has(skill_id):
			playable_skill_ids.append(skill_id)

	var active_enemy_ids: Array = []
	var intent_max_roll: int = 0
	var intent_condition_met: bool = false
	var intent_ult_imminent: bool = false
	for intent: EnemyIntent in _intents:
		if intent.enemy == null or intent.enemy.is_dead:
			continue
		active_enemy_ids.append(TelemetrySchema.unit_id_of(intent.enemy))
		intent_max_roll = maxi(intent_max_roll, intent.effective_value)
		if intent.condition_met:
			intent_condition_met = true
		if intent.will_trigger_ultimate():
			intent_ult_imminent = true

	return {
		"actions_left": state.actions_left,
		"merges_left": state.merges_left,
		"hand_size": state.hand.size(),
		"cards_in_hand": TelemetrySchema.cards_snapshot(state.hand),
		"offered_card_keys": card_keys,
		"living_ally_ids": living_ally_ids,
		"dead_ally_ids": dead_ally_ids,
		"playable_skill_ids": playable_skill_ids,
		"playable_skills": options,
		"legal_merge_pairs": _legal_merge_pairs(state),
		"ready_ultimates": ready_ultimates,
		"ready_ultimate_skills": ready_ultimate_skills,
		"active_enemy_ids": active_enemy_ids,
		"intent_max_roll": intent_max_roll,
		"intent_condition_met": intent_condition_met,
		"intent_ultimate_imminent": intent_ult_imminent,
	}


## Every (ally, card) play the player could legally make right now. This is the
## true denominator behind a skill pick rate: "striker_1 was playable on N
## decisions and was the choice on M of them".
func _playable_skill_options(state: GameState) -> Array:
	var options: Array = []
	for unit: Unit in state.allies:
		if unit.is_dead or unit.data == null:
			continue
		for card: Card in state.hand:
			if card.costs_action() and state.actions_left <= 0:
				continue
			var skill: SkillData = unit.data.skill_1 if card.is_odd() else unit.data.skill_2
			var skill_id: String = TelemetrySchema.skill_id_of(skill)
			if skill_id.is_empty():
				continue
			if options.size() >= TelemetrySchema.MAX_ROWS:
				return options
			options.append({
				"ally_id": TelemetrySchema.unit_id_of(unit),
				"slot": unit.slot_index,
				"skill_id": skill_id,
				"skill_slot": 1 if card.is_odd() else 2,
				"card_key": TelemetrySchema.card_key(card),
				"card_effective_value": card.get_effective_value(),
				"costs_action": card.costs_action(),
				"is_merged": card.is_merged,
				"is_double_merged": card.is_double_merged,
			})
	return options


func _legal_merge_pairs(state: GameState) -> Array:
	var pairs: Array = []
	var hand: Array[Card] = state.hand
	for i: int in hand.size():
		for j: int in range(i + 1, hand.size()):
			if pairs.size() >= TelemetrySchema.MAX_ROWS:
				return pairs
			var a: Card = hand[i]
			var b: Card = hand[j]
			if not state.can_merge_pair(a, b):
				continue
			var is_double: bool = a.is_merged or b.is_merged
			var result_value: int = a.get_effective_value() + b.get_effective_value()
			if is_double:
				result_value += 1
			pairs.append({
				"a": a.id, "b": b.id,
				"kind": "double" if is_double else "cross",
				"a_value": a.get_effective_value(), "b_value": b.get_effective_value(),
				"result_value": result_value,
			})
	return pairs


func _decision_type(action_type: String) -> String:
	match action_type:
		"play":
			return DECISION_PLAY
		"merge":
			return DECISION_MERGE
		"convert":
			return DECISION_CONVERT
		"ultimate":
			return DECISION_ULTIMATE
		"end_turn":
			return DECISION_END_TURN
		"debug":
			return DECISION_DEBUG
		_:
			return DECISION_UNKNOWN


func _chosen(action_type: String, action: Dictionary, state: GameState) -> Dictionary:
	match action_type:
		"play":
			return _chosen_play(action, state)
		"merge":
			return _chosen_merge(action)
		"ultimate":
			return _chosen_ultimate(action)
		"convert":
			return {"applied": _int(_decision_ctx.get("actions_left", 0)) > state.actions_left}
		"end_turn":
			return {
				"applied": true,
				"unused_actions": maxi(0, state.actions_left),
				"unused_merges": maxi(0, state.merges_left),
				"cards_left": state.hand.size(),
			}
		"debug":
			return {"applied": true, "command": str(action.get("command", ""))}
		_:
			return {"applied": false}


func _chosen_play(action: Dictionary, state: GameState) -> Dictionary:
	var card: Card = action.get("card", null)
	var ally: Unit = action.get("target_ally", null)
	var applied: bool = card != null and not state.hand.has(card)
	var payload: Dictionary = {
		"applied": applied,
		"card": TelemetrySchema.card_snapshot(card),
		"target_ally_id": TelemetrySchema.unit_id_of(ally),
		"target_slot": ally.slot_index if ally != null else -1,
	}
	if applied and ally != null and ally.data != null:
		var skill: SkillData = ally.data.skill_1 if card.is_odd() else ally.data.skill_2
		payload["skill_id"] = TelemetrySchema.skill_id_of(skill)
		payload["skill_slot"] = 1 if card.is_odd() else 2
	return payload


func _chosen_merge(action: Dictionary) -> Dictionary:
	var card_a: Card = action.get("card_a", null)
	var card_b: Card = action.get("card_b", null)
	return {
		"applied": not _merge_result.is_empty(),
		"card_a": TelemetrySchema.card_snapshot(card_a),
		"card_b": TelemetrySchema.card_snapshot(card_b),
		"result": _merge_result,
	}


func _chosen_ultimate(action: Dictionary) -> Dictionary:
	var caster: Unit = action.get("caster", null)
	var payload: Dictionary = {
		"applied": caster != null and caster.ult_used_this_turn,
		"caster_id": TelemetrySchema.unit_id_of(caster),
		"slot": caster.slot_index if caster != null else -1,
	}
	if caster != null and caster.data != null:
		payload["ultimate_skill_id"] = TelemetrySchema.skill_id_of(caster.data.ultimate)
	return payload


## Subscribes to the combat signals so outcome deltas need no call sites.
func _connect_bus() -> void:
	if _connected:
		return
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.shield_gained.connect(_on_shield_gained)
	EventBus.shield_reduced.connect(_on_shield_reduced)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.card_drawn.connect(_on_card_drawn)
	EventBus.card_discarded.connect(_on_card_discarded)
	EventBus.card_value_changed.connect(_on_card_value_changed)
	EventBus.wave_started.connect(_on_wave_started)
	_connected = true


func _disconnect_bus() -> void:
	if not _connected:
		return
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.shield_gained.is_connected(_on_shield_gained):
		EventBus.shield_gained.disconnect(_on_shield_gained)
	if EventBus.shield_reduced.is_connected(_on_shield_reduced):
		EventBus.shield_reduced.disconnect(_on_shield_reduced)
	if EventBus.unit_healed.is_connected(_on_unit_healed):
		EventBus.unit_healed.disconnect(_on_unit_healed)
	if EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.disconnect(_on_unit_died)
	if EventBus.card_drawn.is_connected(_on_card_drawn):
		EventBus.card_drawn.disconnect(_on_card_drawn)
	if EventBus.card_discarded.is_connected(_on_card_discarded):
		EventBus.card_discarded.disconnect(_on_card_discarded)
	if EventBus.card_value_changed.is_connected(_on_card_value_changed):
		EventBus.card_value_changed.disconnect(_on_card_value_changed)
	if EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.disconnect(_on_wave_started)
	_connected = false


func _ally_lineup(state: GameState) -> Array:
	var lineup: Array = []
	for unit: Unit in state.allies:
		lineup.append(TelemetrySchema.unit_id_of(unit))
	return lineup


## Ids of the enemies still alive, in board order (used to slice strategy by who
## the player was actually facing).
func _living_enemy_ids(state: GameState) -> Array:
	var ids: Array = []
	for unit: Unit in state.enemies:
		if not unit.is_dead:
			ids.append(TelemetrySchema.unit_id_of(unit))
	return ids


## The anonymous, stable player id. Generated once, only after consent is given.
func _load_or_create_player_id() -> String:
	if FileAccess.file_exists(_player_id_path):
		var reader: FileAccess = FileAccess.open(_player_id_path, FileAccess.READ)
		if reader != null:
			var stored: String = reader.get_as_text().strip_edges()
			reader.close()
			if not stored.is_empty():
				return stored
	var fresh: String = TelemetrySchema.new_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_player_id_path.get_base_dir()))
	var writer: FileAccess = FileAccess.open(_player_id_path, FileAccess.WRITE)
	if writer != null:
		writer.store_string(fresh)
		writer.close()
	return fresh


func _project_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## How many battles this player has started, including this one. Kept beside the
## player id, so the reports can slice "still learning" runs from veteran runs
## without collecting anything that identifies the player.
func _load_and_bump_run_number() -> int:
	var path: String = _run_count_path()
	var count: int = 0
	if FileAccess.file_exists(path):
		var reader: FileAccess = FileAccess.open(path, FileAccess.READ)
		if reader != null:
			var stored: String = reader.get_as_text().strip_edges()
			reader.close()
			if stored.is_valid_int():
				count = stored.to_int()
	count += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if writer != null:
		writer.store_string(str(count))
		writer.close()
	return count


## The run counter lives beside the player id, so a test that points the id at a
## throwaway directory keeps its counter there too.
func _run_count_path() -> String:
	return _player_id_path.get_base_dir() + "/" + RUN_COUNT_FILE


## Non-empty when a metric server is configured (see project.godot / TelemetryUploader),
## which switches the spool from the local-only directory to the upload outbox.
func _upload_endpoint() -> String:
	return str(ProjectSettings.get_setting(TelemetryUploader.ENDPOINT_SETTING, ""))


## The balance fingerprint of the JSON the run is playing, so metrics can be
## split per balance patch without a manual version bump.
func _current_balance_hash() -> String:
	var database: GameDatabase = DataLoader.db()
	return database.balance_hash


func _int(value: Variant, fallback: int = 0) -> int:
	return TelemetrySchema.to_int(value, fallback)
#endregion

#region Signal Handlers
func _on_damage_dealt(source: Unit, target: Unit, amount: int, hp_lost: int) -> void:
	_accumulate("damage_dealt", amount)
	_accumulate("hp_lost", hp_lost)
	# The direction, so reports can tell "damage the player took" from "damage the
	# player dealt" without re-deriving it from the per-row detail.
	if target != null and target.is_ally:
		_accumulate("ally_hp_lost", hp_lost)
	elif target != null:
		_accumulate("enemy_hp_lost", hp_lost)
	var row: Dictionary = {
		"source_id": TelemetrySchema.unit_id_of(source),
		"source_is_ally": source.is_ally if source != null else false,
		"target_id": TelemetrySchema.unit_id_of(target),
		"target_is_ally": target.is_ally if target != null else false,
		"damage": amount,
		"hp_lost": hp_lost,
	}
	_append_damage_event(row)
	# Enemy -> ally damage is attributed to the enemy *and* the skill it cast, so a
	# situational matchup ("HP lost to boss_enemy while playing healer_2") can be
	# answered without replaying the turn.
	if not _active_enemy.is_empty() and target != null and target.is_ally:
		var enemy_row: Dictionary = row.duplicate()
		enemy_row["enemy_unit_id"] = str(_active_enemy.get("unit_id", ""))
		enemy_row["enemy_skill_id"] = str(_active_enemy.get("skill_id", ""))
		enemy_row["enemy_roll"] = _int(_active_enemy.get("effective_value", 0))
		var condition_met: bool = _active_enemy.get("condition_met", false)
		enemy_row["enemy_condition_met"] = condition_met
		var enemy_rows: Array = _turn_outcome["enemy_damage_events"]
		if enemy_rows.size() < TelemetrySchema.MAX_ROWS:
			enemy_rows.append(enemy_row)


func _on_shield_gained(target: Unit, amount: int) -> void:
	_accumulate("shield_gained", amount)
	if target != null and target.is_ally:
		_accumulate("ally_shield_gained", amount)
	elif target != null:
		_accumulate("enemy_shield_gained", amount)


func _on_shield_reduced(target: Unit, amount: int) -> void:
	_accumulate("shield_reduced", amount)
	if target != null and target.is_ally:
		_accumulate("ally_shield_lost", amount)
	elif target != null:
		_accumulate("enemy_shield_lost", amount)


func _on_unit_healed(_target: Unit, amount: int) -> void:
	_accumulate("healed", amount)


func _on_unit_died(target: Unit) -> void:
	var unit_id: String = TelemetrySchema.unit_id_of(target)
	var turn_kills: Array = _turn_outcome["kills"]
	turn_kills.append(unit_id)
	var decision_kills: Array = _decision_outcome["kills"]
	decision_kills.append(unit_id)
	if target == null or not target.is_ally:
		return
	_ally_deaths.append(_death_cause(unit_id))


## Why an ally died: the enemy skill that was mid-resolution, the status that was
## ticking, or unknown. "Which enemy kills players" is the single most useful stat
## for tuning an overtuned encounter, so it is recorded per death.
func _death_cause(unit_id: String) -> Dictionary:
	var cause: Dictionary = {
		"unit_id": unit_id,
		"turn_number": _state.turn_number if _state != null else -1,
	}
	if not _active_enemy.is_empty():
		cause["kind"] = "enemy_skill"
		cause["source_unit_id"] = str(_active_enemy.get("unit_id", ""))
		cause["source_skill_id"] = str(_active_enemy.get("skill_id", ""))
		cause["roll"] = _int(_active_enemy.get("effective_value", 0))
		var condition_met: bool = _active_enemy.get("condition_met", false)
		cause["condition_met"] = condition_met
	elif not _active_status.is_empty():
		cause["kind"] = "status"
		cause["status_id"] = _active_status
	else:
		cause["kind"] = "unknown"
	return cause


func _on_card_drawn(_card: Card) -> void:
	_accumulate("cards_drawn", 1)


func _on_card_discarded(_card: Card) -> void:
	_accumulate("cards_discarded", 1)


func _on_card_value_changed(card: Card, old_value: int, new_value: int) -> void:
	var change: Dictionary = {
		"card_id": card.id if card != null else -1,
		"base_value": card.base_value if card != null else 0,
		"old": old_value,
		"new": new_value,
		"delta": new_value - old_value,
		"parity": TelemetrySchema.parity_of(card),
	}
	var turn_changes: Array = _turn_outcome["card_value_changes"]
	if turn_changes.size() < TelemetrySchema.MAX_ROWS:
		turn_changes.append(change)
	var decision_changes: Array = _decision_outcome["card_value_changes"]
	if decision_changes.size() < TelemetrySchema.MAX_ROWS:
		decision_changes.append(change.duplicate())


func _on_wave_started(wave_index: int) -> void:
	record_wave_started(wave_index)
#endregion


