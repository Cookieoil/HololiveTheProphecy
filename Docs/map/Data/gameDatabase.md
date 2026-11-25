<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Data/gameDatabase.gd` — `class_name GameDatabase` extends `Resource`

`27` lines · [back to the map](../../CODEBASE_MAP.md)

> Skill definitions keyed by skill_id (effects embedded).

Exports:
- L5 `skills: Dictionary = {}`
- L7 `allies: Dictionary = {}` — Ally unit templates keyed by unit_id (from allies.json).
- L9 `enemies: Dictionary = {}` — Enemy unit templates keyed by unit_id (from enemies.json).
- L11 `units: Dictionary = {}` — Union of allies and enemies, kept for unit lookups by id.
- L12 `waves: Array = []`
- L13 `config: Dictionary = {}`

Public API:
- L15-19 `get_unit(id: String) -> UnitData` — Returns the unit template for an id, or null when unknown.
- L22-26 `get_skill(id: String) -> SkillData` — Returns the skill definition for an id, or null when unknown.

Uses: SkillData, UnitData
Used by: Core/DataLoader.gd, GDTest/EnemySkillBalanceTest.gd, Scenes/BattleScene/BattleScene.gd, Tools/validate_gameData.gd
Loads: —

