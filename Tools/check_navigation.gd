extends SceneTree
## Test harness for the generated navigation set in Docs/.
##
## Two jobs:
##   1. Verify the committed artifacts against the sources with independent
##      scans (coverage, ranges, links, scenes, signals, data), so the map cannot
##      silently disagree with the code it describes.
##   2. Exercise the generator against a throwaway output directory: determinism,
##      stale and orphan detection, "check writes nothing", and a benchmark of
##      what each documented recipe actually costs to read.
##
## Usage:
##   godot --headless --path . --script res://Tools/check_navigation.gd
##   godot --headless --path . --script res://Tools/check_navigation.gd -- --benchmark
##
## The scratch output lives in res://reports/navigation-test/ (gitignored) and is
## removed again, so the committed Docs/ is never touched by a test run.
##
## Exit code 0 = every check passed, 1 = at least one check failed.
##
## @author TheGreatJellyfish
## @version 11/18/2026

#region Constants
const MAP_PATH: String = "res://Docs/CODEBASE_MAP.md"
const SYMBOLS_PATH: String = "res://Docs/symbols.tsv"
const MAP_DIR: String = "res://Docs/map"
const GENERATOR_PATH: String = "res://Tools/gen_code_index.gd"
const GENERATE_COMMAND: String = "godot --headless --path . --script res://Tools/gen_code_index.gd"
const ROOT_DIR: String = "res://"
const DATA_JSON_DIR: String = "res://Data/json"
const EVENT_BUS_PATH: String = "res://Managers/EventBus.gd"
const TEST_OUT_DIR: String = "res://reports/navigation-test"
const EXCLUDED_DIRS: PackedStringArray = [
	"res://addons/",
	"res://.godot/",
	"res://reports/",
	"res://Trash/",
	"res://bin/",
]
const KINDS: PackedStringArray = ["class", "enum", "signal", "const", "var", "export", "onready", "func"]
const ARG_BENCHMARK: String = "--benchmark"
const ARG_CHECK: String = "--check"
const ARG_OUTPUT_DIR: String = "--output-dir"
const ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"
## The overview is the file a reader opens first, so it has a hard size budget.
const MAP_MAX_LINES: int = 200
const MAP_MAX_BYTES: int = 24000
const MAX_REPORTED_FAILURES: int = 20
#endregion

#region Private Variables
var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0
#endregion

#region Lifecycle Methods
func _initialize() -> void:
	# `-- --benchmark` prints only the cost report (and still fails when a recipe
	# costs more than reading the sources).
	if ARG_BENCHMARK in OS.get_cmdline_user_args():
		_run_benchmark()
		quit(_report())
		return
	var docs_before: Dictionary = _tree_fingerprints("res://Docs")
	_check_committed_artifacts()
	# The committed set must match a fresh generation; --check never writes.
	_expect_generator(0, [ARG_CHECK], "the committed Docs/ is up to date")
	_run_isolated_generation_tests()
	_check_committed_docs_untouched(docs_before)
	_run_benchmark()
	quit(_report())
#endregion

#region Private Methods
func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_failures.append(message)
	printerr("  FAIL: %s" % message)
	if OS.get_environment(ENV_GITHUB_ACTIONS) == "true":
		printerr("::error title=Navigation index::%s" % message)
	return false


func _report() -> int:
	print("")
	if _failures.is_empty():
		print("NAVIGATION CHECKS PASSED (%d check(s))" % _checks)
		return 0
	printerr("NAVIGATION CHECKS FAILED (%d of %d check(s)):" % [_failures.size(), _checks])
	for i: int in range(mini(_failures.size(), MAX_REPORTED_FAILURES)):
		printerr("  - %s" % _failures[i])
	return 1


func _read(res_path: String) -> String:
	return CodeIndexParser.normalized_text(FileAccess.get_file_as_string(res_path))


func _read_lines(res_path: String) -> PackedStringArray:
	return _read(res_path).split("\n")


