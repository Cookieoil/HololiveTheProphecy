<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/dataBuilder.gd` — `class_name DataBuilder` extends `RefCounted`

`867` lines · [back to the map](../../CODEBASE_MAP.md)

> Converts the bulk-entry workbook (res://Data/xlsx/game_data.xlsx) into the JSON files stored in res://Data/json/. Those JSON files are the single source of trut…

Sections: Constants · Public Variables · Public Methods · Private Methods

Constants:
- L25 `DEFAULT_XLSX_PATH: String = "res://Data/xlsx/game_data.xlsx"`
- L26 `DEFAULT_JSON_DIR: String = "res://Data/json"`
- L27 `JSON_INDENT: String = "\t"`
- L28 `HEADER_SCAN_ROWS: int = 10`
- L29 `DEFAULT_MAX_MOXIE: int = 20`
- L31 `SKILLS_FILE: String = "skills.json"`
- L32 `ALLIES_FILE: String = "allies.json"`
- L33 `ENEMIES_FILE: String = "enemies.json"`
- L34 `WAVES_FILE: String = "waves.json"`
- L35 `CONFIG_FILE: String = "config.json"`
- L37 `REQUIRED_SHEETS: PackedStringArray = [`
- L40 `VALID_TRIGGERS: PackedStringArray = ["base", "merged"]`
- L41 `UNIT_SKILL_SLOTS: PackedStringArray = ["skill_1", "skill_2", "ultimate"]`
- L44 `JSON_FILE_KEYS: Dictionary = {` — Emitted JSON file -> key inside the bundle returned by build_json_bundle().
- L54 `SKILL_DEFAULTS: Dictionary = {` — Field order and fallback value used when emitting each JSON object. Keeping the order stable keeps hand/AI edits readable.
- L64 `EFFECT_DEFAULTS: Dictionary = {`
- L86 `UNIT_DEFAULTS: Dictionary = {`

State:
- L99 `errors: PackedStringArray = []` — Blocking problems found while reading the workbook. Export stops when set.
- L101 `warnings: PackedStringArray = []` — Non-blocking notes (duplicate ids, skipped files, ...).

Public API:
- L107-151 `build_json_bundle(sheets: Dictionary) -> Dictionary` — Builds every JSON payload from already-read worksheet grids.
- L160-177 `export_xlsx_to_json(xlsx_path: String = DEFAULT_XLSX_PATH, out_dir: String = DEFAULT_JSON_DIR, overwrite_existing: bool = true) -> Error` — Reads the workbook, validates it and writes the five JSON files. fresh checkout bootstraps data without clobbering hand/AI edits

Private:
- L182-207 `_write_bundle`
- L211-218 `_empty_bundle`
- L222-227 `_grid`
- L230-251 `_read_enums`
- L255-264 `_find_first_dense_row`
- L268-277 `_find_header_row`
- L281-297 `_parse_spec`
- L301-308 `_row_at`
- L312-328 `_to_int`
- L332-349 `_to_bool`
- L352-372 `_parse_table`
- L378-390 `_parse_column_specs`
- L395-400 `_primary_key_of`
- L405-431 `_parse_table_row`
- L436-451 `_warn_duplicate_id`
- L455-471 `_coerce`
- L475-480 `_cell_text`
- L485-492 `_coerce_int`
- L495-500 `_coerce_float`
- L503-510 `_coerce_bool`
- L516-529 `_coerce_list`
- L533-539 `_coerce_enum_or_unknown`
- L543-544 `_has_enum`
- L548-555 `_enum_contains`
- L560-570 `_ordered_record`
- L574-575 `_row_number`
- L577-587 `_read_skills`
- L593-626 `_read_effects`
- L631-653 `_attach_effects`
- L658-681 `_read_units`
- L684-720 `_read_waves`
- L724-741 `_read_config`
- L745-750 `_find_config_header`
- L756-777 `_normalise_config_allies`
- L780-797 `_parse_config_value`
- L801-812 `_scalar`
- L818-825 `_format_json_value`
- L828-837 `_format_json_object`
- L840-853 `_format_json_array`
- L857-866 `_is_inline_array`

Uses: XlsxReader
Used by: Tools/GameDataValidator.gd, Tools/export_xlsx_to_json.gd, Tools/validate_gameData.gd
Loads: res://Data/xlsx/game_data.xlsx, res://Data/json

