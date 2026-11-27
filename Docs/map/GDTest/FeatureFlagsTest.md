<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/FeatureFlagsTest.gd` — `class_name FeatureFlagsTest` extends `GdUnitTestSuite`

`260` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the feature-flag registry (Core/FeatureFlags.gd): deterministic bucketing, the precedence order, and the rule that an unknown flag is always off.

Constants:
- L9 `SHIPPED_PATH: String = "res://Data/json/features.json"`

Public API:
- L58-61 `test_the_shipped_features_file_is_valid() -> void`
- L64-68 `test_bucketing_is_deterministic_and_in_range() -> void`
- L71-78 `test_a_flag_spreads_across_buckets() -> void`
- L81-90 `test_precedence_override_then_kill_switch_then_rollout() -> void`
- L93-97 `test_an_unknown_flag_is_off() -> void`
- L100-105 `test_a_half_rollout_is_on_for_roughly_half_the_seeds() -> void`
- L108-121 `test_a_malformed_registry_reports_every_problem() -> void`
- L124-130 `test_evaluate_reports_flags_in_name_order() -> void`
- L135-147 `test_a_typoed_key_is_rejected_instead_of_defaulting_to_full_rollout() -> void` — The typo trap this guard exists for: `rollout_pct` would otherwise read as "rollout_percent unset", and unset means 100% - a 5% canary shipping to everyone.
- L173-185 `test_an_unreadable_rollout_percent_fails_closed() -> void` — A value nobody can read must never become a full rollout: the fallback for a broken `rollout_percent` is off, not everyone (it used to fall back to 100%).
- L188-195 `test_a_valid_rollout_percent_is_kept() -> void`
- L200-215 `test_a_run_can_flip_a_flag_through_the_debug_tool() -> void` — The tester tool path: a flag flipped mid-run re-resolves through the same code the setup path uses, and an unknown name is refused instead of invented.
- L219-228 `test_an_override_beats_the_rollout() -> void` — An override is the highest precedence, so it wins over a rollout of zero.
- L232-237 `test_a_run_without_flags_reports_nothing() -> void` — A run with no flags still reports an empty registry rather than failing.
- L240-247 `test_an_unknown_top_level_key_is_rejected() -> void`
- L250-259 `test_a_non_string_description_is_rejected() -> void`

Private:
- L13-22 `_state_with_flags`
- L25-55 `_definitions`
- L152-168 `_stored_percent`

Uses: FeatureFlags, GameState
Used by: —
Loads: res://Data/json/features.json

