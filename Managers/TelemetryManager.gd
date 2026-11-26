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

## Test seam mirroring GameManager.debug_build_override.
const FORCE_ENGINE: int = -1
const FORCE_OFF: int = 0
const FORCE_ON: int = 1

const DEFAULT_SPOOL_DIR: String = "user://telemetry/spool"
const PLAYER_ID_PATH: String = "user://telemetry/player_id.txt"

## Decision types. Deliberately readable strings, never numeric ordinals.
const DECISION_PLAY: String = "play_card"
const DECISION_MERGE: String = "merge_cards"
const DECISION_CONVERT: String = "convert_action"
const DECISION_ULTIMATE: String = "cast_ultimate"
const DECISION_END_TURN: String = "end_turn"
const DECISION_DEBUG: String = "debug_command"
const DECISION_UNKNOWN: String = "unknown"

## Where a decision ended a battle (mirrors GameManager's call sites).
const REASON_FINAL_WAVE: String = "final_wave_cleared"
const REASON_ALL_ALLIES_DEAD: String = "all_allies_dead"
const REASON_STATUS_TICK: String = "status_tick_defeat"
const REASON_DEBUG_PREVIEW: String = "debug_preview"
const REASON_UNKNOWN: String = "unknown"
#endregion

#region Test Seams
## Engine decides (consent + not headless); FORCE_ON/OFF pin the answer so the
## suite can exercise both paths. Never written by game code.
static var enabled_override: int = FORCE_ENGINE
## When set, the recorder writes into this sink instead of a spool file, so a
## test can inspect events in memory. The test owns the sink's lifetime.
static var sink_override: TelemetrySink = null
#endregion

#region Public Variables
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
var start_ms: int = 0
#endregion

#region Private Variables
var _spool_dir: String = DEFAULT_SPOOL_DIR
var _player_id_path: String = PLAYER_ID_PATH
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
#endregion

#region Lifecycle Methods
func _init(consent_path: String = TelemetryConsent.DEFAULT_PATH, spool_dir: String = DEFAULT_SPOOL_DIR, player_id_path: String = PLAYER_ID_PATH) -> void:
	consent = TelemetryConsent.load_from(consent_path)
	_spool_dir = spool_dir
	_player_id_path = player_id_path
	_turn_outcome = _new_outcome()
	_decision_outcome = _new_outcome()
#endregion

#region Public Methods
## True when this recorder may collect at all: a real (non-headless) session and
## the test seam. Consent is checked on top of this in `start_run`.
static func collection_allowed() -> bool:
	if enabled_override >= 0:
		return enabled_override == FORCE_ON
	if DisplayServer.get_name() == "headless":
		return false
	return true


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
	_turn_outcome = _new_outcome()
	_decision_outcome = _new_outcome()
	enabled = collection_allowed() and consent.is_granted()
	if not enabled:
		return
	run_id = TelemetrySchema.new_id()
	player_anon_id = _load_or_create_player_id()
	game_version = version if not version.is_empty() else _project_version()
	balance_hash = _current_balance_hash()
	start_ms = Time.get_ticks_msec()
	if sink_override != null:
		sink = sink_override
		_owns_sink = false
		if not sink.is_open():
			sink.open(run_id)
	else:
		var file_sink: JsonlFileSink = JsonlFileSink.new(_spool_dir, run_id)
		sink = file_sink
		_owns_sink = true
	_connect_bus()
	_emit("run_started", {
		"game_version": game_version,
		"balance_hash": balance_hash,
		"is_debug_build": OS.is_debug_build(),
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


## Closes a run with its result. Safe to call twice.
func end_run(victory: bool, reason: String, state: GameState) -> void:
	if not enabled:
		return
	var survivors: Array = []
	for unit: Unit in state.allies:
		if not unit.is_dead:
			survivors.append(TelemetrySchema.unit_snapshot(unit))
	_emit("run_ended", {
		"victory": victory,
		"end_reason": reason if not reason.is_empty() else REASON_UNKNOWN,
		"final_wave": state.current_wave,
		"total_turns": maxi(total_turns, state.turn_number + 1),
		"total_decisions": total_decisions,
		"survivors": survivors,
		"was_debug_tainted": was_debug_tainted,
		"duration_ms": maxi(0, Time.get_ticks_msec() - start_ms),
	})
	shutdown()


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
		"board": TelemetrySchema.board_snapshot(state),
		"metrics": TelemetrySchema.battlefield_metrics(state, intents),
	})


## Records the end of a turn, including everything that happened in it.
func record_turn_ended(state: GameState) -> void:
	if not enabled:
		return
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
	_emit("decision", {
		"decision_type": mapped,
		"decision_index": _decision_counter,
		"turn_number": _int(_decision_ctx.get("turn_number", 0)),
		"wave_index": _int(_decision_ctx.get("wave_index", 0)),
		"thinking_time_ms": maxi(0, _action_received_ms - _decision_start_ms),
		"context": _decision_ctx,
		"offered": _decision_offered,
		"chosen": _chosen(action_type, action, state),
		"sub_prompts": _decision_sub,
		"outcome": _decision_outcome,
	})
	_decision_counter += 1
	total_decisions += 1
	_decision_sub = []
	_merge_result = {}
	_decision_outcome = _new_outcome()


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
		"cards_drawn": 0,
		"cards_discarded": 0,
		"kills": [],
		"card_value_changes": [],
		"damage_events": [],
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
## legal merge pair, the ready Ultimates and the resources left. This is what
## makes a "pick rate" metric meaningful - the denominator, not just the choice.
func _build_offered(state: GameState) -> Dictionary:
	var ready_ultimates: Array = []
	var ally_ids: Array = []
	for unit: Unit in state.allies:
		ally_ids.append(TelemetrySchema.unit_id_of(unit))
		if not unit.is_dead and unit.can_cast_ultimate:
			ready_ultimates.append(TelemetrySchema.unit_ref(unit))
	return {
		"actions_left": state.actions_left,
		"merges_left": state.merges_left,
		"hand_size": state.hand.size(),
		"cards_in_hand": TelemetrySchema.cards_snapshot(state.hand),
		"ally_ids": ally_ids,
		"legal_merge_pairs": _legal_merge_pairs(state),
		"ready_ultimates": ready_ultimates,
	}


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
	_append_damage_event({
		"source_id": TelemetrySchema.unit_id_of(source),
		"source_is_ally": source.is_ally if source != null else false,
		"target_id": TelemetrySchema.unit_id_of(target),
		"target_is_ally": target.is_ally if target != null else false,
		"damage": amount,
		"hp_lost": hp_lost,
	})


func _on_shield_gained(_target: Unit, amount: int) -> void:
	_accumulate("shield_gained", amount)


func _on_shield_reduced(_target: Unit, amount: int) -> void:
	_accumulate("shield_reduced", amount)


func _on_unit_healed(_target: Unit, amount: int) -> void:
	_accumulate("healed", amount)


func _on_unit_died(target: Unit) -> void:
	var unit_id: String = TelemetrySchema.unit_id_of(target)
	var turn_kills: Array = _turn_outcome["kills"]
	turn_kills.append(unit_id)
	var decision_kills: Array = _decision_outcome["kills"]
	decision_kills.append(unit_id)


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


