<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/SkillTooltipPopup.gd` — `class_name SkillTooltipPopup` extends `Control`

`272` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends Control, 8 function(s)

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
- L144-206 `show_callout(data: Dictionary, anchor_rect: Rect2) -> void`
- L209-212 `hide_callout() -> void`

Private:
- L31-36 `_init`
- L39-120 `_build_ui`
- L124-132 `_apply_side_margins`
- L135-141 `_sync_wrap_widths`
- L215-233 `_rebuild_category_icons`
- L236-271 `_draw`

Uses: CardIconCatalog
Used by: Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/DebugMenuPopup.gd, Scenes/HUD/TooltipIconCatalog.gd
Loads: res

