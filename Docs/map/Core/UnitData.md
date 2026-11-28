<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/UnitData.gd` — `class_name UnitData` extends `Resource`

`20` lines · [back to the map](../../CODEBASE_MAP.md)

> Template definition for a unit type.

Exports:
- L11 `unit_id: String = ""` — Stable id from allies.json / enemies.json (e.g. "striker", "boss_enemy"). Unlike display_name it is never localised or overridden by a wave, so telemetry and sa…
- L12 `display_name: String = ""`
- L13 `max_hp: int = 10`
- L14 `portrait: Texture2D = null`
- L15 `skill_1: SkillData = null`
- L16 `skill_2: SkillData = null`
- L17 `ultimate: SkillData = null`
- L18 `max_moxie: int = 20`
- L19 `is_enemy: bool = false`

Uses: SkillData
Used by: Core/DataLoader.gd, Core/GameState.gd, Core/Unit.gd, Data/gameDatabase.gd, GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DataLoaderTest.gd, GDTest/DebugCommandRunnerTest.gd, GDTest/DebugMenuTest.gd, GDTest/DeterminismTest.gd, GDTest/EffectBlockMessageTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/EnemyUltAuraTest.gd, GDTest/SkillContextFactoryTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryDecisionTest.gd, GDTest/TelemetryFoundationTest.gd, GDTest/TelemetryTest.gd, GDTest/TooltipIconCatalogTest.gd, GDTest/TurnLoopTest.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd, Tools/BattleSimulator.gd, Tools/validate_gameData.gd
Loads: —

