<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/TooltipIconCatalog.gd` — `class_name TooltipIconCatalog` extends `Resource`

`334` lines · [back to the map](../../../CODEBASE_MAP.md)

> Inline icon registry for tooltip descriptions (SkillTooltipPopup bodies). Two authoring styles are supported, mirroring Legend of Runeterra (icon + colored keyw…

Sections: Constants · Exports · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L23 `DEFAULT_ICON_SIZE: int = 16` — Inline icon size tuned for the 13px body / 14px bold tooltip font.
- L25 `COLOR_BUFF: Color = Color("#6EE7B7")` — Buff (emerald) / debuff (amethyst) keyword highlight defaults.
- L26 `COLOR_DEBUFF: Color = Color("#C084FC")`
- L28 `SAMPLE_BUFF_ICON: Texture2D` — Sample art shipped with the project (same textures StatusIcons.tres uses).
- L29 `SAMPLE_DEBUFF_ICON: Texture2D`
- L32 `BBC_TAG_NAMES: PackedStringArray = [` — Tags the tooltip actually emits. Anything else inside brackets is treated as plain text, so a stray "[Value]" can never swallow a keyword behind it.
- L38 `TOKEN_PATTERN: String` — Explicit token palette: {icon:id} / {kw:id} / {icon_only:id}.
- L39 `TAG_OPEN: String = "img"`
- L40 `TAG_CLOSE: String = "[/img]"`

Exports:
- L44 `default_icon_size: int = DEFAULT_ICON_SIZE`
- L45 `entries: Array[TooltipIconEntry] = []`
- L49 `fallback_category_catalog: CardIconCatalog = null` — Optional bridge: card categories ("damage", "shield", ...) missing from `entries` reuse this catalog's textures as ICON_ONLY glyphs, so art is authored once.
- L52 `fallback_status_catalog: StatusIconCatalog = null` — Optional bridge: statuses added to StatusIcons.tres but not here still get a left icon (ICON_AND_KEYWORD) with a buff/debuff default color.

Public API:
- L64-66 `register_default_entries() -> void` — Adds the sample status rules without overwriting authored entries.
- L71-81 `find_entry(id_key: String) -> TooltipIconEntry` — Lookup by id, display name or alias, then by the optional fallback catalogs. Returns null when nothing can render the keyword.
- L85-86 `has_entry(id_key: String) -> bool` — true when `id_key` can be rendered (authored entry or fallback).
- L91-96 `format_description(text: String, icon_size: int = 0) -> String` — Converts a skill description into tooltip-ready BBCode. `icon_size` <= 0 falls back to `default_icon_size`.

Private:
- L58-59 `_init`
- L100-112 `_add_default_entry`
- L115-119 `_find_authored_entry`
- L123-139 `_build_status_fallback_entry`
- L144-156 `_build_category_fallback_entry`
- L160-190 `_resolve_explicit_tokens`
- L194-239 `_apply_keyword_links`
- L242-260 `_link_plain_run`
- L263-268 `_lookup_index`
- L272-280 `_build_keyword_index`
- L283-291 `_build_keyword_pattern`
- L294-295 `_is_longer_key`
- L298-302 `_escape_regex`
- L306-324 `_bbcode_tag_name`
- L328-332 `_collapse_repeated_spaces`

Uses: BattleScene, Card, CardIconCatalog, SkillTooltipPopup, StatusIconCatalog, TooltipIconEntry, Unit
Used by: GDTest/TooltipIconCatalogTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/TooltipIconEntry.gd, Skills/SkillPreviewFormatter.gd
Loads: res

