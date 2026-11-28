<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/GameDataValidatorTest.gd` — `class_name GameDataValidatorTest` extends `GdUnitTestSuite`

`782` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks every rule the game-data gate enforces (Tools/validate_gameData.gd). The validator had no test of its own, so the only thing standing behind it was the ha…

Sections: Fixtures · Helpers · The anchor · Scalars and types · Effect structure · Effect numbers · Targeting, cards and statuses · Cross-effect and cross-file rules · (+4 more)

Public API:
- L189-193 `test_the_valid_bundle_is_clean() -> void` — If this fails, every "X is an error" assertion below it is meaningless: a bundle that is already dirty would satisfy them for the wrong reason.
- L198-207 `test_a_second_run_starts_from_a_clean_slate() -> void` — And the seam itself is idempotent: a second run over a dirty bundle must not accumulate the first run's diagnostics.
- L212-215 `test_a_boolean_where_a_number_belongs_is_an_error() -> void`
- L218-221 `test_a_fractional_number_is_an_error() -> void`
- L226-230 `test_a_numeric_string_is_a_warning_not_an_error() -> void` — A quoted number is almost always an authoring slip, but the value is usable, so it warns rather than blocks.
- L233-236 `test_an_unknown_key_is_a_warning() -> void`
- L239-244 `test_a_non_object_skill_entry_is_an_error() -> void`
- L247-250 `test_a_non_string_display_name_is_an_error() -> void`
- L257-265 `test_a_missing_required_effect_key_is_an_error() -> void` — DataLoader falls back to a default for a missing key, so an absent `action` would silently become `deal_damage` instead of failing.
- L268-271 `test_an_unknown_enum_value_is_an_error() -> void`
- L274-277 `test_an_invalid_trigger_is_an_error() -> void`
- L280-283 `test_a_duplicate_effect_id_inside_a_skill_is_an_error() -> void`
- L288-294 `test_a_duplicate_effect_id_across_skills_is_a_warning() -> void` — Across skills it is only a warning: the ids are global bookkeeping, not a rule the runtime enforces.
- L297-300 `test_a_duplicate_order_in_the_same_trigger_is_a_warning() -> void`
- L303-306 `test_a_negative_order_is_an_error() -> void`
- L311-314 `test_a_divisor_below_one_is_an_error() -> void`
- L317-320 `test_a_negative_multiplier_is_an_error() -> void`
- L323-326 `test_a_value_cap_below_minus_one_is_an_error() -> void`
- L329-332 `test_a_zero_value_cap_is_a_warning() -> void`
- L335-338 `test_a_negative_target_count_is_an_error() -> void`
- L341-344 `test_an_oversized_target_count_is_a_warning() -> void`
- L349-352 `test_a_targeted_action_without_a_target_mode_is_an_error() -> void`
- L355-358 `test_a_pick_n_mode_without_a_count_is_an_error() -> void`
- L361-364 `test_a_count_the_target_mode_ignores_is_a_warning() -> void`
- L367-372 `test_a_card_action_without_a_card_count_is_an_error() -> void`
- L375-378 `test_a_card_action_ignoring_unit_targets_is_a_warning() -> void`
- L381-384 `test_apply_status_with_an_unknown_status_is_an_error() -> void`
- L387-390 `test_apply_status_with_an_empty_status_is_an_error() -> void`
- L393-396 `test_a_status_id_outside_apply_status_is_a_warning() -> void`
- L399-402 `test_negating_a_none_condition_is_a_warning() -> void`
- L405-408 `test_a_fixed_value_action_with_no_amount_is_a_warning() -> void`
- L411-414 `test_a_negative_fixed_amount_is_a_warning() -> void`
- L420-423 `test_cached_targeting_without_a_producer_is_a_warning() -> void` — `cached` reads a target a previous effect cached; without a producer it reads nothing.
- L426-429 `test_stored_value_without_a_producer_is_a_warning() -> void`
- L432-437 `test_an_unreferenced_skill_is_a_warning() -> void`
- L442-447 `test_an_enemy_skill_with_merged_effects_and_no_threshold_is_a_warning() -> void` — An enemy skill with merged effects and no threshold can never reach them: EnemyIntent marks the merge condition from the roll.
- L450-453 `test_an_ally_skill_with_a_threshold_is_a_warning() -> void`
- L456-459 `test_merged_mode_or_without_merged_effects_is_a_warning() -> void`
- L462-465 `test_a_merged_effect_without_a_description_is_a_warning() -> void`
- L468-471 `test_an_unknown_card_category_is_a_warning() -> void`
- L476-479 `test_max_hp_below_one_is_an_error() -> void`
- L482-485 `test_max_moxie_below_one_is_an_error() -> void`
- L489-492 `test_an_is_enemy_mismatch_is_an_error() -> void` — The file the unit lives in decides `is_enemy`, so a contradicting field is a bug.
- L495-501 `test_a_missing_is_enemy_is_a_warning() -> void`
- L504-507 `test_a_unit_referencing_an_unknown_skill_is_an_error() -> void`
- L510-513 `test_a_unit_with_no_usable_skill_is_an_error() -> void`
- L518-523 `test_a_unit_id_in_both_files_is_an_error() -> void` — The two files share one `units` registry in GameDatabase, so the same id in both silently drops one of them.
- L526-531 `test_a_non_snake_case_unit_id_is_a_warning() -> void`
- L536-539 `test_an_empty_wave_is_an_error() -> void`
- L542-549 `test_a_wave_without_an_enemies_key_is_an_error() -> void`
- L552-555 `test_a_wave_spawning_an_ally_is_an_error() -> void`
- L558-561 `test_a_wave_spawning_an_unknown_unit_is_an_error() -> void`
- L564-573 `test_a_wave_hp_override_below_one_is_an_error() -> void`
- L578-581 `test_a_wave_index_mismatch_is_a_warning() -> void` — DataLoader uses array order, so a mismatched index means the author's intent and the game's behaviour disagree.
- L586-589 `test_hand_size_below_one_is_an_error() -> void`
- L592-595 `test_an_empty_decklist_is_an_error() -> void`
- L598-601 `test_a_decklist_pair_with_the_wrong_arity_is_an_error() -> void`
- L604-607 `test_a_decklist_value_below_one_is_an_error() -> void`
- L610-613 `test_a_decklist_count_below_one_is_an_error() -> void`
- L616-619 `test_a_deck_smaller_than_a_starting_hand_is_a_warning() -> void`
- L622-625 `test_an_empty_dice_progression_is_an_error() -> void`
- L628-631 `test_a_dice_size_below_one_is_an_error() -> void`
- L634-637 `test_a_dice_progression_that_shrinks_is_a_warning() -> void`
- L640-643 `test_a_duplicate_starting_ally_is_an_error() -> void`
- L646-649 `test_an_enemy_as_a_starting_ally_is_an_error() -> void`
- L652-655 `test_an_unknown_starting_ally_is_an_error() -> void`
- L658-661 `test_an_unknown_wave_transition_mode_is_an_error() -> void`
- L718-723 `test_the_diagnostic_file_maps_a_message_to_its_repo_path() -> void`
- L727-731 `test_a_diagnostic_that_names_no_file_has_no_path() -> void` — A loader failure names no file, so it must not be attributed to one.
- L734-743 `test_the_diagnostic_line_locates_a_skill_and_its_effect() -> void`
- L746-756 `test_the_diagnostic_line_locates_a_unit_and_a_wave() -> void`
- L759-765 `test_the_diagnostic_line_locates_a_config_key() -> void`
- L768-780 `test_the_step_summary_reports_the_result_and_the_counts() -> void`

Private:
- L20-43 `_effect`
- L48-60 `_skill`
- L63-74 `_unit`
- L79-97 `_valid_bundle`
- L103-106 `_report`
- L109-110 `_errors`
- L113-114 `_warnings`
- L117-122 `_lines`
- L125-129 `_has`
- L132-137 `_with_skill`
- L140-145 `_with_ally`
- L148-152 `_with_config`
- L155-161 `_with_wave`
- L165-172 `_with_effect`
- L176-182 `_with_extra_effect`
- L667-682 `_skills_text`
- L686-693 `_units_text`
- L697-706 `_waves_text`
- L710-714 `_config_text`

Uses: GameDataValidatorRunner, ValidationReporter
Used by: —
Loads: res://Data/json/skills.json, res://Data/json/allies.json, res://Data/json/waves.json, res://Data/json/config.json

