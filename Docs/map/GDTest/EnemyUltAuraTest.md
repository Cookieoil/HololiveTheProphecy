<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/EnemyUltAuraTest.gd` — `class_name EnemyUltAuraTest` extends `GdUnitTestSuite`

`139` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks in the enemy Ultimate warning lifecycle. The crimson character aura and the Moxie orb preview both describe one *pending* roll, so neither may outlive the…

Constants:
- L12 `UNIT_UI_SCENE_PATH: String = "res://Scenes/BattleUnit/UnitUI.tscn"`
- L15 `CRIMSON_MID: Color` — Mid colours of the OutlineGlow presets (see OutlineGlow.apply_preset).
- L16 `RUNETERRA_BLUE_MID: Color = Color(0.18, 0.70, 1.00) # RUNETERRA_BLUE`

Public API:
- L56-66 `test_orb_preview_is_spent_when_the_roll_lands_short() -> void`
- L69-84 `test_orb_preview_never_double_counts_into_a_false_ready_glow() -> void`
- L87-105 `test_aura_warns_before_the_roll_then_releases_on_the_cast() -> void`
- L108-119 `test_aura_drops_when_the_roll_lands_short() -> void`
- L122-138 `test_ally_highlights_are_never_rewritten_as_the_enemy_warning() -> void`

Private:
- L20-26 `_make_enemy`
- L29-33 `_make_orb`
- L38-44 `_make_unit_ui`
- L49-53 `_glow_param`

Uses: MoxieOrbUI, OutlineGlow, SkillData, Unit, UnitData, UnitUI
Used by: —
Loads: res

