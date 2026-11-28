<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/gen_code_index.gd` extends `SceneTree`

`800` lines · [back to the map](../../CODEBASE_MAP.md)

> Headless symbol-index generator for this repository. Parses every first-party GDScript source and writes the navigation set that replaces reading the sources: D…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L40 `ROOT_DIR: String = "res://"`
- L43 `DEFAULT_DOCS_DIR: String = "res://Docs"` — Default output; `--output-dir` overrides it (the test harness generates into res://reports/ so the committed Docs/ is never touched by a test run).
- L44 `MAP_FILE_NAME: String = "CODEBASE_MAP.md"`
- L45 `SYMBOLS_FILE_NAME: String = "symbols.tsv"`
- L46 `MAP_DIR_NAME: String = "map"`
- L47 `EVENT_BUS_PATH: String = "res://Managers/EventBus.gd"`
- L48 `DATA_JSON_DIR: String = "res://Data/json"`
- L49 `GENERATE_COMMAND: String`
- L50 `ARG_CHECK: String = "--check"`
- L51 `ARG_OUTPUT_DIR: String = "--output-dir"`
- L52 `ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"`
- L55 `SYMBOLS_HEADER: String` — First line of symbols.tsv: names the columns and states the convention.
- L58 `EXCLUDED_DIRS: PackedStringArray = [` — Folders that hold no first-party game code (vendor, scratch, generated output).
- L67 `MAX_REGIONS_LISTED: int = 8` — Only the overview needs a cap; everything else scales with the codebase.

State:
- L71 `_script_paths: PackedStringArray = PackedStringArray()`
- L72 `_scene_paths: PackedStringArray = PackedStringArray()`
- L73 `_infos: Array[Dictionary] = []`
- L74 `_texts: Dictionary = {}`
- L75 `_class_names: PackedStringArray = PackedStringArray()`
- L76 `_check_only: bool = false`
- L77 `_docs_dir: String = DEFAULT_DOCS_DIR`

Private:
- L81-106 `_initialize`
- L111-117 `_read_output_dir`
- L120-121 `_map_path`
- L124-125 `_symbols_path`
- L128-129 `_map_dir`
- L134-143 `_build_artifacts`
- L146-165 `_collect`
- L168-176 `_is_excluded`
- L179-180 `_normalized_text`
- L183-196 `_write_text`
- L199-202 `_matches_artifact`
- L207-215 `_orphan_pages`
- L218-239 `_report_staleness`
- L242-260 `_write_artifacts`
- L264-265 `_script_page_path`
- L269-270 `_scene_page_path`
- L274-276 `_up_to_map_link`
- L280-281 `_map_link`
- L286-296 `_prune_empty_map_dirs`
- L299-311 `_collect_dirs`
- L314-319 `_find_info`
- L322-350 `_render_symbols`
- L353-359 `_append_entry_rows`
- L362-382 `_append_function_rows`
- L385-389 `_symbol_row`
- L392-394 `_append_row`
- L397-409 `_build_used_by`
- L412-413 `_cell`
- L416-419 `_join_paths`
- L422-426 `_compact_regions`
- L431-461 `_collect_global_signals`
- L466-470 `_collect_scenes`
- L473-480 `_collect_data_files`
- L482-515 `_render_map`
- L518-519 `_game_infos`
- L522-523 `_test_infos`
- L526-531 `_infos_with_tests`
- L534-552 `_append_script_table`
- L555-584 `_render_script_page`
- L587-596 `_append_enum_lines`
- L599-608 `_append_inner_class_lines`
- L611-616 `_append_dependencies`
- L621-655 `_render_scene_page`
- L658-674 `_append_declarations`
- L677-689 `_declaration_text`
- L694-730 `_append_functions`
- L733-749 `_append_signal_table`
- L752-773 `_append_scene_table`
- L776-798 `_append_data_table`

Uses: CodeIndexParser
Used by: —
Loads: res://, res://Docs, res://Managers/EventBus.gd, res://Data/json, res://Tools/gen_code_index.gd, res://.godot/, res://reports/, res://Trash/, res://bin/, res://Tools/check_navigation.gd

