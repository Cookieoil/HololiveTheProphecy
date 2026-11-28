<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/validate_gameData.gd` — `class_name GameDataValidatorRunner` extends `Node`

`394` lines · [back to the map](../../CODEBASE_MAP.md)

> Headless, offline validator for the whole game-data pipeline. res://Data/json/ is the single source of truth the game reads at runtime, while res://Data/xlsx/ga…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L26 `JSON_DIR: String = "res://Data/json"`
- L27 `SKILLS_PATH: String = JSON_DIR + "/skills.json"`
- L28 `ALLIES_PATH: String = JSON_DIR + "/allies.json"`
- L29 `ENEMIES_PATH: String = JSON_DIR + "/enemies.json"`
- L30 `WAVES_PATH: String = JSON_DIR + "/waves.json"`
- L31 `CONFIG_PATH: String = JSON_DIR + "/config.json"`
- L33 `WORKBOOK_PATH: String = "res://Data/xlsx/game_data.xlsx"`
- L34 `DATA_BUILDER_PATH: String = "res://Tools/dataBuilder.gd"`
- L39 `DIAGNOSTIC_PATHS: Dictionary = {` — Diagnostic needle -> the res:// path it belongs to, in the order a message is matched, so Tools/ValidationReporter.gd can attribute a message to a repo file (an…
- L48 `ARG_JSON_ONLY: String = "--json-only"`
- L49 `ARG_STRICT: String = "--strict"`
- L50 `ARG_SUMMARY: String = "--summary"`
- L51 `ARG_HELP: String = "--help"`
- L54 `ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"` — GitHub Actions environment variables used for CI reporting.
- L55 `ENV_STEP_SUMMARY: String = "GITHUB_STEP_SUMMARY"`

State:
- L60 `_errors: PackedStringArray = PackedStringArray()`
- L61 `_warnings: PackedStringArray = PackedStringArray()`
- L62 `_skip_workbook: bool = false`
- L63 `_strict: bool = false`
- L67 `_rules: GameDataValidator = GameDataValidator.new()` — The rule engine (Tools/GameDataValidator.gd). It owns the rule diagnostics; this Node owns the file reads, the workbook smoke test, the DataLoader integration c…
- L70 `_raw_text: Dictionary = {}` — Raw JSON text per res:// path, so diagnostics can be located in the source.
- L72 `_summary_path: String = ""`
- L73 `_help_requested: bool = false`

Private:
- L77-91 `_ready`
- L95-111 `_parse_arguments`
- L116-143 `_report`
- L145-146 `_fail`
- L149-151 `_warn`
- L155-158 `_all_errors`
- L161-164 `_all_warnings`
- L169-200 `_validate_workbook`
- L202-204 `_bundle_count`
- L207-218 `_validate_runtime_json`
- L223-224 `_validate_bundle`
- L227-248 `_read_json_object`
- L252-275 `_check_loader_integration`
- L278-290 `_print_usage`
- L296-309 `_write_step_summary`
- L313-341 `_validate_loader_consistency`
- L343-372 `_validate_loaded_units`
- L375-392 `_database_fingerprint`

Uses: DataBuilder, DataLoader, GameDataValidator, GameDatabase, SkillData, UnitData, ValidationReporter, XlsxReader
Used by: GDTest/GameDataValidatorTest.gd
Loads: res://Data/json, res://Data/xlsx/game_data.xlsx, res://Tools/dataBuilder.gd, res://Tools/validator.tscn

