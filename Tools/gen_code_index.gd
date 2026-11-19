extends SceneTree
## Headless symbol-index generator for this repository.
##
## Parses every first-party GDScript source and writes two artifacts that make
## the codebase navigable without reading the sources:
##
##   Docs/code_index.json  machine-readable index (symbol -> path:line)
##   Docs/CODEBASE_MAP.md  compact map of the same data, meant to be read first
##
## res://addons/, res://Trash/, res://bin/, res://reports/ and res://.godot/ are
## ignored, so only game code ends up in the index.
##
## Usage:
##   godot --headless --path . --script res://Tools/gen_code_index.gd
##   godot --headless --path . --script res://Tools/gen_code_index.gd -- --check
##
## --check never writes: it compares the committed artifacts against a fresh
## in-memory generation, so a stale map fails a gate instead of silently lying.
## The output is deterministic (sorted, no timestamps), which is what makes that
## comparison meaningful.
##
## Exit code 0 = artifacts written (or already up to date), 1 = write failure,
## stale artifact or missing source.
##
## @author TheGreatJellyfish
## @version 11/18/2026

#region Constants
## Bump when the shape of Docs/code_index.json changes.
const SCHEMA_VERSION: int = 1
const ROOT_DIR: String = "res://"
const DOCS_DIR: String = "res://Docs"
const INDEX_PATH: String = "res://Docs/code_index.json"
const MAP_PATH: String = "res://Docs/CODEBASE_MAP.md"
const EVENT_BUS_PATH: String = "res://Managers/EventBus.gd"
const DATA_JSON_DIR: String = "res://Data/json"
const GENERATOR_PATH: String = "res://Tools/gen_code_index.gd"
const GENERATE_COMMAND: String = "godot --headless --path . --script res://Tools/gen_code_index.gd"
const ARG_CHECK: String = "--check"
const ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"

## Folders that hold no first-party game code (vendor, scratch, generated output).
const EXCLUDED_DIRS: PackedStringArray = [
	"res://addons/",
	"res://.godot/",
	"res://reports/",
	"res://Trash/",
	"res://bin/",
]

## Caps that keep the generated map cheap to read.
const MAX_ITEM_KEYS: int = 24
const MAX_REGIONS_LISTED: int = 8
const MAX_DOC_CHARS: int = 160
const MAX_REFS_LISTED: int = 20
const HEADER_SCAN_LINES: int = 40
const KEY_COLLECT_DEPTH: int = 3
#endregion

#region Private Variables
var _script_paths: PackedStringArray = PackedStringArray()
var _scene_paths: PackedStringArray = PackedStringArray()
var _infos: Array[Dictionary] = []
var _texts: Dictionary = {}
var _class_names: PackedStringArray = PackedStringArray()
var _check_only: bool = false
#endregion

#region Lifecycle Methods
func _initialize() -> void:
	_check_only = ARG_CHECK in OS.get_cmdline_user_args()
	_collect(ROOT_DIR, ".gd", _script_paths)
	_collect(ROOT_DIR, ".tscn", _scene_paths)
	_script_paths.sort()
	_scene_paths.sort()
	for path: String in _script_paths:
		var text: String = _normalized_text(path)
		_texts[path] = text
		var info: Dictionary = _parse_script(path, text)
		_infos.append(info)
		var class_value: String = _dict_string(info, "class_name")
		if not class_value.is_empty():
			_class_names.append(class_value)
	_class_names.sort()
	_apply_dependencies()
	var global_signals: Array[Dictionary] = _collect_global_signals()
	var scenes: Array[Dictionary] = _collect_scenes()
	var data_files: Array[Dictionary] = _collect_data_files()
	var index_text: String = _render_index(global_signals, scenes, data_files)
	var map_text: String = _render_map(global_signals, scenes, data_files)
	if _check_only:
		quit(_report_staleness(index_text, map_text))
		return
	quit(_write_artifacts(index_text, map_text))
#endregion

