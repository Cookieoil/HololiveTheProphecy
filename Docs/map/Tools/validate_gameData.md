<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/validate_gameData.gd` extends `Node`

`1263` lines · [back to the map](../../CODEBASE_MAP.md)

> Headless, offline validator for the whole game-data pipeline. res://Data/json/ is the single source of truth the game reads at runtime, while res://Data/xlsx/ga…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L25 `JSON_DIR: String = "res://Data/json"`
- L26 `SKILLS_PATH: String = JSON_DIR + "/skills.json"`
- L27 `ALLIES_PATH: String = JSON_DIR + "/allies.json"`
- L28 `ENEMIES_PATH: String = JSON_DIR + "/enemies.json"`
- L29 `WAVES_PATH: String = JSON_DIR + "/waves.json"`
- L30 `CONFIG_PATH: String = JSON_DIR + "/config.json"`
- L32 `WORKBOOK_PATH: String = "res://Data/xlsx/game_data.xlsx"`
- L33 `DATA_BUILDER_PATH: String = "res://Tools/dataBuilder.gd"`
- L35 `ARG_JSON_ONLY: String = "--json-only"`
- L36 `ARG_STRICT: String = "--strict"`
- L37 `ARG_SUMMARY: String = "--summary"`
- L38 `ARG_HELP: String = "--help"`
- L41 `ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"` — GitHub Actions environment variables used for CI reporting.
- L42 `ENV_STEP_SUMMARY: String = "GITHUB_STEP_SUMMARY"`
- L46 `REQUIRED_EFFECT_KEYS: PackedStringArray` — Keys a typo would silently change: Core/DataLoader.gd falls back to a default for any missing key, so these four must always be present on an effect.
- L48 `UNIT_SKILL_SLOTS: PackedStringArray = ["skill_1", "skill_2", "ultimate"]`
- L49 `WAVE_KEYS: PackedStringArray = ["wave_index", "enemies"]`
- L50 `WAVE_ENEMY_KEYS: PackedStringArray`
- L53 `TARGETED_ACTIONS: PackedStringArray = [` — Actions that must resolve at least one unit target.
- L58 `VALUE_ACTIONS: PackedStringArray = [` — Actions that resolve a numeric amount (so a fixed_amount of 0 does nothing).
- L63 `CARD_ACTIONS: PackedStringArray` — Actions that consume card_count / card_select_mode / card_mod_type.
- L65 `N_TARGET_MODES: PackedStringArray` — Target modes that select N units and therefore need target_count >= 1.
- L67 `TARGET_CACHING_MODES: PackedStringArray = [` — Target modes that fill SkillContext.targets for later "cached" effects.
- L72 `CARD_CATEGORIES: PackedStringArray` — Card categories the UI has art for (see CardIconCatalog).
- L75 `SANITY_MAX_TARGET_COUNT: int = 10` — Obvious-typo guards.
- L76 `SANITY_MAX_CARD_VALUE: int = 99`
- L77 `SANITY_MAX_DICE_SIDES: int = 100`
- L78 `SANITY_MIN_HP: int = 1`

