<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/AllyKitTest.gd` — `class_name AllyKitTest` extends `GdUnitTestSuite`

`274` lines · [back to the map](../../CODEBASE_MAP.md)

> Tests for the MOBA-style pure-skill rework of all ally kits. Covers: shield-slam, hand-scaling, value-positive buff, self-shield cleave, and the corrected Skill…

Sections: Helpers · EffectBlock: CASTER_SHIELD value source · EffectBlock: _add_bonus skips zero values · GameState: get_highest_card_in_hand with exclude · SkillPreviewFormatter: token substitution · SkillPreviewFormatter: build_card_on_ally_data with new kits

Public API:
- L65-71 `test_caster_shield_computes_shield_value() -> void`
- L73-79 `test_caster_shield_zero_shield_returns_zero() -> void`
- L81-86 `test_caster_shield_with_null_caster_returns_zero() -> void`
- L90-99 `test_add_bonus_skips_zero_value_log_spam() -> void`
- L103-113 `test_highest_card_excludes_dragged_card() -> void`
- L117-128 `test_formatter_replaces_shield_token_with_clean_number() -> void`
- L130-138 `test_formatter_shield_token_teaches_the_rule_at_zero_shield() -> void`
- L140-150 `test_formatter_replaces_highest_card_token_with_clean_number() -> void`
- L152-160 `test_formatter_highest_card_token_teaches_the_rate_at_zero() -> void`
- L162-172 `test_formatter_highest_card_token_excludes_dragged_card() -> void`
- L174-183 `test_formatter_replaces_div_add_token_with_clean_number() -> void`
- L185-194 `test_formatter_replaces_multiply_token_with_clean_number() -> void`
- L198-221 `test_build_healer_1_shows_shield_slam_preview() -> void`
- L223-247 `test_build_buff_2_shows_value_positive_preview() -> void`
- L249-272 `test_build_striker_2_shows_shield_category() -> void`

Private:
- L11-12 `_make_enemy_skill`
- L14-22 `_make_ally_data`
- L24-27 `_make_ally`
- L29-53 `_make_effect_block`
- L55-61 `_make_context`

Uses: Card, DataLoader, EffectBlock, GameState, SkillContext, SkillData, SkillEffect, SkillPreviewFormatter, TooltipIconCatalog, Unit, UnitData
Used by: —
Loads: —

