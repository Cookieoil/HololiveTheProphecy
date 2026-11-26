<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleResultPrompt.gd` — `class_name BattleResultPrompt` extends `MarginContainer`

`209` lines · [back to the map](../../../CODEBASE_MAP.md)

> The end screen's action prompt, drawn the way big-budget menus do it: no box, no border and no fill at rest - just wide-tracked lettering flanked by two small d…

Sections: Signals · Constants · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers

Signals:
- L16 `pressed`

Constants:
- L20 `LABEL_TEXT: String = "PLAY AGAIN"`
- L21 `FONT_SIZE: int = 15`
- L24 `GLYPH_SPACING: int = 6` — Letter spacing in pixels. The tracking is what makes the prompt read as typography instead of a form control.
- L26 `PAD_X: int = 34`
- L27 `PAD_Y: int = 13`
- L29 `MARKER_HALF: float = 4.0`
- L30 `MARKER_REST: float = 15.0`
- L31 `MARKER_HOVER: float = 21.0`
- L32 `MARKER_ALPHA_REST: float = 0.45`
- L33 `MARKER_ALPHA_HOVER: float = 0.95`
- L38 `WASH_COLS: int = 26` — The hover wash is painted as a coarse grid of rects, so both of its edges can fall off smoothly without a shader. Cheap, and only redrawn while the hover blend…
- L39 `WASH_ROWS: int = 5`
- L40 `WASH_PEAK: float = 0.42`
- L41 `WASH_PRESS_BOOST: float = 1.25`
- L42 `WASH_H_FEATHER: float = 0.26`
- L43 `WASH_V_FEATHER: float = 0.42`
- L45 `HOVER_TIME: float = 0.18`
- L47 `TEXT_REST: Color = Color(0.82, 0.85, 0.90, 0.90)`
- L48 `TEXT_HOVER: Color = Color(0.98, 0.95, 0.86, 1.0)`
- L49 `WASH_COLOR: Color = Color(0.02, 0.02, 0.03, 1.0)`
- L50 `MARKER_COLOR: Color = Color(0.94, 0.88, 0.72, 1.0)`

State:
- L55 `interactive: bool = true` — False while the cutscene is still playing: a disabled prompt takes no clicks.
- L59 `_label: Label`
- L60 `_font_variation: FontVariation`
- L61 `_hover_blend: float = 0.0`
- L62 `_hover_tween: Tween`
- L63 `_is_hovered: bool = false`
- L64 `_is_pressed: bool = false`

Public API:
- L98-104 `set_interactive(enabled: bool) -> void` — Gates the prompt: a disabled prompt takes no clicks and stops pointing.

Private:
- L69-93 `_init`
- L108-120 `_draw`
- L125-143 `_draw_wash`
- L146-153 `_draw_marker`
- L156-167 `_set_hovered`
- L170-173 `_set_hover_blend`
- L176-179 `_kill_hover_tween`
- L183-185 `_on_mouse_entered`
- L188-191 `_on_mouse_exited`
- L194-207 `_gui_input`

Uses: —
Used by: GDTest/BattleEndTest.gd, Scenes/HUD/BattleResultOverlay.gd
Loads: —

