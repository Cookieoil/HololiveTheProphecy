<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DeterminismTest.gd` — `class_name DeterminismTest` extends `GdUnitTestSuite`

`327` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the property the whole telemetry story rests on: a battle is reproducible from its run seed. If it is not, "replay this seed to see the bug" is a lie, and…

Sections: Constants · Helpers · The same seed, the same battle · Invariants under a sweep · The generator itself · The audit

Constants:
- L25 `SEED: int = 20260101` — The seed every determinism check starts from.
- L27 `SWEEP_SEEDS: int = 24` — How many seeds the invariant sweep covers.
- L30 `SHIPPED_SEEDS: int = 12` — How many seeds the shipped-battle sweep covers: fewer, because these are real battles with real skills rather than a two-card fixture.
- L34 `GLOBAL_RNG_ALLOWED: Dictionary = {` — Shipped scripts that may draw from the global RNG, and why. A *seeded* member call (`generator.randi_range(...)`) is not one of these: the audit looks for bare…
- L38 `GLOBAL_RNG_PATTERN: String` — A *bare* global-RNG call (not `rng.randi_range(...)`) or a built-in shuffle.
- L40 `NON_SHIPPED_DIRS: PackedStringArray = [` — Directories whose scripts never ship, so their randomness cannot affect a replay.

Public API:
- L191-204 `test_the_same_seed_replays_the_same_battle() -> void` — The core promise: the same seed and the same decisions produce the same battle. Both runs are fingerprinted at every decision, so a divergence is caught at the…
- L209-216 `test_a_different_seed_deals_a_different_battle() -> void` — Guards against the failure mode where the test above passes because nothing in the battle is random at all.
- L222-233 `test_a_recorded_plan_replays_against_a_fresh_board() -> void` — The seed alone is not enough: if any path reached for the global RNG, the decisions recorded from one run would not fit a fresh board. Replaying them is what pr…
- L240-243 `test_the_board_holds_its_invariants_across_many_seeds() -> void` — A sweep rather than a single battle, because an invariant that only breaks on one deck order is exactly the bug a single scripted run would miss.
- L251-254 `test_the_shipped_battle_holds_its_invariants_across_seeds() -> void` — The same invariants against the battle the game actually ships, not just the fixture: real skills draw cards, buff values and pick targets in ways a two-card de…
- L261-268 `test_a_swept_battle_is_a_real_battle() -> void` — The sweep is only meaningful if the runs are real: a battle that ended on turn one would satisfy every invariant above by never reaching the interesting states.
- L273-289 `test_a_roll_is_reproducible_from_its_generator() -> void`
- L297-308 `test_no_shipped_script_reaches_for_the_global_rng() -> void` — The check that keeps this file honest over time: a new global-RNG call in shipped code would break replays without failing any other test, so it fails this one…
- L314-324 `test_every_rng_allowlist_entry_is_still_needed() -> void` — The allowlist is a decision, so it is checked rather than trusted: every entry must name a script that exists and really does use the global RNG. A stale entry…

Private:
- L48-60 `_damage_skill`
- L63-74 `_ally_data`
- L77-91 `_enemy_data`
- L94-98 `_waves`
- L101-110 `_config`
- L114-118 `_simulator`
- L123-125 `_run`
- L131-148 `_sweep_seeds`
- L153-156 `_shipped_scripts`
- L159-170 `_collect_scripts`
- L173-183 `_rng_calls`

Uses: BattleSimulator, DiceRoller, EffectBlock, SkillData, SkillEffect, UnitData
Used by: —
Loads: res://GDTest, res://Tools, res://addons, res://reports, res://Trash, res://bin, res://.godot, res://