func _collect(dir_path: String, extension: String, result: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var base: String = dir_path if dir_path.ends_with("/") else dir_path + "/"
	var skip_files: bool = dir_path == ROOT_DIR
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			var child: String = base + entry + "/"
			# reports/ is skipped as game code, but it is where the scratch output
			# of this harness lives, so it has to be walkable.
			var excluded: bool = false
			for prefix: String in EXCLUDED_DIRS:
				if child.begins_with(prefix) and not child.begins_with(TEST_OUT_DIR):
					excluded = true
			if not excluded:
				_collect(child, extension, result)
		elif not skip_files and entry.ends_with(extension):
			result.append(base + entry)
		entry = dir.get_next()
	dir.list_dir_end()


## relative path -> content hash, used to prove a check run wrote nothing and to
## compare two generated trees that live in different directories.
func _tree_fingerprints(dir_path: String) -> Dictionary:
	var files: PackedStringArray = PackedStringArray()
	_collect(dir_path, ".md", files)
	_collect(dir_path, ".tsv", files)
	var result: Dictionary = {}
	for res_path: String in files:
		result[res_path.substr(dir_path.length() + 1)] = _read(res_path).sha256_text()
	return result


## Everything that can be verified by reading the committed artifacts.
func _check_committed_artifacts() -> void:
	print("Checking committed artifacts (Docs/)...")
	if not _check(FileAccess.file_exists(MAP_PATH), "missing %s" % MAP_PATH):
		return
	var map_text: String = _read(MAP_PATH)
	var map_lines: int = _read_lines(MAP_PATH).size()
	_check(map_lines <= MAP_MAX_LINES, "overview grew past %d lines (%d)" % [MAP_MAX_LINES, map_lines])
	_check(map_text.length() <= MAP_MAX_BYTES, "overview grew past %d bytes (%d)" % [MAP_MAX_BYTES, map_text.length()])
	_check(FileAccess.file_exists(SYMBOLS_PATH), "missing %s" % SYMBOLS_PATH)
	var rows: Array[Dictionary] = _parse_symbol_rows()
	if not _check(not rows.is_empty(), "symbols.tsv has no rows"):
		return
	_check_rows_are_valid(rows)
	_check_lookup_recipes(rows)
	_check_declaration_coverage(rows)
	_check_links()
	_check_scenes()
	_check_signal_table(map_text)
	_check_data_table(map_text)


## Parses symbols.tsv into typed rows, failing on any malformed line.
func _parse_symbol_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var lines: PackedStringArray = _read_lines(SYMBOLS_PATH)
	if lines.is_empty() or not lines[0].begins_with("#name"):
		_check(false, "symbols.tsv is missing its column header")
		return rows
	for i: int in range(1, lines.size()):
		var line: String = lines[i]
		if line.is_empty():
			continue
		var fields: PackedStringArray = line.split("\t")
		if fields.size() != 4:
			_check(false, "symbols.tsv:%d does not have 4 tab-separated columns" % (i + 1))
			continue
		var location: Dictionary = _parse_location(fields[2])
		if location.is_empty():
			_check(false, "symbols.tsv:%d has a malformed location '%s'" % [i + 1, fields[2]])
			continue
		rows.append({
			"name": fields[0],
			"kind": fields[1],
			"path": CodeIndexParser.dict_string(location, "path"),
			"start": CodeIndexParser.dict_int(location, "start"),
			"end": CodeIndexParser.dict_int(location, "end"),
			"detail": fields[3],
			"line": i + 1,
		})
	return rows


## `Core/Card.gd:74-75` -> {path, start, end}; empty when malformed.
func _parse_location(text: String) -> Dictionary:
	var colon: int = text.rfind(":")
	if colon <= 0:
		return {}
	var range_text: String = text.substr(colon + 1)
	var dash: int = range_text.find("-")
	if dash < 0:
		return {}
	var start_text: String = range_text.substr(0, dash)
	var end_text: String = range_text.substr(dash + 1)
	if not start_text.is_valid_int() or not end_text.is_valid_int():
		return {}
	return {
		"path": text.substr(0, colon),
		"start": start_text.to_int(),
		"end": end_text.to_int(),
	}


func _check_rows_are_valid(rows: Array[Dictionary]) -> void:
	var bad_kinds: PackedStringArray = PackedStringArray()
	var bad_paths: PackedStringArray = PackedStringArray()
	var bad_ranges: PackedStringArray = PackedStringArray()
	var bad_functions: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		var kind: String = CodeIndexParser.dict_string(row, "kind")
		var path_value: String = CodeIndexParser.dict_string(row, "path")
		var start_line: int = CodeIndexParser.dict_int(row, "start")
		var end_line: int = CodeIndexParser.dict_int(row, "end")
		if not KINDS.has(kind):
			bad_kinds.append(kind)
			continue
		if not FileAccess.file_exists("res://" + path_value):
			bad_paths.append(path_value)
			continue
		var lines: PackedStringArray = _read_lines("res://" + path_value)
		if start_line < 1 or end_line < start_line or end_line > lines.size():
			bad_ranges.append("%s:%d-%d" % [path_value, start_line, end_line])
			continue
		if kind == "func":
			var declaration: String = lines[start_line - 1]
			var symbol: String = CodeIndexParser.dict_string(row, "name")
			if not (declaration.contains("func ") and declaration.contains(symbol)):
				bad_functions.append("%s:%d" % [path_value, start_line])
	_check(bad_kinds.is_empty(), "unknown symbol kinds: %s" % _join(bad_kinds))
	_check(bad_paths.is_empty(), "symbols point at missing files: %s" % _join(bad_paths))
	_check(bad_ranges.is_empty(), "symbol ranges fall outside their file: %s" % _join(bad_ranges))
	_check(bad_functions.is_empty(), "func rows do not start on their declaration: %s" % _join(bad_functions))


## The documented lookup recipe must keep answering with one row per symbol.
func _check_lookup_recipes(rows: Array[Dictionary]) -> void:
	var expected: Dictionary = {
		"get_effective_value": "Core/Card.gd",
		"turn_started": "Managers/EventBus.gd",
		"build_card_on_ally_data": "Skills/SkillPreviewFormatter.gd",
	}
	for symbol: String in expected:
		var matches: Array[Dictionary] = _rows_named(rows, symbol)
		if not _check(matches.size() == 1, "lookup '%s' matched %d row(s), expected exactly 1" % [symbol, matches.size()]):
			continue
		var row: Dictionary = matches[0]
		var found_path: String = CodeIndexParser.dict_string(row, "path")
		var want_path: String = str(expected[symbol])
		_check(found_path == want_path, "lookup '%s' points at %s, expected %s" % [symbol, found_path, want_path])


func _rows_named(rows: Array[Dictionary], symbol: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for row: Dictionary in rows:
		if CodeIndexParser.dict_string(row, "name") == symbol:
			matches.append(row)
	return matches


func _join(values: PackedStringArray) -> String:
	if values.is_empty():
		return "-"
	var head: PackedStringArray = values.slice(0, mini(values.size(), 5))
	return ", ".join(head)


## Independent scan of the sources: every top-level declaration must be indexed.
func _check_declaration_coverage(rows: Array[Dictionary]) -> void:
	var indexed: Dictionary = {}
	for row: Dictionary in rows:
		var key: String = CodeIndexParser.dict_string(row, "name") + "|" + CodeIndexParser.dict_string(row, "kind")
		indexed[key] = true
	var missing: PackedStringArray = PackedStringArray()
	var scripts: PackedStringArray = PackedStringArray()
	_collect(ROOT_DIR, ".gd", scripts)
	scripts.sort()
	for res_path: String in scripts:
		for declaration: Dictionary in _scan_declarations(_read_lines(res_path)):
			var name_value: String = CodeIndexParser.dict_string(declaration, "name")
			var kind: String = CodeIndexParser.dict_string(declaration, "kind")
			if not _is_indexed(indexed, name_value, kind):
				missing.append("%s:%d %s %s" % [
					CodeIndexParser.repo_path(res_path),
					CodeIndexParser.dict_int(declaration, "line"),
					kind,
					name_value,
				])
	_check(missing.is_empty(), "%d declaration(s) missing from symbols.tsv: %s" % [missing.size(), _join(missing)])


## A `var` may legitimately be indexed as var, export or onready.
func _is_indexed(indexed: Dictionary, name_value: String, kind: String) -> bool:
	if indexed.has(name_value + "|" + kind):
		return true
	if kind == "var":
		for alternative: String in ["var", "export", "onready"]:
			if indexed.has(name_value + "|" + alternative):
				return true
	return false


## A deliberately simple oracle: the same "column 0 declaration" rule the parser
## documents, written independently so a parser regression shows up as a diff.
func _scan_declarations(lines: PackedStringArray) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		if line.begins_with("\t") or line.begins_with(" ") or line.begins_with("#"):
			continue
		var kind: String = ""
		var rest: String = ""
		if line.begins_with("class_name "):
			kind = "class"
			rest = line.substr("class_name ".length())
		elif line.begins_with("signal "):
			kind = "signal"
			rest = line.substr("signal ".length())
		elif line.begins_with("const "):
			kind = "const"
			rest = line.substr("const ".length())
		elif line.begins_with("static var "):
			kind = "var"
			rest = line.substr("static var ".length())
		elif line.begins_with("var "):
			kind = "var"
			rest = line.substr("var ".length())
		elif line.begins_with("static func "):
			kind = "func"
			rest = line.substr("static func ".length())
		elif line.begins_with("func "):
			kind = "func"
			rest = line.substr("func ".length())
		elif line.begins_with("enum "):
			kind = "enum"
			rest = line.substr("enum ".length())
		elif (line.begins_with("@export") or line.begins_with("@onready")) and line.contains("var "):
			kind = "var"
			rest = line.substr(line.find("var ") + "var ".length())
		if kind.is_empty():
			continue
		found.append({
			"name": CodeIndexParser.leading_identifier(rest),
			"kind": kind,
			"line": i + 1,
		})
	return found


func _check_links() -> void:
	var broken_map_links: PackedStringArray = PackedStringArray()
	for link: String in _extract_links(_read(MAP_PATH)):
		if not FileAccess.file_exists("res://Docs/" + link):
			broken_map_links.append(link)
	_check(broken_map_links.is_empty(), "map links do not resolve: %s" % _join(broken_map_links))
	var pages: PackedStringArray = PackedStringArray()
	_collect(MAP_DIR, ".md", pages)
	pages.sort()
	var broken_page_links: PackedStringArray = PackedStringArray()
	var without_back_link: PackedStringArray = PackedStringArray()
	for page: String in pages:
		var has_back_link: bool = false
		for link: String in _extract_links(_read(page)):
			if not link.ends_with("CODEBASE_MAP.md"):
				continue
			has_back_link = true
			if not FileAccess.file_exists(_resolve_relative(page, link)):
				broken_page_links.append("%s -> %s" % [CodeIndexParser.repo_path(page), link])
		if not has_back_link:
			without_back_link.append(CodeIndexParser.repo_path(page))
	_check(broken_page_links.is_empty(), "page links do not resolve: %s" % _join(broken_page_links))
	_check(without_back_link.is_empty(), "%d page(s) without a link back to the map: %s" % [
		without_back_link.size(),
		_join(without_back_link),
	])


## Markdown link targets, ignoring anchors and external URLs.
func _extract_links(text: String) -> PackedStringArray:
	var links: PackedStringArray = PackedStringArray()
	var cursor: int = 0
	while true:
		var open_index: int = text.find("](", cursor)
		if open_index < 0:
			return links
		var close_index: int = text.find(")", open_index + 2)
		if close_index < 0:
			return links
		var target: String = text.substr(open_index + 2, close_index - open_index - 2)
		cursor = close_index + 1
		if target.is_empty() or target.begins_with("#") or target.contains("://"):
			continue
		links.append(target)
	return links


## Resolves a markdown link relative to the file that contains it.
func _resolve_relative(from_res_path: String, link: String) -> String:
	var parts: PackedStringArray = from_res_path.get_base_dir().split("/")
	for segment: String in link.split("/"):
		if segment == "..":
			if parts.size() > 0:
				parts.remove_at(parts.size() - 1)
		elif segment != "." and not segment.is_empty():
			parts.append(segment)
	return "/".join(parts)


## Every scene needs a page, and every node in the scene needs to be on it.
func _check_scenes() -> void:
	var scenes: PackedStringArray = PackedStringArray()
	_collect(ROOT_DIR, ".tscn", scenes)
	scenes.sort()
	var missing_pages: PackedStringArray = PackedStringArray()
	var missing_nodes: PackedStringArray = PackedStringArray()
	for res_path: String in scenes:
		var repo_path_value: String = CodeIndexParser.repo_path(res_path)
		var page: String = MAP_DIR + "/" + CodeIndexParser.scene_page_file(repo_path_value)
		if not FileAccess.file_exists(page):
			missing_pages.append(repo_path_value)
			continue
		var page_text: String = _read(page)
		for node_name: String in _scan_node_names(_read_lines(res_path)):
			# Pages render a node as "- Name `Type`", so the name is followed by a
			# backticked type rather than being backticked itself.
			if not page_text.contains(node_name + " `"):
				missing_nodes.append("%s: %s" % [repo_path_value, node_name])
	_check(missing_pages.is_empty(), "scene(s) without a page: %s" % _join(missing_pages))
	_check(missing_nodes.is_empty(), "scene node(s) missing from their page: %s" % _join(missing_nodes))


func _scan_node_names(lines: PackedStringArray) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("[node"):
			continue
		var name_value: String = CodeIndexParser.attribute(trimmed, "name")
		if not name_value.is_empty():
			names.append(name_value)
	return names


## The EventBus table must name exactly the scripts that emit or listen.
func _check_signal_table(map_text: String) -> void:
	var scripts: PackedStringArray = PackedStringArray()
	_collect(ROOT_DIR, ".gd", scripts)
	scripts.sort()
	var wrong: PackedStringArray = PackedStringArray()
	for line: String in _read_lines(EVENT_BUS_PATH):
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("signal "):
			continue
		var signal_name: String = CodeIndexParser.leading_identifier(trimmed.substr("signal ".length()))
		if signal_name.is_empty():
			continue
		var row: String = _signal_row(map_text, signal_name)
		if row.is_empty():
			wrong.append("no table row for %s" % signal_name)
			continue
		for res_path: String in scripts:
			var text: String = _read(res_path)
			var repo_path_value: String = CodeIndexParser.repo_path(res_path)
			if text.contains("EventBus." + signal_name + ".emit(") and not row.contains(repo_path_value):
				wrong.append("%s: emitter %s missing" % [signal_name, repo_path_value])
			if text.contains("EventBus." + signal_name + ".connect(") and not row.contains(repo_path_value):
				wrong.append("%s: listener %s missing" % [signal_name, repo_path_value])
	_check(wrong.is_empty(), "EventBus table disagrees with the sources: %s" % _join(wrong))


func _signal_row(map_text: String, signal_name: String) -> String:
	for line: String in map_text.split("\n"):
		if line.begins_with("| `" + signal_name + "`"):
			return line
	return ""


## Every runtime JSON file must appear with its real entry count.
func _check_data_table(map_text: String) -> void:
	var files: PackedStringArray = PackedStringArray()
	_collect(DATA_JSON_DIR, ".json", files)
	files.sort()
	var wrong: PackedStringArray = PackedStringArray()
	for res_path: String in files:
		var repo_path_value: String = CodeIndexParser.repo_path(res_path)
		var row: String = ""
		for line: String in map_text.split("\n"):
			if line.begins_with("| `" + repo_path_value + "`"):
				row = line
				break
		if row.is_empty():
			wrong.append("no data row for " + repo_path_value)
			continue
		var parsed: Variant = JSON.parse_string(_read(res_path))
		var entries: int = 0
		if parsed is Dictionary:
			var mapping: Dictionary = parsed
			entries = mapping.size()
		elif parsed is Array:
			var items: Array = parsed
			entries = items.size()
		if not row.contains("| %d |" % entries):
			wrong.append("%s: entry count %d is not in the table row" % [repo_path_value, entries])
	_check(wrong.is_empty(), "data table disagrees with the JSON files: %s" % _join(wrong))


## Exercises the generator in a throwaway output directory, so the committed
## Docs/ is never touched and each behaviour can be checked in isolation.
func _run_isolated_generation_tests() -> void:
	print("Exercising the generator in %s ..." % TEST_OUT_DIR)
	_remove_dir(TEST_OUT_DIR)
	var dir_a: String = TEST_OUT_DIR + "/a"
	var dir_b: String = TEST_OUT_DIR + "/b"
	_expect_generator(0, ["--output-dir", dir_a], "generate into a scratch directory")
	_expect_generator(0, ["--output-dir", dir_b], "generate into a second scratch directory")
	_check(_tree_fingerprints(dir_a) == _tree_fingerprints(dir_b), "two generations are not byte-identical")
	_expect_generator(0, ["--output-dir", dir_a, ARG_CHECK], "fresh scratch output passes --check")

	var page: String = _first_page(dir_a)
	if not _check(not page.is_empty(), "scratch output has no pages to test with"):
		return
	var original: String = _read(page)
	_append_text(page, "<!-- tampered -->\n")
	var tampered: String = _read(page)
	_expect_generator(1, ["--output-dir", dir_a, ARG_CHECK], "a tampered page is reported as stale")
	_check(_read(page) == tampered, "--check rewrote a page instead of only reporting it")
	_write_text(page, original)
	_expect_generator(0, ["--output-dir", dir_a, ARG_CHECK], "the restored page passes --check again")

	var orphan: String = dir_a + "/map/Orphan/Page.md"
	_write_text(orphan, "orphan\n")
	_expect_generator(1, ["--output-dir", dir_a, ARG_CHECK], "an orphaned page is reported as stale")
	_expect_generator(0, ["--output-dir", dir_a], "regenerate after the orphan")
	_check(not FileAccess.file_exists(orphan), "regeneration kept an orphaned page")
	_check(not DirAccess.dir_exists_absolute(dir_a + "/map/Orphan"), "regeneration kept an empty directory")
	_remove_dir(TEST_OUT_DIR)


## Runs the generator and asserts its exit code, reporting the tail on failure.
func _expect_generator(expected: int, extra_args: Array, label: String) -> void:
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", _project_dir(), "--script", GENERATOR_PATH, "--",
	])
	for value: Variant in extra_args:
		args.append(str(value))
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = ""
	if not output.is_empty():
		text = str(output[0]).strip_edges()
		if text.length() > 240:
			text = text.substr(text.length() - 240)
	_check(code == expected, "%s: generator exited %d, expected %d (%s)" % [label, code, expected, text])


