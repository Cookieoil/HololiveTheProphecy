class_name CodeIndexParser
extends RefCounted
## Pure parsing layer behind Tools/gen_code_index.gd.
##
## Every function here takes text in and returns plain Dictionaries: no file
## system access, no rendering, no CLI. That keeps the tricky parts (wrapped
## signatures, file-header detection, `.tscn` attributes, JSON shapes, line
## ranges) unit-testable against fixtures in GDTest/CodeIndexTest.gd, which is
## what stops the generated map from silently drifting away from the sources.
##
## @author TheGreatJellyfish
## @version 11/18/2026

#region Constants
## Tests live here; they get their own overview table so game code stays visible.
const TEST_DIR_PREFIX: String = "GDTest/"
## Every resource reference starts with this scheme.
const RES_SCHEME: String = "res://"
## Caps that keep the generated artifacts cheap to read.
const MAX_ITEM_KEYS: int = 24
const MAX_DOC_CHARS: int = 160
## The role cell in the overview table is capped harder than a page header, because the
## overview has a byte budget and one line per script (see overview_role()). 96 was
## comfortable until the project reached ~100 scripts; at 72 the overview keeps its
## headroom inside the budget Tools/check_navigation.gd enforces, without dropping a row.
const OVERVIEW_ROLE_CHARS: int = 72
const MAX_REFS_LISTED: int = 20
const HEADER_SCAN_LINES: int = 40
const KEY_COLLECT_DEPTH: int = 3
#endregion