State:
- L82 `_errors: PackedStringArray = PackedStringArray()`
- L83 `_warnings: PackedStringArray = PackedStringArray()`
- L84 `_skip_workbook: bool = false`
- L85 `_strict: bool = false`
- L88 `_actions: PackedStringArray = PackedStringArray()` — Enum allowlists, sourced from the runtime so the two can never drift apart.
- L89 `_target_modes: PackedStringArray = PackedStringArray()`
- L90 `_value_sources: PackedStringArray = PackedStringArray()`
- L91 `_conditions: PackedStringArray = PackedStringArray()`
- L92 `_card_select_modes: PackedStringArray = PackedStringArray()`
- L93 `_card_mod_types: PackedStringArray = PackedStringArray()`
- L94 `_merged_modes: PackedStringArray = PackedStringArray()`
- L95 `_status_ids: PackedStringArray = PackedStringArray()`
- L96 `_wave_modes: PackedStringArray = PackedStringArray()`
- L99 `_effect_keys: PackedStringArray = PackedStringArray()` — Canonical key sets, sourced from the workbook exporter so unknowns are typos.
- L100 `_skill_keys: PackedStringArray = PackedStringArray()`
- L101 `_unit_keys: PackedStringArray = PackedStringArray()`
- L104 `_skill_ids: Dictionary = {}` — Cross-file registries filled while validating.
- L105 `_ally_ids: Dictionary = {}`
- L106 `_enemy_ids: Dictionary = {}`
- L107 `_used_skill_ids: Dictionary = {}`
- L108 `_enemy_skill_ids: Dictionary = {}`
- L109 `_ally_skill_ids: Dictionary = {}`
- L110 `_skill_meta: Dictionary = {}`
- L112 `_id_pattern: RegEx = null`
- L115 `_raw_text: Dictionary = {}` — Raw JSON text per res:// path, so diagnostics can be located in the source.
- L117 `_skills_json: Dictionary = {}` — Raw parsed JSON, kept so the loaded database can be cross-checked against it.
- L118 `_allies_json: Dictionary = {}`
- L119 `_enemies_json: Dictionary = {}`
- L120 `_waves_json: Dictionary = {}`
- L121 `_config_json: Dictionary = {}`
- L123 `_summary_path: String = ""`
- L124 `_help_requested: bool = false`

Private:
- L128-142 `_ready`
- L147-163 `_parse_arguments`
- L168-191 `_report`
- L194-195 `_fail`
- L199-201 `_warn`
- L204-208 `_keys_of`
- L211-215 `_as_dictionary`
- L218-222 `_as_array`
- L225-233 `_dict_int`
- L236-241 `_dict_bool`
- L244-259 `_type_name`
- L262-265 `_is_snake_case_id`
- L270-282 `_collect_allowlists`
- L285-290 `_warn_unknown_keys`
- L296-316 `_int_value`
- L319-326 `_int_field`
- L329-339 `_string_field`
- L342-350 `_bool_field`
- L355-367 `_enum_field`
- L370-380 `_array_field`
- L383-386 `_require_effect_keys`
- L392-423 `_validate_workbook`
- L426-428 `_bundle_count`
- L432-446 `_validate_runtime_json`
- L450-471 `_read_json_object`
- L474-490 `_validate_skills`
- L493-536 `_validate_skill`
- L539-555 `_validate_categories`
- L560-605 `_validate_effects`
- L608-697 `_validate_effect`
- L700-760 `_validate_units`
- L763-766 `_validate_unit_collisions`
- L770-781 `_validate_skill_usage`
- L784-812 `_validate_waves`
- L815-839 `_validate_wave_enemy`
- L842-865 `_validate_config`
- L868-900 `_validate_decklist`
- L903-922 `_validate_dice_progression`
- L925-953 `_validate_config_allies`
- L958-981 `_check_loader_integration`
- L985-997 `_print_usage`
- L1002-1008 `_emit_annotations`
- L1011-1020 `_emit_annotation`
- L1024-1037 `_diagnostic_file`
- L1040-1043 `_repo_path`
- L1047-1069 `_diagnostic_line`
- L1072-1082 `_waves_line`
- L1085-1094 `_config_line`
- L1099-1112 `_line_of`
- L1116-1123 `_first_quoted`
- L1127-1138 `_bracket_index`
- L1143-1179 `_write_step_summary`
- L1184-1212 `_validate_loader_consistency`
- L1215-1240 `_validate_loaded_units`
- L1244-1261 `_database_fingerprint`

Uses: Card, CardIconCatalog, DataBuilder, DataLoader, EffectBlock, EnemyIntent, GameDatabase, GameManager, GameState, SkillContext, SkillData, Unit, UnitData, XlsxReader
Used by: —
Loads: res

