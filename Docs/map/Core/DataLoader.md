<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/DataLoader.gd` — `class_name DataLoader` extends `RefCounted`

`563` lines · [back to the map](../../CODEBASE_MAP.md)

> Runtime loader for the game data JSON files in res://Data/json/. Those JSON files are the single source of truth; the workbook (res://Data/xlsx/game_data.xlsx)…

Sections: Constants · Private Variables · Public Methods · Private Methods

Constants:
- L17 `JSON_DIR: String = "res://Data/json"`
- L18 `SKILLS_PATH: String = "res://Data/json/skills.json"`
- L19 `ALLIES_PATH: String = "res://Data/json/allies.json"`
- L20 `ENEMIES_PATH: String = "res://Data/json/enemies.json"`
- L21 `WAVES_PATH: String = "res://Data/json/waves.json"`
- L22 `CONFIG_PATH: String = "res://Data/json/config.json"`
- L23 `FLAGS_PATH: String = "res://Data/json/features.json"`
- L25 `DEFAULT_MAX_MOXIE: int = 20`
- L26 `DEFAULT_MAX_HP: int = 10`
- L29 `ACTION_MAP: Dictionary = {` — JSON enum strings -> runtime enums (mirrors the Enums sheet).
- L44 `TARGET_MODE_MAP: Dictionary = {`
- L54 `VALUE_SOURCE_MAP: Dictionary = {`
- L65 `MERGED_MODE_MAP: Dictionary = {`
- L70 `CONDITION_MAP: Dictionary = {`
- L74 `CARD_SELECT_MAP: Dictionary = {`
- L79 `CARD_MOD_MAP: Dictionary = {`

State:
- L86 `_db: GameDatabase = null`
- L87 `_errors: PackedStringArray = PackedStringArray()`

Public API:
- L91-106 `static db() -> GameDatabase` — Returns the cached database, loading the JSON files on first use.
- L112-131 `static load_database() -> GameDatabase` — Reads every JSON file and rebuilds a fresh GameDatabase. Problems are collected in get_errors() instead of aborting immediately so tooling can report them all a…
- L135-136 `static get_errors() -> PackedStringArray` — Problems collected by the most recent db() or load_database() call.
- L140-142 `static reload() -> void` — Drops the cached database so the next db() call re-reads the JSON files.
- L146-152 `static quit_code(code: int) -> void` — Quits the running game with the given exit code (no-op inside the editor).

Private:
- L158-173 `_read_json_object`
- L179-184 `_compute_balance_hash`
- L189-197 `_read_text`
- L202-204 `_get_int`
- L208-224 `_to_int`
- L228-246 `_get_bool`
- L250-257 `_get_string`
- L261-271 `_get_string_array`
- L275-280 `_get_array`
- L282-305 `_build_skills`
- L310-324 `_add_effects`
- L329-351 `_sorted_effects`
- L355-392 `_build_effect_block`
- L397-401 `_resolve_enum`
- L404-422 `_build_units`
- L426-434 `_resolve_skill`
- L438-471 `_build_waves`
- L475-486 `_clone_unit`
- L492-503 `_build_flags`
- L506-562 `_build_config`

Uses: EffectBlock, FeatureFlags, GameDatabase, GameState, SkillData, UnitData
Used by: GDTest/AllyKitTest.gd, GDTest/EffectBlockMessageTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/TelemetryFoundationTest.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd, Tools/GameDataValidator.gd, Tools/validate_gameData.gd
Loads: res://Data/json, res://Data/json/skills.json, res://Data/json/allies.json, res://Data/json/enemies.json, res://Data/json/waves.json, res://Data/json/config.json, res://Data/json/features.json, res://Tools/export_xlsx_to_json.gd