#region Public Methods
## Normalises line endings, so CRLF and LF sources produce identical output.
static func normalized_text(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\r", "\n")


static func repo_path(res_path: String) -> String:
	if res_path.begins_with("res://"):
		return res_path.substr("res://".length())
	return res_path


## Parses one script into a flat record. Only top-level declarations (column 0)
## are indexed; function bodies and inner-class members are skipped on purpose,
## which keeps the generated pages small enough to be worth reading.
static func parse_script(res_path: String, text: String) -> Dictionary:
	var lines: PackedStringArray = normalized_text(text).split("\n")
	var header_end: int = header_end_index(lines)
	var class_value: String = ""
	var class_line: int = 0
	var extends_value: String = ""
	var regions: PackedStringArray = PackedStringArray()
	var enums: Array[Dictionary] = []
	var inner_classes: Array[Dictionary] = []
	var signals: Array[Dictionary] = []
	var constants: Array[Dictionary] = []
	var exports: Array[Dictionary] = []
	var onready: Array[Dictionary] = []
	var variables: Array[Dictionary] = []
	var functions: Array[Dictionary] = []
	var pending_doc: PackedStringArray = PackedStringArray()
	var pending_export: bool = false
	var pending_onready: bool = false
	var index: int = 0
	while index < lines.size():
		var raw: String = lines[index]
		var line: String = raw.strip_edges(false, true)
		index += 1
		var line_number: int = index
		if line.is_empty() or raw.begins_with("\t") or raw.begins_with(" "):
			continue
		if line.begins_with("##"):
			if line_number > header_end:
				pending_doc.append(doc_text(line))
			continue
		if line.begins_with("#region"):
			regions.append(line.substr("#region".length()).strip_edges())
			continue
		if line.begins_with("#"):
			continue
		if line.begins_with("class_name "):
			class_value = leading_identifier(line.substr("class_name ".length()))
			class_line = line_number
			continue
		if line.begins_with("extends "):
			extends_value = line.substr("extends ".length()).strip_edges()
			continue
		if line.begins_with("class "):
			inner_classes.append({
				"name": leading_identifier(line.substr("class ".length())),
				"extends": extract_between(line, "extends ", ":"),
				"line": line_number,
			})
			pending_doc.clear()
			continue
		if line.begins_with("@export"):
			pending_export = true
			if line.contains("var "):
				var exported: Dictionary = parse_named_declaration(line.substr(line.find("var ")), "var ")
				exported["line"] = line_number
				exported["doc"] = join_doc(pending_doc)
				exports.append(exported)
				pending_doc.clear()
				pending_export = false
			continue
		if line.begins_with("@onready"):
			pending_onready = true
			if line.contains("var "):
				var wired: Dictionary = parse_named_declaration(line.substr(line.find("var ")), "var ")
				wired["line"] = line_number
				wired["doc"] = join_doc(pending_doc)
				onready.append(wired)
				pending_doc.clear()
				pending_onready = false
			continue
		if line.begins_with("@"):
			pending_export = false
			pending_onready = false
			continue
		if line.begins_with("signal "):
			var signal_entry: Dictionary = parse_signal(line)
			signal_entry["line"] = line_number
			signal_entry["doc"] = join_doc(pending_doc)
			signals.append(signal_entry)
			pending_doc.clear()
			continue
		if line.begins_with("const "):
			var const_entry: Dictionary = parse_named_declaration(line, "const ")
			const_entry["line"] = line_number
			const_entry["doc"] = join_doc(pending_doc)
			constants.append(const_entry)
			pending_doc.clear()
			continue
		if line.begins_with("enum "):
			var enum_entry: Dictionary = parse_enum(lines, line_number - 1, line)
			index = dict_int(enum_entry, "next", index)
			enum_entry.erase("next")
			enum_entry["end"] = index
			enums.append(enum_entry)
			pending_doc.clear()
			continue
		if line.begins_with("var ") or line.begins_with("static var "):
			var keyword: String = "var " if line.begins_with("var ") else "static var "
			var variable_entry: Dictionary = parse_named_declaration(line, keyword)
			variable_entry["line"] = line_number
			variable_entry["doc"] = join_doc(pending_doc)
			if pending_export:
				exports.append(variable_entry)
			elif pending_onready:
				onready.append(variable_entry)
			else:
				variables.append(variable_entry)
			pending_export = false
			pending_onready = false
			pending_doc.clear()
			continue
		if line.begins_with("func ") or line.begins_with("static func "):
			var signature: String = line
			while not signature_complete(signature) and index < lines.size():
				signature = signature + " " + lines[index].strip_edges()
				index += 1
			var function_entry: Dictionary = parse_function(signature, line_number)
			function_entry["end"] = function_end(lines, index, line_number)
			function_entry["doc"] = join_doc(pending_doc)
			functions.append(function_entry)
			pending_doc.clear()
			pending_export = false
			pending_onready = false
			continue
		pending_doc.clear()
	return {
		"path": repo_path(res_path),
		"class_name": class_value,
		"class_line": class_line,
		"extends": extends_value,
		"lines": lines.size(),
		"summary": header_summary(lines, header_end),
		"regions": regions,
		"enums": enums,
		"inner_classes": inner_classes,
		"signals": signals,
		"constants": constants,
		"exports": exports,
		"onready": onready,
		"variables": variables,
		"functions": functions,
		"refs": PackedStringArray(),
		"uses": PackedStringArray(),
	}


## Parses one .tscn into a summary plus its full node tree, so @onready paths and
## instanced scenes can be checked without opening the scene file.
static func parse_scene(res_path: String, text: String) -> Dictionary:
	var resources_by_id: Dictionary = {}
	var nodes: Array[Dictionary] = []
	var current_node: Dictionary = {}
	for raw_line: String in normalized_text(text).split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("[ext_resource"):
			var id_value: String = attribute(line, "id")
			var resource_path: String = attribute(line, "path")
			if not id_value.is_empty() and not resource_path.is_empty():
				resources_by_id[id_value] = resource_path
			continue
		if line.begins_with("[node"):
			var node: Dictionary = {
				"name": attribute(line, "name"),
				"type": attribute(line, "type"),
				"depth": node_depth(attribute(line, "parent")),
				"instance": "",
				"script": "",
			}
			var instance_id: String = extract_between(line, "instance=ExtResource(\"", "\")")
			if not instance_id.is_empty():
				node["instance"] = dict_string(resources_by_id, instance_id, instance_id)
			nodes.append(node)
			current_node = node
			continue
		if line.begins_with("["):
			current_node = {}
			continue
		if not current_node.is_empty() and line.begins_with("script ="):
			var reference: String = extract_between(line, "ExtResource(\"", "\")")
			current_node["script"] = dict_string(resources_by_id, reference, reference)
	var root_name: String = ""
	var root_type: String = ""
	var root_script: String = ""
	if not nodes.is_empty():
		var root: Dictionary = nodes[0]
		root_name = dict_string(root, "name")
		root_type = dict_string(root, "type")
		if root_type.is_empty():
			root_type = repo_path(dict_string(root, "instance"))
		root_script = dict_string(root, "script")
	var listed: Array[Dictionary] = []
	for node: Dictionary in nodes:
		listed.append({
			"depth": dict_int(node, "depth"),
			"name": dict_string(node, "name"),
			"type": dict_string(node, "type"),
			"instance": repo_path(dict_string(node, "instance")),
			"script": repo_path(dict_string(node, "script")),
		})
	return {
		"path": repo_path(res_path),
		"root_name": root_name,
		"root_type": root_type,
		"script": repo_path(root_script),
		"nodes": nodes.size(),
		"node_list": listed,
	}


## Depth of a .tscn node. The root carries no parent attribute; `parent="."` is a
## direct child of the root; every other parent path adds one level per segment,
## so `parent="HUD/Bar"` sits three levels below the scene root.
static func node_depth(parent_path: String) -> int:
	if parent_path.is_empty():
		return 0
	if parent_path == ".":
		return 1
	return parent_path.count("/") + 2


## Shape of one runtime data file, so balancing work rarely needs the JSON open.
static func parse_data_file(res_path: String, text: String) -> Dictionary:
	var normalized: String = normalized_text(text)
	var entry: Dictionary = {
		"path": repo_path(res_path),
		"bytes": normalized.length(),
		"lines": normalized.split("\n").size(),
		"shape": "invalid",
		"entries": 0,
		"keys": PackedStringArray(),
		"root_keys": PackedStringArray(),
	}
	var parsed: Variant = JSON.parse_string(normalized)
	if parsed is Dictionary:
		var mapping: Dictionary = parsed
		entry["shape"] = "object"
		entry["entries"] = mapping.size()
		entry["keys"] = collect_keys(mapping.values(), 0)
		entry["root_keys"] = keys_of(mapping.keys())
	elif parsed is Array:
		var items: Array = parsed
		entry["shape"] = "array"
		entry["entries"] = items.size()
		entry["keys"] = collect_keys(items, 0)
	return entry


## Records which `class_name` symbols and res:// paths each script touches, so a
## page can answer "what else do I have to check if I change this?".
##
## Two scans, because the two kinds of reference live in different places. A `res://`
## path only ever appears *inside* a quoted literal (`preload("res://...")`), so `refs`
## reads the comment-stripped text with the literals intact. A `class_name` reference is
## code, so `uses` reads that same text with the literals blanked out: without that, a
## tool's rule list, a fixture or a doc-example string that merely *names* a class (a
## reviewer's question about `GameState`, a scene path in `TRUNK_FILES`) would be
## recorded as a real dependency and quietly inflate the class's `Used by` fan-in.
static func apply_dependencies(infos: Array[Dictionary], texts: Dictionary, class_names: PackedStringArray) -> void:
	for info: Dictionary in infos:
		var repo_path_value: String = dict_string(info, "path")
		var code_text: String = strip_comments(dict_string(texts, "res://" + repo_path_value))
		var symbol_text: String = strip_literals(code_text)
		var own_class: String = dict_string(info, "class_name")
		var uses: PackedStringArray = PackedStringArray()
		for candidate: String in class_names:
			if candidate == own_class:
				continue
			if symbol_text.contains(candidate) and contains_word(symbol_text, candidate):
				uses.append(candidate)
		info["uses"] = uses
		info["refs"] = scan_resource_refs(code_text)


## Drops whole-line `#` comments, which keeps prose out of the dependency scan.
static func strip_comments(text: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


## Blanks every quoted literal (and a trailing `#` comment), so a dependency scan of the
## result only ever sees code. Offsets are preserved - a literal becomes spaces rather
## than disappearing - which keeps `contains_word` boundaries honest.
static func strip_literals(text: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		kept.append(line_without_literals(line))
	return "\n".join(kept)


## One line with its quoted literals and comment replaced by spaces.
static func line_without_literals(line: String) -> String:
	var out: String = ""
	var quote: String = ""
	var escaped: bool = false
	for index: int in range(line.length()):
		var character: String = line[index]
		if escaped:
			escaped = false
			out += " "
			continue
		if not quote.is_empty():
			if character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
			out += " "
			continue
		if character == "\"" or character == "'":
			quote = character
			out += " "
			continue
		if character == "#":
			break
		out += character
	return out


## Core/Card.gd -> Core/Card.md, relative to the directory holding the map.
static func script_page_file(repo_path_value: String) -> String:
	return repo_path_value.trim_suffix(".gd") + ".md"


## Scenes/BattleScene/BattleScene.tscn -> .../BattleScene.scene.md
static func scene_page_file(repo_path_value: String) -> String:
	return repo_path_value.trim_suffix(".tscn") + ".scene.md"


## `12` for a single line, `12-40` for a range.
static func line_range(record: Dictionary) -> String:
	var start_line: int = dict_int(record, "line")
	var end_line: int = dict_int(record, "end", start_line)
	if end_line <= start_line:
		return str(start_line)
	return "%d-%d" % [start_line, end_line]


## Type/argument/value suffix used by both the TSV rows and the detail pages.
static func declaration_detail(record: Dictionary, with_value: bool) -> String:
	var args_value: String = dict_string(record, "args")
	if not args_value.is_empty():
		return "(" + args_value + ")"
	var detail: String = ""
	var type_value: String = dict_string(record, "type")
	if not type_value.is_empty():
		detail = ": " + type_value
	if with_value:
		var value_text: String = dict_string(record, "value")
		if not value_text.is_empty() and value_text.length() <= 40:
			detail += " = " + value_text
	return detail


## A shorter role for the overview table only. The per-script page carries the full
## sentence; the overview has a hard byte budget it has to stay inside (see
## Tools/check_navigation.gd), and one line per script is what keeps it scannable as
## the project grows.
static func overview_role(role: String) -> String:
	if role.length() <= OVERVIEW_ROLE_CHARS:
		return role
	return role.substr(0, OVERVIEW_ROLE_CHARS).strip_edges() + "…"


## The map's "role" cell: the file's own header doc when it has one, otherwise a
## structural summary, so the column is never empty for a real file.
static func script_role(info: Dictionary) -> String:
	var summary: String = dict_string(info, "summary")
	if not summary.is_empty():
		return summary
	var parts: PackedStringArray = PackedStringArray()
	var extends_value: String = dict_string(info, "extends")
	if not extends_value.is_empty():
		parts.append("extends " + extends_value)
	var signal_count: int = dict_array(info, "signals").size()
	if signal_count > 0:
		parts.append("%d signal(s)" % signal_count)
	var export_count: int = dict_array(info, "exports").size()
	if export_count > 0:
		parts.append("%d export(s)" % export_count)
	parts.append("%d function(s)" % dict_array(info, "functions").size())
	return ", ".join(parts)
#endregion

#region Private Methods
static func dict_string(source: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = source.get(key, fallback)
	if value is String:
		var text: String = value
		return text
	return fallback


static func dict_int(source: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = source.get(key, fallback)
	if value is int:
		var number: int = value
		return number
	if value is float:
		var float_value: float = value
		return int(float_value)
	return fallback


static func dict_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		var listed: Array = value
		return listed
	return []


static func dict_string_array(source: Dictionary, key: String) -> PackedStringArray:
	var value: Variant = source.get(key, PackedStringArray())
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		return packed
	if value is Array:
		var listed: Array = value
		var result: PackedStringArray = PackedStringArray()
		for item: Variant in listed:
			result.append(str(item))
		return result
	return PackedStringArray()


static func dict_bool(source: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = source.get(key, fallback)
	if value is bool:
		var flag: bool = value
		return flag
	return fallback


## Last line of a function body: everything up to the next column-0 declaration,
## which is what makes `path:start-end` ranges safe to read directly.
static func function_end(lines: PackedStringArray, from_index: int, start_line: int) -> int:
	var end_line: int = start_line
	var cursor: int = from_index
	while cursor < lines.size():
		var raw: String = lines[cursor]
		if raw.begins_with("\t") or raw.begins_with(" "):
			end_line = cursor + 1
		elif not raw.strip_edges().is_empty():
			break
		cursor += 1
	return end_line


## End (0-based, exclusive) of the file's leading `##` block, or -1 when there is
## none. A `##` block that sits after a real declaration is a member's doc
## comment, not the file header, so it must not become the file's "role".
static func header_end_index(lines: PackedStringArray) -> int:
	var limit: int = mini(lines.size(), HEADER_SCAN_LINES)
	var start: int = -1
	for i: int in range(limit):
		if lines[i].begins_with("##"):
			start = i
			break
	if start < 0 or has_declaration_before(lines, start):
		return -1
	var end: int = start
	while end < lines.size() and lines[end].begins_with("##"):
		end += 1
	return end


## True when anything other than the class_name/extends preamble, an annotation,
## a comment or a blank line already appeared before `index`.
static func has_declaration_before(lines: PackedStringArray, index: int) -> bool:
	for i: int in range(index):
		var line: String = lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("class_name ") or line.begins_with("extends "):
			continue
		if line.begins_with("@") and not line.contains("var "):
			continue
		return true
	return false


static func header_summary(lines: PackedStringArray, header_end: int) -> String:
	if header_end <= 0:
		return ""
	var start: int = header_end
	while start > 0 and lines[start - 1].begins_with("##"):
		start -= 1
	var block: PackedStringArray = PackedStringArray()
	for i: int in range(start, header_end):
		block.append(doc_text(lines[i]))
	return join_doc(block)


static func doc_text(line: String) -> String:
	return line.substr(2).strip_edges()


## Joins a `##` block into one line, dropping empty lines and `@tag` metadata.
static func join_doc(doc: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for line: String in doc:
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("@"):
			continue
		parts.append(text)
	var joined: String = " ".join(parts)
	if joined.length() > MAX_DOC_CHARS:
		joined = joined.substr(0, MAX_DOC_CHARS).strip_edges() + "…"
	return joined


static func leading_identifier(text: String) -> String:
	var trimmed: String = text.strip_edges()
	var end_index: int = 0
	while end_index < trimmed.length() and is_identifier_char(trimmed[end_index]):
		end_index += 1
	return trimmed.substr(0, end_index)


static func is_identifier_char(character: String) -> bool:
	if character == "_":
		return true
	if character >= "a" and character <= "z":
		return true
	if character >= "A" and character <= "Z":
		return true
	return character >= "0" and character <= "9"


## Text between the first `prefix` and the next `suffix` after it, or "".
static func extract_between(text: String, prefix: String, suffix: String) -> String:
	var start: int = text.find(prefix)
	if start < 0:
		return ""
	start += prefix.length()
	var end: int = text.find(suffix, start)
	if end < 0:
		return ""
	return text.substr(start, end - start)


## Value of a `name="value"` attribute inside a .tscn header line, or "".
## The leading space keeps `id="..."` from matching inside `uid="..."`.
static func attribute(line: String, attribute_name: String) -> String:
	return extract_between(line, " " + attribute_name + "=\"", "\"")


static func parse_signal(line: String) -> Dictionary:
	var rest: String = line.substr("signal ".length()).strip_edges()
	var name_value: String = rest
	var args_value: String = ""
	var open_index: int = rest.find("(")
	if open_index >= 0:
		name_value = rest.substr(0, open_index)
		var close_index: int = rest.rfind(")")
		if close_index > open_index:
			args_value = rest.substr(open_index + 1, close_index - open_index - 1)
	return {
		"name": name_value.strip_edges(),
		"args": args_value.strip_edges(),
	}


static func parse_function(signature: String, line_number: int) -> Dictionary:
	var func_index: int = signature.find("func ")
	var rest: String = signature.substr(func_index + "func ".length()).strip_edges()
	var open_index: int = rest.find("(")
	var name_value: String = rest
	var args_value: String = ""
	if open_index >= 0:
		name_value = rest.substr(0, open_index)
		var close_index: int = rest.rfind(")")
		if close_index > open_index:
			args_value = rest.substr(open_index + 1, close_index - open_index - 1)
	var returns_value: String = ""
	var arrow_index: int = rest.find("->")
	if arrow_index >= 0:
		returns_value = rest.substr(arrow_index + 2).strip_edges()
		if returns_value.ends_with(":"):
			returns_value = returns_value.substr(0, returns_value.length() - 1).strip_edges()
	var clean_name: String = name_value.strip_edges()
	return {
		"name": clean_name,
		"args": args_value.strip_edges(),
		"returns": returns_value,
		"line": line_number,
		"static": signature.begins_with("static "),
		"private": clean_name.begins_with("_"),
		"doc": "",
	}


## Splits `var/const/static var NAME: TYPE = VALUE` into its three parts.
static func parse_named_declaration(line: String, keyword: String) -> Dictionary:
	var rest: String = line.substr(keyword.length()).strip_edges()
	var name_value: String = rest
	var type_value: String = ""
	var value_value: String = ""
	var colon_index: int = rest.find(":")
	var equals_index: int = rest.find("=")
	if colon_index >= 0 and (equals_index < 0 or colon_index < equals_index):
		name_value = rest.substr(0, colon_index)
		var tail: String = rest.substr(colon_index + 1)
		var tail_equals: int = tail.find("=")
		if tail_equals >= 0:
			type_value = tail.substr(0, tail_equals)
			value_value = tail.substr(tail_equals + 1)
		else:
			type_value = tail
	elif equals_index >= 0:
		name_value = rest.substr(0, equals_index)
		value_value = rest.substr(equals_index + 1)
	return {
		"name": name_value.strip_edges(),
		"type": type_value.strip_edges(),
		"value": value_value.strip_edges(),
	}


## Reads `enum Name { A, B = 3 }` in both the one-line and the block form.
## `next` is the 0-based index of the first line after the enum.
static func parse_enum(lines: PackedStringArray, start_index: int, header_line: String) -> Dictionary:
	var header: String = header_line.substr("enum ".length())
	var values: PackedStringArray = PackedStringArray()
	var buffer: String = header
	var cursor: int = start_index
	var finished: bool = false
	while cursor < lines.size() and not finished:
		var open_index: int = buffer.find("{")
		if open_index >= 0:
			var close_index: int = buffer.find("}", open_index)
			if close_index >= 0:
				values = enum_values(buffer.substr(open_index + 1, close_index - open_index - 1))
				finished = true
				break
		cursor += 1
		if cursor < lines.size():
			buffer = buffer + " " + lines[cursor].strip_edges()
	return {
		"name": leading_identifier(header),
		"values": values,
		"line": start_index + 1,
		"next": cursor + 1 if finished else lines.size(),
	}


static func enum_values(body: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for chunk: String in body.split(","):
		var text: String = chunk.strip_edges()
		var comment_index: int = text.find("#")
		if comment_index >= 0:
			text = text.substr(0, comment_index).strip_edges()
		var equals_index: int = text.find("=")
		if equals_index >= 0:
			text = text.substr(0, equals_index).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


## True once a (possibly wrapped) function header ends in `:` with balanced brackets.
static func signature_complete(signature: String) -> bool:
	var text: String = signature.strip_edges()
	if not text.ends_with(":"):
		return false
	var depth: int = 0
	for i: int in range(text.length()):
		var character: String = text[i]
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
	return depth == 0


static func is_resource_path_char(character: String) -> bool:
	return is_identifier_char(character) or character == "/" or character == "." or character == "-"


## Whole-word search, so `Unit` does not match `UnitUI`.
static func contains_word(text: String, word: String) -> bool:
	if word.is_empty():
		return false
	var from: int = 0
	while from < text.length():
		var found: int = text.find(word, from)
		if found < 0:
			return false
		var before_ok: bool = found == 0 or not is_identifier_char(text[found - 1])
		var after_index: int = found + word.length()
		var after_ok: bool = after_index >= text.length() or not is_identifier_char(text[after_index])
		if before_ok and after_ok:
			return true
		from = found + 1
	return false


## res:// paths referenced by a script (preload/load), deduplicated and without
## vendor paths. The scan starts after the `res://` scheme itself, otherwise the
## first token would stop at the `:` and report a path of `res`.
static func scan_resource_refs(text: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var cursor: int = 0
	while result.size() < MAX_REFS_LISTED:
		var found: int = text.find(RES_SCHEME, cursor)
		if found < 0:
			break
		var end_index: int = found + RES_SCHEME.length()
		while end_index < text.length() and is_resource_path_char(text[end_index]):
			end_index += 1
		var path_value: String = text.substr(found, end_index - found)
		if not result.has(path_value) and not path_value.begins_with("res://addons/"):
			result.append(path_value)
		cursor = maxi(end_index, found + 1)
	return result


## Union of the dictionary keys found in `values`, walking nested arrays and
## objects a few levels deep. Capped so a wide schema cannot bloat the map.
static func collect_keys(values: Array, depth: int) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	if depth > KEY_COLLECT_DEPTH:
		return keys
	for value: Variant in values:
		if value is Dictionary:
			var mapping: Dictionary = value
			for key: Variant in mapping.keys():
				keys.append(str(key))
			keys.append_array(collect_keys(mapping.values(), depth + 1))
		elif value is Array:
			var nested: Array = value
			keys.append_array(collect_keys(nested, depth + 1))
	return finalize_keys(keys)


## Stringifies raw JSON keys (object roots), then dedupes, sorts and caps them.
static func keys_of(raw_keys: Array) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in raw_keys:
		keys.append(str(key))
	return finalize_keys(keys)


static func finalize_keys(keys: PackedStringArray) -> PackedStringArray:
	var unique: PackedStringArray = PackedStringArray()
	for key: String in keys:
		if not unique.has(key):
			unique.append(key)
	unique.sort()
	if unique.size() > MAX_ITEM_KEYS:
		var capped: PackedStringArray = unique.slice(0, MAX_ITEM_KEYS)
		capped.append("(+%d more)" % [unique.size() - MAX_ITEM_KEYS])
		return capped
	return unique
#endregion
