extends SceneTree
## Second-pass reviewer for a branch: summarises the diff and flags the things a
## reviewer (human or the next agent) should look at, so the first look is a short
## report instead of a raw diff.
##
## The hard gates stay where they are (Tools/line_godot_slop.py, the test suite, the
## data validator). This is the *review* layer: no rule here fails the build unless
## `--strict` is passed, which promotes the high-signal rules for a pre-push run.
##
## It also answers the two questions that decide how deep a review has to go: the
## blast radius (trunk code needs a line-by-line read, leaf code can be skimmed once
## the gates are green) and whether a staged feature flag already bounds the change.
## The fan-in behind that tier comes from the generated map, so the measure is the
## codebase's own dependency graph rather than a guess.
##
## The rules live in Tools/DiffReviewParser.gd and the rendering in
## Tools/DiffReviewFormatter.gd; this file is only the git plumbing and the CLI.
##
## Usage:
##   godot --headless --path . --script res://Tools/review_diff.gd
##   godot --headless --path . --script res://Tools/review_diff.gd -- \
##     --base origin/main --format markdown --output review.md
##   godot --headless --path . --script res://Tools/review_diff.gd -- --strict
##   godot --headless --path . --script res://Tools/review_diff.gd -- --adversarial
##
## `--adversarial` appends the context-isolated brief: the invariants a *fresh* reviewer
## (one that never saw the authoring conversation) should attack, plus the files whose
## map pages belong in its context.
##
## Exit code 0 = nothing blocking, 1 = a strict rule failed, 2 = git could not run.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Constants
const BASELINE_PATH: String = "res://Tools/slop_baseline.json"
const ARG_BASE: String = "--base"
const ARG_FORMAT: String = "--format"
const ARG_OUTPUT: String = "--output"
const ARG_STRICT: String = "--strict"
const ARG_ADVERSARIAL: String = "--adversarial"
const DEFAULT_BASE: String = "origin/main"
const FORMAT_MARKDOWN: String = "markdown"
const FORMAT_TEXT: String = "text"
const GIT_FAILED: int = 2
## The generated map: its `Used by:` line is the measured fan-in that decides which
## changed scripts are trunk, whatever folder they happen to sit in.
const MAP_DIR: String = "res://Docs/map"
const SCRIPT_SUFFIX: String = ".gd"
#endregion

#region Lifecycle Methods
func _initialize() -> void:
	var base: String = _arg_value(ARG_BASE, DEFAULT_BASE)
	var diff: Dictionary = _git_diff(base)
	if not CodeIndexParser.dict_bool(diff, "ok"):
		printerr("review_diff: `git diff %s...HEAD` failed (exit %d)" % [
			base,
			CodeIndexParser.dict_int(diff, "code"),
		])
		quit(GIT_FAILED)
		return
	var diff_text: String = CodeIndexParser.dict_string(diff, "text")
	var options: Dictionary = {
		"strict": ARG_STRICT in OS.get_cmdline_user_args(),
		"known_large_files": _known_large_files(),
		"trunk_files": _measure_trunk_files(DiffReviewParser.parse_diff(diff_text)),
	}
	var result: Dictionary = DiffReviewParser.review(diff_text, options)
	var report: String = _format(result)
	if ARG_ADVERSARIAL in OS.get_cmdline_user_args():
		report = report.strip_edges() + "\n\n" + DiffReviewFormatter.adversarial_section(result, _is_markdown()) + "\n"
	print(report)
	var output_path: String = _arg_value(ARG_OUTPUT, "")
	if not output_path.is_empty():
		_write(output_path, report)
	quit(DiffReviewParser.exit_code(result))
#endregion

#region Private Methods
## Diffs the branch against its base, with three lines of context so the parser can
## see the line above a change (that is how "new public function without a doc
## comment" is detected).
func _git_diff(base: String) -> Dictionary:
	var args: PackedStringArray = PackedStringArray(["diff", "-U3", base + "...HEAD"])
	var output: Array = []
	var code: int = OS.execute("git", args, output, true)
	var text: String = ""
	for raw: Variant in output:
		text += str(raw)
	return {"ok": code == 0, "code": code, "text": text}


func _format(result: Dictionary) -> String:
	if _is_markdown():
		return DiffReviewFormatter.format_markdown(result)
	return DiffReviewFormatter.format_text(result)


## Markdown is what CI posts as the pull-request comment; text is for a terminal run.
func _is_markdown() -> bool:
	return _arg_value(ARG_FORMAT, FORMAT_TEXT) == FORMAT_MARKDOWN


func _arg_value(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
	return fallback


## The files already at their size ceiling, so appending to them is flagged.
func _known_large_files() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	if not (parsed is Dictionary):
		return result
	var root: Dictionary = parsed
	var mapping: Variant = root.get("files")
	if not (mapping is Dictionary):
		return result
	var files: Dictionary = mapping
	for key: Variant in files.keys():
		result.append(str(key))
	return result


## Trunk by *measurement*: a changed script that the generated map says `TRUNK_FAN_IN`
## or more others ship against is shared state, so it gets the line-by-line treatment even
## when its folder looks leaf-like. Test suites and offline tools are skipped - they never
## reach a player - and the map is a gate-checked artifact, so its fan-in cannot drift
## from the sources; a missing page simply means "not measured".
func _measure_trunk_files(files: Array[Dictionary]) -> PackedStringArray:
	var trunk: PackedStringArray = PackedStringArray()
	for file: Dictionary in files:
		var path_value: String = CodeIndexParser.dict_string(file, "path")
		if not path_value.ends_with(SCRIPT_SUFFIX) or DiffReviewParser.is_non_shipped(path_value):
			continue
		var page: String = "%s/%s.md" % [MAP_DIR, path_value.trim_suffix(SCRIPT_SUFFIX)]
		if not FileAccess.file_exists(page):
			continue
		if DiffReviewParser.fan_in_from_map(FileAccess.get_file_as_string(page)) >= DiffReviewParser.TRUNK_FAN_IN:
			trunk.append(path_value)
	return trunk


func _write(path: String, text: String) -> void:
	var dir_path: String = path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("review_diff: cannot write %s" % path)
		return
	file.store_string(text)
	file.close()
#endregion
