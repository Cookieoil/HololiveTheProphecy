<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DiffReviewTest.gd` — `class_name DiffReviewTest` extends `GdUnitTestSuite`

`469` lines · [back to the map](../../CODEBASE_MAP.md)

> Fixture tests for Tools/DiffReviewParser.gd, the pure review layer behind Tools/review_diff.gd. Each fixture is an inline unified diff, so the test never depend…

Public API:
- L111-117 `test_parse_diff_reads_paths_counts_and_lines() -> void`
- L120-123 `test_hunk_start_line_reads_the_new_file_side() -> void`
- L126-130 `test_banned_patterns_are_reported_on_the_added_line() -> void`
- L133-137 `test_a_changed_script_without_its_test_is_flagged() -> void`
- L140-145 `test_an_undocumented_public_function_is_flagged_only_without_a_doc_line() -> void`
- L148-155 `test_core_purity_is_advisory_until_strict() -> void`
- L158-168 `test_a_todo_in_added_code_is_flagged() -> void`
- L172-212 `test_a_quoted_marker_or_a_docs_line_is_not_a_todo() -> void` — The marker naming the rule (and a docs page quoting it) is not a leftover TODO.
- L215-219 `test_markdown_report_lists_the_findings() -> void`
- L223-243 `test_a_banned_pattern_inside_a_string_literal_is_not_flagged() -> void` — A fixture that feeds the parser a banned-looking string is data, not a call.
- L247-257 `test_a_banned_pattern_documented_in_markdown_is_not_flagged() -> void` — Documentation mentions the ban on purpose; only GDScript can call the API.
- L261-271 `test_test_suite_methods_are_not_treated_as_public_api() -> void` — GDScript has no private tests, so a suite's method names are not "new API surface".
- L356-365 `test_review_tier_covers_folders_files_and_measured_fan_in() -> void`
- L382-386 `test_oversize_counts_source_churn_but_not_regenerated_docs() -> void`
- L389-420 `test_a_docs_mention_of_the_flag_registry_is_not_a_feature_gate() -> void`
- L423-427 `test_fan_in_from_map_reads_the_used_by_line() -> void`
- L430-433 `test_blast_radius_follows_the_trunk_rule() -> void`
- L436-439 `test_markdown_report_leads_with_the_blast_radius() -> void`
- L442-448 `test_a_feature_gated_change_is_reported_and_an_unstaged_rollout_is_flagged() -> void`
- L451-459 `test_a_new_test_without_an_assertion_is_flagged_and_promoted_by_strict() -> void`
- L462-468 `test_adversarial_section_names_the_deep_context_and_the_invariants() -> void`

Private:
- L12-20 `_rules`
- L24-32 `_where`
- L35-36 `_review`
- L40-51 `_banned_fixture`
- L54-72 `_game_change_fixture`
- L75-87 `_api_fixture`
- L92-108 `_core_fixture`
- L275-284 `_trunk_fixture`
- L288-297 `_leaf_fixture`
- L301-317 `_tooling_fixture`
- L321-339 `_feature_fixture`
- L343-353 `_test_fixture`
- L369-379 `_bulk_fixture`

Uses: CardUI, CodeIndexParser, DiffReviewParser, FeatureFlags, GameManager, GameState, HandBar, HudTooltip
Used by: —
Loads: —

