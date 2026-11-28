<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/EnemyIntent.gd` — `class_name EnemyIntent` extends `RefCounted`

`38` lines · [back to the map](../../CODEBASE_MAP.md)

> Pre-rolled intent for one enemy this turn. Created at step 1 of the turn loop, resolved at step 7.

State:
- L9 `enemy: Unit`
- L10 `raw_dice_value: int          ## The unmodified roll`
- L11 `effective_value: int         ## After value_modifier applied`
- L12 `skill: SkillData             ## skill_1 or skill_2 based on odd/even`
- L13 `condition_met: bool          ## effective_value > = skill.condition_threshold`

Public API:
- L20-23 `recalculate() -> void`
- L25-29 `will_trigger_ultimate() -> bool`

Private:
- L15-18 `_init`
- L31-37 `_to_string`

Uses: SkillData, Unit
Used by: Core/GameUI.gd, Core/Telemetry/TelemetryDecision.gd, Core/Telemetry/TelemetrySchema.gd, GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/DeterminismTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryDecisionTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Skills/SkillPreviewFormatter.gd
Loads: —

