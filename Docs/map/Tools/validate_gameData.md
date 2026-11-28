<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/validate_gameData.gd` — `class_name GameDataValidatorRunner` extends `Node`

`1161` lines · [back to the map](../../CODEBASE_MAP.md)

> Headless, offline validator for the whole game-data pipeline. res://Data/json/ is the single source of truth the game reads at runtime, while res://Data/xlsx/ga…

Sections: Constants · Private Variables · Lifecycle Methods · Public Methods · Private Methods

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
- L59 `REQUIRED_EFFECT_KEYS: PackedStringArray` — Keys a typo would silently change: Core/DataLoader.gd falls back to a default for any missing key, so these four must always be present on an effect.
- L61 `UNIT_SKILL_SLOTS: PackedStringArray = ["skill_1", "skill_2", "ultimate"]`
- L62 `WAVE_KEYS: PackedStringArray = ["wave_index", "enemies"]`
- L63 `WAVE_ENEMY_KEYS: PackedStringArray`
- L66 `TARGETED_ACTIONS: PackedStringArray = [` — Actions that must resolve at least one unit target.
- L71 `VALUE_ACTIONS: PackedStringArray = [` — Actions that resolve a numeric amount (so a fixed_amount of 0 does nothing).
- L76 `CARD_ACTIONS: PackedStringArray` — Actions that consume card_count / card_select_mode / card_mod_type.
- L78 `N_TARGET_MODES: PackedStringArray` — Target modes that select N units and therefore need target_count >= 1.
- L80 `TARGET_CACHING_MODES: PackedStringArray = [` — Target modes that fill SkillContext.targets for later "cached" effects.
- L85 `CARD_CATEGORIES: PackedStringArray` — Card categories the UI has art for (see CardIconCatalog).
- L88 `SANITY_MAX_TARGET_COUNT: int = 10` — Obvious-typo guards.
- L89 `SANITY_MAX_CARD_VALUE: int = 99`
- L90 `SANITY_MAX_DICE_SIDES: int = 100`
- L91 `SANITY_MIN_HP: int = 1`

State:
- L95 `_errors: PackedStringArray = PackedStringArray()`
- L96 `_warnings: PackedStringArray = PackedStringArray()`
- L97 `_skip_workbook: bool = false`
- L98 `_strict: bool = false`
- L101 `_actions: PackedStringArray = PackedStringArray()` — Enum allowlists, sourced from the runtime so the two can never drift apart.
- L102 `_target_modes: PackedStringArray = PackedStringArray()`
- L103 `_value_sources: PackedStringArray = PackedStringArray()`
- L104 `_conditions: PackedStringArray = PackedStringArray()`
- L105 `_card_select_modes: PackedStringArray = PackedStringArray()`
- L106 `_card_mod_types: PackedStringArray = PackedStringArray()`
- L107 `_merged_modes: PackedStringArray = PackedStringArray()`
- L108 `_status_ids: PackedStringArray = PackedStringArray()`
- L109 `_wave_modes: PackedStringArray = PackedStringArray()`
- L112 `_effect_keys: PackedStringArray = PackedStringArray()` — Canonical key sets, sourced from the workbook exporter so unknowns are typos.
- L113 `_skill_keys: PackedStringArray = PackedStringArray()`
- L114 `_unit_keys: PackedStringArray = PackedStringArray()`
- L117 `_skill_ids: Dictionary = {}` — Cross-file registries filled while validating.
- L118 `_ally_ids: Dictionary = {}`
- L119 `_enemy_ids: Dictionary = {}`
- L120 `_used_skill_ids: Dictionary = {}`
- L121 `_enemy_skill_ids: Dictionary = {}`
- L122 `_ally_skill_ids: Dictionary = {}`
- L123 `_skill_meta: Dictionary = {}`
- L125 `_id_pattern: RegEx = null`
- L128 `_raw_text: Dictionary = {}` — Raw JSON text per res:// path, so diagnostics can be located in the source.
- L130 `_skills_json: Dictionary = {}` — Raw parsed JSON, kept so the loaded database can be cross-checked against it.
- L131 `_allies_json: Dictionary = {}`
- L132 `_enemies_json: Dictionary = {}`
- L133 `_waves_json: Dictionary = {}`
- L134 `_config_json: Dictionary = {}`
- L136 `_summary_path: String = ""`
- L137 `_help_requested: bool = false`

Public API:
- L187-190 `validate_bundle(bundle: Dictionary) -> Dictionary` — Runs the JSON rules over an in-memory bundle and returns what they found, instead of printing and quitting. This is the seam GDTest/GameDataValidatorTest.gd dri…
- L196-206 `reset() -> void` — Clears every diagnostic and every cross-file registry, so a run starts from a clean slate. The allowlists are re-collected as well, because they are what the ru…

Private:
- L141-155 `_ready`
- L160-176 `_parse_arguments`
- L212-235 `_report`
- L238-239 `_fail`
- L243-245 `_warn`
- L248-252 `_keys_of`
- L255-259 `_as_dictionary`
- L262-266 `_as_array`
- L269-277 `_dict_int`
- L280-285 `_dict_bool`
- L288-303 `_type_name`
- L306-309 `_is_snake_case_id`
- L314-326 `_collect_allowlists`
- L329-334 `_warn_unknown_keys`
- L340-360 `_int_value`
- L363-370 `_int_field`
- L373-383 `_string_field`
- L386-394 `_bool_field`
- L399-411 `_enum_field`
- L414-424 `_array_field`
- L427-430 `_require_effect_keys`
- L436-467 `_validate_workbook`
- L470-472 `_bundle_count`
- L476-487 `_validate_runtime_json`
- L493-506 `_validate_bundle`
- L510-531 `_read_json_object`
- L534-550 `_validate_skills`
- L553-596 `_validate_skill`
- L599-615 `_validate_categories`
- L620-665 `_validate_effects`
- L668-757 `_validate_effect`
- L760-820 `_validate_units`
- L823-826 `_validate_unit_collisions`
- L830-841 `_validate_skill_usage`
- L844-872 `_validate_waves`
- L875-899 `_validate_wave_enemy`
- L902-925 `_validate_config`
- L928-960 `_validate_decklist`
- L963-982 `_validate_dice_progression`
- L985-1013 `_validate_config_allies`
- L1018-1041 `_check_loader_integration`
- L1045-1057 `_print_usage`
- L1064-1077 `_write_step_summary`
- L1082-1110 `_validate_loader_consistency`
- L1113-1138 `_validate_loaded_units`
- L1142-1159 `_database_fingerprint`

Uses: DataBuilder, DataLoader, GameDatabase, GameState, SkillData, Unit, UnitData, ValidationReporter, XlsxReader
Used by: GDTest/GameDataValidatorTest.gd
Loads: res://Data/json, res://Data/xlsx/game_data.xlsx, res://Tools/dataBuilder.gd, res://Tools/validator.tscn

