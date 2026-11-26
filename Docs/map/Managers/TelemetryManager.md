<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/TelemetryManager.gd` — `class_name TelemetryManager` extends `RefCounted`

`669` lines · [back to the map](../../CODEBASE_MAP.md)

> Records every decision a player makes, for game design and balancing. It is a passive observer: GameManager (or a test) calls the `begin_*` / `record_*` hooks a…

Sections: Constants · Test Seams · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Decision Recording · Private Methods · (+1 more)

Constants:
- L20 `SCHEMA_VERSION: int = 1`
- L23 `FORCE_ENGINE: int = -1` — Test seam mirroring GameManager.debug_build_override.
- L24 `FORCE_OFF: int = 0`
- L25 `FORCE_ON: int = 1`
- L27 `DEFAULT_SPOOL_DIR: String = "user://telemetry/spool"`
- L28 `PLAYER_ID_PATH: String = "user://telemetry/player_id.txt"`
- L31 `DECISION_PLAY: String = "play_card"` — Decision types. Deliberately readable strings, never numeric ordinals.
- L32 `DECISION_MERGE: String = "merge_cards"`
- L33 `DECISION_CONVERT: String = "convert_action"`
- L34 `DECISION_ULTIMATE: String = "cast_ultimate"`
- L35 `DECISION_END_TURN: String = "end_turn"`
- L36 `DECISION_DEBUG: String = "debug_command"`
- L37 `DECISION_UNKNOWN: String = "unknown"`
- L40 `REASON_FINAL_WAVE: String = "final_wave_cleared"` — Where a decision ended a battle (mirrors GameManager's call sites).
- L41 `REASON_ALL_ALLIES_DEAD: String = "all_allies_dead"`
- L42 `REASON_STATUS_TICK: String = "status_tick_defeat"`
- L43 `REASON_DEBUG_PREVIEW: String = "debug_preview"`
- L44 `REASON_UNKNOWN: String = "unknown"`

State:
- L50 `enabled_override: int = FORCE_ENGINE` — Engine decides (consent + not headless); FORCE_ON/OFF pin the answer so the suite can exercise both paths. Never written by game code.
- L53 `sink_override: TelemetrySink = null` — When set, the recorder writes into this sink instead of a spool file, so a test can inspect events in memory. The test owns the sink's lifetime.
- L57 `consent: TelemetryConsent`
- L58 `sink: TelemetrySink = null`
- L59 `enabled: bool = false`
- L60 `run_id: String = ""`
- L61 `player_anon_id: String = ""`
- L62 `balance_hash: String = ""`
- L63 `game_version: String = ""`
- L64 `was_debug_tainted: bool = false`
- L65 `total_turns: int = 0`
- L66 `total_decisions: int = 0`
- L67 `start_ms: int = 0`
- L71 `_spool_dir: String = DEFAULT_SPOOL_DIR`
- L72 `_player_id_path: String = PLAYER_ID_PATH`
- L73 `_state: GameState = null`
- L74 `_owns_sink: bool = false`
- L75 `_connected: bool = false`
- L77 `_intents: Array[EnemyIntent] = []`
- L78 `_turn_outcome: Dictionary = {}`
- L79 `_decision_outcome: Dictionary = {}`
- L80 `_decision_ctx: Dictionary = {}`
- L81 `_decision_offered: Dictionary = {}`
- L82 `_decision_sub: Array = []`
- L83 `_decision_start_ms: int = 0`
- L84 `_action_received_ms: int = 0`
- L85 `_decision_counter: int = 0`
- L86 `_merge_result: Dictionary = {}`

Public API:
- L101-106 `static collection_allowed() -> bool` — True when this recorder may collect at all: a real (non-headless) session and the test seam. Consent is checked on top of this in `start_run`.
- L111-153 `start_run(state: GameState, version: String = "") -> void` — Opens a run: creates the spool file, a player id and the `run_started` event. A no-op (leaving every buffer empty) when collection is not allowed.
- L157-174 `end_run(victory: bool, reason: String, state: GameState) -> void` — Closes a run with its result. Safe to call twice.
- L178-187 `shutdown() -> void` — Disconnects the bus and closes an owned sink. Always safe to call.
- L191-192 `mark_debug_tainted() -> void` — Flags the whole run as tester-tainted so balance views can ignore it.
- L196-197 `is_recording() -> bool` — True while a live run is being recorded.
- L202-210 `record_wave_started(wave_index: int) -> void` — Records a wave spawn (subscribed to EventBus.wave_started).
- L214-233 `record_turn_started(state: GameState, intents: Array[EnemyIntent], dice_sides: int) -> void` — Records the start-of-turn state: intents rolled, hand dealt, board snapshot.
- L237-248 `record_turn_ended(state: GameState) -> void` — Records the end of a turn, including everything that happened in it.
- L254-276 `begin_decision(state: GameState, intents: Array[EnemyIntent]) -> void` — Opens a decision window: snapshots everything the player can see *before* they choose, and starts the thinking clock. Every `record_*` outcome lands in this dec…
- L281-284 `note_action_received() -> void` — Marks the moment the player's answer arrived (thinking time ends here, before any animation plays).
- L288-291 `note_merge_result(result: Card) -> void` — Remembers a merge result so the decision can name the card it produced.
- L295-320 `end_decision(action: Dictionary, state: GameState) -> void` — Closes the decision window and writes the event.
- L324-334 `note_pick_target(candidates: Array[Unit], count: int, picked: Array[Unit], thinking_ms: int) -> void` — Records a target prompt inside a skill: every candidate and what was picked.
- L338-348 `note_pick_card(candidates: Array[Card], count: int, picked: Array[Card], thinking_ms: int) -> void` — Records a card prompt inside a skill: every candidate and what was picked.

Private:
- L90-95 `_init`
- L353-367 `_emit`
- L370-382 `_new_outcome`
- L385-387 `_accumulate`
- L390-396 `_append_damage_event`
- L402-417 `_build_offered`
- L420-441 `_legal_merge_pairs`
- L444-459 `_decision_type`
- L462-482 `_chosen`
- L485-499 `_chosen_play`
- L502-510 `_chosen_merge`
- L513-522 `_chosen_ultimate`
- L526-538 `_connect_bus`
- L541-562 `_disconnect_bus`
- L565-569 `_ally_lineup`
- L573-587 `_load_or_create_player_id`
- L590-591 `_project_version`
- L596-598 `_current_balance_hash`
- L601-602 `_int`
- L606-616 `_on_damage_dealt`
- L619-620 `_on_shield_gained`
- L623-624 `_on_shield_reduced`
- L627-628 `_on_unit_healed`
- L631-636 `_on_unit_died`
- L639-640 `_on_card_drawn`
- L643-644 `_on_card_discarded`
- L647-661 `_on_card_value_changed`
- L664-665 `_on_wave_started`

Uses: Card, DataLoader, EnemyIntent, GameDatabase, GameState, JsonlFileSink, SkillData, TelemetryConsent, TelemetrySchema, TelemetrySink, Unit
Used by: GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd
Loads: —

