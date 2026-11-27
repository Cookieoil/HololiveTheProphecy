class_name DiffReviewParser
extends RefCounted
## Pure review layer behind Tools/review_diff.gd.
##
## Every function takes a unified diff as text and returns plain Dictionaries:
## no file system access, no git, no printing. That keeps the rules unit-testable
## against fixtures in GDTest/DiffReviewTest.gd, the same way CodeIndexParser keeps
## the generated map honest.
##
## The reviewer is deliberately *advisory*: the hard gates (Tools/line_godot_slop.py,
## the test suite, the data validator) already block. What a diff adds is the
## reviewer's context - which files this change touches, which new API surface it
## exposes and whether a behaviour change came with a test - so a human (or the next
## agent) starts from a summary instead of a raw diff. `--strict` promotes the
## high-signal rules to blocking for a local pre-push run.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Constants
const TEST_DIR: String = "GDTest/"
const TOOLS_DIR: String = "Tools/"
const CORE_DIR: String = "Core/"
const DATA_DIR: String = "Data/"
const SCRIPT_SUFFIX: String = ".gd"
const SCENE_SUFFIX: String = ".tscn"
## Cap the report: the point is to lower review cost, not add to it.
const MAX_REPORTED_FINDINGS: int = 30
## A diff this large cannot be reviewed properly in one pass; split it.
const MAX_CHANGED_LINES: int = 400
## Rules that `--strict` turns into failures. `untested_change` is deliberately not
## here: this repo names suites by behaviour (GDTest/TelemetryTest.gd covers
## GameManager, GDTest/UiSnapshotTest.gd covers BattleScene), so a filename match
## would fail a change that is in fact covered. It stays advisory, for a human.
const STRICT_RULES: Array[String] = [
	"undocumented_api",
	"core_purity",
]
## Banned patterns, mirrored from Tools/line_godot_slop.py but reported on the exact
## added line so the comment points at the spot. The lint gate remains the blocker.
const BANNED_PATTERNS: Array[String] = [
	"create_timer(",
	"await get_tree().process_frame",
	"get_node(\"..\"",
	"get_node('..'",
]
## Core/ is the pure-logic layer; a Node type there cannot be tested headlessly.
const CORE_NODE_TYPES: Array[String] = [
	"Node", "Node2D", "Node3D", "Control", "SceneTree", "CanvasItem",
]
const MARKER_TODO: String = "TODO"
const MARKER_FIXME: String = "FIXME"
#endregion

#region Public Methods
## Parses a unified diff into one record per file:
## `{path, entries, added, removed, is_new, is_deleted}` where `entries` is an
## ordered list of `{kind, text, line}` (kind is "added", "removed" or "context"),
## so context-aware rules can look at the line before an added one.
static func parse_diff(diff_text: String) -> Array[Dictionary]:
	var files: Array[Dictionary] = []
	var current: Dictionary = {}
	var new_line: int = 0
	var old_path: String = ""
	for raw: String in CodeIndexParser.normalized_text(diff_text).split("\n"):
		if raw.begins_with("--- "):
			old_path = _diff_path(raw.substr(4))
			continue
		if raw.begins_with("+++ "):
			current = _start_file(raw, old_path)
			files.append(current)
			continue
		if raw.begins_with("@@"):
			new_line = hunk_start_line(raw)
			continue
		if current.is_empty():
			continue
		if _is_diff_header(raw):
			continue
		if raw.begins_with("+"):
			_append_entry(current, "added", raw.substr(1), new_line)
			new_line += 1
		elif raw.begins_with("-"):
			_append_entry(current, "removed", raw.substr(1), 0)
		elif raw.begins_with(" "):
			_append_entry(current, "context", raw.substr(1), new_line)
			new_line += 1
	return files


## The new-file line number the hunk starts at: `@@ -3,7 +9,4 @@` -> 9.
static func hunk_start_line(header: String) -> int:
	var plus_index: int = header.find("+")
	if plus_index < 0:
		return 0
	var text: String = header.substr(plus_index + 1)
	var end_index: int = text.find(" ")
	if end_index >= 0:
		text = text.substr(0, end_index)
	var comma_index: int = text.find(",")
	if comma_index >= 0:
		text = text.substr(0, comma_index)
	if not text.is_valid_int():
		return 0
	return text.to_int()


