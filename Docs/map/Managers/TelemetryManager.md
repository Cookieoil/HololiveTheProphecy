<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/TelemetryManager.gd` — `class_name TelemetryManager` extends `RefCounted`

`913` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L32 `DECISION_DRAFT: String = "draft_pick"`
- L33 `DECISION_UNKNOWN: String = "unknown"`
- L36 `REASON_FINAL_WAVE: String = "final_wave_cleared"` — Where a decision ended a battle (mirrors GameManager's call sites).
- L37 `REASON_ALL_ALLIES_DEAD: String = "all_allies_dead"`
- L38 `REASON_STATUS_TICK: String = "status_tick_defeat"`
- L39 `REASON_DEBUG_PREVIEW: String = "debug_preview"`
- L41 `REASON_ABANDONED: String = "abandoned"` — The battle never finished: the player restarted or quit mid-run.
- L42 `REASON_UNKNOWN: String = "unknown"`

State:
- L49 `sink_override: TelemetrySink = null` — When supplied (tests only), the recorder writes into this sink and ignores the headless rule instead of opening a spool file. Deliberately per-instance: a globa…
- L50 `consent: TelemetryConsent`
- L51 `sink: TelemetrySink = null`
- L52 `enabled: bool = false`
- L53 `run_id: String = ""`
- L54 `player_anon_id: String = ""`
- L55 `balance_hash: String = ""`
- L56 `game_version: String = ""`
- L57 `was_debug_tainted: bool = false`
- L58 `total_turns: int = 0`
- L59 `total_decisions: int = 0`
- L60 `start_ms: int = 0`
- L64 `_spool_dir: String = DEFAULT_SPOOL_DIR`
- L65 `_player_id_path: String = PLAYER_ID_PATH`
- L68 `_consent_path: String = TelemetryConsent.DEFAULT_PATH` — Where the consent answer is read from (and re-read at `start_run`, because the disclosure can be answered after this recorder was constructed).
- L69 `_state: GameState = null`
- L70 `_owns_sink: bool = false`
- L71 `_connected: bool = false`
- L73 `_intents: Array[EnemyIntent] = []`
- L74 `_turn_outcome: Dictionary = {}`
- L75 `_decision_outcome: Dictionary = {}`
- L76 `_decision_ctx: Dictionary = {}`
- L77 `_decision_offered: Dictionary = {}`
- L78 `_decision_sub: Array = []`
- L79 `_decision_start_ms: int = 0`
- L80 `_action_received_ms: int = 0`
- L81 `_decision_counter: int = 0`
- L82 `_merge_result: Dictionary = {}`
- L86 `_active_enemy: Dictionary = {}` — The enemy currently resolving its skill, so the damage it deals can be attributed to the enemy *and* the skill that caused it. Empty when no enemy is acting (ev…
- L89 `_last_closed_turn: int = -1` — Last turn number already closed, so `record_turn_ended` may be called on every exit path of the loop while still writing exactly one turn_ended per turn.

Public API:
- L111-114 `may_collect() -> bool` — True when this recorder may collect at all: a real (non-headless) session, or a test that supplied its own sink. Consent is checked on top in `start_run`.
- L119-175 `start_run(state: GameState, version: String = "") -> void` — Opens a run: creates the spool file, a player id and the `run_started` event. A no-op (leaving every buffer empty) when collection is not allowed.
- L181-199 `end_run(victory: bool, reason: String, state: GameState, abandoned: bool = false) -> void` — Closes a run with its result. Safe to call twice. `abandoned` marks a run the player never finished (restart / quit), so it is reported separately instead of be…
- L204-207 `abandon_run(state: GameState) -> void` — Closes an unfinished run when the battle scene goes away (a restart or a quit). Idempotent: a buttoned-up run has already stopped recording, so this is a no-op.
- L211-220 `shutdown() -> void` — Disconnects the bus and closes an owned sink. Always safe to call.
- L224-225 `mark_debug_tainted() -> void` — Flags the whole run as tester-tainted so balance views can ignore it.
- L229-230 `is_recording() -> bool` — True while a live run is being recorded.
- L235-243 `record_wave_started(wave_index: int) -> void` — Records a wave spawn (subscribed to EventBus.wave_started).
- L247-267 `record_turn_started(state: GameState, intents: Array[EnemyIntent], dice_sides: int) -> void` — Records the start-of-turn state: intents rolled, hand dealt, board snapshot.
- L275-289 `record_turn_ended(state: GameState) -> void` — Records the end of a turn, including everything that happened in it. Idempotent per turn: GameManager closes the turn on every way out of the loop (including a…
- L295-318 `begin_decision(state: GameState, intents: Array[EnemyIntent]) -> void` — Opens a decision window: snapshots everything the player can see *before* they choose, and starts the thinking clock. Every `record_*` outcome lands in this dec…
- L323-326 `note_action_received() -> void` — Marks the moment the player's answer arrived (thinking time ends here, before any animation plays).
- L330-333 `note_merge_result(result: Card) -> void` — Remembers a merge result so the decision can name the card it produced.
- L337-364 `end_decision(action: Dictionary, state: GameState) -> void` — Closes the decision window and writes the event.
- L394-404 `note_pick_target(candidates: Array[Unit], count: int, picked: Array[Unit], thinking_ms: int) -> void` — Records a target prompt inside a skill: every candidate and what was picked.
- L408-418 `note_pick_card(candidates: Array[Card], count: int, picked: Array[Card], thinking_ms: int) -> void` — Records a card prompt inside a skill: every candidate and what was picked.
- L423-433 `begin_enemy_action(enemy: Unit, skill: SkillData, intent: EnemyIntent) -> void` — Opens the window in which one enemy resolves its skill, so the damage it deals can be attributed to that enemy and that skill (see `_on_damage_dealt`).
- L436-437 `end_enemy_action() -> void`
- L443-475 `record_draft_decision(category: String, offered_ids: Array[String], picked_id: String, state: GameState) -> void` — Records an explicit reward / draft choice (card reward, ally recruit, skill upgrade). Documents the offer so pick rate works for future progression, even though…

Private:
- L93-105 `_init`
- L370-390 `_note_turn_action`
- L480-494 `_emit`
- L497-518 `_new_outcome`
- L521-523 `_accumulate`
- L526-532 `_append_damage_event`
- L539-600 `_build_offered`
- L606-631 `_playable_skill_options`
- L634-655 `_legal_merge_pairs`
- L658-673 `_decision_type`
- L676-696 `_chosen`
- L699-713 `_chosen_play`
- L716-724 `_chosen_merge`
- L727-736 `_chosen_ultimate`
- L740-752 `_connect_bus`
- L755-776 `_disconnect_bus`
- L779-783 `_ally_lineup`
- L788-793 `_living_enemy_ids`
- L797-811 `_load_or_create_player_id`
- L814-815 `_project_version`
- L820-821 `_upload_endpoint`
- L826-828 `_current_balance_hash`
- L831-832 `_int`
- L836-860 `_on_damage_dealt`
- L863-864 `_on_shield_gained`
- L867-868 `_on_shield_reduced`
- L871-872 `_on_unit_healed`
- L875-880 `_on_unit_died`
- L883-884 `_on_card_drawn`
- L887-888 `_on_card_discarded`
- L891-905 `_on_card_value_changed`
- L908-909 `_on_wave_started`

Uses: Card, DataLoader, EnemyIntent, GameDatabase, GameState, HttpBatchSink, JsonlFileSink, SkillData, TelemetryConsent, TelemetrySchema, TelemetrySink, TelemetryUploader, Unit
Used by: GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd
Loads: —

