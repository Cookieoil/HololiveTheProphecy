<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/HudTooltip.gd` — `class_name HudTooltip` extends `Control`

`91` lines · [back to the map](../../../CODEBASE_MAP.md)

> Content of the hover tooltip for one top-bar widget. Every icon in the top bar is the same placeholder logo, so the icon alone cannot say what the number beside…

Sections: Constants · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L31 `TITLE_FONT_SIZE: int = 13`
- L32 `BODY_FONT_SIZE: int = 12`
- L34 `LINE_SEPARATION: int = 2` — Space between the title and the description.
- L37 `TITLE_COLOR: Color = Color(0.55, 0.86, 1.0)` — Text colours. The slab itself is the tooltip theme's (HudTooltipTheme.tres).
- L38 `BODY_COLOR: Color = Color(0.80, 0.85, 0.93)`

Public API:
- L57-75 `static build_tooltip_content(for_text: String) -> Control` — Builds the tooltip content for one `tooltip_text` payload: the first line is the title, every following line the description. A payload without a line break ren…

Private:
- L46-47 `_make_custom_tooltip`
- L83-89 `_build_label`

Uses: —
Used by: GDTest/DiffReviewTest.gd, GDTest/HudTooltipTest.gd
Loads: —