## Reviews a diff and returns `{files, changed_paths, blocking, advisory, stats}`.
## `options` accepts `strict: bool` and `known_large_files: PackedStringArray`.
static func review(diff_text: String, options: Dictionary = {}) -> Dictionary:
	var files: Array[Dictionary] = parse_diff(diff_text)
	var advisory: Array[Dictionary] = []
	var changed: PackedStringArray = PackedStringArray()
	for file: Dictionary in files:
		var path_value: String = CodeIndexParser.dict_string(file, "path")
		if path_value.is_empty():
			continue
		changed.append(path_value)
		advisory.append_array(_line_findings(file))
		var risk: Dictionary = _risk_finding(file, options)
		if not risk.is_empty():
			advisory.append(risk)
	advisory.append_array(_change_findings(changed, files))
	var result: Dictionary = {
		"files": files,
		"changed_paths": changed,
		"blocking": [],
		"advisory": advisory,
		"stats": _stats(files, changed),
	}
	if CodeIndexParser.dict_bool(options, "strict"):
		_promote_strict(result)
	return result


## True when the report has anything a reviewer should look at.
static func has_findings(result: Dictionary) -> bool:
	return not CodeIndexParser.dict_array(result, "blocking").is_empty() \
		or not CodeIndexParser.dict_array(result, "advisory").is_empty()


## How many findings would fail the run.
static func blocking_count(result: Dictionary) -> int:
	return CodeIndexParser.dict_array(result, "blocking").size()


## 1 when the report would fail, 0 otherwise. Advisory findings never fail; only
## what `--strict` promoted (or a rule that is inherently blocking) does.
static func exit_code(result: Dictionary) -> int:
	return 1 if blocking_count(result) > 0 else 0


## Compact markdown for a pull-request comment: a summary line, then one table row
## per finding, so the whole review fits in a screenful.
static func format_markdown(result: Dictionary) -> String:
	var stats: Dictionary = _dict(result.get("stats"))
	var blocking: Array = CodeIndexParser.dict_array(result, "blocking")
	var advisory: Array = CodeIndexParser.dict_array(result, "advisory")
	var out: PackedStringArray = PackedStringArray()
	out.append("### Second-pass review")
	out.append("")
	out.append("%d file(s) changed, +%d / -%d lines." % [
		CodeIndexParser.dict_int(stats, "file_count"),
		CodeIndexParser.dict_int(stats, "added"),
		CodeIndexParser.dict_int(stats, "removed"),
	])
	out.append("")
	out.append("| area | files |")
	out.append("| --- | --- |")
	for area: String in ["game", "tests", "tools", "data", "docs", "other"]:
		out.append("| %s | %d |" % [area, CodeIndexParser.dict_int(stats, area)])
	out.append("")
	out.append_array(_markdown_section("Blocking", blocking))
	out.append_array(_markdown_section("Review-worthy", advisory))
	return "\n".join(out).strip_edges() + "\n"


