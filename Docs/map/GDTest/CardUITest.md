<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/CardUITest.gd` — `class_name CardUITest` extends `GdUnitTestSuite`

`99` lines · [back to the map](../../CODEBASE_MAP.md)

> Tests for CardUI's runtime card feedback: the delayed value-label refresh after a skill buff/debuff and the hostile (enemy-caused) red glow preset.

Constants:
- L10 `CARD_UI_SCENE_PATH: String = "res://Scenes/Cards/CardUI.tscn"`
- L13 `CRIMSON_MID: Color` — Mid colours of the OutlineGlow presets a hand card picks between.
- L14 `RUNETERRA_BLUE_MID: Color = Color(0.18, 0.70, 1.00) # RUNETERRA_BLUE`

Public API:
- L47-60 `test_value_label_refreshes_after_runtime_value_change() -> void`
- L63-73 `test_unrelated_card_change_is_ignored() -> void`
- L76-98 `test_hostile_flash_uses_the_crimson_preset() -> void`

Private:
- L19-25 `_make_card_ui`
- L30-37 `_glow_param`
- L40-44 `_glow_is_active`

Uses: Card, CardUI, OutlineGlow
Used by: —
Loads: res

