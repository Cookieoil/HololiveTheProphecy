<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/HudTooltipTest.gd` — `class_name HudTooltipTest` extends `GdUnitTestSuite`

`286` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the top-bar hover tooltips (HudTooltip) and the slab they are drawn on (the tooltip theme in HudTooltipTheme.tres). Every icon in the bar is the same plac…

Constants:
- L19 `SCENE_PATH: String`
- L20 `SCRIPT_PATH: String = "res://Scenes/HUD/HudTooltip.gd"`
- L21 `THEME_PATH: String = "res://Scenes/HUD/HudTooltipTheme.tres"`
- L23 `THEME_SETTING: String = "gui/theme/custom"` — Project setting that puts the theme in charge of the engine's tooltip popup.
- L25 `TOOLTIP_DELAY_SETTING: String = "gui/timers/tooltip_delay_sec"` — Project setting for how long a hover has to last before the tooltip appears.
- L27 `THEME_TYPE: String = "TooltipPanel"` — Theme type and item the engine's tooltip popup asks for its background.
- L28 `THEME_ITEM: String = "panel"`
- L30 `TOOLTIP_WIDGETS: Array[String] = [` — Top-bar widgets that must show a hover tooltip, in bar order.

Public API:
- L83-90 `test_two_lines_become_a_title_and_a_description() -> void`
- L93-97 `test_one_line_is_a_description_only() -> void`
- L103-140 `test_slab_reuses_the_debug_menu_background() -> void` — The requested background: the debug menu's chrome, not Godot's built-in tooltip look. Because the engine paints its own tooltip popup behind the content, the sl…
- L145-154 `test_slab_never_grows_past_its_own_border() -> void` — The leak itself: an expand margin grows the background past the slab's own border, so the slab must never carry one.
- L160-170 `test_project_theme_reaches_the_tooltip_panel() -> void` — Wiring: the theme only reaches the engine's tooltip popup as the *project* theme (a theme on the scene or on the main window does not get that far), so the proj…
- L176-182 `test_tooltip_has_no_hover_delay() -> void` — Hovering a widget has to name it straight away: the engine's tooltip timer defaults to half a second, so the project overrides it. The setting is asserted expli…
- L187-197 `test_hover_hook_returns_the_tooltip_content() -> void` — The engine hook: returning a Control from `_make_custom_tooltip()` is what makes Godot show our content inside its tooltip popup.
- L201-207 `test_tooltip_never_eats_the_hover() -> void` — The tooltip is opened *by* a hover, so neither it nor its children may take that hover.
- L210-233 `test_top_bar_widgets_carry_the_hover_tooltip() -> void`
- L238-260 `test_action_buttons_are_labelless_icons() -> void` — The word moved out of the buttons: they are icon-only squares now that the tooltip names them.
- L265-285 `test_action_buttons_light_up_on_hover() -> void` — Flat icon buttons need another cue that they are clickable: hovering brightens the icon (self_modulate above white) and leaving restores it, like the ultimate o…

Private:
- L44-47 `_make_content`
- L53-61 `_instantiate_battle_scene`
- L65-71 `_labels`
- L75-80 `_tooltip_slab`

Uses: BattleScene, DebugMenuPopup, HudTooltip
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn, res://Scenes/HUD/HudTooltip.gd, res://Scenes/HUD/HudTooltipTheme.tres

