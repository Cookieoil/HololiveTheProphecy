<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DiffReviewTest.gd` — `class_name DiffReviewTest` extends `GdUnitTestSuite`

`656` lines · [back to the map](../../CODEBASE_MAP.md)

> Fixture tests for the review layer behind Tools/review_diff.gd: the rules in Tools/DiffReviewParser.gd and the rendering in Tools/DiffReviewFormatter.gd. Each f…

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
- L444-459 `test_a_blank_line_inside_a_new_test_does_not_hide_its_assertion() -> void` — A blank line between arrange and act must not be read as the end of the test: every suite here writes it that way, and the rule is blocking under --strict.
- L463-476 `test_a_wrapped_test_signature_still_finds_its_assertion() -> void` — A wrapped signature keeps the body open until the `:` closes it.
- L480-491 `test_a_comment_mentioning_assert_does_not_count_as_an_assertion() -> void` — A test whose only mention of the word is a comment still cannot fail.
- L496-514 `test_an_empty_test_does_not_borrow_the_next_tests_assertion() -> void` — Two tests added back to back: the first one's empty body must not borrow the second one's assertion.
- L524-530 `test_adversarial_section_names_the_deep_context_and_the_invariants() -> void`
- L534-537 `test_a_collapsible_adversarial_brief_is_wrapped_in_details() -> void` — The brief is collapsed in the pull-request comment so the report stays a screenful.
- L542-547 `test_fan_in_counts_runtime_dependents_only() -> void` — Only what ships decides the fan-in: otherwise adding unit tests to an isolated leaf widget would promote it to trunk and demand a line-by-line read of a HUD too…
- L552-557 `test_a_scene_or_shader_change_asks_for_visual_proof() -> void` — A flagged change that touches scenes or shaders needs the rendered snapshot: the headless gates rasterise nothing.
- L562-577 `test_the_report_caps_its_finding_list() -> void` — A report longer than the cap is cut with a footer, not dumped: the reviewer exists to lower review cost.
- L581-591 `test_a_comment_naming_the_flag_api_is_not_a_feature_gate() -> void` — A note-to-self that names a flag is prose: only a real read counts as a gate.
- L595-605 `test_a_banned_pattern_in_a_comment_is_not_flagged() -> void` — Documenting a ban in a comment is not a call to the banned API.
- L610-635 `test_unstaged_rollout_is_judged_per_flag() -> void` — Each enabled flag is judged on its own rollout, so a second one cannot hide behind the first, and a staged value already on an unchanged line still counts as st…
- L638-644 `test_a_feature_gated_change_is_reported_and_an_unstaged_rollout_is_flagged() -> void`
- L647-655 `test_a_new_test_without_an_assertion_is_flagged_and_promoted_by_strict() -> void`

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
- L517-521 `_finding_of`

Uses: CodeIndexParser, DiffReviewFormatter, DiffReviewParser
Used by: —
Loads: —

