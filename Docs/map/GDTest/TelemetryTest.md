<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryTest.gd` — `class_name TelemetryTest` extends `GdUnitTestSuite`

`520` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the gameplay recorder end to end: a real battle through GameManager must produce run / wave / turn / decision / run-ended events, every decision must carr…

Sections: Helpers · Run events · Tester tools taint the run · Turn strategy and enemy attribution · Abandoned runs · Stage 2 upload plumbing
- L16 `class MemorySink extends TelemetrySink` (members are not indexed)
- L34 `class ScriptedUI extends GameUI` (members are not indexed)

Constants:
- L11 `TEMP_ROOT: String = "user://telemetry_test"`

State:
- L12 `_temp_dir: String = ""`

Public API:
- L115-116 `before() -> void`
- L119-124 `after() -> void`
- L240-277 `test_a_full_battle_records_run_wave_turn_and_decision_events() -> void`
- L280-346 `test_a_play_decision_carries_its_alternatives_and_outcome() -> void`
- L349-368 `test_a_merge_decision_names_the_result_card() -> void`
- L373-387 `test_a_debug_command_taints_the_run() -> void`
- L394-436 `test_turn_ended_records_strategy_and_enemy_damage() -> void` — Every turn records what the player did (skills / Ultimates / merges / converts) and the damage the enemy dealt back, attributed to the enemy *and* its skill.
- L441-465 `test_an_abandoned_run_is_flagged_and_closed_once() -> void`
- L470-486 `test_leaving_the_tree_mid_battle_abandons_the_run() -> void` — Leaving the tree while the battle is still running (a restart or a quit) closes the run instead of losing it.
- L494-506 `test_http_batch_sink_spools_into_the_outbox() -> void` — The Stage 2 sink must spool into the upload outbox (never the local-only spool), so TelemetryUploader can find it.
- L511-517 `test_uploader_is_inert_without_an_endpoint() -> void` — With no endpoint configured the uploader must be completely inert: a local-only build never opens a socket.

Private:
- L128-135 `_remove_tree`
- L138-150 `_nuke_skill`
- L153-163 `_ally_data`
- L166-178 `_enemy_data`
- L181-186 `_events_of`
- L189-193 `_first_decision`
- L196-201 `_turn_ended`
- L205-217 `_prepare`
- L220-224 `_waves`
- L227-235 `_config`

Uses: Card, EffectBlock, EnemyIntent, GameManager, GameState, GameUI, HttpBatchSink, SkillData, SkillEffect, TelemetryConsent, TelemetryConsentPopup, TelemetryManager, TelemetrySchema, TelemetrySink, TelemetryUploader, Unit, UnitData
Used by: —
Loads: —

