<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/GameDataValidator.gd` — `class_name GameDataValidator` extends `RefCounted`

`889` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure schema and semantic rules for the game data in res://Data/json/. Split out of Tools/validate_gameData.gd, which had grown the rules, the file I/O, the CLI…

Sections: Constants · Public Variables · Private Variables · Public Methods · Private Methods

Constants:
- L21 `REQUIRED_EFFECT_KEYS: PackedStringArray` — Keys a typo would silently change: Core/DataLoader.gd falls back to a default for any missing key, so these four must always be present on an effect.
- L23 `UNIT_SKILL_SLOTS: PackedStringArray = ["skill_1", "skill_2", "ultimate"]`
- L24 `WAVE_KEYS: PackedStringArray = ["wave_index", "enemies"]`
- L25 `WAVE_ENEMY_KEYS: PackedStringArray`
- L28 `TARGETED_ACTIONS: PackedStringArray = [` — Actions that must resolve at least one unit target.
- L33 `VALUE_ACTIONS: PackedStringArray = [` — Actions that resolve a numeric amount (so a fixed_amount of 0 does nothing).
- L38 `CARD_ACTIONS: PackedStringArray` — Actions that consume card_count / card_select_mode / card_mod_type.
- L40 `N_TARGET_MODES: PackedStringArray` — Target modes that select N units and therefore need target_count >= 1.
- L42 `TARGET_CACHING_MODES: PackedStringArray = [` — Target modes that fill SkillContext.targets for later "cached" effects.
- L47 `CARD_CATEGORIES: PackedStringArray` — Card categories the UI has art for (see CardIconCatalog).
- L50 `SANITY_MAX_TARGET_COUNT: int = 10` — Obvious-typo guards.
- L51 `SANITY_MAX_CARD_VALUE: int = 99`
- L52 `SANITY_MAX_DICE_SIDES: int = 100`
- L53 `SANITY_MIN_HP: int = 1`

State:
- L59 `errors: PackedStringArray = PackedStringArray()` — Every problem the most recent `validate()` found.
- L62 `warnings: PackedStringArray = PackedStringArray()` — Every warning the most recent `validate()` found, de-duplicated so a repeated typo does not flood the log.
- L65 `skills: Dictionary = {}` — The bundle the most recent `validate()` read, so a caller can report its shape (the runner's CI summary and its loader consistency check) without re-reading the…
- L66 `allies: Dictionary = {}`
- L67 `enemies: Dictionary = {}`
- L68 `waves: Dictionary = {}`
- L69 `config: Dictionary = {}`
- L75 `_actions: PackedStringArray = PackedStringArray()` — Enum allowlists, sourced from the runtime so the two can never drift apart.
- L76 `_target_modes: PackedStringArray = PackedStringArray()`
- L77 `_value_sources: PackedStringArray = PackedStringArray()`
- L78 `_conditions: PackedStringArray = PackedStringArray()`
- L79 `_card_select_modes: PackedStringArray = PackedStringArray()`
- L80 `_card_mod_types: PackedStringArray = PackedStringArray()`
- L81 `_merged_modes: PackedStringArray = PackedStringArray()`
- L82 `_status_ids: PackedStringArray = PackedStringArray()`
- L83 `_wave_modes: PackedStringArray = PackedStringArray()`
- L86 `_effect_keys: PackedStringArray = PackedStringArray()` — Canonical key sets, sourced from the workbook exporter so unknowns are typos.
- L87 `_skill_keys: PackedStringArray = PackedStringArray()`
- L88 `_unit_keys: PackedStringArray = PackedStringArray()`
- L91 `_skill_ids: Dictionary = {}` — Cross-file registries filled while validating.
- L92 `_ally_ids: Dictionary = {}`
- L93 `_enemy_ids: Dictionary = {}`
- L94 `_used_skill_ids: Dictionary = {}`
- L95 `_enemy_skill_ids: Dictionary = {}`
- L96 `_ally_skill_ids: Dictionary = {}`
- L97 `_skill_meta: Dictionary = {}`
- L99 `_id_pattern: RegEx = null`

Public API:
- L108-122 `validate(bundle: Dictionary) -> Dictionary` — Validates one already-parsed bundle and returns what it found. Starts from a clean slate, so a second call cannot accumulate the first call's diagnostics.
- L128-138 `reset() -> void` — Clears every diagnostic and every cross-file registry, so a run starts from a clean slate. The allowlists are re-collected as well, because they are what a rule…
- L143-144 `fail(message: String) -> void` — Records one problem. Public because the runner reports its own failures - a missing file, a workbook that will not parse, a DataLoader error - into the same lis…
- L148-150 `warn(message: String) -> void` — Records one warning, de-duplicated. Public for the same reason as `fail`.
- L154-169 `static type_name(value: Variant) -> String` — Describes a JSON value for a diagnostic: "number", "string", "object", ...
- L173-177 `static as_dict(value: Variant) -> Dictionary` — Reads a Dictionary out of a parsed JSON value, or {} when it is anything else.
- L181-185 `static as_array(value: Variant) -> Array` — Reads an Array out of a parsed JSON value, or [] when it is anything else.
- L229-241 `collect_allowlists() -> void` — Pulls every allowlist straight from the runtime so validation can never drift away away from what DataLoader, EffectBlock and Unit actually accept.

Private:
- L190-194 `_keys_of`
- L197-205 `_dict_int`
- L208-213 `_dict_bool`
- L217-218 `_dict_string`
- L221-224 `_is_snake_case_id`
- L244-249 `_warn_unknown_keys`
- L255-275 `_int_value`
- L278-285 `_int_field`
- L288-298 `_string_field`
- L301-309 `_bool_field`
- L314-326 `_enum_field`
- L329-339 `_array_field`
- L342-345 `_require_effect_keys`
- L349-365 `_validate_skills`
- L368-411 `_validate_skill`
- L414-430 `_validate_categories`
- L435-480 `_validate_effects`
- L483-508 `_validate_effect`
- L512-522 `_check_effect_enums`
- L526-537 `_check_effect_id`
- L541-566 `_check_effect_numbers`
- L570-581 `_check_effect_targeting`
- L585-593 `_check_effect_status`
- L598-607 `_check_effect_value_warnings`
- L612-620 `_record_effect_flow`
- L625-646 `_validate_units`
- L651-668 `_validate_unit_entry`
- L673-693 `_validate_unit_skills`
- L696-699 `_validate_unit_collisions`
- L703-714 `_validate_skill_usage`
- L717-745 `_validate_waves`
- L748-772 `_validate_wave_enemy`
- L775-798 `_validate_config`
- L801-833 `_validate_decklist`
- L836-855 `_validate_dice_progression`
- L858-886 `_validate_config_allies`

Uses: DataBuilder, DataLoader, GameState, Unit
Used by: GDTest/GameDataValidatorTest.gd, Tools/validate_gameData.gd
Loads: —