func _project_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


func _first_page(dir_path: String) -> String:
	var pages: PackedStringArray = PackedStringArray()
	_collect(dir_path + "/map", ".md", pages)
	pages.sort()
	if pages.is_empty():
		return ""
	return pages[0]


func _append_text(res_path: String, text: String) -> void:
	_write_text(res_path, _read(res_path) + text)


func _write_text(res_path: String, text: String) -> void:
	var dir_path: String = res_path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file: FileAccess = FileAccess.open(res_path, FileAccess.WRITE)
	if file == null:
		_check(false, "cannot write %s" % res_path)
		return
	file.store_string(text)
	file.close()


func _remove_dir(dir_path: String) -> void:
	var files: PackedStringArray = PackedStringArray()
	_collect(dir_path, ".md", files)
	_collect(dir_path, ".tsv", files)
	for res_path: String in files:
		DirAccess.remove_absolute(res_path)
	var dirs: PackedStringArray = PackedStringArray()
	_collect_dirs(dir_path, dirs)
	dirs.reverse()
	for child: String in dirs:
		DirAccess.remove_absolute(child)
	DirAccess.remove_absolute(dir_path)


func _collect_dirs(dir_path: String, result: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			var child: String = dir_path + "/" + entry
			result.append(child)
			_collect_dirs(child, result)
		entry = dir.get_next()
	dir.list_dir_end()


## Proves the whole run left the committed artifacts untouched.
func _check_committed_docs_untouched(before: Dictionary) -> void:
	var after: Dictionary = _tree_fingerprints("res://Docs")
	_check(before == after, "the committed Docs/ tree changed during the check run")


## What each documented recipe costs to read, against the naive alternative of
## opening the files that contain the answer. Bytes are measured; the token
## column is a rough estimate (bytes / 4), not model billing.
func _run_benchmark() -> void:
	var tasks: Array[Dictionary] = _benchmark_tasks()
	print("")
	print("%-40s %6s %10s %10s %7s %9s" % ["task", "reads", "indexed_B", "naive_B", "ratio", "~tokens"])
	for task: Dictionary in tasks:
		var indexed_entries: Array = CodeIndexParser.dict_array(task, "indexed")
		var naive_entries: Array = CodeIndexParser.dict_array(task, "naive")
		var indexed_bytes: int = _measure(indexed_entries)
		var naive_bytes: int = _measure(naive_entries)
		var ratio: float = float(naive_bytes) / maxf(1.0, float(indexed_bytes))
		print("%-40s %6d %10d %10d %6.1fx %9d" % [
			CodeIndexParser.dict_string(task, "name"),
			indexed_entries.size(),
			indexed_bytes,
			naive_bytes,
			ratio,
			ceili(indexed_bytes / 4.0),
		])
		_check(indexed_bytes <= naive_bytes, "benchmark '%s' reads more than the sources (%d > %d bytes)" % [
			CodeIndexParser.dict_string(task, "name"),
			indexed_bytes,
			naive_bytes,
		])


func _benchmark_tasks() -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	tasks.append({
		"name": "one function body",
		"indexed": [_grep(SYMBOLS_PATH, "get_effective_value"), _row_range("get_effective_value")],
		"naive": [_whole("res://Core/Card.gd")],
	})
	tasks.append({
		"name": "one manager's public API",
		"indexed": [_whole(MAP_DIR + "/Managers/GameManager.md")],
		"naive": [_whole("res://Managers/GameManager.gd")],
	})
	tasks.append({
		"name": "one script's API and its scene",
		"indexed": [_whole(MAP_DIR + "/Scenes/Cards/CardUI.md"), _whole(MAP_DIR + "/Scenes/Cards/CardUI.scene.md")],
		"naive": [_whole("res://Scenes/Cards/CardUI.gd"), _whole("res://Scenes/Cards/CardUI.tscn")],
	})
	tasks.append({
		"name": "who emits and listens to a signal",
		"indexed": [_grep(MAP_PATH, "turn_started")],
		"naive": [
			_whole("res://Managers/EventBus.gd"),
			_whole("res://Managers/GameManager.gd"),
			_whole("res://Scenes/HUD/BattleOverlayController.gd"),
		],
	})
	tasks.append({
		"name": "scene node tree",
		"indexed": [_whole(MAP_DIR + "/Scenes/BattleScene/BattleScene.scene.md")],
		"naive": [_whole("res://Scenes/BattleScene/BattleScene.tscn")],
	})
	tasks.append({
		"name": "data file schema",
		"indexed": [_grep(MAP_PATH, "Data/json/skills.json")],
		"naive": [_whole("res://Data/json/skills.json")],
	})
	tasks.append({
		"name": "impact of changing one class",
		"indexed": [_grep(MAP_DIR + "/Core/Card.md", "Used by:")],
		"naive": _used_by_files(MAP_DIR + "/Core/Card.md"),
	})
	return tasks


func _whole(res_path: String) -> Dictionary:
	return {"path": res_path}


## Counts only the matching lines, which is what a search actually returns.
func _grep(res_path: String, pattern: String) -> Dictionary:
	return {"path": res_path, "grep": pattern}


## The exact source range of a symbol, read back from the index itself.
func _row_range(symbol: String) -> Dictionary:
	for row: Dictionary in _parse_symbol_rows():
		if CodeIndexParser.dict_string(row, "name") == symbol:
			return {
				"path": "res://" + CodeIndexParser.dict_string(row, "path"),
				"start": CodeIndexParser.dict_int(row, "start"),
				"end": CodeIndexParser.dict_int(row, "end"),
			}
	return {}


## The files a page lists as dependents: the honest baseline for "what breaks if
## I change this?", because those are the files a reader would have to open.
func _used_by_files(page_res_path: String) -> Array:
	var entries: Array = []
	for line: String in _read_lines(page_res_path):
		if not line.begins_with("Used by:"):
			continue
		for part: String in line.substr("Used by:".length()).split(","):
			var path_value: String = part.strip_edges()
			if path_value.is_empty() or path_value == "—":
				continue
			entries.append(_whole("res://" + path_value))
	return entries


func _measure(entries: Array) -> int:
	var total: int = 0
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var path_value: String = CodeIndexParser.dict_string(entry, "path")
		var pattern: String = CodeIndexParser.dict_string(entry, "grep")
		var lines: PackedStringArray = _read_lines(path_value)
		if not pattern.is_empty():
			for line: String in lines:
				if line.contains(pattern):
					total += line.length() + 1
			continue
		var start_line: int = CodeIndexParser.dict_int(entry, "start")
		if start_line > 0:
			var end_line: int = mini(CodeIndexParser.dict_int(entry, "end", start_line), lines.size())
			for i: int in range(start_line - 1, end_line):
				total += lines[i].length() + 1
			continue
		for line: String in lines:
			total += line.length() + 1
	return total
#endregion
