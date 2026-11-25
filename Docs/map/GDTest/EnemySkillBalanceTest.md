<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/EnemySkillBalanceTest.gd` — `class_name EnemySkillBalanceTest` extends `GdUnitTestSuite`

`169` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the enemy-skill balance pass: - an enemy threshold matches the parity of the slot it sits in (an Odd skill can never be gated on an even number like 6, wh…

Sections: Helpers · Threshold parity · Dice curve & survivability · Tooltip resolution · Dead-caster guard

Public API:
- L53-60 `test_enemy_thresholds_match_their_slot_parity() -> void`
- L62-68 `test_normal_enemy_odd_gate_is_reachable_on_turn_one() -> void`
- L72-82 `test_dice_progression_is_smooth() -> void`
- L86-97 `test_shielded_ally_survives_one_max_single_target_hit() -> void` — The weakest ally must survive one maximum single-target hit *while shielded*. Being unshielded is the risk the player is expected to answer with Shield.
- L100-110 `test_boss_aoe_hit_stays_below_weakest_ally_hp() -> void` — The AoE boss skill halves the roll, so it can never wipe a full-HP team either.
- L116-132 `test_all_skill_tooltips_resolve_without_raw_tokens() -> void` — Every enemy (and ally) description must resolve to plain prose: no raw [Value ...] / [.. Shield] tokens may survive the formatter.
- L136-150 `test_dead_caster_stops_remaining_effects() -> void`
- L152-168 `test_living_caster_still_fires_effects() -> void`

Private:
- L15-16 `_db`
- L18-28 `_make_ally`
- L30-39 `_make_enemy`
- L42-49 `_as_int`

Uses: Card, DataLoader, EffectBlock, GameDatabase, GameState, SkillContext, SkillData, SkillPreviewFormatter, Unit, UnitData
Used by: —
Loads: —