## Plain text for a terminal run.
static func format_text(result: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	for section: String in ["blocking", "advisory"]:
		for raw: Variant in CodeIndexParser.dict_array(result, section):
			var finding: Dictionary = _dict(raw)
			out.append("[%s] %s  %s  %s" % [
				section,
				CodeIndexParser.dict_string(finding, "rule"),
				CodeIndexParser.dict_string(finding, "where"),
				CodeIndexParser.dict_string(finding, "detail"),
			])
	if out.is_empty():
		return "No review-worthy findings.\n"
	return "\n".join(out) + "\n"
#endregion

#region Private Methods
static func _markdown_section(title: String, findings: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if findings.is_empty():
		return out
	out.append("#### %s (%d)" % [title, findings.size()])
	out.append("")
	out.append("| rule | where | detail |")
	out.append("| --- | --- | --- |")
	for raw: Variant in findings:
		var finding: Dictionary = _dict(raw)
		out.append("| `%s` | `%s` | %s |" % [
			CodeIndexParser.dict_string(finding, "rule"),
			CodeIndexParser.dict_string(finding, "where"),
			CodeIndexParser.dict_string(finding, "detail").replace("|", "\\|"),
		])
	out.append("")
	return out


static func _dict(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		var value: Dictionary = raw
		return value
	return {}


## Opens a file record from its `+++` line; `old_path` empty means it is new.
static func _start_file(header: String, old_path: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	return {
		"path": _diff_path(header.substr(4)),
		"entries": entries,
		"added": 0,
		"removed": 0,
		"is_new": old_path.is_empty(),
	}


## `git` writes `b/path/to/file.gd` (or `/dev/null`); timestamps come after a tab.
static func _diff_path(raw: String) -> String:
	var text: String = raw
	var tab_index: int = text.find("\t")
	if tab_index >= 0:
		text = text.substr(0, tab_index)
	text = text.strip_edges()
	if text == "/dev/null":
		return ""
	if text.begins_with("b/"):
		return text.substr(2)
	return text


static func _is_diff_header(raw: String) -> bool:
	for prefix: String in ["diff ", "index ", "new file", "deleted file", "similarity ", "rename ", "\\ No newline"]:
		if raw.begins_with(prefix):
			return true
	return false


static func _append_entry(file: Dictionary, kind: String, text: String, line: int) -> void:
	var entries: Array = CodeIndexParser.dict_array(file, "entries")
	entries.append({"kind": kind, "text": text, "line": line})
	if kind == "added":
		file["added"] = CodeIndexParser.dict_int(file, "added") + 1
	elif kind == "removed":
		file["removed"] = CodeIndexParser.dict_int(file, "removed") + 1


## Every finding that can be made from one added line.
static func _line_findings(file: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var path_value: String = CodeIndexParser.dict_string(file, "path")
	var entries: Array = CodeIndexParser.dict_array(file, "entries")
	for index: int in range(entries.size()):
		var entry: Dictionary = _dict(entries[index])
		if CodeIndexParser.dict_string(entry, "kind") != "added":
			continue
		var text: String = CodeIndexParser.dict_string(entry, "text")
		var line: int = CodeIndexParser.dict_int(entry, "line")
		for candidate: Dictionary in [
			_banned_finding(path_value, line, text),
			_todo_finding(path_value, line, text),
			_api_finding(path_value, line, text, _previous_line(entries, index)),
		]:
			if not candidate.is_empty():
				findings.append(candidate)
	return findings


static func _previous_line(entries: Array, index: int) -> String:
	if index <= 0:
		return ""
	var previous: Dictionary = _dict(entries[index - 1])
	return CodeIndexParser.dict_string(previous, "text")


static func _banned_finding(path_value: String, line: int, text: String) -> Dictionary:
	# Only GDScript can call these: a diff that *documents* the ban (AGENTS.md, a
	# changelog, this file's own rule list) is prose, not a violation.
	if not path_value.ends_with(SCRIPT_SUFFIX):
		return {}
	for pattern: String in BANNED_PATTERNS:
		var start: int = text.find(pattern)
		while start >= 0:
			if not _quoted_at(text, start):
				return _finding("banned_pattern", path_value, line,
					"added `%s`; the lint gate bans it - fix the root cause" % pattern)
			start = text.find(pattern, start + 1)
	if path_value.begins_with(CORE_DIR) and text.begins_with("extends "):
		for type_name: String in CORE_NODE_TYPES:
			if text.contains(type_name):
				return _finding("core_purity", path_value, line,
					"`Core/` must stay pure logic (RefCounted/Resource); move the Node to Managers/ or Scenes/")
	return {}


## True when `index` sits inside a quoted literal: a banned pattern that only appears
## as data (a test fixture feeding the parser a diff) is not a violation.
static func _quoted_at(text: String, index: int) -> bool:
	var quote: String = ""
	var escaped: bool = false
	for position: int in range(index):
		var char: String = text[position]
		if escaped:
			escaped = false
		elif char == "\\":
			escaped = true
		elif not quote.is_empty():
			if char == quote:
				quote = ""
		elif char == "\"" or char == "'":
			quote = char
	return not quote.is_empty()


## Only shipped source is checked: a generated Docs/ page mirrors the source (and the
## constant that names the marker), and a quoted marker is data, not a leftover. The
## marker must also look like one - the word TODO or FIXME immediately followed by a
## colon or an opening parenthesis - so prose that merely mentions the word, and the
## MARKER_TODO constant, stay quiet.
static func _todo_finding(path_value: String, line: int, text: String) -> Dictionary:
	if not path_value.ends_with(SCRIPT_SUFFIX):
		return {}
	for marker: String in [MARKER_TODO, MARKER_FIXME]:
		if not text.contains(marker):
			continue
		var regex: RegEx = RegEx.new()
		if regex.compile("\\b%s\\s*[:(]" % marker) != OK:
			continue
		for found: RegExMatch in regex.search_all(text):
			if not _quoted_at(text, found.get_start()):
				return _finding("todo_added", path_value, line, "TODO/FIXME marker left in added code")
	return {}


static func _api_finding(path_value: String, line: int, text: String, previous: String) -> Dictionary:
	# A test suite's method name is its documentation, and GDScript has no private
	# tests, so flagging them would bury the real API surface in noise.
	if path_value.begins_with(TEST_DIR):
		return {}
	if not _is_public_function(text) or previous.begins_with("##"):
		return {}
	return _finding("undocumented_api", path_value, line,
		"public function added with no `##` doc comment above it")


static func _is_public_function(text: String) -> bool:
	var rest: String = text
	if rest.begins_with("static func "):
		rest = rest.substr("static func ".length())
	elif rest.begins_with("func "):
		rest = rest.substr("func ".length())
	else:
		return false
	return not rest.begins_with("_")


## A change to a file already at its size ceiling is where new code should be
## extracted, not appended.
static func _risk_finding(file: Dictionary, options: Dictionary) -> Dictionary:
	var path_value: String = CodeIndexParser.dict_string(file, "path")
	if not CodeIndexParser.dict_string_array(options, "known_large_files").has(path_value):
		return {}
	return _finding("large_file_change", path_value, 0,
		"file is already at its size ceiling (Tools/slop_baseline.json); prefer extracting a helper")


static func _change_findings(changed: PackedStringArray, files: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for path_value: String in changed:
		if _needs_test(path_value, changed):
			findings.append(_finding("untested_change", path_value, 0,
				"script changed with no GDTest/<Name>Test.gd in this diff"))
	var totals: Dictionary = _line_totals(files)
	var changed_lines: int = CodeIndexParser.dict_int(totals, "added") + CodeIndexParser.dict_int(totals, "removed")
	if changed_lines > MAX_CHANGED_LINES:
		findings.append(_finding("oversize_diff", "", 0,
			"%d changed lines; split the change so it can actually be reviewed" % changed_lines))
	return findings


## Tools/ and GDTest/ changes are excluded: a tool is exercised by running it, and
## a test change is already the test.
static func _needs_test(path_value: String, changed: PackedStringArray) -> bool:
	if not path_value.ends_with(SCRIPT_SUFFIX):
		return false
	if path_value.begins_with(TEST_DIR) or path_value.begins_with(TOOLS_DIR):
		return false
	var stem: String = path_value.get_file().get_basename()
	return not changed.has(TEST_DIR + stem + "Test.gd")


static func _line_totals(files: Array[Dictionary]) -> Dictionary:
	var added: int = 0
	var removed: int = 0
	for file: Dictionary in files:
		added += CodeIndexParser.dict_int(file, "added")
		removed += CodeIndexParser.dict_int(file, "removed")
	return {"added": added, "removed": removed}


static func _stats(files: Array[Dictionary], changed: PackedStringArray) -> Dictionary:
	var totals: Dictionary = _line_totals(files)
	var stats: Dictionary = {
		"file_count": changed.size(),
		"added": CodeIndexParser.dict_int(totals, "added"),
		"removed": CodeIndexParser.dict_int(totals, "removed"),
		"game": 0,
		"tests": 0,
		"tools": 0,
		"data": 0,
		"docs": 0,
		"other": 0,
	}
	for path_value: String in changed:
		var area: String = _area(path_value)
		stats[area] = CodeIndexParser.dict_int(stats, area) + 1
	return stats


static func _area(path_value: String) -> String:
	if path_value.begins_with(TEST_DIR):
		return "tests"
	if path_value.begins_with(TOOLS_DIR):
		return "tools"
	if path_value.begins_with("Docs/"):
		return "docs"
	if path_value.begins_with(DATA_DIR):
		return "data"
	if path_value.ends_with(SCRIPT_SUFFIX) or path_value.ends_with(SCENE_SUFFIX):
		return "game"
	return "other"


## Moves the high-signal advisories into `blocking`, so `--strict` can gate a
## pre-push run without pretending the softer findings are failures.
static func _promote_strict(result: Dictionary) -> void:
	var blocking: Array[Dictionary] = []
	var advisory: Array[Dictionary] = []
	for raw: Variant in CodeIndexParser.dict_array(result, "advisory"):
		var finding: Dictionary = _dict(raw)
		if STRICT_RULES.has(CodeIndexParser.dict_string(finding, "rule")):
			finding["severity"] = "blocking"
			blocking.append(finding)
		else:
			advisory.append(finding)
	result["blocking"] = blocking
	result["advisory"] = advisory


static func _finding(rule: String, path_value: String, line: int, detail: String) -> Dictionary:
	var where: String = path_value if line <= 0 else "%s:%d" % [path_value, line]
	return {
		"severity": "advisory",
		"rule": rule,
		"path": path_value,
		"line": line,
		"where": where,
		"detail": detail,
	}
#endregion


