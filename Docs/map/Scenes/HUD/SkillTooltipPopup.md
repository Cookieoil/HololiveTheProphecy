<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/SkillTooltipPopup.gd` — `class_name SkillTooltipPopup` extends `Control`

`287` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends Control, 13 function(s)

Constants:
- L5 `CARD_WIDTH: float = 310.0`
- L6 `MIN_CARD_HEIGHT: float = 88.0`
- L7 `ARROW_SIZE: float = 11.0`
- L8 `PAD_X: int = 14`
- L9 `PAD_Y: int = 11`
- L10 `SCREEN_MARGIN: float = 12.0`
- L12 `SHOW_CATEGORY_ICONS: bool = false` — Temporary toggle: category icon row in the tooltip header.

State:
- L14 `icon_catalog: CardIconCatalog`
- L16 `_accent_color: Color = Color(0.49, 0.83, 0.99)`
- L17 `_arrow_on_left: bool = true`
- L18 `_arrow_local_y: float = 40.0`
- L19 `_open_tween: Tween`
- L21 `_margin: MarginContainer`
- L22 `_vbox: VBoxContainer`
- L23 `_header_label: Label`
- L24 `_icons_box: HBoxContainer`
- L25 `_subtitle_label: Label`
- L26 `_body_rtl: RichTextLabel`
- L27 `_footer_sep: ColorRect`
- L28 `_footer_rtl: RichTextLabel`

Public API:
- L159-221 `show_callout(data: Dictionary, anchor_rect: Rect2) -> void`
- L224-227 `hide_callout() -> void`

Private:
- L31-36 `_init`
- L39-57 `_build_ui`
- L62-79 `_build_header_row`
- L83-91 `_build_subtitle`
- L96-101 `_make_separator`
- L105-120 `_build_body`
- L124-135 `_build_footer`
- L139-147 `_apply_side_margins`
- L150-156 `_sync_wrap_widths`
- L230-248 `_rebuild_category_icons`
- L251-286 `_draw`

Uses: CardIconCatalog
Used by: GDTest/HudTooltipTest.gd, Scenes/HUD/BattleOverlayController.gd
Loads: —

