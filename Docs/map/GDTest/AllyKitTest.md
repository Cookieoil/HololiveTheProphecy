<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/AllyKitTest.gd` — `class_name AllyKitTest` extends `GdUnitTestSuite`

`250` lines · [back to the map](../../CODEBASE_MAP.md)

> Tests for the MOBA-style pure-skill rework of all ally kits. Covers: shield-slam, hand-scaling, value-positive buff, self-shield cleave, and the corrected Skill…

Sections: Helpers · EffectBlock: CASTER_SHIELD value source · EffectBlock: _add_bonus skips zero values · GameState: get_highest_card_in_hand with exclude · SkillPreviewFormatter: token substitution · SkillPreviewFormatter: build_card_on_ally_data with new kits

Public API:
- L65-71 `test_caster_shield_computes_shield_value() -> void`
- L73-79 `test_caster_shield_zero_shield_returns_zero() -> void`
- L81-86 `test_caster_shield_with_null_caster_returns_zero() -> void`
- L90-99 `test_add_bonus_skips_zero_value_log_spam() -> void`
- L103-113 `test_highest_card_excludes_dragged_card() -> void`
- L117-127 `test_formatter_replaces_caster_shield_token() -> void`
- L129-138 `test_formatter_replaces_highest_card_in_hand_token() -> void`
- L140-150 `test_formatter_replaces_highest_card_excludes_dragged_card() -> void`
- L152-160 `test_formatter_replaces_value_div_add_token() -> void`
- L162-170 `test_formatter_replaces_value_x_n_token() -> void`
- L174-197 `test_build_healer_1_shows_shield_slam_preview() -> void`
- L199-223 `test_build_buff_2_shows_value_positive_preview() -> void`
- L225-248 `test_build_striker_2_shows_shield_category() -> void`

Private:
- L11-12 `_make_enemy_skill`
- L14-22 `_make_ally_data`
- L24-27 `_make_ally`
- L29-53 `_make_effect_block`
- L55-61 `_make_context`

Uses: Card, DataLoader, EffectBlock, GameState, SkillContext, SkillData, SkillEffect, SkillPreviewFormatter, TooltipIconCatalog, Unit, UnitData
Used by: —
Loads: —

