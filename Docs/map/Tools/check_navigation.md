<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/check_navigation.gd` extends `SceneTree`

`763` lines · [back to the map](../../CODEBASE_MAP.md)

> Test harness for the generated navigation set in Docs/. Two jobs: 1. Verify the committed artifacts against the sources with independent scans (coverage, ranges…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L25 `MAP_PATH: String = "res://Docs/CODEBASE_MAP.md"`
- L26 `SYMBOLS_PATH: String = "res://Docs/symbols.tsv"`
- L27 `MAP_DIR: String = "res://Docs/map"`
- L28 `GENERATOR_PATH: String = "res://Tools/gen_code_index.gd"`
- L29 `GENERATE_COMMAND: String`
- L30 `ROOT_DIR: String = "res://"`
- L31 `DATA_JSON_DIR: String = "res://Data/json"`
- L32 `EVENT_BUS_PATH: String = "res://Managers/EventBus.gd"`
- L33 `TEST_OUT_DIR: String = "res://reports/navigation-test"`
- L34 `EXCLUDED_DIRS: PackedStringArray = [`
- L41 `KINDS: PackedStringArray`
- L42 `ARG_BENCHMARK: String = "--benchmark"`
- L43 `ARG_CHECK: String = "--check"`
- L44 `ARG_OUTPUT_DIR: String = "--output-dir"`
- L45 `ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"`
- L47 `MAP_MAX_LINES: int = 200` — The overview is the file a reader opens first, so it has a hard size budget.
- L48 `MAP_MAX_BYTES: int = 24000`
- L49 `MAX_REPORTED_FAILURES: int = 20`

State:
- L53 `_failures: PackedStringArray = PackedStringArray()`
- L54 `_checks: int = 0`

Private:
- L58-72 `_initialize`
- L76-84 `_check`
- L87-95 `_report`
- L98-99 `_read`
- L102-103 `_read_lines`
- L106-128 `_collect`
- L133-140 `_tree_fingerprints`
- L144-162 `_check_committed_artifacts`
- L166-193 `_parse_symbol_rows`
- L197-213 `_parse_location`
- L216-244 `_check_rows_are_valid`
- L248-261 `_check_lookup_recipes`
- L264-269 `_rows_named`
- L272-276 `_join`
- L280-300 `_check_declaration_coverage`
- L304-311 `_is_indexed`
- L316-358 `_scan_declarations`
- L361-386 `_check_links`
- L390-405 `_extract_links`
- L409-417 `_resolve_relative`
- L421-440 `_check_scenes`
- L443-452 `_scan_node_names`
- L456-479 `_check_signal_table`
- L482-486 `_signal_row`
- L490-515 `_check_data_table`
- L520-547 `_run_isolated_generation_tests`
- L551-564 `_expect_generator`
- L567-568 `_project_dir`
- L571-577 `_first_page`
- L580-581 `_append_text`
- L584-593 `_write_text`
- L596-607 `_remove_dir`
- L610-622 `_collect_dirs`
- L626-628 `_check_committed_docs_untouched`
- L634-656 `_run_benchmark`
- L659-700 `_benchmark_tasks`
- L703-704 `_whole`
- L708-709 `_grep`
- L713-721 `_row_range`
- L726-736 `_used_by_files`
- L739-761 `_measure`

Uses: CodeIndexParser
Used by: —
Loads: res://Docs/CODEBASE_MAP.md, res://Docs/symbols.tsv, res://Docs/map, res://Tools/gen_code_index.gd, res://, res://Data/json, res://Managers/EventBus.gd, res://reports/navigation-test, res://.godot/, res://reports/, res://Trash/, res://bin/, res://Docs, res://Docs/, res://Core/Card.gd, res://Managers/GameManager.gd, res://Scenes/Cards/CardUI.gd, res://Scenes/Cards/CardUI.tscn, res://Scenes/HUD/BattleOverlayController.gd, res://Scenes/BattleScene/BattleScene.tscn

