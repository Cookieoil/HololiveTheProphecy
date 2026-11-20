<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/HudTooltipTest.gd` — `class_name HudTooltipTest` extends `GdUnitTestSuite`

`163` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the top-bar hover tooltips (HudTooltip). Every icon in the bar is the same placeholder logo, so each stat and each icon-only action button describes itsel…

Constants:
- L13 `SCENE_PATH: String`
- L14 `SCRIPT_PATH: String = "res://Scenes/HUD/HudTooltip.gd"`
- L16 `TOOLTIP_WIDGETS: Array[String] = [` — Top-bar widgets that must show a hover tooltip, in bar order.

Public API:
- L58-65 `test_two_lines_become_a_title_and_a_description() -> void`
- L68-72 `test_one_line_is_a_description_only() -> void`
- L76-91 `test_slab_reuses_the_debug_menu_background() -> void` — The requested background: the debug menu's chrome, not Godot's default tooltip look.
- L96-106 `test_hover_hook_returns_the_slab() -> void` — The engine hook: returning a Control is what makes Godot show this slab instead of its own tooltip popup.
- L110-116 `test_slab_never_eats_the_hover() -> void` — The slab is opened *by* a hover, so neither it nor its children may take that hover.
- L119-142 `test_top_bar_widgets_carry_the_hover_tooltip() -> void`
- L147-162 `test_action_buttons_are_labelless_icons() -> void` — The word moved out of the buttons: they are icon-only squares now that the tooltip names them.

Private:
- L28-31 `_make_slab`
- L37-45 `_instantiate_battle_scene`
- L49-55 `_labels`

Uses: BattleScene, DebugMenuPopup, HudTooltip
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn, res://Scenes/HUD/HudTooltip.gd

