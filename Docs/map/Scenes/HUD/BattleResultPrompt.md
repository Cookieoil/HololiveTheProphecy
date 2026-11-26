<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleResultPrompt.gd` — `class_name BattleResultPrompt` extends `MarginContainer`

`183` lines · [back to the map](../../../CODEBASE_MAP.md)

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
- L32 `WASH_COLS: int = 26` — The hover wash is painted as a coarse grid of rects, so both of its edges can fall off smoothly without a shader. Cheap, and only redrawn while the hover blend…
- L33 `WASH_ROWS: int = 5`
- L34 `WASH_PEAK: float = 0.42`
- L35 `WASH_PRESS_BOOST: float = 1.25`
- L36 `WASH_H_FEATHER: float = 0.26`
- L37 `WASH_V_FEATHER: float = 0.42`
- L39 `HOVER_TIME: float = 0.18`
- L41 `TEXT_REST: Color = Color(0.82, 0.85, 0.90, 0.90)`
- L42 `TEXT_HOVER: Color = Color(0.98, 0.95, 0.86, 1.0)`
- L43 `WASH_COLOR: Color = Color(0.02, 0.02, 0.03, 1.0)`

State:
- L48 `interactive: bool = true` — False while the cutscene is still playing: a disabled prompt takes no clicks.
- L52 `_label: Label`
- L53 `_font_variation: FontVariation`
- L54 `_hover_blend: float = 0.0`
- L55 `_hover_tween: Tween`
- L56 `_is_hovered: bool = false`
- L57 `_is_pressed: bool = false`

Public API:
- L91-97 `set_interactive(enabled: bool) -> void` — Gates the prompt: a disabled prompt takes no clicks and stops pointing.

Private:
- L62-86 `_init`
- L101-104 `_draw`
- L109-127 `_draw_wash`
- L130-141 `_set_hovered`
- L144-147 `_set_hover_blend`
- L150-153 `_kill_hover_tween`
- L157-159 `_on_mouse_entered`
- L162-165 `_on_mouse_exited`
- L168-181 `_gui_input`

Uses: —
Used by: GDTest/BattleEndTest.gd, Scenes/HUD/BattleResultOverlay.gd
Loads: —

