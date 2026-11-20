# res://Scenes/HUD/TooltipIconCatalog.gd
class_name TooltipIconCatalog
extends Resource
## Inline icon registry for tooltip descriptions (SkillTooltipPopup bodies).
##
## Two authoring styles are supported, mirroring Legend of Runeterra (icon + colored
## keyword) and Riftbound (pure inline glyph):
##   1. Plain prose keywords are auto-linked with their left icon:
##        "inflict 2 Gloom"  ->  "[img] [color]Gloom[/color]"
##   2. Explicit tokens allow a Riftbound-style shorthand:
##        {icon:damage}      -> the entry's authored DisplayMode
##        {icon_only:gloom}  -> pure glyph, the word is dropped
##        {kw:gloom}         -> always icon + keyword
##
## Unknown tokens are stripped instead of leaking "{icon:...}" to the player, and
## previously written BBCode (colors, font sizes, [img] payloads) is never rewritten.
##
## @author TheGreatJellyfish
## @version 11/16/2026

#region Constants
## Inline icon size tuned for the 13px body / 14px bold tooltip font.
const DEFAULT_ICON_SIZE: int = 16
## Buff (emerald) / debuff (amethyst) keyword highlight defaults.
const COLOR_BUFF: Color = Color("#6EE7B7")
const COLOR_DEBUFF: Color = Color("#C084FC")
## Sample art shipped with the project (same textures StatusIcons.tres uses).
const SAMPLE_BUFF_ICON: Texture2D = preload("res://Scenes/BattleScene/Assets/icon2.png")
const SAMPLE_DEBUFF_ICON: Texture2D = preload("res://Scenes/BattleScene/Assets/icon.svg")
## Tags the tooltip actually emits. Anything else inside brackets is treated as
## plain text, so a stray "[Value]" can never swallow a keyword behind it.
const BBC_TAG_NAMES: PackedStringArray = [
	"color", "b", "i", "u", "s", "font_size", "img", "center", "left", "right",
	"bgcolor", "fgcolor", "outline_size", "outline_color", "font", "url", "code",
	"p", "indent", "ul", "ol", "table", "cell", "dropcap", "lang",
]
## Explicit token palette: {icon:id} / {kw:id} / {icon_only:id}.
const TOKEN_PATTERN: String = "\\{(icon_only|icon|kw):([A-Za-z0-9_\\- ]+)\\}"
const TAG_OPEN: String = "img"
const TAG_CLOSE: String = "[/img]"
#endregion

#region Exports
@export var default_icon_size: int = DEFAULT_ICON_SIZE
@export var entries: Array[TooltipIconEntry] = []
## Optional bridge: card categories ("damage", "shield", ...) missing from
## `entries` reuse this catalog's textures as ICON_ONLY glyphs, so art is
## authored once.
@export var fallback_category_catalog: CardIconCatalog = null
## Optional bridge: statuses added to StatusIcons.tres but not here still get a
## left icon (ICON_AND_KEYWORD) with a buff/debuff default color.
@export var fallback_status_catalog: StatusIconCatalog = null
#endregion

#region Lifecycle Methods
## Registers the two shipped sample statuses so a bare `TooltipIconCatalog.new()`
## already formats correctly. Entries authored in a .tres replace this array.
func _init() -> void:
	register_default_entries()
#endregion

#region Public Methods
## Adds the sample status rules without overwriting authored entries.
func register_default_entries() -> void:
	_add_default_entry(Unit.STATUS_REGENERATION, "Regeneration", SAMPLE_BUFF_ICON, COLOR_BUFF)
	_add_default_entry(Unit.STATUS_GLOOM, "Gloom", SAMPLE_DEBUFF_ICON, COLOR_DEBUFF)


## Lookup by id, display name or alias, then by the optional fallback catalogs.
## Returns null when nothing can render the keyword.
func find_entry(id_key: String) -> TooltipIconEntry:
	var key: String = id_key.strip_edges().to_lower()
	if key == "":
		return null
	var authored: TooltipIconEntry = _find_authored_entry(key)
	if authored != null:
		return authored
	var status_entry: TooltipIconEntry = _build_status_fallback_entry(key)
	if status_entry != null:
		return status_entry
	return _build_category_fallback_entry(key)


## true when `id_key` can be rendered (authored entry or fallback).
func has_entry(id_key: String) -> bool:
	return find_entry(id_key) != null


