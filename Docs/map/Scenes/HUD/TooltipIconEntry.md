<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/TooltipIconEntry.gd` — `class_name TooltipIconEntry` extends `Resource`

`133` lines · [back to the map](../../../CODEBASE_MAP.md)

> One tooltip keyword/icon rule, consumed by TooltipIconCatalog. DisplayMode decides how the keyword is drawn inside a RichTextLabel: ICON_AND_KEYWORD -> [icon] K…

Sections: Enums · Exports · Public Methods · Private Methods
- L18-22 `enum DisplayMode` = ICON_AND_KEYWORD, followed by the colored keyword. ICON_ONLY, the keyword word is dropped. KEYWORD_ONLY

Exports:
- L27 `id: String = ""` — Canonical id ("gloom", "regeneration", "damage"). Case insensitive.
- L29 `display_name: String = ""` — Keyword printed next to the icon. Empty = reuse the matched text.
- L31 `icon: Texture2D = null` — Texture shown inline. Null (or path-less) textures degrade to colored text.
- L32 `display_mode: DisplayMode = DisplayMode.ICON_AND_KEYWORD`
- L33 `use_custom_color: bool = true`
- L34 `keyword_color: Color = Color("#FBBF24")`
- L35 `bold_keyword: bool = false`
- L37 `match_plain_keyword: bool = true` — true = also auto-link plain whole-word mentions in prose (no {icon:...} tag).
- L39 `aliases: PackedStringArray = PackedStringArray()` — Extra word forms that resolve/link to this entry ("Shields", "glooms").
- L41 `icon_size_override: int = 0` — 0 = use TooltipIconCatalog.default_icon_size.

Public API:
- L46-57 `matches_key(key: String) -> bool` — true when `key` (normalized by the caller) names this entry, its label or an alias.
- L61-65 `get_label() -> String` — Text used for the keyword slot of the rendered BBCode.
- L69-81 `get_keyword_keys() -> PackedStringArray` — Lowercase words this entry should auto-link in plain prose.
- L85-86 `build_inline(matched_text: String, icon_size: int = 0) -> String` — Renders `matched_text` using this entry's authored DisplayMode.
- L91-104 `build_inline_with_mode(matched_text: String, icon_size: int, mode: DisplayMode) -> String` — Renders `matched_text`, overriding the authored DisplayMode. Used by the explicit `{icon:id}` / `{kw:id}` / `{icon_only:id}` tokens.
- L110-119 `build_icon_tag(icon_size: int = 0) -> String` — `[img=WxH,valign=center]path[/img]`, or "" when no usable texture is set. Matching width/height keeps the 128x128 SVG and the 1000x1000 PNG at the exact same in…

Private:
- L123-131 `_style_keyword`

Uses: TooltipIconCatalog
Used by: GDTest/TooltipIconCatalogTest.gd, Scenes/HUD/TooltipIconCatalog.gd
Loads: res

