<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/check_navigation.gd` extends `SceneTree`

`773` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L46 `DECLARATION_PREFIXES: Array[Array] = [` — The column-0 declarations the oracle recognises, as `[prefix, kind]`. A table rather than a ladder because this is an independent second opinion on the parser:…
- L57 `ANNOTATED_VAR_PREFIXES: PackedStringArray = ["@export", "@onready"]` — The two annotations that can carry a declaration (`@export var x` / `@onready var x`).
- L58 `ARG_BENCHMARK: String = "--benchmark"`
- L59 `ARG_CHECK: String = "--check"`
- L60 `ARG_OUTPUT_DIR: String = "--output-dir"`
- L61 `ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"`
- L63 `MAP_MAX_LINES: int = 200` — The overview is the file a reader opens first, so it has a hard size budget.
- L64 `MAP_MAX_BYTES: int = 24000`
- L65 `MAX_REPORTED_FAILURES: int = 20`

State:
- L69 `_failures: PackedStringArray = PackedStringArray()`
- L70 `_checks: int = 0`

Private:
- L74-88 `_initialize`
- L92-100 `_check`
- L103-111 `_report`
- L114-115 `_read`
- L118-119 `_read_lines`
- L122-144 `_collect`
- L149-156 `_tree_fingerprints`
- L160-178 `_check_committed_artifacts`
- L182-209 `_parse_symbol_rows`
- L213-229 `_parse_location`
- L232-260 `_check_rows_are_valid`
- L264-277 `_check_lookup_recipes`
- L280-285 `_rows_named`
- L288-292 `_join`
- L296-316 `_check_declaration_coverage`
- L320-327 `_is_indexed`
- L332-346 `_scan_declarations`
- L350-358 `_declaration_rest`
- L363-368 `_declaration_kind`
- L371-396 `_check_links`
- L400-415 `_extract_links`
- L419-427 `_resolve_relative`
- L431-450 `_check_scenes`
- L453-462 `_scan_node_names`
- L466-489 `_check_signal_table`
- L492-496 `_signal_row`
- L500-525 `_check_data_table`
- L530-557 `_run_isolated_generation_tests`
- L561-574 `_expect_generator`
- L577-578 `_project_dir`
- L581-587 `_first_page`
- L590-591 `_append_text`
- L594-603 `_write_text`
- L606-617 `_remove_dir`
- L620-632 `_collect_dirs`
- L636-638 `_check_committed_docs_untouched`
- L644-666 `_run_benchmark`
- L669-710 `_benchmark_tasks`
- L713-714 `_whole`
- L718-719 `_grep`
- L723-731 `_row_range`
- L736-746 `_used_by_files`
- L749-771 `_measure`

Uses: CodeIndexParser
Used by: —
Loads: res://Docs/CODEBASE_MAP.md, res://Docs/symbols.tsv, res://Docs/map, res://Tools/gen_code_index.gd, res://, res://Data/json, res://Managers/EventBus.gd, res://reports/navigation-test, res://.godot/, res://reports/, res://Trash/, res://bin/, res://Docs, res://Docs/, res://Core/Card.gd, res://Managers/GameManager.gd, res://Scenes/Cards/CardUI.gd, res://Scenes/Cards/CardUI.tscn, res://Scenes/HUD/BattleOverlayController.gd, res://Scenes/BattleScene/BattleScene.tscn

