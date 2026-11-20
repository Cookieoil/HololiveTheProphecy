<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/HudTooltip.gd` — `class_name HudTooltip` extends `Control`

`117` lines · [back to the map](../../../CODEBASE_MAP.md)

> Hover tooltip for one top-bar widget. Every icon in the top bar is the same placeholder logo, so the icon alone cannot say what the number beside it means. Inst…

Sections: Constants · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L32 `PADDING: int = 10` — Inner padding of the slab, in pixels. Matches DebugMenuPopup.PADDING.
- L34 `CORNER_RADIUS: int = 0` — Square corners (0 px): the slab and the debug menu are one flat HUD surface.
- L36 `BORDER_WIDTH: int = 1` — Border width of the slab, matching DebugMenuPopup._apply_chrome().
- L37 `TITLE_FONT_SIZE: int = 13`
- L38 `BODY_FONT_SIZE: int = 12`
- L42 `PANEL_BG: Color = Color(0.07, 0.08, 0.11, 0.97)` — Palette, kept identical to DebugMenuPopup's chrome so the hover tooltip and the tester debug menu can never drift apart.
- L43 `PANEL_BORDER: Color = Color(0.45, 0.78, 0.95, 0.5)`
- L44 `TITLE_COLOR: Color = Color(0.55, 0.86, 1.0)`
- L45 `BODY_COLOR: Color = Color(0.80, 0.85, 0.93)`

Public API:
- L64-87 `static build_tooltip_panel(for_text: String) -> Control` — Builds the slab for one `tooltip_text` payload: the first line is the title, every following line the description. A payload without a line break renders as a d…

Private:
- L53-54 `_make_custom_tooltip`
- L93-103 `_build_chrome`
- L109-115 `_build_label`

Uses: —
Used by: GDTest/HudTooltipTest.gd
Loads: —

