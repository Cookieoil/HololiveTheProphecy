<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/DataLoader.gd` — `class_name DataLoader` extends `RefCounted`

`516` lines · [back to the map](../../CODEBASE_MAP.md)

> Runtime loader for the game data JSON files in res://Data/json/. Those JSON files are the single source of truth; the workbook (res://Data/xlsx/game_data.xlsx)…

Sections: Constants · Private Variables · Public Methods · Private Methods

Constants:
- L17 `JSON_DIR: String = "res://Data/json"`
- L18 `SKILLS_PATH: String = "res://Data/json/skills.json"`
- L19 `ALLIES_PATH: String = "res://Data/json/allies.json"`
- L20 `ENEMIES_PATH: String = "res://Data/json/enemies.json"`
- L21 `WAVES_PATH: String = "res://Data/json/waves.json"`
- L22 `CONFIG_PATH: String = "res://Data/json/config.json"`
- L24 `DEFAULT_MAX_MOXIE: int = 20`
- L25 `DEFAULT_MAX_HP: int = 10`
- L28 `ACTION_MAP: Dictionary = {` — JSON enum strings -> runtime enums (mirrors the Enums sheet).
- L43 `TARGET_MODE_MAP: Dictionary = {`
- L53 `VALUE_SOURCE_MAP: Dictionary = {`
- L64 `MERGED_MODE_MAP: Dictionary = {`
- L69 `CONDITION_MAP: Dictionary = {`
- L73 `CARD_SELECT_MAP: Dictionary = {`
- L78 `CARD_MOD_MAP: Dictionary = {`

State:
- L85 `_db: GameDatabase = null`
- L86 `_errors: PackedStringArray = PackedStringArray()`

Public API:
- L90-105 `static db() -> GameDatabase` — Returns the cached database, loading the JSON files on first use.
- L111-128 `static load_database() -> GameDatabase` — Reads every JSON file and rebuilds a fresh GameDatabase. Problems are collected in get_errors() instead of aborting immediately so tooling can report them all a…
- L132-133 `static get_errors() -> PackedStringArray` — Problems collected by the most recent db() or load_database() call.
- L137-139 `static reload() -> void` — Drops the cached database so the next db() call re-reads the JSON files.
- L143-149 `static quit_code(code: int) -> void` — Quits the running game with the given exit code (no-op inside the editor).

Private:
- L155-170 `_read_json_object`
- L175-177 `_get_int`
- L181-197 `_to_int`
- L201-219 `_get_bool`
- L223-230 `_get_string`
- L234-244 `_get_string_array`
- L248-253 `_get_array`
- L255-277 `_build_skills`
- L282-296 `_add_effects`
- L301-323 `_sorted_effects`
- L327-364 `_build_effect_block`
- L369-373 `_resolve_enum`
- L376-393 `_build_units`
- L397-405 `_resolve_skill`
- L409-442 `_build_waves`
- L446-456 `_clone_unit`
- L459-515 `_build_config`

Uses: EffectBlock, GameDatabase, GameState, SkillData, UnitData
Used by: GDTest/AllyKitTest.gd, Scenes/BattleScene/BattleScene.gd, Tools/validate_gameData.gd
Loads: res://Data/json, res://Data/json/skills.json, res://Data/json/allies.json, res://Data/json/enemies.json, res://Data/json/waves.json, res://Data/json/config.json, res://Tools/export_xlsx_to_json.gd

