<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DeterminismTest.gd` — `class_name DeterminismTest` extends `GdUnitTestSuite`

`557` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the property the whole telemetry story rests on: a battle is reproducible from its run seed. If it is not, "replay this seed to see the bug" is a lie, and…

Sections: Constants · Helpers · The same seed, the same battle · Invariants under a sweep · The generator itself · The audit
- L26 `class ScriptedUI extends GameUI` (members are not indexed)

Constants:
- L288 `SEED: int = 20260101` — The seed every determinism check starts from.
- L292 `GLOBAL_RNG_ALLOWED: Dictionary = {` — Shipped scripts that may draw from the global RNG, and why. Note that a *seeded* member call (`generator.randi_range(...)`) is not one of these: the audit looks…
- L296 `GLOBAL_RNG_PATTERN: String` — A *bare* global-RNG call (not `rng.randi_range(...)`) or a built-in shuffle.
- L298 `NON_SHIPPED_DIRS: PackedStringArray = [` — Directories whose scripts never ship, so their randomness cannot affect a replay.

Public API:
- L426-439 `test_the_same_seed_replays_the_same_battle() -> void` — The core promise: the same seed and the same decisions produce the same battle. Both runs are fingerprinted at every decision, so a divergence is caught at the…
- L444-451 `test_a_different_seed_deals_a_different_battle() -> void` — Guards against the failure mode where the test above passes because nothing in the battle is random at all.
- L457-468 `test_a_recorded_plan_replays_against_a_fresh_board() -> void` — The seed alone is not enough: if any path reached for the global RNG, the decisions recorded from one run would not fit a fresh board. Replaying them is what pr…
- L475-488 `test_the_board_holds_its_invariants_across_many_seeds() -> void` — A sweep rather than a single battle, because an invariant that only breaks on one deck order is exactly the bug a single scripted run would miss.
- L493-500 `test_a_swept_battle_is_a_real_battle() -> void` — The sweep is only meaningful if the runs are real: a battle that ended on turn one would satisfy every invariant above by never reaching the interesting states.
- L505-521 `test_a_roll_is_reproducible_from_its_generator() -> void`
- L528-539 `test_no_shipped_script_reaches_for_the_global_rng() -> void` — The check that keeps this file honest over time: a new global-RNG call in shipped code would break replays without failing any other test, so it fails this one…
- L545-555 `test_every_rng_allowlist_entry_is_still_needed() -> void` — The allowlist is a decision, so it is checked rather than trusted: every entry must name a script that exists and really does use the global RNG. A stale entry…

Private:
- L306-318 `_damage_skill`
- L321-332 `_ally_data`
- L335-349 `_enemy_data`
- L352-356 `_waves`
- L359-368 `_config`
- L373-383 `_run`
- L388-391 `_shipped_scripts`
- L394-405 `_collect_scripts`
- L408-418 `_rng_calls`

Uses: Card, DiceRoller, EffectBlock, EnemyIntent, GameManager, GameState, GameUI, SkillData, SkillEffect, TelemetrySchema, Unit, UnitData
Used by: —
Loads: res://GDTest, res://Tools, res://addons, res://reports, res://Trash, res://bin, res://.godot, res://