## Converts a skill description into tooltip-ready BBCode.
## `icon_size` <= 0 falls back to `default_icon_size`.
func format_description(text: String, icon_size: int = 0) -> String:
	if text.strip_edges() == "":
		return text
	var px: int = icon_size if icon_size > 0 else default_icon_size
	var result: String = _resolve_explicit_tokens(text, px)
	return _apply_keyword_links(result, px)
#endregion

#region Private Methods
func _add_default_entry(
	status_id: String, label: String, texture: Texture2D, keyword_color: Color
) -> void:
	if _find_authored_entry(status_id) != null:
		return
	var entry: TooltipIconEntry = TooltipIconEntry.new()
	entry.id = status_id
	entry.display_name = label
	entry.icon = texture
	entry.display_mode = TooltipIconEntry.DisplayMode.ICON_AND_KEYWORD
	entry.keyword_color = keyword_color
	entry.match_plain_keyword = true
	entries.append(entry)


func _find_authored_entry(key: String) -> TooltipIconEntry:
	for entry: TooltipIconEntry in entries:
		if entry != null and entry.matches_key(key):
			return entry
	return null


## Statuses registered in StatusIcons.tres but not in `entries`.
func _build_status_fallback_entry(key: String) -> TooltipIconEntry:
	if fallback_status_catalog == null:
		return null
	var buff_icon: Texture2D = fallback_status_catalog.buff_icons.get(key, null)
	var debuff_icon: Texture2D = fallback_status_catalog.debuff_icons.get(key, null)
	var texture: Texture2D = buff_icon if buff_icon != null else debuff_icon
	if texture == null:
		return null
	var is_debuff: bool = fallback_status_catalog.is_debuff_id(key)
	var entry: TooltipIconEntry = TooltipIconEntry.new()
	entry.id = key
	entry.display_name = key.capitalize()
	entry.icon = texture
	entry.display_mode = TooltipIconEntry.DisplayMode.ICON_AND_KEYWORD
	entry.keyword_color = COLOR_DEBUFF if is_debuff else COLOR_BUFF
	entry.match_plain_keyword = true
	return entry


## Card categories ("damage", "shield", ...) render as pure glyphs and never
## auto-link prose, so existing sentences keep reading naturally.
func _build_category_fallback_entry(key: String) -> TooltipIconEntry:
	if fallback_category_catalog == null:
		return null
	var texture: Texture2D = fallback_category_catalog.get_icon(StringName(key))
	if texture == null:
		return null
	var entry: TooltipIconEntry = TooltipIconEntry.new()
	entry.id = key
	entry.display_name = ""
	entry.icon = texture
	entry.display_mode = TooltipIconEntry.DisplayMode.ICON_ONLY
	entry.match_plain_keyword = false
	return entry


## Replaces {icon:id} / {kw:id} / {icon_only:id}; unknown ids collapse cleanly.
func _resolve_explicit_tokens(text: String, icon_size: int) -> String:
	if not text.contains("{"):
		return text
	var token_rx: RegEx = RegEx.new()
	if token_rx.compile(TOKEN_PATTERN) != OK:
		return text
	var matches: Array[RegExMatch] = token_rx.search_all(text)
	if matches.is_empty():
		return text
	var out: String = ""
	var cursor: int = 0
	var stripped_token: bool = false
	for match_result: RegExMatch in matches:
		out += text.substr(cursor, match_result.get_start() - cursor)
		var token: String = match_result.get_string(1).to_lower()
		var entry_id: String = match_result.get_string(2).strip_edges()
		var entry: TooltipIconEntry = find_entry(entry_id)
		if entry == null:
			stripped_token = true
		else:
			var mode: TooltipIconEntry.DisplayMode = entry.display_mode
			if token == "kw":
				mode = TooltipIconEntry.DisplayMode.ICON_AND_KEYWORD
			elif token == "icon_only":
				mode = TooltipIconEntry.DisplayMode.ICON_ONLY
			out += entry.build_inline_with_mode(entry_id, icon_size, mode)
		cursor = match_result.get_end()
	out += text.substr(cursor)
	if stripped_token:
		out = _collapse_repeated_spaces(out)
	return out


