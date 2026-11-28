<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DeterminismTest.gd` — `class_name DeterminismTest` extends `GdUnitTestSuite`

`403` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the property the whole telemetry story rests on: a battle is reproducible from its run seed. If it is not, "replay this seed to see the bug" is a lie, and…

Sections: Constants · Helpers · The same seed, the same battle · Invariants under a sweep · What the fingerprint has to describe · The generator itself · The audit

Constants:
- L25 `SEED: int = 20260101` — The seed every determinism check starts from.
- L27 `SWEEP_SEEDS: int = 24` — How many seeds the invariant sweep covers.
- L30 `SHIPPED_SEEDS: int = 12` — How many seeds the shipped-battle sweep covers: fewer, because these are real battles with real skills rather than a two-card fixture.
- L34 `GLOBAL_RNG_ALLOWED: Dictionary = {` — Shipped scripts that may draw from the global RNG, and why. A *seeded* member call (`generator.randi_range(...)`) is not one of these: the audit looks for bare…
- L38 `GLOBAL_RNG_PATTERN: String` — A *bare* global-RNG call (not `rng.randi_range(...)`) or a built-in shuffle.
- L40 `NON_SHIPPED_DIRS: PackedStringArray = [` — Directories whose scripts never ship, so their randomness cannot affect a replay.

Public API:
- L200-213 `test_the_same_seed_replays_the_same_battle() -> void` — The core promise: the same seed and the same decisions produce the same battle. Both runs are fingerprinted at every decision, so a divergence is caught at the…
- L218-225 `test_a_different_seed_deals_a_different_battle() -> void` — Guards against the failure mode where the test above passes because nothing in the battle is random at all.
- L231-242 `test_a_recorded_plan_replays_against_a_fresh_board() -> void` — The seed alone is not enough: if any path reached for the global RNG, the decisions recorded from one run would not fit a fresh board. Replaying them is what pr…
- L249-252 `test_the_board_holds_its_invariants_across_many_seeds() -> void` — A sweep rather than a single battle, because an invariant that only breaks on one deck order is exactly the bug a single scripted run would miss.
- L260-263 `test_the_shipped_battle_holds_its_invariants_across_seeds() -> void` — The same invariants against the battle the game actually ships, not just the fixture: real skills draw cards, buff values and pick targets in ways a two-card de…
- L270-277 `test_a_swept_battle_is_a_real_battle() -> void` — The sweep is only meaningful if the runs are real: a battle that ended on turn one would satisfy every invariant above by never reaching the interesting states.
- L286-294 `test_a_status_shows_up_in_the_fingerprint() -> void` — The fingerprint is only worth comparing if it covers what a later decision depends on. A status that ticks at the end of the round changes the board as much as…
- L297-303 `test_a_pending_skill_bonus_shows_up_in_the_fingerprint() -> void`
- L308-318 `test_the_status_order_does_not_change_the_fingerprint() -> void` — The order two statuses arrived in is not part of the board, so the digest sorts them: two units holding the same badges must fingerprint the same either way.
- L324-328 `test_a_status_at_zero_stacks_is_a_broken_invariant() -> void` — A badge with nothing left on it is a leak, not a state: it would render, and tick, forever. `tick_round_end_statuses` erases a spent duration status, so 0 is un…
- L331-335 `test_a_negative_skill_bonus_is_a_broken_invariant() -> void`
- L340-344 `test_a_unit_without_statuses_reads_as_healthy() -> void` — The two checks above are only meaningful if the healthy case is quiet, and if a statusless unit says so rather than being assumed healthy.
- L349-365 `test_a_roll_is_reproducible_from_its_generator() -> void`
- L373-384 `test_no_shipped_script_reaches_for_the_global_rng() -> void` — The check that keeps this file honest over time: a new global-RNG call in shipped code would break replays without failing any other test, so it fails this one…
- L390-400 `test_every_rng_allowlist_entry_is_still_needed() -> void` — The allowlist is a decision, so it is checked rather than trusted: every entry must name a script that exists and really does use the global RNG. A stale entry…

Private:
- L48-60 `_damage_skill`
- L63-74 `_ally_data`
- L77-91 `_enemy_data`
- L94-98 `_waves`
- L101-110 `_config`
- L115-119 `_fixture_state`
- L123-127 `_simulator`
- L132-134 `_run`
- L140-157 `_sweep_seeds`
- L162-165 `_shipped_scripts`
- L168-179 `_collect_scripts`
- L182-192 `_rng_calls`

Uses: BattleSimulator, DiceRoller, EffectBlock, GameState, SkillData, SkillEffect, Unit, UnitData
Used by: —
Loads: res://GDTest, res://Tools, res://addons, res://reports, res://Trash, res://bin, res://.godot, res://

