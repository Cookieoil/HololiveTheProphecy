<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/HudTooltip.gd` — `class_name HudTooltip` extends `Control`

`116` lines · [back to the map](../../../CODEBASE_MAP.md)

> Hover tooltip for one top-bar widget. Every icon in the top bar is the same placeholder logo, so the icon alone cannot say what the number beside it means. Inst…

Sections: Constants · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L32 `PADDING: int = 10` — Inner padding of the slab, in pixels. Matches DebugMenuPopup.PADDING.
- L34 `CORNER_RADIUS: int = 6` — Corner radius and border width of the slab, matching DebugMenuPopup._apply_chrome().
- L35 `BORDER_WIDTH: int = 1`
- L36 `TITLE_FONT_SIZE: int = 13`
- L37 `BODY_FONT_SIZE: int = 12`
- L41 `PANEL_BG: Color = Color(0.07, 0.08, 0.11, 0.97)` — Palette, kept identical to DebugMenuPopup's chrome so the hover tooltip and the tester debug menu can never drift apart.
- L42 `PANEL_BORDER: Color = Color(0.45, 0.78, 0.95, 0.5)`
- L43 `TITLE_COLOR: Color = Color(0.55, 0.86, 1.0)`
- L44 `BODY_COLOR: Color = Color(0.80, 0.85, 0.93)`

Public API:
- L63-86 `static build_tooltip_panel(for_text: String) -> Control` — Builds the slab for one `tooltip_text` payload: the first line is the title, every following line the description. A payload without a line break renders as a d…

Private:
- L52-53 `_make_custom_tooltip`
- L92-102 `_build_chrome`
- L108-114 `_build_label`

Uses: —
Used by: GDTest/HudTooltipTest.gd
Loads: —