## Walks the string tag-by-tag so only real prose runs are keyword-scanned.
func _apply_keyword_links(text: String, icon_size: int) -> String:
	var index: Dictionary[String, TooltipIconEntry] = _build_keyword_index()
	if index.is_empty():
		return text
	var pattern: String = _build_keyword_pattern(index)
	if pattern == "":
		return text
	var keyword_rx: RegEx = RegEx.new()
	if keyword_rx.compile("(?i)\\b(%s)\\b" % pattern) != OK:
		return text

	var out: String = ""
	var text_length: int = text.length()
	var cursor: int = 0
	while cursor < text_length:
		var bracket_at: int = text.find("[", cursor)
		var run_end: int = text_length if bracket_at == -1 else bracket_at
		if run_end > cursor:
			out += _link_plain_run(text.substr(cursor, run_end - cursor), keyword_rx, index, icon_size)
		if run_end >= text_length:
			break

		var tag_end: int = text.find("]", run_end)
		if tag_end == -1:
			out += _link_plain_run(text.substr(run_end), keyword_rx, index, icon_size)
			break

		var tag: String = text.substr(run_end, tag_end - run_end + 1)
		var tag_name: String = _bbcode_tag_name(tag)
		if tag_name == "":
			out += _link_plain_run(tag, keyword_rx, index, icon_size)
			cursor = tag_end + 1
			continue

		out += tag
		cursor = tag_end + 1
		if tag_name != TAG_OPEN:
			continue
		# Never touch an image payload: a file path may contain a keyword.
		var close_at: int = text.find(TAG_CLOSE, cursor)
		if close_at == -1:
			out += text.substr(cursor)
			return out
		out += text.substr(cursor, close_at - cursor + TAG_CLOSE.length())
		cursor = close_at + TAG_CLOSE.length()
	return out


func _link_plain_run(
	run: String, keyword_rx: RegEx, index: Dictionary[String, TooltipIconEntry], icon_size: int
) -> String:
	var matches: Array[RegExMatch] = keyword_rx.search_all(run)
	if matches.is_empty():
		return run
	var out: String = ""
	var cursor: int = 0
	for match_result: RegExMatch in matches:
		out += run.substr(cursor, match_result.get_start() - cursor)
		var matched_text: String = match_result.get_string(0)
		var entry: TooltipIconEntry = _lookup_index(index, match_result.get_string(1))
		if entry == null:
			out += matched_text
		else:
			out += entry.build_inline(matched_text, icon_size)
		cursor = match_result.get_end()
	out += run.substr(cursor)
	return out


func _lookup_index(index: Dictionary[String, TooltipIconEntry], key: String) -> TooltipIconEntry:
	var raw: Variant = index.get(key.strip_edges().to_lower(), null)
	if raw is TooltipIconEntry:
		var entry: TooltipIconEntry = raw
		return entry
	return null


## Longest keyword first so "true damage" wins over "damage".
func _build_keyword_index() -> Dictionary[String, TooltipIconEntry]:
	var index: Dictionary[String, TooltipIconEntry] = {}
	for entry: TooltipIconEntry in entries:
		if entry == null or not entry.match_plain_keyword:
			continue
		for key: String in entry.get_keyword_keys():
			if key != "" and not index.has(key):
				index[key] = entry
	return index


func _build_keyword_pattern(index: Dictionary[String, TooltipIconEntry]) -> String:
	var keys: Array[String] = []
	for key: String in index.keys():
		keys.append(key)
	keys.sort_custom(_is_longer_key)
	var parts: PackedStringArray = PackedStringArray()
	for key: String in keys:
		parts.append(_escape_regex(key))
	return "|".join(parts)


static func _is_longer_key(a: String, b: String) -> bool:
	return a.length() > b.length()


func _escape_regex(text: String) -> String:
	var escaped: String = text
	for special: String in ["\\", ".", "^", "$", "|", "?", "*", "+", "(", ")", "[", "]", "{", "}", "-"]:
		escaped = escaped.replace(special, "\\" + special)
	return escaped


## Returns the lowercase tag name for a whitelisted BBCode tag, "" otherwise.
func _bbcode_tag_name(tag: String) -> String:
	if not tag.begins_with("[") or not tag.ends_with("]"):
		return ""
	if tag.length() < 3:
		return ""
	var inner: String = tag.substr(1, tag.length() - 2).strip_edges()
	if inner.begins_with("/"):
		inner = inner.substr(1)
	var name: String = inner
	var equals_at: int = name.find("=")
	if equals_at != -1:
		name = name.substr(0, equals_at)
	var comma_at: int = name.find(",")
	if comma_at != -1:
		name = name.substr(0, comma_at)
	name = name.to_lower()
	if BBC_TAG_NAMES.has(name):
		return name
	return ""


## Only used after a token was removed, so "Deal  4" becomes "Deal 4".
func _collapse_repeated_spaces(text: String) -> String:
	var result: String = text
	while result.contains("  "):
		result = result.replace("  ", " ")
	return result
#endregion