#region Private Methods
func _collect(dir_path: String, extension: String, result: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var base: String = dir_path if dir_path.ends_with("/") else dir_path + "/"
	# Files directly in res:// are skipped on purpose: the project root only ever
	# holds editor scratch saves (e.g. a stray scene copy), and indexing those
	# would make the generated index differ between checkouts.
	var skip_files: bool = dir_path == ROOT_DIR
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			var child: String = base + entry + "/"
			if not _is_excluded(child):
				_collect(child, extension, result)
		elif not skip_files and entry.ends_with(extension):
			result.append(base + entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_excluded(dir_path: String) -> bool:
	for excluded: String in EXCLUDED_DIRS:
		if dir_path.begins_with(excluded):
			return true
	return false


func _normalized_text(res_path: String) -> String:
	var text: String = FileAccess.get_file_as_string(res_path)
	return text.replace("\r\n", "\n").replace("\r", "\n")


func _repo_path(res_path: String) -> String:
	if res_path.begins_with("res://"):
		return res_path.substr("res://".length())
	return res_path


func _write_text(res_path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(res_path, FileAccess.WRITE)
	if file == null:
		printerr("[code-index] cannot write %s (error %d)" % [res_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	return true


func _matches_artifact(res_path: String, expected: String) -> bool:
	if not FileAccess.file_exists(res_path):
		return false
	return _normalized_text(res_path) == expected


func _report_staleness(index_text: String, map_text: String) -> int:
	var stale: PackedStringArray = PackedStringArray()
	if not _matches_artifact(INDEX_PATH, index_text):
		stale.append(_repo_path(INDEX_PATH))
	if not _matches_artifact(MAP_PATH, map_text):
		stale.append(_repo_path(MAP_PATH))
	if stale.is_empty():
		print("[code-index] UP TO DATE: %s, %s" % [_repo_path(INDEX_PATH), _repo_path(MAP_PATH)])
		return 0
	var in_ci: bool = OS.get_environment(ENV_GITHUB_ACTIONS) == "true"
	for path_value: String in stale:
		printerr("[code-index] STALE: %s does not match the current sources" % path_value)
		if in_ci:
			printerr("::error file=%s,title=Code index::stale symbol index" % path_value)
	printerr("[code-index] regenerate with: %s" % GENERATE_COMMAND)
	return 1


func _write_artifacts(index_text: String, map_text: String) -> int:
	var error: Error = DirAccess.make_dir_recursive_absolute(DOCS_DIR)
	if error != OK and error != ERR_ALREADY_EXISTS:
		printerr("[code-index] cannot create %s (error %d)" % [DOCS_DIR, error])
		return 1
	if not _write_text(INDEX_PATH, index_text):
		return 1
	if not _write_text(MAP_PATH, map_text):
		return 1
	print("[code-index] wrote %s and %s (%d script(s), %d scene(s))" % [
		_repo_path(INDEX_PATH),
		_repo_path(MAP_PATH),
		_infos.size(),
		_scene_paths.size(),
	])
	return 0


## Parses one script into a flat record. Only top-level declarations (column 0)
## are indexed; function bodies and inner-class members are skipped on purpose,
## which keeps the map small enough to be worth reading.
func _parse_script(res_path: String, text: String) -> Dictionary:
	var lines: PackedStringArray = text.split("\n")
	var header_end: int = _header_end_index(lines)
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
				pending_doc.append(_doc_text(line))
			continue
		if line.begins_with("#region"):
			regions.append(line.substr("#region".length()).strip_edges())
			continue
		if line.begins_with("#"):
			continue
		if line.begins_with("class_name "):
			class_value = _leading_identifier(line.substr("class_name ".length()))
			class_line = line_number
			continue
		if line.begins_with("extends "):
			extends_value = line.substr("extends ".length()).strip_edges()
			continue
		if line.begins_with("class "):
			inner_classes.append({
				"name": _leading_identifier(line.substr("class ".length())),
				"extends": _extract_between(line, "extends ", ":"),
				"line": line_number,
			})
			pending_doc.clear()
			continue
		if line.begins_with("@export"):
			pending_export = true
			if line.contains("var "):
				var exported: Dictionary = _parse_named_declaration(line.substr(line.find("var ")), "var ")
				exported["line"] = line_number
				exported["doc"] = _join_doc(pending_doc)
				exports.append(exported)
				pending_doc.clear()
				pending_export = false
			continue
		if line.begins_with("@onready"):
			pending_onready = true
			if line.contains("var "):
				var wired: Dictionary = _parse_named_declaration(line.substr(line.find("var ")), "var ")
				wired["line"] = line_number
				wired["doc"] = _join_doc(pending_doc)
				onready.append(wired)
				pending_doc.clear()
				pending_onready = false
			continue
		if line.begins_with("@"):
			pending_export = false
			pending_onready = false
			continue
		if line.begins_with("signal "):
			var signal_entry: Dictionary = _parse_signal(line)
			signal_entry["line"] = line_number
			signal_entry["doc"] = _join_doc(pending_doc)
			signals.append(signal_entry)
			pending_doc.clear()
			continue
		if line.begins_with("const "):
			var const_entry: Dictionary = _parse_named_declaration(line, "const ")
			const_entry["line"] = line_number
			const_entry["doc"] = _join_doc(pending_doc)
			constants.append(const_entry)
			pending_doc.clear()
			continue
		if line.begins_with("enum "):
			var enum_entry: Dictionary = _parse_enum(lines, line_number - 1, line)
			index = _dict_int(enum_entry, "next", index)
			enum_entry.erase("next")
			enums.append(enum_entry)
			pending_doc.clear()
			continue
		if line.begins_with("var ") or line.begins_with("static var "):
			var keyword: String = "var " if line.begins_with("var ") else "static var "
			var variable_entry: Dictionary = _parse_named_declaration(line, keyword)
			variable_entry["line"] = line_number
			variable_entry["doc"] = _join_doc(pending_doc)
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
			while not _signature_complete(signature) and index < lines.size():
				signature = signature + " " + lines[index].strip_edges()
				index += 1
			var function_entry: Dictionary = _parse_function(signature, line_number)
			function_entry["doc"] = _join_doc(pending_doc)
			functions.append(function_entry)
			pending_doc.clear()
			pending_export = false
			pending_onready = false
			continue
		pending_doc.clear()
	return {
		"path": _repo_path(res_path),
		"class_name": class_value,
		"class_line": class_line,
		"extends": extends_value,
		"lines": lines.size(),
		"summary": _header_summary(lines, header_end),
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


## Index (0-based, exclusive) of the end of the file's leading `##` block, or -1.
func _header_end_index(lines: PackedStringArray) -> int:
	var limit: int = mini(lines.size(), HEADER_SCAN_LINES)
	var start: int = -1
	for i: int in range(limit):
		if lines[i].begins_with("##"):
			start = i
			break
	if start < 0:
		return -1
	var end: int = start
	while end < lines.size() and lines[end].begins_with("##"):
		end += 1
	return end


func _header_summary(lines: PackedStringArray, header_end: int) -> String:
	if header_end <= 0:
		return ""
	var start: int = header_end
	while start > 0 and lines[start - 1].begins_with("##"):
		start -= 1
	var block: PackedStringArray = PackedStringArray()
	for i: int in range(start, header_end):
		block.append(_doc_text(lines[i]))
	return _join_doc(block)


func _doc_text(line: String) -> String:
	return line.substr(2).strip_edges()


## Joins a `##` block into one line, dropping empty lines and `@tag` metadata.
func _join_doc(doc: PackedStringArray) -> String:
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


func _leading_identifier(text: String) -> String:
	var trimmed: String = text.strip_edges()
	var end_index: int = 0
	while end_index < trimmed.length() and _is_identifier_char(trimmed[end_index]):
		end_index += 1
	return trimmed.substr(0, end_index)


func _is_identifier_char(character: String) -> bool:
	if character == "_":
		return true
	if character >= "a" and character <= "z":
		return true
	if character >= "A" and character <= "Z":
		return true
	return character >= "0" and character <= "9"


## Text between the first `prefix` and the next `suffix` after it, or "".
func _extract_between(text: String, prefix: String, suffix: String) -> String:
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
func _attribute(line: String, attribute_name: String) -> String:
	return _extract_between(line, " " + attribute_name + "=\"", "\"")


func _parse_signal(line: String) -> Dictionary:
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


func _parse_function(signature: String, line_number: int) -> Dictionary:
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
func _parse_named_declaration(line: String, keyword: String) -> Dictionary:
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
func _parse_enum(lines: PackedStringArray, start_index: int, header_line: String) -> Dictionary:
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
				values = _enum_values(buffer.substr(open_index + 1, close_index - open_index - 1))
				finished = true
				break
		cursor += 1
		if cursor < lines.size():
			buffer = buffer + " " + lines[cursor].strip_edges()
	return {
		"name": _leading_identifier(header),
		"values": values,
		"line": start_index + 1,
		"next": cursor + 1 if finished else lines.size(),
	}


func _enum_values(body: String) -> PackedStringArray:
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
func _signature_complete(signature: String) -> bool:
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


func _is_resource_path_char(character: String) -> bool:
	return _is_identifier_char(character) or character == "/" or character == "." or character == "-"


## Whole-word search, so `Unit` does not match `UnitUI`.
func _contains_word(text: String, word: String) -> bool:
	if word.is_empty():
		return false
	var from: int = 0
	while from < text.length():
		var found: int = text.find(word, from)
		if found < 0:
			return false
		var before_ok: bool = found == 0 or not _is_identifier_char(text[found - 1])
		var after_index: int = found + word.length()
		var after_ok: bool = after_index >= text.length() or not _is_identifier_char(text[after_index])
		if before_ok and after_ok:
			return true
		from = found + 1
	return false


func _find_info(res_path: String) -> Dictionary:
	var wanted: String = _repo_path(res_path)
	for info: Dictionary in _infos:
		if _dict_string(info, "path") == wanted:
			return info
	return {}


## Records which `class_name` symbols and res:// paths each script touches, so
## the map can answer "what else do I have to check if I change this?".
func _apply_dependencies() -> void:
	for info: Dictionary in _infos:
		var repo_path_value: String = _dict_string(info, "path")
		var text: String = _dict_string(_texts, "res://" + repo_path_value)
		var own_class: String = _dict_string(info, "class_name")
		var uses: PackedStringArray = PackedStringArray()
		for candidate: String in _class_names:
			if candidate == own_class:
				continue
			if text.contains(candidate) and _contains_word(text, candidate):
				uses.append(candidate)
		info["uses"] = uses
		info["refs"] = _scan_resource_refs(text)


func _scan_resource_refs(text: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var cursor: int = 0
	while result.size() < MAX_REFS_LISTED:
		var found: int = text.find("res://", cursor)
		if found < 0:
			break
		var end_index: int = found
		while end_index < text.length() and _is_resource_path_char(text[end_index]):
			end_index += 1
		var path_value: String = text.substr(found, end_index - found)
		if not result.has(path_value) and not path_value.begins_with("res://addons/"):
			result.append(path_value)
		cursor = maxi(end_index, found + 1)
	return result


## symbol -> ["path:line", ...] for classes, signals, constants, vars, functions.
func _build_symbol_table() -> Dictionary:
	var table: Dictionary = {}
	for info: Dictionary in _infos:
		var path_value: String = _dict_string(info, "path")
		var class_value: String = _dict_string(info, "class_name")
		if not class_value.is_empty():
			_add_symbol(table, class_value, path_value, _dict_int(info, "class_line"))
		_add_symbol_list(table, _dict_array(info, "signals"), path_value)
		_add_symbol_list(table, _dict_array(info, "constants"), path_value)
		_add_symbol_list(table, _dict_array(info, "variables"), path_value)
		_add_symbol_list(table, _dict_array(info, "functions"), path_value)
	return table


func _add_symbol_list(table: Dictionary, entries: Array, path_value: String) -> void:
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var record: Dictionary = entry
		_add_symbol(table, _dict_string(record, "name"), path_value, _dict_int(record, "line"))


func _add_symbol(table: Dictionary, symbol: String, path_value: String, line: int) -> void:
	if symbol.is_empty():
		return
	var location: String = "%s:%d" % [path_value, line]
	var existing: Variant = table.get(symbol, PackedStringArray())
	if not (existing is PackedStringArray):
		return
	var locations: PackedStringArray = existing
	if not locations.has(location):
		locations.append(location)
	table[symbol] = locations


## class_name -> scripts that reference it (reverse of each script's `uses`).
func _build_used_by() -> Dictionary:
	var table: Dictionary = {}
	for info: Dictionary in _infos:
		var path_value: String = _dict_string(info, "path")
		for used: String in _dict_string_array(info, "uses"):
			var existing: Variant = table.get(used, PackedStringArray())
			if not (existing is PackedStringArray):
				continue
			var users: PackedStringArray = existing
			if not users.has(path_value):
				users.append(path_value)
			table[used] = users
	return table


func _dict_string(source: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = source.get(key, fallback)
	if value is String:
		var text: String = value
		return text
	return fallback


func _dict_int(source: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = source.get(key, fallback)
	if value is int:
		var number: int = value
		return number
	if value is float:
		var float_value: float = value
		return int(float_value)
	return fallback


func _dict_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		var listed: Array = value
		return listed
	return []


func _dict_string_array(source: Dictionary, key: String) -> PackedStringArray:
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


## Escapes a value so it cannot break the markdown table it is rendered into.
func _cell(text: String) -> String:
	return text.replace("|", "\\|").replace("\n", " ").strip_edges()


func _join_paths(values: PackedStringArray) -> String:
	if values.is_empty():
		return "—"
	return ", ".join(values)


func _compact_regions(regions: PackedStringArray) -> String:
	if regions.size() <= MAX_REGIONS_LISTED:
		return " · ".join(regions)
	var head: PackedStringArray = regions.slice(0, MAX_REGIONS_LISTED)
	return " · ".join(head) + " · (+%d more)" % [regions.size() - MAX_REGIONS_LISTED]


## Every EventBus signal with the scripts that emit it and the scripts that
## listen to it: the fastest way to see the blast radius of a signal change.
func _collect_global_signals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bus_info: Dictionary = _find_info(EVENT_BUS_PATH)
	if bus_info.is_empty():
		return result
	for declared: Variant in _dict_array(bus_info, "signals"):
		if not (declared is Dictionary):
			continue
		var signal_entry: Dictionary = declared
		var signal_name: String = _dict_string(signal_entry, "name")
		if signal_name.is_empty():
			continue
		var emitters: PackedStringArray = PackedStringArray()
		var listeners: PackedStringArray = PackedStringArray()
		var pattern: String = "EventBus." + signal_name
		for info: Dictionary in _infos:
			var path_value: String = _dict_string(info, "path")
			var text: String = _dict_string(_texts, "res://" + path_value)
			if not text.contains(pattern):
				continue
			if text.contains(pattern + ".emit("):
				emitters.append(path_value)
			if text.contains(pattern + ".connect("):
				listeners.append(path_value)
		result.append({
			"signal": signal_name,
			"args": _dict_string(signal_entry, "args"),
			"emitters": emitters,
			"listeners": listeners,
		})
	return result


func _collect_scenes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for res_path: String in _scene_paths:
		var text: String = _normalized_text(res_path)
		var scripts_by_id: Dictionary = {}
		var node_count: int = 0
		var root_name: String = ""
		var root_type: String = ""
		var root_script: String = ""
		var in_root: bool = false
		for raw_line: String in text.split("\n"):
			var line: String = raw_line.strip_edges()
			if line.begins_with("[ext_resource"):
				var id_value: String = _attribute(line, "id")
				var script_path: String = _attribute(line, "path")
				if not id_value.is_empty() and not script_path.is_empty():
					scripts_by_id[id_value] = script_path
				continue
			if line.begins_with("[node"):
				node_count += 1
				in_root = node_count == 1
				if in_root:
					root_name = _attribute(line, "name")
					root_type = _attribute(line, "type")
					if root_type.is_empty():
						root_type = _extract_between(line, "instance=", ")")
				continue
			if line.begins_with("["):
				in_root = false
				continue
			if in_root and line.begins_with("script ="):
				var reference: String = _extract_between(line, "ExtResource(\"", "\")")
				root_script = _dict_string(scripts_by_id, reference, reference)
		result.append({
			"path": _repo_path(res_path),
			"root_name": root_name,
			"root_type": root_type,
			"script": _repo_path(root_script),
			"nodes": node_count,
		})
	return result


## Shape of every runtime data file, so balancing work rarely needs the JSON open.
func _collect_data_files() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var paths: PackedStringArray = PackedStringArray()
	_collect(DATA_JSON_DIR, ".json", paths)
	paths.sort()
	for res_path: String in paths:
		var text: String = _normalized_text(res_path)
		var entry: Dictionary = {
			"path": _repo_path(res_path),
			"bytes": text.length(),
			"lines": text.split("\n").size(),
			"shape": "invalid",
			"entries": 0,
			"keys": PackedStringArray(),
			"root_keys": PackedStringArray(),
		}
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			var mapping: Dictionary = parsed
			entry["shape"] = "object"
			entry["entries"] = mapping.size()
			entry["keys"] = _collect_keys(mapping.values(), 0)
			entry["root_keys"] = _keys_of(mapping.keys())
		elif parsed is Array:
			var items: Array = parsed
			entry["shape"] = "array"
			entry["entries"] = items.size()
			entry["keys"] = _collect_keys(items, 0)
		result.append(entry)
	return result


## Union of the dictionary keys found in `values`, walking nested arrays and
## objects a few levels deep. Capped so a wide schema cannot bloat the map.
func _collect_keys(values: Array, depth: int) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	if depth > KEY_COLLECT_DEPTH:
		return keys
	for value: Variant in values:
		if value is Dictionary:
			var mapping: Dictionary = value
			for key: Variant in mapping.keys():
				keys.append(str(key))
			keys.append_array(_collect_keys(mapping.values(), depth + 1))
		elif value is Array:
			var nested: Array = value
			keys.append_array(_collect_keys(nested, depth + 1))
	return _finalize_keys(keys)


## Stringifies raw JSON keys (object roots), then dedupes, sorts and caps them.
func _keys_of(raw_keys: Array) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in raw_keys:
		keys.append(str(key))
	return _finalize_keys(keys)


func _finalize_keys(keys: PackedStringArray) -> PackedStringArray:
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


func _render_index(global_signals: Array[Dictionary], scenes: Array[Dictionary], data_files: Array[Dictionary]) -> String:
	var root: Dictionary = {
		"schema": SCHEMA_VERSION,
		"generator": _repo_path(GENERATOR_PATH),
		"check_command": GENERATE_COMMAND + " -- --check",
		"counts": {
			"scripts": _infos.size(),
			"scenes": scenes.size(),
			"data_files": data_files.size(),
		},
		"scripts": _infos,
		"symbols": _build_symbol_table(),
		"global_signals": global_signals,
		"scenes": scenes,
		"data": data_files,
	}
	return JSON.stringify(root, "  ") + "\n"


func _render_map(global_signals: Array[Dictionary], scenes: Array[Dictionary], data_files: Array[Dictionary]) -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("# Codebase Map — Hololive: The Prophecy")
	out.append("")
	out.append("<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd from the first-party sources. -->")
	out.append("")
	out.append("Refresh it after changing any first-party script, scene or data file:")
	out.append("")
	out.append("```powershell")
	out.append(GENERATE_COMMAND)
	out.append("```")
	out.append("")
	out.append("Staleness gate (the same check Tools/preflight.ps1 and CI run; exits 1 when stale):")
	out.append("")
	out.append("```powershell")
	out.append(GENERATE_COMMAND + " -- --check")
	out.append("```")
	out.append("")
	out.append("## How to use this map (read this, not the whole repo)")
	out.append("")
	out.append("- **One-screen overview:** section 1 lists every first-party script with its `class_name`, size and role.")
	out.append("- **Find a symbol:** `rg -n '\"my_symbol\"' Docs/code_index.json` gives every `path:line` definition.")
	out.append("- **Impact of a change:** section 2 carries `Uses` / `Used by` per script; section 3 shows who emits and who listens to each `EventBus` signal.")
	out.append("- **Balancing:** section 5 lists each JSON file's shape, entry count and per-entry keys, so the file rarely has to be opened.")
	out.append("- Open a source file only for the specific line range the index points at.")
	out.append("")
	_append_overview(out)
	_append_details(out)
	_append_signals(out, global_signals)
	_append_scenes(out, scenes)
	_append_data(out, data_files)
	out.append("---")
	out.append("")
	out.append("Indexed %d script(s), %d scene(s), %d data file(s); %d indexed symbol(s)." % [
		_infos.size(),
		scenes.size(),
		data_files.size(),
		_build_symbol_table().size(),
	])
	return "\n".join(out) + "\n"


## Section 1: the one-screen overview that replaces opening files to orient.
func _append_overview(out: PackedStringArray) -> void:
	out.append("## 1. Scripts at a glance (%d)" % [_infos.size()])
	out.append("")
	out.append("| Script | class_name | lines | role |")
	out.append("| --- | --- | --- | --- |")
	for info: Dictionary in _infos:
		var class_value: String = _dict_string(info, "class_name")
		var class_cell: String = "—"
		if not class_value.is_empty():
			class_cell = "`" + class_value + "`"
		out.append("| `%s` | %s | %d | %s |" % [
			_dict_string(info, "path"),
			class_cell,
			_dict_int(info, "lines"),
			_cell(_dict_string(info, "summary")),
		])
	out.append("")


func _append_details(out: PackedStringArray) -> void:
	var used_by: Dictionary = _build_used_by()
	out.append("## 2. Script details")
	out.append("")
	for info: Dictionary in _infos:
		_append_script_detail(out, info, used_by)


func _append_script_detail(out: PackedStringArray, info: Dictionary, used_by: Dictionary) -> void:
	var class_value: String = _dict_string(info, "class_name")
	var extends_value: String = _dict_string(info, "extends")
	var title: String = "### `%s`" % _dict_string(info, "path")
	if not class_value.is_empty():
		title += " — `class_name %s`" % class_value
	if not extends_value.is_empty():
		title += " extends `%s`" % extends_value
	out.append(title + (" · %d lines" % _dict_int(info, "lines")))
	var summary: String = _dict_string(info, "summary")
	if not summary.is_empty():
		out.append("")
		out.append("> " + _cell(summary))
	var regions: PackedStringArray = _dict_string_array(info, "regions")
	if not regions.is_empty():
		out.append("")
		out.append("Sections: " + _compact_regions(regions))
	for entry: Variant in _dict_array(info, "enums"):
		if not (entry is Dictionary):
			continue
		var enum_entry: Dictionary = entry
		out.append("- L%d `enum %s` = %s" % [
			_dict_int(enum_entry, "line"),
			_dict_string(enum_entry, "name"),
			_join_paths(_dict_string_array(enum_entry, "values")),
		])
	for entry: Variant in _dict_array(info, "inner_classes"):
		if not (entry is Dictionary):
			continue
		var inner: Dictionary = entry
		out.append("- L%d `class %s extends %s` (members not indexed)" % [
			_dict_int(inner, "line"),
			_dict_string(inner, "name"),
			_dict_string(inner, "extends"),
		])
	_append_declarations(out, "Signals", _dict_array(info, "signals"), false)
	_append_declarations(out, "Constants", _dict_array(info, "constants"), true)
	_append_declarations(out, "Exports", _dict_array(info, "exports"), true)
	_append_declarations(out, "Onready", _dict_array(info, "onready"), false)
	_append_declarations(out, "State", _dict_array(info, "variables"), true)
	_append_functions(out, _dict_array(info, "functions"))
	out.append("")
	out.append("Uses: " + _join_paths(_dict_string_array(info, "uses")))
	out.append("Used by: " + _join_paths(_dict_string_array(used_by, class_value)))
	out.append("Loads: " + _join_paths(_dict_string_array(info, "refs")))
	out.append("")


func _append_declarations(out: PackedStringArray, label: String, entries: Array, with_value: bool) -> void:
	if entries.is_empty():
		return
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var record: Dictionary = entry
		var text: String = _declaration_text(record, with_value)
		if not text.is_empty():
			parts.append(text)
	if parts.is_empty():
		return
	out.append("")
	out.append(label + ":")
	for part: String in parts:
		out.append("- " + part)


func _declaration_text(record: Dictionary, with_value: bool) -> String:
	var name_value: String = _dict_string(record, "name")
	if name_value.is_empty():
		return ""
	var type_value: String = _dict_string(record, "type")
	var args_value: String = _dict_string(record, "args")
	var text: String = "L%d `%s" % [_dict_int(record, "line"), name_value]
	if not type_value.is_empty():
		text += ": " + type_value
	if not args_value.is_empty():
		text += "(" + args_value + ")"
	text += "`"
	if with_value:
		var value_text: String = _dict_string(record, "value")
		if not value_text.is_empty() and value_text.length() <= 40:
			text += " = `" + _cell(value_text) + "`"
	var doc_text: String = _dict_string(record, "doc")
	if not doc_text.is_empty():
		text += " — " + _cell(doc_text)
	return text


## Public functions keep their full signature; private ones are listed as
## `name + line` only, which is enough to jump straight to the implementation.
func _append_functions(out: PackedStringArray, functions: Array) -> void:
	if functions.is_empty():
		return
	var public_parts: PackedStringArray = PackedStringArray()
	var private_parts: PackedStringArray = PackedStringArray()
	for entry: Variant in functions:
		if not (entry is Dictionary):
			continue
		var record: Dictionary = entry
		var name_value: String = _dict_string(record, "name")
		if name_value.is_empty():
			continue
		if _dict_bool(record, "private"):
			private_parts.append("L%d `%s`" % [_dict_int(record, "line"), name_value])
			continue
		var text: String = "L%d `" % _dict_int(record, "line")
		if _dict_bool(record, "static"):
			text += "static "
		text += name_value + "(" + _dict_string(record, "args") + ")"
		var returns_value: String = _dict_string(record, "returns")
		if not returns_value.is_empty():
			text += " -> " + returns_value
		text += "`"
		var doc_text: String = _dict_string(record, "doc")
		if not doc_text.is_empty():
			text += " — " + _cell(doc_text)
		public_parts.append(text)
	if not public_parts.is_empty():
		out.append("")
		out.append("Public API:")
		for part: String in public_parts:
			out.append("- " + part)
	if not private_parts.is_empty():
		out.append("")
		out.append("Private:")
		for part: String in private_parts:
			out.append("- " + part)


func _dict_bool(source: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = source.get(key, fallback)
	if value is bool:
		var flag: bool = value
		return flag
	return fallback


## Section 3: the EventBus contract, with both ends of every signal.
func _append_signals(out: PackedStringArray, global_signals: Array[Dictionary]) -> void:
	out.append("## 3. Global signals (Managers/EventBus.gd)")
	out.append("")
	if global_signals.is_empty():
		out.append("No EventBus signals indexed.")
		out.append("")
		return
	out.append("| signal | args | emitted by | listened by |")
	out.append("| --- | --- | --- | --- |")
	for entry: Dictionary in global_signals:
		out.append("| `%s` | %s | %s | %s |" % [
			_dict_string(entry, "signal"),
			_cell(_dict_string(entry, "args")),
			_cell(_join_paths(_dict_string_array(entry, "emitters"))),
			_cell(_join_paths(_dict_string_array(entry, "listeners"))),
		])
	out.append("")


func _append_scenes(out: PackedStringArray, scenes: Array[Dictionary]) -> void:
	out.append("## 4. Scenes (%d)" % [scenes.size()])
	out.append("")
	out.append("| scene | root | nodes | script |")
	out.append("| --- | --- | --- | --- |")
	for entry: Dictionary in scenes:
		var script_value: String = _dict_string(entry, "script")
		var script_cell: String = "—"
		if not script_value.is_empty():
			script_cell = "`" + script_value + "`"
		out.append("| `%s` | %s `%s` | %d | %s |" % [
			_dict_string(entry, "path"),
			_dict_string(entry, "root_name"),
			_dict_string(entry, "root_type"),
			_dict_int(entry, "nodes"),
			script_cell,
		])
	out.append("")


func _append_data(out: PackedStringArray, data_files: Array[Dictionary]) -> void:
	out.append("## 5. Game data (Data/json)")
	out.append("")
	out.append("| file | shape | entries | per-entry keys |")
	out.append("| --- | --- | --- | --- |")
	for entry: Dictionary in data_files:
		out.append("| `%s` | %s | %d | %s |" % [
			_dict_string(entry, "path"),
			_dict_string(entry, "shape"),
			_dict_int(entry, "entries"),
			_cell(_join_paths(_dict_string_array(entry, "keys"))),
		])
	out.append("")
	var root_lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in data_files:
		var root_keys: PackedStringArray = _dict_string_array(entry, "root_keys")
		if not root_keys.is_empty():
			root_lines.append("- `%s`: %s" % [_dict_string(entry, "path"), _join_paths(root_keys)])
	if not root_lines.is_empty():
		out.append("Top-level keys:")
		for line: String in root_lines:
			out.append(line)
		out.append("")
#endregion
