extends SceneTree
## Forward pressure: turns evidence into agent-ready task issues.
##
## An agent (or a human) should never have to *notice* work. This collects the signals
## the repository already produces, runs them through Tools/TriageParser.gd, and prints
## one spec per finding - title, evidence, repro command and acceptance - so a fix
## starts from a definition of done. With `--create` it files them with `gh`, skipping
## any task whose issue already exists (the spec carries a stable marker).
##
## Sources, all secret-free:
##   - a telemetry report (`--report report.json`, written by
##     `python Tools/analyze_telemetry.py --json report.json`),
##   - leftover review markers in first-party comments,
##   - the anti-slop lint's stale-ratchet warnings.
##
## Usage:
##   godot --headless --path . --script res://Tools/triage.gd
##   godot --headless --path . --script res://Tools/triage.gd -- \
##     --report report.json --json tasks.json --create --label agent-task
##
## Exit code is 0 even with findings: intake reports, it does not gate. The gates are
## the five in Tools/preflight.ps1.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Constants
const SOURCE_DIRS: Array[String] = [
	"res://Core",
	"res://Managers",
	"res://Scenes",
	"res://Skills",
	"res://Tools",
	"res://GDTest",
]
const LINT_SCRIPT: String = "res://Tools/line_godot_slop.py"
const ARG_REPORT: String = "--report"
const ARG_CREATE: String = "--create"
const ARG_LABEL: String = "--label"
const ARG_JSON: String = "--json"
const ARG_PYTHON: String = "--python"
const DEFAULT_LABEL: String = "agent-task"
const DEFAULT_PYTHON: String = "python"
#endregion

#region Lifecycle Methods
func _initialize() -> void:
	var report: Dictionary = _read_report()
	var markers: Array[Dictionary] = _collect_markers()
	var warnings: PackedStringArray = _ratchet_warnings()
	var tasks: Array[Dictionary] = TriageParser.collect(report, markers, warnings)
	_write_json(tasks)
	_print_summary(tasks, markers.size(), warnings.size())
	if ARG_CREATE in OS.get_cmdline_user_args():
		_file_issues(tasks)
	quit(0)


func _arg_value(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
	return fallback
#endregion


#region Private Methods
## The telemetry report, or an empty one: intake works with whatever evidence exists.
func _read_report() -> Dictionary:
	var path: String = _arg_value(ARG_REPORT, "")
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var report: Dictionary = parsed
		return report
	printerr("[triage] %s is not a JSON object; ignoring it" % path)
	return {}


## Every leftover review marker in a first-party comment. Only comments count: a marker
## in a string literal is data, which is the same distinction the lint gate makes.
func _collect_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var files: PackedStringArray = PackedStringArray()
	for dir: String in SOURCE_DIRS:
		_scan_dir(dir, files)
	files.sort()
	for path: String in files:
		_scan_file(path, markers)
	return markers


func _scan_dir(dir_path: String, files: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var base: String = dir_path if dir_path.ends_with("/") else dir_path + "/"
	for entry: String in dir.get_files():
		if entry.ends_with(".gd"):
			files.append(base + entry)
	for entry: String in dir.get_directories():
		_scan_dir(base + entry, files)


func _scan_file(res_path: String, markers: Array[Dictionary]) -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(res_path).split("\n")
	for index: int in range(lines.size()):
		var found: Dictionary = TriageParser.marker_in_line(
			CodeIndexParser.repo_path(res_path), index + 1, lines[index]
		)
		if not found.is_empty():
			markers.append(found)


## Stale ratchet entries, straight from the lint that reports them: the loop that keeps
## Tools/slop_baseline.json honest instead of merely not-growing.
func _ratchet_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([ProjectSettings.globalize_path(LINT_SCRIPT)])
	OS.execute(_arg_value(ARG_PYTHON, DEFAULT_PYTHON), args, output, true)
	for raw: Variant in output:
		for line: String in str(raw).split("\n"):
			if line.contains("WARNING:") and line.contains("slop_baseline"):
				warnings.append(line.strip_edges())
	return warnings


func _print_summary(tasks: Array[Dictionary], marker_count: int, warning_count: int) -> void:
	print("=== TASK INTAKE ===")
	print("tasks:   %d (%d high, %d medium, %d low)" % [
		tasks.size(),
		TriageParser.count_of_severity(tasks, TriageParser.SEVERITY_HIGH),
		TriageParser.count_of_severity(tasks, TriageParser.SEVERITY_MEDIUM),
		TriageParser.count_of_severity(tasks, TriageParser.SEVERITY_LOW),
	])
	print("sources: %d marker(s), %d stale ratchet entry(ies)" % [marker_count, warning_count])
	for task: Dictionary in tasks:
		print("  [%s] %s" % [
			CodeIndexParser.dict_string(task, "severity"),
			CodeIndexParser.dict_string(task, "title"),
		])
	if tasks.is_empty():
		print("  nothing to hand out - the evidence is clean")


func _write_json(tasks: Array[Dictionary]) -> void:
	var path: String = _arg_value(ARG_JSON, "")
	if path.is_empty():
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("[triage] cannot write %s" % path)
		return
	file.store_string(JSON.stringify({"tasks": tasks}, "  "))
	file.close()
	print("wrote %d task(s) to %s" % [tasks.size(), path])


## Files every task that is not already tracked, one issue each. The body is the prompt:
## what, the evidence, how to reproduce, and what "done" means.
func _file_issues(tasks: Array[Dictionary]) -> void:
	var label: String = _arg_value(ARG_LABEL, DEFAULT_LABEL)
	_ensure_label(label)
	var tracked: String = _open_issue_text()
	var filed: int = 0
	for task: Dictionary in tasks:
		if tracked.contains(TriageParser.marker_for(task)):
			continue
		if _create_issue(task, label):
			filed += 1
	print("[triage] filed %d new issue(s); %d already tracked" % [filed, tasks.size() - filed])


## The label is created on first use, so a fresh clone needs no manual setup.
func _ensure_label(label: String) -> void:
	var args: PackedStringArray = PackedStringArray([
		"label", "create", label,
		"--description", "Filed by Tools/triage.gd (evidence + repro + acceptance)",
		"--color", "1D76DB",
		"--force",
	])
	OS.execute("gh", args, [], true)


## Every open issue's body in one blob: a marker is a substring check, not a parse.
func _open_issue_text() -> String:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([
		"issue", "list", "--state", "open", "--limit", "200", "--json", "body",
	])
	OS.execute("gh", args, output, true)
	var text: String = ""
	for raw: Variant in output:
		text += str(raw)
	return text


## `--body-file` avoids quoting a multi-line spec through the shell.
func _create_issue(task: Dictionary, label: String) -> bool:
	var body_path: String = ProjectSettings.globalize_path("user://triage_issue_body.md")
	var file: FileAccess = FileAccess.open(body_path, FileAccess.WRITE)
	if file == null:
		printerr("[triage] cannot stage an issue body")
		return false
	file.store_string(TriageParser.issue_body(task))
	file.close()
	var args: PackedStringArray = PackedStringArray([
		"issue", "create",
		"--title", TriageParser.issue_title(task),
		"--body-file", body_path,
		"--label", label,
	])
	var output: Array = []
	var code: int = OS.execute("gh", args, output, true)
	if code != 0:
		printerr("[triage] gh issue create failed for %s" % TriageParser.issue_title(task))
	return code == 0
#endregion
