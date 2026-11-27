<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DiffReviewTest.gd` — `class_name DiffReviewTest` extends `GdUnitTestSuite`

`272` lines · [back to the map](../../CODEBASE_MAP.md)

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

Private:
- L12-20 `_rules`
- L24-32 `_where`
- L35-36 `_review`
- L40-51 `_banned_fixture`
- L54-72 `_game_change_fixture`
- L75-87 `_api_fixture`
- L92-108 `_core_fixture`

Uses: CodeIndexParser, DiffReviewParser, GameManager
Used by: —
Loads: —

