<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/EnemySkillBalanceTest.gd` — `class_name EnemySkillBalanceTest` extends `GdUnitTestSuite`

`269` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the enemy-skill balance pass: - an enemy threshold matches the parity of the slot it sits in (an Odd skill can never be gated on an even number like 6, wh…

Sections: Helpers · Threshold parity · Dice curve & survivability · Tooltip resolution · Dead-caster guard · Target-cache preservation · No stray brackets

Public API:
- L60-67 `test_enemy_thresholds_match_their_slot_parity() -> void`
- L69-75 `test_normal_enemy_odd_gate_is_reachable_on_turn_one() -> void`
- L79-89 `test_dice_progression_is_smooth() -> void`
- L93-104 `test_shielded_ally_survives_one_max_single_target_hit() -> void` — The weakest ally must survive one maximum single-target hit *while shielded*. Being unshielded is the risk the player is expected to answer with Shield.
- L107-117 `test_boss_aoe_hit_stays_below_weakest_ally_hp() -> void` — The AoE boss skill halves the roll, so it can never wipe a full-HP team either.
- L123-139 `test_all_skill_tooltips_resolve_without_raw_tokens() -> void` — Every enemy (and ally) description must resolve to plain prose: no raw [Value ...] / [.. Shield] tokens may survive the formatter.
- L143-157 `test_dead_caster_stops_remaining_effects() -> void`
- L159-175 `test_living_caster_still_fires_effects() -> void`
- L182-222 `test_utility_block_preserves_cached_targets() -> void` — Reproduces the merged healer_1 / buff_1 order: pick an enemy, run a utility block (target_mode none), then deal cached damage. The utility block must not erase…
- L225-247 `test_bonus_before_cached_damage_still_applies() -> void` — The add_bonus fix-up must still reach the damage block when it adds value.
- L253-268 `test_no_stray_brackets_after_substitution() -> void` — After substitution every description must be plain prose once the BBCode is stripped: a leftover token like "[13 (+5 from highest card)]" fails here.

Private:
- L15-16 `_db`
- L18-28 `_make_ally`
- L30-39 `_make_enemy`
- L42-49 `_as_int`
- L52-55 `_strip_bbcode`

Uses: Card, DataLoader, EffectBlock, GameDatabase, GameState, SkillContext, SkillData, SkillPreviewFormatter, Unit, UnitData
Used by: —
Loads: —

