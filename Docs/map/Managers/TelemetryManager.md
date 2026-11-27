<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/TelemetryManager.gd` — `class_name TelemetryManager` extends `RefCounted`

`1021` lines · [back to the map](../../CODEBASE_MAP.md)

> Records every decision a player makes, for game design and balancing. It is a passive observer: GameManager (or a test) calls the `begin_*` / `record_*` hooks a…

Sections: Constants · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Decision Recording · Private Methods · Signal Handlers

Constants:
- L20 `SCHEMA_VERSION: int = 1`
- L22 `DEFAULT_SPOOL_DIR: String = "user://telemetry/spool"`
- L23 `PLAYER_ID_PATH: String = "user://telemetry/player_id.txt"`
- L26 `RUN_COUNT_FILE: String = "run_count.txt"` — Counts the battles this player has started, kept beside the player id, so the reports can slice "still learning" runs from veteran runs without any identity.
- L29 `DECISION_PLAY: String = "play_card"` — Decision types. Deliberately readable strings, never numeric ordinals.
- L30 `DECISION_MERGE: String = "merge_cards"`
- L31 `DECISION_CONVERT: String = "convert_action"`
- L32 `DECISION_ULTIMATE: String = "cast_ultimate"`
- L33 `DECISION_END_TURN: String = "end_turn"`
- L34 `DECISION_DEBUG: String = "debug_command"`
- L35 `DECISION_DRAFT: String = "draft_pick"`
- L36 `DECISION_UNKNOWN: String = "unknown"`
- L39 `REASON_FINAL_WAVE: String = "final_wave_cleared"` — Where a decision ended a battle (mirrors GameManager's call sites).
- L40 `REASON_ALL_ALLIES_DEAD: String = "all_allies_dead"`
- L41 `REASON_STATUS_TICK: String = "status_tick_defeat"`
- L42 `REASON_DEBUG_PREVIEW: String = "debug_preview"`
- L44 `REASON_ABANDONED: String = "abandoned"` — The battle never finished: the player restarted or quit mid-run.
- L45 `REASON_UNKNOWN: String = "unknown"`

State:
- L52 `sink_override: TelemetrySink = null` — When supplied (tests only), the recorder writes into this sink and ignores the headless rule instead of opening a spool file. Deliberately per-instance: a globa…
- L53 `consent: TelemetryConsent`
- L54 `sink: TelemetrySink = null`
- L55 `enabled: bool = false`
- L56 `run_id: String = ""`
- L57 `player_anon_id: String = ""`
- L58 `balance_hash: String = ""`
- L59 `game_version: String = ""`
- L60 `was_debug_tainted: bool = false`
- L61 `total_turns: int = 0`
- L62 `total_decisions: int = 0`
- L64 `player_run_number: int = 0` — How many battles this player has started, including this one.
- L65 `start_ms: int = 0`
- L69 `_spool_dir: String = DEFAULT_SPOOL_DIR`
- L70 `_player_id_path: String = PLAYER_ID_PATH`
- L73 `_consent_path: String = TelemetryConsent.DEFAULT_PATH` — Where the consent answer is read from (and re-read at `start_run`, because the disclosure can be answered after this recorder was constructed).
- L74 `_state: GameState = null`
- L75 `_owns_sink: bool = false`
- L76 `_connected: bool = false`
- L78 `_intents: Array[EnemyIntent] = []`
- L79 `_turn_outcome: Dictionary = {}`
- L80 `_decision_outcome: Dictionary = {}`
- L81 `_decision_ctx: Dictionary = {}`
- L82 `_decision_offered: Dictionary = {}`
- L83 `_decision_sub: Array = []`
- L84 `_decision_start_ms: int = 0`
- L85 `_action_received_ms: int = 0`
- L86 `_decision_counter: int = 0`
- L87 `_merge_result: Dictionary = {}`
- L91 `_active_enemy: Dictionary = {}` — The enemy currently resolving its skill, so the damage it deals can be attributed to the enemy *and* the skill that caused it. Empty when no enemy is acting (ev…
- L94 `_active_status: String = ""` — The status currently ticking (a damage-over-time round tick), so a death it causes is attributed to that status instead of an unknown source.
- L96 `_ally_deaths: Array = []` — Every ally death this run with its cause. The last one is what ended a defeat.
- L99 `_last_closed_turn: int = -1` — Last turn number already closed, so `record_turn_ended` may be called on every exit path of the loop while still writing exactly one turn_ended per turn.

Public API:
- L121-124 `may_collect() -> bool` — True when this recorder may collect at all: a real (non-headless) session, or a test that supplied its own sink. Consent is checked on top in `start_run`.
- L129-180 `start_run(state: GameState, version: String = "") -> void` — Opens a run: creates the spool file, a player id and the `run_started` event. A no-op (leaving every buffer empty) when collection is not allowed.
- L186-207 `end_run(victory: bool, reason: String, state: GameState, abandoned: bool = false) -> void` — Closes a run with its result. Safe to call twice. `abandoned` marks a run the player never finished (restart / quit), so it is reported separately instead of be…
- L221-227 `abandon_run(state: GameState) -> void` — Closes an unfinished run when the battle scene goes away (a restart or a quit). Idempotent: a buttoned-up run has already stopped recording, so this is a no-op.
- L231-240 `shutdown() -> void` — Disconnects the bus and closes an owned sink. Always safe to call.
- L244-245 `mark_debug_tainted() -> void` — Flags the whole run as tester-tainted so balance views can ignore it.
- L249-250 `is_recording() -> bool` — True while a live run is being recorded.
- L255-263 `record_wave_started(wave_index: int) -> void` — Records a wave spawn (subscribed to EventBus.wave_started).
- L267-287 `record_turn_started(state: GameState, intents: Array[EnemyIntent], dice_sides: int) -> void` — Records the start-of-turn state: intents rolled, hand dealt, board snapshot.
- L295-309 `record_turn_ended(state: GameState) -> void` — Records the end of a turn, including everything that happened in it. Idempotent per turn: GameManager closes the turn on every way out of the loop (including a…
- L315-338 `begin_decision(state: GameState, intents: Array[EnemyIntent]) -> void` — Opens a decision window: snapshots everything the player can see *before* they choose, and starts the thinking clock. Every `record_*` outcome lands in this dec…
- L343-346 `note_action_received() -> void` — Marks the moment the player's answer arrived (thinking time ends here, before any animation plays).
- L350-353 `note_merge_result(result: Card) -> void` — Remembers a merge result so the decision can name the card it produced.
- L357-384 `end_decision(action: Dictionary, state: GameState) -> void` — Closes the decision window and writes the event.
- L414-424 `note_pick_target(candidates: Array[Unit], count: int, picked: Array[Unit], thinking_ms: int) -> void` — Records a target prompt inside a skill: every candidate and what was picked.
- L428-438 `note_pick_card(candidates: Array[Card], count: int, picked: Array[Card], thinking_ms: int) -> void` — Records a card prompt inside a skill: every candidate and what was picked.
- L443-453 `begin_enemy_action(enemy: Unit, skill: SkillData, intent: EnemyIntent) -> void` — Opens the window in which one enemy resolves its skill, so the damage it deals can be attributed to that enemy and that skill (see `_on_damage_dealt`).
- L456-457 `end_enemy_action() -> void`
- L462-465 `begin_status_tick(status_id: String) -> void` — Opens the window in which one status ticks, so a death it causes is attributed to that status instead of being recorded as an unknown source.
- L468-469 `end_status_tick() -> void`
- L475-507 `record_draft_decision(category: String, offered_ids: Array[String], picked_id: String, state: GameState) -> void` — Records an explicit reward / draft choice (card reward, ally recruit, skill upgrade). Documents the offer so pick rate works for future progression, even though…

Private:
- L103-115 `_init`
- L212-216 `_killed_by`
- L390-410 `_note_turn_action`
- L512-526 `_emit`
- L529-558 `_new_outcome`
- L561-563 `_accumulate`
- L566-572 `_append_damage_event`
- L579-640 `_build_offered`
- L646-671 `_playable_skill_options`
- L674-695 `_legal_merge_pairs`
- L698-713 `_decision_type`
- L716-736 `_chosen`
- L739-753 `_chosen_play`
- L756-764 `_chosen_merge`
- L767-776 `_chosen_ultimate`
- L780-792 `_connect_bus`
- L795-816 `_disconnect_bus`
- L819-823 `_ally_lineup`
- L828-833 `_living_enemy_ids`
- L837-851 `_load_or_create_player_id`
- L854-855 `_project_version`
- L861-877 `_load_and_bump_run_number`
- L882-883 `_run_count_path`
- L888-889 `_upload_endpoint`
- L894-896 `_current_balance_hash`
- L899-900 `_int`
- L904-934 `_on_damage_dealt`
- L937-942 `_on_shield_gained`
- L945-950 `_on_shield_reduced`
- L953-954 `_on_unit_healed`
- L957-965 `_on_unit_died`
- L971-988 `_death_cause`
- L991-992 `_on_card_drawn`
- L995-996 `_on_card_discarded`
- L999-1013 `_on_card_value_changed`
- L1016-1017 `_on_wave_started`

Uses: Card, DataLoader, EnemyIntent, GameDatabase, GameState, HttpBatchSink, JsonlFileSink, SkillData, TelemetryConsent, TelemetrySchema, TelemetrySink, TelemetryUploader, Unit
Used by: GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd
Loads: —

