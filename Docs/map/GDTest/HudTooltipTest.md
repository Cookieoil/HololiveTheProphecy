<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/HudTooltipTest.gd` — `class_name HudTooltipTest` extends `GdUnitTestSuite`

`373` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L94-117 `test_the_callout_builds_one_slot_per_line_of_text() -> void`
- L123-137 `test_the_callout_body_wraps_its_text_instead_of_scrolling() -> void` — The two rich-text slots have to stay plain wrappers: no scrollbar, a height that follows the text, and the line spacing that keeps an inline keyword icon off th…
- L142-167 `test_an_empty_subtitle_or_footer_collapses_its_slot() -> void` — Empty optional lines collapse instead of leaving a gap or an orphaned rule, which is what makes the same panel serve a skill with and without a footer.
- L170-177 `test_two_lines_become_a_title_and_a_description() -> void`
- L180-184 `test_one_line_is_a_description_only() -> void`
- L190-227 `test_slab_reuses_the_debug_menu_background() -> void` — The requested background: the debug menu's chrome, not Godot's built-in tooltip look. Because the engine paints its own tooltip popup behind the content, the sl…
- L232-241 `test_slab_never_grows_past_its_own_border() -> void` — The leak itself: an expand margin grows the background past the slab's own border, so the slab must never carry one.
- L247-257 `test_project_theme_reaches_the_tooltip_panel() -> void` — Wiring: the theme only reaches the engine's tooltip popup as the *project* theme (a theme on the scene or on the main window does not get that far), so the proj…
- L263-269 `test_tooltip_has_no_hover_delay() -> void` — Hovering a widget has to name it straight away: the engine's tooltip timer defaults to half a second, so the project overrides it. The setting is asserted expli…
- L274-284 `test_hover_hook_returns_the_tooltip_content() -> void` — The engine hook: returning a Control from `_make_custom_tooltip()` is what makes Godot show our content inside its tooltip popup.
- L288-294 `test_tooltip_never_eats_the_hover() -> void` — The tooltip is opened *by* a hover, so neither it nor its children may take that hover.
- L297-320 `test_top_bar_widgets_carry_the_hover_tooltip() -> void`
- L325-347 `test_action_buttons_are_labelless_icons() -> void` — The word moved out of the buttons: they are icon-only squares now that the tooltip names them.
- L352-372 `test_action_buttons_light_up_on_hover() -> void` — Flat icon buttons need another cue that they are clickable: hovering brightens the icon (self_modulate above white) and leaving restores it, like the ultimate o…

Private:
- L44-47 `_make_content`
- L53-61 `_instantiate_battle_scene`
- L65-71 `_labels`
- L75-80 `_tooltip_slab`
- L88-91 `_make_callout`

Uses: DebugMenuPopup, HudTooltip, SkillTooltipPopup
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn, res://Scenes/HUD/HudTooltip.gd, res://Scenes/HUD/HudTooltipTheme.tres

