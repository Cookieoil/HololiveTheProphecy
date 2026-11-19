<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/DataLoader.gd` — `class_name DataLoader` extends `RefCounted`

`515` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L63 `MERGED_MODE_MAP: Dictionary = {`
- L68 `CONDITION_MAP: Dictionary = {`
- L72 `CARD_SELECT_MAP: Dictionary = {`
- L77 `CARD_MOD_MAP: Dictionary = {`

State:
- L84 `_db: GameDatabase = null`
- L85 `_errors: PackedStringArray = PackedStringArray()`

Public API:
- L89-104 `static db() -> GameDatabase` — Returns the cached database, loading the JSON files on first use.
- L110-127 `static load_database() -> GameDatabase` — Reads every JSON file and rebuilds a fresh GameDatabase. Problems are collected in get_errors() instead of aborting immediately so tooling can report them all a…
- L131-132 `static get_errors() -> PackedStringArray` — Problems collected by the most recent db() or load_database() call.
- L136-138 `static reload() -> void` — Drops the cached database so the next db() call re-reads the JSON files.
- L142-148 `static quit_code(code: int) -> void` — Quits the running game with the given exit code (no-op inside the editor).

Private:
- L154-169 `_read_json_object`
- L174-176 `_get_int`
- L180-196 `_to_int`
- L200-218 `_get_bool`
- L222-229 `_get_string`
- L233-243 `_get_string_array`
- L247-252 `_get_array`
- L254-276 `_build_skills`
- L281-295 `_add_effects`
- L300-322 `_sorted_effects`
- L326-363 `_build_effect_block`
- L368-372 `_resolve_enum`
- L375-392 `_build_units`
- L396-404 `_resolve_skill`
- L408-441 `_build_waves`
- L445-455 `_clone_unit`
- L458-514 `_build_config`

Uses: EffectBlock, GameDatabase, GameState, SkillData, UnitData
Used by: Scenes/BattleScene/BattleScene.gd, Tools/validate_gameData.gd
Loads: res://Data/json, res://Data/json/skills.json, res://Data/json/allies.json, res://Data/json/enemies.json, res://Data/json/waves.json, res://Data/json/config.json, res://Tools/export_xlsx_to_json.gd

