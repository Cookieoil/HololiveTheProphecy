<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/gen_code_index.gd` extends `SceneTree`

`1466` lines · [back to the map](../../CODEBASE_MAP.md)

> Headless symbol-index generator for this repository. Parses every first-party GDScript source and writes the navigation set that replaces reading the sources: D…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L34 `ROOT_DIR: String = "res://"`
- L35 `MAP_PATH: String = "res://Docs/CODEBASE_MAP.md"`
- L36 `SYMBOLS_PATH: String = "res://Docs/symbols.tsv"`
- L37 `MAP_DIR: String = "res://Docs/map"`
- L39 `TEST_DIR_PREFIX: String = "GDTest/"` — Tests live here; they get their own overview table so game code stays visible.
- L40 `EVENT_BUS_PATH: String = "res://Managers/EventBus.gd"`
- L41 `DATA_JSON_DIR: String = "res://Data/json"`
- L42 `GENERATE_COMMAND: String`
- L43 `ARG_CHECK: String = "--check"`
- L44 `ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"`
- L47 `SYMBOLS_HEADER: String` — First line of Docs/symbols.tsv: names the columns and states the convention.
- L50 `EXCLUDED_DIRS: PackedStringArray = [` — Folders that hold no first-party game code (vendor, scratch, generated output).
- L59 `MAX_ITEM_KEYS: int = 24` — Caps that keep the generated artifacts cheap to read.
- L60 `MAX_REGIONS_LISTED: int = 8`
- L61 `MAX_DOC_CHARS: int = 160`
- L62 `MAX_REFS_LISTED: int = 20`
- L63 `HEADER_SCAN_LINES: int = 40`
- L64 `KEY_COLLECT_DEPTH: int = 3`

State:
- L68 `_script_paths: PackedStringArray = PackedStringArray()`
- L69 `_scene_paths: PackedStringArray = PackedStringArray()`
- L70 `_infos: Array[Dictionary] = []`
- L71 `_texts: Dictionary = {}`
- L72 `_class_names: PackedStringArray = PackedStringArray()`
- L73 `_check_only: bool = false`

Private:
- L77-100 `_initialize`
- L106-115 `_build_artifacts`
- L118-137 `_collect`
- L140-144 `_is_excluded`
- L147-149 `_normalized_text`
- L152-155 `_repo_path`
- L158-171 `_write_text`
- L174-177 `_matches_artifact`
- L182-190 `_orphan_pages`
- L193-214 `_report_staleness`
- L217-235 `_write_artifacts`
- L239-240 `_script_page_path`
- L244-245 `_scene_page_path`
- L249-251 `_up_to_map_link`
- L255-256 `_map_link`
- L261-271 `_prune_empty_map_dirs`
- L274-286 `_collect_dirs`
- L292-435 `_parse_script`
- L441-451 `_function_end`
- L457-469 `_header_end_index`
- L474-484 `_has_declaration_before`
- L487-496 `_header_summary`
- L499-500 `_doc_text`
- L504-514 `_join_doc`
- L517-522 `_leading_identifier`
- L525-532 `_is_identifier_char`
- L536-544 `_extract_between`
- L549-550 `_attribute`
- L553-566 `_parse_signal`
- L569-595 `_parse_function`
- L599-622 `_parse_named_declaration`
- L627-649 `_parse_enum`
- L652-664 `_enum_values`
- L668-679 `_signature_complete`
- L682-683 `_is_resource_path_char`
- L687-701 `_contains_word`
- L704-709 `_find_info`
- L714-726 `_apply_dependencies`
- L729-743 `_scan_resource_refs`
- L748-776 `_render_symbols`
- L779-785 `_append_entry_rows`
- L788-808 `_append_function_rows`
- L811-815 `_symbol_row`
- L818-820 `_append_row`
- L824-836 `_declaration_detail`
- L840-852 `_build_used_by`
- L855-860 `_dict_string`
- L863-871 `_dict_int`
- L874-879 `_dict_array`
- L882-893 `_dict_string_array`
- L897-898 `_cell`
- L901-904 `_join_paths`
- L907-911 `_compact_regions`
- L916-946 `_collect_global_signals`
- L951-1013 `_collect_scenes`
- L1018-1023 `_node_depth`
- L1027-1056 `_collect_data_files`
- L1061-1074 `_collect_keys`
- L1078-1082 `_keys_of`
- L1085-1095 `_finalize_keys`
- L1100-1141 `_render_map`
- L1144-1145 `_game_infos`
- L1148-1149 `_test_infos`
- L1152-1157 `_infos_with_tests`
- L1160-1178 `_append_script_table`
- L1183-1198 `_script_role`
- L1203-1232 `_render_script_page`
- L1235-1244 `_append_enum_lines`
- L1247-1256 `_append_inner_class_lines`
- L1259-1264 `_append_dependencies`
- L1269-1303 `_render_scene_page`
- L1307-1312 `_line_range`
- L1315-1331 `_append_declarations`
- L1334-1346 `_declaration_text`
- L1351-1387 `_append_functions`
- L1390-1395 `_dict_bool`
- L1399-1415 `_append_signal_table`
- L1418-1439 `_append_scene_table`
- L1442-1464 `_append_data_table`

Uses: BattleScene, Card, Unit, UnitUI
Used by: —
Loads: res

