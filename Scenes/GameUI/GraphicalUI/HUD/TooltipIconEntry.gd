# res://Scenes/GameUI/GraphicalUI/HUD/TooltipIconEntry.gd
class_name TooltipIconEntry
extends Resource
## One tooltip keyword/icon rule, consumed by TooltipIconCatalog.
##
## DisplayMode decides how the keyword is drawn inside a RichTextLabel:
##   ICON_AND_KEYWORD -> [icon] Keyword   (Legends of Runeterra style)
##   ICON_ONLY        -> [icon]           (Riftbound style, replaces the word)
##   KEYWORD_ONLY     -> Keyword          (text-only / accessibility fallback)
##
## A missing (or path-less) texture never breaks the tooltip: it degrades to the
## colored keyword so descriptions stay readable before art lands.
##
## @author TheGreatJellyfish
## @version 11/16/2026

#region Enums
enum DisplayMode {
	ICON_AND_KEYWORD, ## Icon on the left, followed by the colored keyword.
	ICON_ONLY, ## Pure inline glyph, the keyword word is dropped.
	KEYWORD_ONLY, ## Colored keyword without any icon.
}
#endregion

#region Exports
## Canonical id ("gloom", "regeneration", "damage"). Case insensitive.
@export var id: String = ""
## Keyword printed next to the icon. Empty = reuse the matched text.
@export var display_name: String = ""
## Texture shown inline. Null (or path-less) textures degrade to colored text.
@export var icon: Texture2D = null
@export var display_mode: DisplayMode = DisplayMode.ICON_AND_KEYWORD
@export var use_custom_color: bool = true
@export var keyword_color: Color = Color("#FBBF24")
@export var bold_keyword: bool = false
## true = also auto-link plain whole-word mentions in prose (no {icon:...} tag).
@export var match_plain_keyword: bool = true
## Extra word forms that resolve/link to this entry ("Shields", "glooms").
@export var aliases: PackedStringArray = PackedStringArray()
## 0 = use TooltipIconCatalog.default_icon_size.
@export_range(0, 64, 1) var icon_size_override: int = 0
#endregion

#region Public Methods
## true when `key` (normalized by the caller) names this entry, its label or an alias.
func matches_key(key: String) -> bool:
	var normalized: String = key.strip_edges().to_lower()
	if normalized == "":
		return false
	if id.strip_edges().to_lower() == normalized:
		return true
	if display_name.strip_edges().to_lower() == normalized:
		return true
	for alias: String in aliases:
		if alias.strip_edges().to_lower() == normalized:
			return true
	return false


## Text used for the keyword slot of the rendered BBCode.
func get_label() -> String:
	var named: String = display_name.strip_edges()
	if named != "":
		return named
	return id.strip_edges()


## Lowercase words this entry should auto-link in plain prose.
func get_keyword_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	var label: String = get_label().to_lower()
	if label != "":
		keys.append(label)
	var raw_id: String = id.strip_edges().to_lower()
	if raw_id != "" and not keys.has(raw_id):
		keys.append(raw_id)
	for alias: String in aliases:
		var alias_key: String = alias.strip_edges().to_lower()
		if alias_key != "" and not keys.has(alias_key):
			keys.append(alias_key)
	return keys


## Renders `matched_text` using this entry's authored DisplayMode.
func build_inline(matched_text: String, icon_size: int = 0) -> String:
	return build_inline_with_mode(matched_text, icon_size, display_mode)


## Renders `matched_text`, overriding the authored DisplayMode.
## Used by the explicit `{icon:id}` / `{kw:id}` / `{icon_only:id}` tokens.
func build_inline_with_mode(matched_text: String, icon_size: int, mode: DisplayMode) -> String:
	var label: String = get_label()
	if label == "":
		label = matched_text.strip_edges()
	var icon_tag: String = build_icon_tag(icon_size)
	match mode:
		DisplayMode.ICON_ONLY:
			return icon_tag if icon_tag != "" else _style_keyword(label)
		DisplayMode.KEYWORD_ONLY:
			return _style_keyword(label)
		_:
			if icon_tag == "":
				return _style_keyword(label)
			return "%s %s" % [icon_tag, _style_keyword(label)]


## `[img=WxH,valign=center]path[/img]`, or "" when no usable texture is set.
## Matching width/height keeps the 128x128 SVG and the 1000x1000 PNG at the
## exact same inline footprint, so a line never jumps between statuses.
func build_icon_tag(icon_size: int = 0) -> String:
	if icon == null:
		return ""
	var path: String = icon.resource_path.strip_edges()
	if path == "":
		return ""
	var px: int = icon_size_override if icon_size_override > 0 else icon_size
	if px <= 0:
		return ""
	return "[img=%dx%d,valign=center]%s[/img]" % [px, px, path]
#endregion

#region Private Methods
func _style_keyword(label: String) -> String:
	if label == "":
		return ""
	var styled: String = label
	if use_custom_color:
		styled = "[color=#%s]%s[/color]" % [keyword_color.to_html(false), styled]
	if bold_keyword:
		styled = "[b]%s[/b]" % styled
	return styled
#endregion
