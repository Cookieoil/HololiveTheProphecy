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
## Review depth is a gradient, not a constant: `blast_radius` marks a change that moved
## trunk code (shared state, the core loops, the gates) as needing a line-by-line read
## and a leaf one as safe to skim behind green gates, and `feature_gated` says whether a
## kill switch bounds it. Turning that into a comment, a terminal report or the
## context-isolated brief is Tools/DiffReviewFormatter.gd, so this file stays a rule set.
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
## A diff this large cannot be reviewed properly in one pass; split it.
const MAX_CHANGED_LINES: int = 400
## Rules that `--strict` turns into failures. `untested_change` is deliberately not
## here: this repo names suites by behaviour (GDTest/TelemetryTest.gd covers
## GameManager, GDTest/UiSnapshotTest.gd covers BattleScene), so a filename match
## would fail a change that is in fact covered. It stays advisory, for a human.
const STRICT_RULES: Array[String] = [
	"undocumented_api",
	"core_purity",
	"assertionless_test",
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
const ASSERT_PREFIX: String = "assert"
const TEST_FUNCTION_PREFIX: String = "test_"
const DOCS_DIR: String = "Docs/"
const JSON_SUFFIX: String = ".json"
const FEATURES_PATH: String = "Data/json/features.json"
const ROLLOUT_KEY: String = "rollout_percent"
const ENABLED_KEY: String = "\"enabled\""
## A rollout of every bucket is not a canary: a newly enabled flag that lands already
## at 100 (or with no `rollout_percent` at all, which means 100) skips the staged
## rollout the 80/20 rule asks for.
const ROLLOUT_FULL: int = 100
## Areas whose change carries the most blast radius: shared state and the core loops,
## the managers that own the turn machine, and the CI pipeline the gates themselves run
## through. `.github/` itself is not trunk: a pull-request template cannot break a run.
const TRUNK_PREFIXES: Array[String] = ["Core/", "Managers/", ".github/workflows/"]
## Single-instance seams that are trunk wherever they sit: the runtime config, the
## global signal bus, the shared effect interpreter and the one battle entry point.
const TRUNK_FILES: Array[String] = [
	"project.godot",
	"Data/json/config.json",
	"Managers/EventBus.gd",
	"Skills/EffectBlock.gd",
	"Scenes/BattleScene/BattleScene.gd",
	"Scenes/BattleScene/BattleScene.tscn",
]
## A changed script this many others depend on is trunk by *measurement*, not by
## folder. Tools/review_diff.gd reads the fan-in off the generated map's `Used by`
## line and passes it in, so the folder rules only have to cover what the map cannot
## say.
const TRUNK_FAN_IN: int = 5
const TIER_TRUNK: String = "trunk"
const TIER_LEAF: String = "leaf"
const RADIUS_HIGH: String = "high"
const RADIUS_MEDIUM: String = "medium"
const RADIUS_LOW: String = "low"
## Markers that show a change is behind a staged flag, which is what makes a leaf change
## safe to skim: the control path is untouched and the kill switch is one JSON edit.
## They are looked for in scripts only, and never inside a quoted literal - a docs page
## that documents the registry, or a fixture that feeds the parser gate-looking text, is
## not a gate.
const FEATURE_GATE_MARKERS: Array[String] = [
	"FeatureFlags.is_active",
	"Data/json/features.json",
]
## Paths that never ship in the game: a test suite or an offline tool. Nothing there can
## reach a player, so those files are neither trunk nor part of a script's *runtime*
## fan-in - and counting them would let writing more unit tests promote an isolated leaf
## widget to trunk.
const NON_SHIPPED_PREFIXES: Array[String] = [TEST_DIR, TOOLS_DIR]
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


## Reviews a diff and returns
## `{files, changed_paths, blocking, advisory, stats, blast_radius, trunk_paths, feature_gated}`.
## `options` accepts `strict: bool`, `known_large_files: PackedStringArray` and
## `trunk_files: PackedStringArray` (measured fan-in, from Tools/review_diff.gd).
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
	advisory.append_array(_assertionless_findings(files))
	advisory.append_array(_rollout_findings(files))
	var trunk: PackedStringArray = _trunk_paths(changed, options)
	var result: Dictionary = {
		"files": files,
		"changed_paths": changed,
		"blocking": [],
		"advisory": advisory,
		"stats": _stats(files, changed),
		"blast_radius": _radius(changed, trunk),
		"trunk_paths": trunk,
		"feature_gated": _feature_gated(files),
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


## The review tier of one changed path. `trunk` code is where a wrong line reaches
## every player (shared state, the core loops, the gates themselves); `leaf` code is
## isolated enough that green gates plus proof can stand in for a line-by-line read.
## `trunk_files` carries the fan-in that Tools/review_diff.gd measured off the
## generated map, which is how a leaf-looking scene with many dependents is still
## caught.
static func review_tier(path_value: String, trunk_files: PackedStringArray = PackedStringArray()) -> String:
	if trunk_files.has(path_value) or TRUNK_FILES.has(path_value):
		return TIER_TRUNK
	for prefix: String in TRUNK_PREFIXES:
		if path_value.begins_with(prefix):
			return TIER_TRUNK
	return TIER_LEAF


## True when a path never ships in the game (a test suite or an offline tool). Such a
## change cannot reach a player, so it is neither trunk nor part of another script's
## runtime fan-in.
static func is_non_shipped(path_value: String) -> bool:
	for prefix: String in NON_SHIPPED_PREFIXES:
		if path_value.begins_with(prefix):
			return true
	return false


## The *runtime* fan-in the generated map records for a script: how many of the entries
## on the `Used by:` line of `Docs/map/<path>.md` actually ship. Test suites and tools are
## skipped on purpose - otherwise writing more tests for an isolated leaf widget would
## push it over TRUNK_FAN_IN and call it shared state. Reading the committed map turns
## "blast radius" into a measurement, and the map is itself a gate-checked artifact, so
## it cannot drift from the sources unnoticed. Returns 0 for a missing or empty line.
static func fan_in_from_map(page_text: String) -> int:
	for raw: String in CodeIndexParser.normalized_text(page_text).split("\n"):
		if not raw.begins_with("Used by:"):
			continue
		var names: String = raw.substr("Used by:".length()).strip_edges()
		if names.is_empty() or names == "—":
			return 0
		var shipped: int = 0
		for entry: String in names.split(","):
			var path_value: String = entry.strip_edges()
			if not path_value.is_empty() and not is_non_shipped(path_value):
				shipped += 1
		return shipped
	return 0


#endregion

#region Private Methods
## Every changed path that is trunk: the folder rules plus the fan-in the caller
## measured (Tools/review_diff.gd reads it off the generated map).
static func _trunk_paths(changed: PackedStringArray, options: Dictionary) -> PackedStringArray:
	var measured: PackedStringArray = CodeIndexParser.dict_string_array(options, "trunk_files")
	var trunk: PackedStringArray = PackedStringArray()
	for path_value: String in changed:
		if review_tier(path_value, measured) == TIER_TRUNK:
			trunk.append(path_value)
	return trunk


## How far a mistake can travel: HIGH once trunk code moved, MEDIUM when leaf game code
## did, LOW when the diff only touched tests, tools or docs - which is exactly the
## gradient the review depth follows.
static func _radius(changed: PackedStringArray, trunk: PackedStringArray) -> String:
	if not trunk.is_empty():
		return RADIUS_HIGH
	for path_value: String in changed:
		if _is_leaf_game_code(path_value):
			return RADIUS_MEDIUM
	return RADIUS_LOW


static func _is_leaf_game_code(path_value: String) -> bool:
	if path_value.begins_with(TEST_DIR) or path_value.begins_with(TOOLS_DIR) or path_value.begins_with(DOCS_DIR):
		return false
	if path_value.begins_with(DATA_DIR) and path_value.ends_with(JSON_SUFFIX):
		return true
	return path_value.ends_with(SCRIPT_SUFFIX) or path_value.ends_with(SCENE_SUFFIX)


## True when the diff adds a read of a staged flag, or edits the flag registry itself:
## either way the control path is untouched and a rollback is one JSON edit. A marker
## inside a quoted literal or a comment is prose (a fixture, a note-to-self), not a read,
## which is the same distinction the banned-pattern rule makes.
static func _feature_gated(files: Array[Dictionary]) -> bool:
	for file: Dictionary in files:
		var path_value: String = CodeIndexParser.dict_string(file, "path")
		if path_value == FEATURES_PATH:
			return true
		if path_value.begins_with(TEST_DIR) or not path_value.ends_with(SCRIPT_SUFFIX):
			continue
		for text: String in _added_texts(file):
			if _mentions_gate(text):
				return true
	return false


static func _mentions_gate(text: String) -> bool:
	var code_text: String = _code_part(text)
	for marker: String in FEATURE_GATE_MARKERS:
		var start: int = code_text.find(marker)
		while start >= 0:
			if not _quoted_at(code_text, start):
				return true
			start = code_text.find(marker, start + 1)
	return false


static func _added_texts(file: Dictionary) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for raw: Variant in CodeIndexParser.dict_array(file, "entries"):
		var entry: Dictionary = _dict(raw)
		if CodeIndexParser.dict_string(entry, "kind") == "added":
			texts.append(CodeIndexParser.dict_string(entry, "text"))
	return texts


## A test that cannot fail is not proof, it is coverage theatre. Only *newly added*
## `test_*` bodies are judged, and a body asserts if any of its own added lines mentions
## `assert` (every gdUnit4 assertion is `assert_*`), so a helper that asserts inside
## itself is not mistaken for an empty test.
static func _assertionless_findings(files: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for file: Dictionary in files:
		var path_value: String = CodeIndexParser.dict_string(file, "path")
		if not path_value.begins_with(TEST_DIR) or not path_value.ends_with(SCRIPT_SUFFIX):
			continue
		findings.append_array(_file_assertionless(path_value, CodeIndexParser.dict_array(file, "entries")))
	return findings


static func _file_assertionless(path_value: String, entries: Array) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for index: int in range(entries.size()):
		var entry: Dictionary = _dict(entries[index])
		if CodeIndexParser.dict_string(entry, "kind") != "added":
			continue
		var name_value: String = _declared_function_name(CodeIndexParser.dict_string(entry, "text"))
		if not name_value.begins_with(TEST_FUNCTION_PREFIX):
			continue
		if _body_asserts(entries, index):
			continue
		findings.append(_finding("assertionless_test", path_value, CodeIndexParser.dict_int(entry, "line"),
			"new test has no assertion; a test that cannot fail only pads the coverage number"))
	return findings


## True when the added block that starts at `index` mentions a real assertion.
##
## A blank line does not end the body (the suites here separate arrange from act that way)
## and neither does a non-indented line while the signature is still open (a wrapped
## parameter list). A non-indented line *after* that starts the next member, so the walk
## stops there without parsing the whole file. The `assert` has to sit outside a comment
## and outside a quoted literal, or a test could pass on its own doc line.
static func _body_asserts(entries: Array, index: int) -> bool:
	var in_signature: bool = true
	var cursor: int = index
	while cursor < entries.size():
		var entry: Dictionary = _dict(entries[cursor])
		var text: String = CodeIndexParser.dict_string(entry, "text")
		if CodeIndexParser.dict_string(entry, "kind") != "added":
			break
		if cursor > index and not _continues_body(text, in_signature):
			break
		if in_signature and CodeIndexParser.signature_complete(text):
			in_signature = false
		if _has_assertion(text):
			return true
		cursor += 1
	return false


## True when `text` still belongs to the body that started earlier: blank lines and
## indented lines always do, and a non-indented line does while the signature is still
## open (a wrapped parameter list).
static func _continues_body(text: String, in_signature: bool) -> bool:
	if text.strip_edges().is_empty():
		return true
	if text.begins_with("\t") or text.begins_with(" "):
		return true
	return in_signature


## True when the line carries an assertion call: `assert` outside a trailing comment and
## outside a quoted literal.
static func _has_assertion(text: String) -> bool:
	var code_text: String = _code_part(text)
	var start: int = code_text.find(ASSERT_PREFIX)
	while start >= 0:
		if not _quoted_at(code_text, start):
			return true
		start = code_text.find(ASSERT_PREFIX, start + 1)
	return false


## A newly enabled flag is the one place a mistake reaches every player at once, so
## landing it at 100 in the same diff that adds it skips the canary the 80/20 rule asks
## for. Each enabled flag is judged on its own rollout, read forward from its own line, so
## a second flag in the same file cannot hide behind the first - and a staged value that
## already sits on an unchanged (context) line still counts as staged. Advisory on
## purpose: a deliberate graduation is a legitimate reason to land at 100.
static func _rollout_findings(files: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for file: Dictionary in files:
		if CodeIndexParser.dict_string(file, "path") != FEATURES_PATH:
			continue
		findings.append_array(_unstaged_flags(CodeIndexParser.dict_array(file, "entries")))
	return findings


static func _unstaged_flags(entries: Array) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for index: int in range(entries.size()):
		var entry: Dictionary = _dict(entries[index])
		if CodeIndexParser.dict_string(entry, "kind") != "added":
			continue
		var text: String = CodeIndexParser.dict_string(entry, "text")
		if not _enables_flag(text):
			continue
		var percent: int = _rollout_after(entries, index)
		if percent > 0 and percent < ROLLOUT_FULL:
			continue
		findings.append(_finding("unstaged_rollout", FEATURES_PATH, 0,
			"flag enabled with no staged `rollout_percent`: canary it (e.g. 25) and read the cohort before 100"))
	return findings


## True when this line turns a flag on.
static func _enables_flag(text: String) -> bool:
	return text.contains(ENABLED_KEY) and text.contains("true")


## The `rollout_percent` belonging to the flag enabled at `index`: the next value at or
## after that line, stopping at the next flag's `enabled` key. -1 means this flag sets
## none, which FeatureFlags reads as a full rollout.
static func _rollout_after(entries: Array, index: int) -> int:
	for cursor: int in range(index, entries.size()):
		var text: String = CodeIndexParser.dict_string(_dict(entries[cursor]), "text")
		if cursor > index and text.contains(ENABLED_KEY):
			return -1
		var percent: int = _rollout_value(text)
		if percent >= 0:
			return percent
	return -1


## The integer written after `rollout_percent` on this line, or -1 when the line does
## not set one. The digits are read as text rather than trusting a parsed number's
## type, because JSON numbers always arrive as floats.
static func _rollout_value(text: String) -> int:
	var key: int = text.find(ROLLOUT_KEY)
	if key < 0:
		return -1
	var digits: String = ""
	for index: int in range(key + ROLLOUT_KEY.length(), text.length()):
		var character: String = text[index]
		if character >= "0" and character <= "9":
			digits += character
		elif not digits.is_empty():
			break
	if digits.is_empty():
		return -1
	return digits.to_int()


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
	# changelog, this file's own rule list, a trailing comment) is prose, not a
	# violation - which is also why the lint gate skips comment lines.
	if not path_value.ends_with(SCRIPT_SUFFIX):
		return {}
	var code_text: String = _code_part(text)
	for pattern: String in BANNED_PATTERNS:
		var start: int = code_text.find(pattern)
		while start >= 0:
			if not _quoted_at(code_text, start):
				return _finding("banned_pattern", path_value, line,
					"added `%s`; the lint gate bans it - fix the root cause" % pattern)
			start = code_text.find(pattern, start + 1)
	if path_value.begins_with(CORE_DIR) and text.begins_with("extends "):
		for type_name: String in CORE_NODE_TYPES:
			if text.contains(type_name):
				return _finding("core_purity", path_value, line,
					"`Core/` must stay pure logic (RefCounted/Resource); move the Node to Managers/ or Scenes/")
	return {}


## The code part of a line: everything before a `#` that is not inside a quoted literal.
## A note-to-self that mentions an API is prose, not a call, so every marker rule reads
## through here.
static func _code_part(text: String) -> String:
	var start: int = text.find("#")
	while start >= 0:
		if not _quoted_at(text, start):
			return text.substr(0, start)
		start = text.find("#", start + 1)
	return text


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


## The name a `func` line declares, or "" when the line does not declare one. Shared by
## the public-API rule and the assertionless-test rule, so both agree on what counts as
## a function.
static func _declared_function_name(text: String) -> String:
	var rest: String = text
	if rest.begins_with("static func "):
		rest = rest.substr("static func ".length())
	elif rest.begins_with("func "):
		rest = rest.substr("func ".length())
	else:
		return ""
	var open_index: int = rest.find("(")
	if open_index < 0:
		return rest.strip_edges()
	return rest.substr(0, open_index).strip_edges()


static func _is_public_function(text: String) -> bool:
	var name_value: String = _declared_function_name(text)
	return not name_value.is_empty() and not name_value.begins_with("_")


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
	var changed_lines: int = _reviewable_lines(files)
	if changed_lines > MAX_CHANGED_LINES:
		findings.append(_finding("oversize_diff", "", 0,
			"%d changed lines; split the change so it can actually be reviewed" % changed_lines))
	return findings


## Changed lines a human actually has to read. The generated `Docs/` tree is excluded:
## it is regenerated from the sources, so counting it would make every small code change
## look oversize and train the reader to ignore the rule.
static func _reviewable_lines(files: Array[Dictionary]) -> int:
	var total: int = 0
	for file: Dictionary in files:
		if CodeIndexParser.dict_string(file, "path").begins_with(DOCS_DIR):
			continue
		total += CodeIndexParser.dict_int(file, "added") + CodeIndexParser.dict_int(file, "removed")
	return total


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


