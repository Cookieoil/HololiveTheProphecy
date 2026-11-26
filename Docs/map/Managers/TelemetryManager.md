<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/TelemetryManager.gd` — `class_name TelemetryManager` extends `RefCounted`

`663` lines · [back to the map](../../CODEBASE_MAP.md)

> Records every decision a player makes, for game design and balancing. It is a passive observer: GameManager (or a test) calls the `begin_*` / `record_*` hooks a…

Sections: Constants · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Decision Recording · Private Methods · Signal Handlers

Constants:
- L20 `SCHEMA_VERSION: int = 1`
- L22 `DEFAULT_SPOOL_DIR: String = "user://telemetry/spool"`
- L23 `PLAYER_ID_PATH: String = "user://telemetry/player_id.txt"`
- L26 `DECISION_PLAY: String = "play_card"` — Decision types. Deliberately readable strings, never numeric ordinals.
- L27 `DECISION_MERGE: String = "merge_cards"`
- L28 `DECISION_CONVERT: String = "convert_action"`
- L29 `DECISION_ULTIMATE: String = "cast_ultimate"`
- L30 `DECISION_END_TURN: String = "end_turn"`
- L31 `DECISION_DEBUG: String = "debug_command"`
- L32 `DECISION_UNKNOWN: String = "unknown"`
- L35 `REASON_FINAL_WAVE: String = "final_wave_cleared"` — Where a decision ended a battle (mirrors GameManager's call sites).
- L36 `REASON_ALL_ALLIES_DEAD: String = "all_allies_dead"`
- L37 `REASON_STATUS_TICK: String = "status_tick_defeat"`
- L38 `REASON_DEBUG_PREVIEW: String = "debug_preview"`
- L39 `REASON_UNKNOWN: String = "unknown"`

State:
- L46 `sink_override: TelemetrySink = null` — When supplied (tests only), the recorder writes into this sink and ignores the headless rule instead of opening a spool file. Deliberately per-instance: a globa…
- L47 `consent: TelemetryConsent`
- L48 `sink: TelemetrySink = null`
- L49 `enabled: bool = false`
- L50 `run_id: String = ""`
- L51 `player_anon_id: String = ""`
- L52 `balance_hash: String = ""`
- L53 `game_version: String = ""`
- L54 `was_debug_tainted: bool = false`
- L55 `total_turns: int = 0`
- L56 `total_decisions: int = 0`
- L57 `start_ms: int = 0`
- L61 `_spool_dir: String = DEFAULT_SPOOL_DIR`
- L62 `_player_id_path: String = PLAYER_ID_PATH`
- L63 `_state: GameState = null`
- L64 `_owns_sink: bool = false`
- L65 `_connected: bool = false`
- L67 `_intents: Array[EnemyIntent] = []`
- L68 `_turn_outcome: Dictionary = {}`
- L69 `_decision_outcome: Dictionary = {}`
- L70 `_decision_ctx: Dictionary = {}`
- L71 `_decision_offered: Dictionary = {}`
- L72 `_decision_sub: Array = []`
- L73 `_decision_start_ms: int = 0`
- L74 `_action_received_ms: int = 0`
- L75 `_decision_counter: int = 0`
- L76 `_merge_result: Dictionary = {}`

Public API:
- L97-100 `may_collect() -> bool` — True when this recorder may collect at all: a real (non-headless) session, or a test that supplied its own sink. Consent is checked on top in `start_run`.
- L105-147 `start_run(state: GameState, version: String = "") -> void` — Opens a run: creates the spool file, a player id and the `run_started` event. A no-op (leaving every buffer empty) when collection is not allowed.
- L151-168 `end_run(victory: bool, reason: String, state: GameState) -> void` — Closes a run with its result. Safe to call twice.
- L172-181 `shutdown() -> void` — Disconnects the bus and closes an owned sink. Always safe to call.
- L185-186 `mark_debug_tainted() -> void` — Flags the whole run as tester-tainted so balance views can ignore it.
- L190-191 `is_recording() -> bool` — True while a live run is being recorded.
- L196-204 `record_wave_started(wave_index: int) -> void` — Records a wave spawn (subscribed to EventBus.wave_started).
- L208-227 `record_turn_started(state: GameState, intents: Array[EnemyIntent], dice_sides: int) -> void` — Records the start-of-turn state: intents rolled, hand dealt, board snapshot.
- L231-242 `record_turn_ended(state: GameState) -> void` — Records the end of a turn, including everything that happened in it.
- L248-270 `begin_decision(state: GameState, intents: Array[EnemyIntent]) -> void` — Opens a decision window: snapshots everything the player can see *before* they choose, and starts the thinking clock. Every `record_*` outcome lands in this dec…
- L275-278 `note_action_received() -> void` — Marks the moment the player's answer arrived (thinking time ends here, before any animation plays).
- L282-285 `note_merge_result(result: Card) -> void` — Remembers a merge result so the decision can name the card it produced.
- L289-314 `end_decision(action: Dictionary, state: GameState) -> void` — Closes the decision window and writes the event.
- L318-328 `note_pick_target(candidates: Array[Unit], count: int, picked: Array[Unit], thinking_ms: int) -> void` — Records a target prompt inside a skill: every candidate and what was picked.
- L332-342 `note_pick_card(candidates: Array[Card], count: int, picked: Array[Card], thinking_ms: int) -> void` — Records a card prompt inside a skill: every candidate and what was picked.

Private:
- L80-91 `_init`
- L347-361 `_emit`
- L364-376 `_new_outcome`
- L379-381 `_accumulate`
- L384-390 `_append_damage_event`
- L396-411 `_build_offered`
- L414-435 `_legal_merge_pairs`
- L438-453 `_decision_type`
- L456-476 `_chosen`
- L479-493 `_chosen_play`
- L496-504 `_chosen_merge`
- L507-516 `_chosen_ultimate`
- L520-532 `_connect_bus`
- L535-556 `_disconnect_bus`
- L559-563 `_ally_lineup`
- L567-581 `_load_or_create_player_id`
- L584-585 `_project_version`
- L590-592 `_current_balance_hash`
- L595-596 `_int`
- L600-610 `_on_damage_dealt`
- L613-614 `_on_shield_gained`
- L617-618 `_on_shield_reduced`
- L621-622 `_on_unit_healed`
- L625-630 `_on_unit_died`
- L633-634 `_on_card_drawn`
- L637-638 `_on_card_discarded`
- L641-655 `_on_card_value_changed`
- L658-659 `_on_wave_started`

Uses: Card, DataLoader, EnemyIntent, GameDatabase, GameState, JsonlFileSink, SkillData, TelemetryConsent, TelemetrySchema, TelemetrySink, Unit
Used by: GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd
Loads: —

