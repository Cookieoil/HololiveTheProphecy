<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryTest.gd` — `class_name TelemetryTest` extends `GdUnitTestSuite`

`697` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the gameplay recorder end to end: a real battle through GameManager must produce run / wave / turn / decision / run-ended events, every decision must carr…

Sections: Helpers · Run events · Tester tools taint the run · Turn strategy and enemy attribution · Abandoned runs · Stage 2 upload plumbing · Seeds, run numbers, direction, defeat cause
- L18 `class MemorySink extends TelemetrySink` (members are not indexed)
- L36 `class ScriptedUI extends GameUI` (members are not indexed)

Constants:
- L11 `TEMP_ROOT: String = "user://telemetry_test"`
- L13 `SEED: int = 12345` — Fixed run seed for the scripted battles, so every assertion is reproducible.

State:
- L14 `_temp_dir: String = ""`

Public API:
- L122-123 `before() -> void`
- L126-131 `after() -> void`
- L250-287 `test_a_full_battle_records_run_wave_turn_and_decision_events() -> void`
- L292-311 `test_the_run_records_the_flags_that_were_on() -> void` — A staged flag has to reach the report, or the experiment cannot be read at all: the run records the flags that were ON, and nothing else.
- L314-380 `test_a_play_decision_carries_its_alternatives_and_outcome() -> void`
- L383-402 `test_a_merge_decision_names_the_result_card() -> void`
- L407-421 `test_a_debug_command_taints_the_run() -> void`
- L428-470 `test_turn_ended_records_strategy_and_enemy_damage() -> void` — Every turn records what the player did (skills / Ultimates / merges / converts) and the damage the enemy dealt back, attributed to the enemy *and* its skill.
- L475-501 `test_an_abandoned_run_is_flagged_and_closed_once() -> void`
- L506-522 `test_leaving_the_tree_mid_battle_abandons_the_run() -> void` — Leaving the tree while the battle is still running (a restart or a quit) closes the run instead of losing it.
- L531-553 `test_http_batch_sink_promotes_only_after_close() -> void` — A finished run is promoted from the local spool into the upload outbox only when it is closed, so the uploader can never list a half-written battle, never uploa…
- L558-564 `test_uploader_is_inert_without_an_endpoint() -> void` — With no endpoint configured the uploader must be completely inert: a local-only build never opens a socket.
- L572-591 `test_the_run_seed_reproduces_shuffle_and_rolls() -> void` — A run must be reproducible from its seed: the same seed has to give the same deck order and the same rolls, which is what makes a telemetry outlier replayable.
- L595-607 `test_the_seed_is_recorded_on_the_run() -> void` — The seed is recorded on the run, so a designer can reload any flagged battle.
- L611-626 `test_the_run_number_increments_per_battle() -> void` — How many battles this player has started, so reports can slice new from veteran.
- L631-651 `test_turn_totals_split_damage_by_direction() -> void` — Turn totals must split by direction, so a report never has to guess which side a "hp_lost" belongs to.
- L656-679 `test_a_defeat_records_what_killed_the_run() -> void` — A defeat must name the enemy and skill that killed the last ally: the single most useful stat for finding an overtuned encounter.
- L683-694 `test_a_victory_has_no_killed_by() -> void` — A victory has nothing that killed the run, so killed_by stays empty.

Private:
- L135-142 `_remove_tree`
- L145-157 `_nuke_skill`
- L160-170 `_ally_data`
- L173-185 `_enemy_data`
- L188-193 `_events_of`
- L196-200 `_first_decision`
- L203-208 `_turn_ended`
- L212-224 `_prepare`
- L227-231 `_waves`
- L234-245 `_config`

Uses: Card, DiceRoller, EffectBlock, EnemyIntent, GameManager, GameState, GameUI, HttpBatchSink, JsonlFileSink, SkillData, SkillEffect, TelemetryConsent, TelemetryConsentPopup, TelemetryManager, TelemetrySchema, TelemetrySink, TelemetryUploader, Unit, UnitData
Used by: —
Loads: —

