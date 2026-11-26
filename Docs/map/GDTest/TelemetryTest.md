<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryTest.gd` — `class_name TelemetryTest` extends `GdUnitTestSuite`

`366` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the gameplay recorder end to end: a real battle through GameManager must produce run / wave / turn / decision / run-ended events, every decision must carr…

Sections: Helpers · Run events · Tester tools taint the run
- L16 `class MemorySink extends TelemetrySink` (members are not indexed)
- L34 `class ScriptedUI extends GameUI` (members are not indexed)

Constants:
- L11 `TEMP_ROOT: String = "user://telemetry_test"`

State:
- L12 `_temp_dir: String = ""`

Public API:
- L115-116 `before() -> void`
- L119-121 `after() -> void`
- L124-126 `after_test() -> void`
- L234-271 `test_a_full_battle_records_run_wave_turn_and_decision_events() -> void`
- L274-323 `test_a_play_decision_carries_its_alternatives_and_outcome() -> void`
- L326-345 `test_a_merge_decision_names_the_result_card() -> void`
- L350-364 `test_a_debug_command_taints_the_run() -> void`

Private:
- L130-137 `_remove_tree`
- L140-152 `_nuke_skill`
- L155-165 `_ally_data`
- L168-178 `_enemy_data`
- L181-186 `_events_of`
- L189-193 `_first_decision`
- L197-211 `_prepare`
- L214-218 `_waves`
- L221-229 `_config`

Uses: Card, EffectBlock, EnemyIntent, GameManager, GameState, GameUI, SkillData, SkillEffect, TelemetryConsent, TelemetryManager, TelemetrySchema, TelemetrySink, Unit, UnitData
Used by: —
Loads: —

