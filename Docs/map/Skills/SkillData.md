<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Skills/SkillData.gd` — `class_name SkillData` extends `Resource`

`54` lines · [back to the map](../../CODEBASE_MAP.md)

> Defines one skill slot (Skill 1 or Skill 2) on a unit Holds arrays of effects for unmerged and merged resolution
- L9-13 `enum MergedMode` = AND_MERGED_FIRST, then base effects AND_BASE_FIRST, then merged effects (for "that target" follow-ups) OR

Exports:
- L17 `skill_id: String = ""` — Stable id from skills.json (e.g. "striker_1", "buff_ult"). Unlike skill_name it never changes when a skill is renamed, so telemetry can key on it.
- L18 `skill_name: String = ""`
- L19 `description: String = ""`
- L20 `merged_description: String = ""`
- L21 `merged_mode: MergedMode = MergedMode.AND_MERGED_FIRST`
- L22 `base_effects: Array[SkillEffect] = []`
- L23 `merged_effects: Array[SkillEffect] = []`
- L27 `condition_threshold: int = 0` — For enemy skills: merged_effects trigger when dice value >= this. Leave at 0 for ally skills (uses card merge state instead).

State:
- L29 `base_categories: PackedStringArray = []`
- L30 `merged_categories: PackedStringArray = []`

Public API:
- L40-53 `get_active_categories(is_merged: bool) -> PackedStringArray` — Helper: Returns the active categories based on current merge status. Handles whether 'or' replaces base categories or if 'and' combines them.

Private:
- L34-37 `_init`

Uses: SkillEffect
Used by: Core/DataLoader.gd, Core/EnemyIntent.gd, Core/Telemetry/TelemetryDecision.gd, Core/Telemetry/TelemetrySchema.gd, Core/UnitData.gd, Data/gameDatabase.gd, GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/EnemyUltAuraTest.gd, GDTest/TelemetryFoundationTest.gd, GDTest/TelemetryTest.gd, GDTest/TooltipIconCatalogTest.gd, Managers/GameManager.gd, Managers/TelemetryManager.gd, Scenes/BattleUnit/UnitUI.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

