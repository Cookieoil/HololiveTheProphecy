<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/HudTooltipTest.gd` — `class_name HudTooltipTest` extends `GdUnitTestSuite`

`247` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the top-bar hover tooltips (HudTooltip) and the slab they are drawn on (the tooltip theme in HudTooltipTheme.tres). Every icon in the bar is the same plac…

Constants:
- L19 `SCENE_PATH: String`
- L20 `SCRIPT_PATH: String = "res://Scenes/HUD/HudTooltip.gd"`
- L21 `THEME_PATH: String = "res://Scenes/HUD/HudTooltipTheme.tres"`
- L23 `THEME_SETTING: String = "gui/theme/custom"` — Project setting that puts the theme in charge of the engine's tooltip popup.
- L25 `THEME_TYPE: String = "TooltipPanel"` — Theme type and item the engine's tooltip popup asks for its background.
- L26 `THEME_ITEM: String = "panel"`
- L28 `TOOLTIP_WIDGETS: Array[String] = [` — Top-bar widgets that must show a hover tooltip, in bar order.

Public API:
- L81-88 `test_two_lines_become_a_title_and_a_description() -> void`
- L91-95 `test_one_line_is_a_description_only() -> void`
- L101-138 `test_slab_reuses_the_debug_menu_background() -> void` — The requested background: the debug menu's chrome, not Godot's built-in tooltip look. Because the engine paints its own tooltip popup behind the content, the sl…
- L143-152 `test_slab_never_grows_past_its_own_border() -> void` — The leak itself: an expand margin grows the background past the slab's own border, so the slab must never carry one.
- L158-168 `test_project_theme_reaches_the_tooltip_panel() -> void` — Wiring: the theme only reaches the engine's tooltip popup as the *project* theme (a theme on the scene or on the main window does not get that far), so the proj…
- L173-183 `test_hover_hook_returns_the_tooltip_content() -> void` — The engine hook: returning a Control from `_make_custom_tooltip()` is what makes Godot show our content inside its tooltip popup.
- L187-193 `test_tooltip_never_eats_the_hover() -> void` — The tooltip is opened *by* a hover, so neither it nor its children may take that hover.
- L196-219 `test_top_bar_widgets_carry_the_hover_tooltip() -> void`
- L224-246 `test_action_buttons_are_labelless_icons() -> void` — The word moved out of the buttons: they are icon-only squares now that the tooltip names them.

Private:
- L42-45 `_make_content`
- L51-59 `_instantiate_battle_scene`
- L63-69 `_labels`
- L73-78 `_tooltip_slab`

Uses: BattleScene, DebugMenuPopup, HudTooltip
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn, res://Scenes/HUD/HudTooltip.gd, res://Scenes/HUD/HudTooltipTheme.tres

