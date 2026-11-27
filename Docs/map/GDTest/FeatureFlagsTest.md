<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/FeatureFlagsTest.gd` — `class_name FeatureFlagsTest` extends `GdUnitTestSuite`

`118` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the feature-flag registry (Core/FeatureFlags.gd): deterministic bucketing, the precedence order, and the rule that an unknown flag is always off.

Constants:
- L9 `SHIPPED_PATH: String = "res://Data/json/features.json"`

Public API:
- L45-48 `test_the_shipped_features_file_is_valid() -> void`
- L51-55 `test_bucketing_is_deterministic_and_in_range() -> void`
- L58-65 `test_a_flag_spreads_across_buckets() -> void`
- L68-77 `test_precedence_override_then_kill_switch_then_rollout() -> void`
- L80-84 `test_an_unknown_flag_is_off() -> void`
- L87-92 `test_a_half_rollout_is_on_for_roughly_half_the_seeds() -> void`
- L95-108 `test_a_malformed_registry_reports_every_problem() -> void`
- L111-117 `test_evaluate_reports_flags_in_name_order() -> void`

Private:
- L12-42 `_definitions`

Uses: FeatureFlags
Used by: —
Loads: res://Data/json/features.json

