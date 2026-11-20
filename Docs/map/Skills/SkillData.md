<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Skills/SkillData.gd` — `class_name SkillData` extends `Resource`

`51` lines · [back to the map](../../CODEBASE_MAP.md)

> Defines one skill slot (Skill 1 or Skill 2) on a unit Holds arrays of effects for unmerged and merged resolution
- L9-13 `enum MergedMode` = AND_MERGED_FIRST, then base effects AND_BASE_FIRST, then merged effects (for "that target" follow-ups) OR

Exports:
- L15 `skill_name: String = ""`
- L16 `description: String = ""`
- L17 `merged_description: String = ""`
- L18 `merged_mode: MergedMode = MergedMode.AND_MERGED_FIRST`
- L19 `base_effects: Array[SkillEffect] = []`
- L20 `merged_effects: Array[SkillEffect] = []`
- L24 `condition_threshold: int = 0` — For enemy skills: merged_effects trigger when dice value >= this. Leave at 0 for ally skills (uses card merge state instead).

State:
- L26 `base_categories: PackedStringArray = []`
- L27 `merged_categories: PackedStringArray = []`

Public API:
- L37-50 `get_active_categories(is_merged: bool) -> PackedStringArray` — Helper: Returns the active categories based on current merge status. Handles whether 'or' replaces base categories or if 'and' combines them.

Private:
- L31-34 `_init`

Uses: SkillEffect
Used by: Core/DataLoader.gd, Core/EnemyIntent.gd, Core/UnitData.gd, Data/gameDatabase.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/EnemyUltAuraTest.gd, GDTest/TooltipIconCatalogTest.gd, Managers/GameManager.gd, Scenes/BattleUnit/UnitUI.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

