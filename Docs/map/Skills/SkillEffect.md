<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Skills/SkillEffect.gd` — `class_name SkillEffect` extends `Resource`

`20` lines · [back to the map](../../CODEBASE_MAP.md)

> Abstract base for all skill effect components. Subclasses override execute(). The GameManager always calls: await effect.execute(ctx). Note: This base shouldn't…

Public API:
- L13-15 `execute(_ctx: SkillContext) -> void`
- L18-19 `get_description() -> String` — Auto-description for inspectat	ion/debug

Uses: SkillContext
Used by: GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/DeterminismTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd, Skills/EffectBlock.gd, Skills/SkillData.gd, Skills/SkillPreviewFormatter.gd
Loads: —

