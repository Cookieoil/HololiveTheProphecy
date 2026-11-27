extends SceneTree
## Headless compile gate: loads every project GDScript outside the excluded
## folders, so a type error, a stale `class_name` or a bad annotation fails CI
## instead of only surfacing when the affected scene is opened in the editor.
##
## Usage:
##   godot --headless --path . --script res://Tools/check_scripts.gd
##
## Exit code 0 = every script compiled, 1 = at least one script failed to load.
##
## @author TheGreatJellyfish
## @version 11/17/2026

#region Constants
## Folders that are not part of the shipped game code (vendor, scratch, output).
const EXCLUDED_DIRS: PackedStringArray = [
	"res://addons/",
	"res://.godot/",
	"res://reports/",
	"res://Trash/",
]
const ROOT_DIR: String = "res://"
const ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"
#endregion

#region Lifecycle Methods
func _initialize() -> void:
	var scripts: PackedStringArray = PackedStringArray()
	_collect_scripts(ROOT_DIR, scripts)
	var failures: PackedStringArray = PackedStringArray()
	for path: String in scripts:
		var resource: Resource = load(path)
		if resource == null:
			failures.append(path)
			continue
		# A script with a parse error can still come back non-null, so `load()`
		# alone is not enough: only a compiled script can be instantiated.
		var script: GDScript = resource as GDScript
		if script == null or not script.can_instantiate():
			failures.append(path)
	if failures.is_empty():
		print("SCRIPT CHECK PASSED (%d script(s))" % scripts.size())
		quit(0)
		return
	print("SCRIPT CHECK FAILED (%d of %d script(s) did not compile):" % [failures.size(), scripts.size()])
	var in_ci: bool = OS.get_environment(ENV_GITHUB_ACTIONS) == "true"
	for path: String in failures:
		print("  - %s" % path)
		if in_ci:
			print("::error file=%s,title=GDScript::script failed to compile" % _repo_path(path))
	quit(1)
#endregion

#region Private Methods
func _collect_scripts(dir_path: String, result: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var base: String = dir_path if dir_path.ends_with("/") else dir_path + "/"
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			var child: String = base + entry + "/"
			if not _is_excluded(child):
				_collect_scripts(child, result)
		elif entry.ends_with(".gd"):
			result.append(base + entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_excluded(dir_path: String) -> bool:
	for excluded: String in EXCLUDED_DIRS:
		if dir_path.begins_with(excluded):
			return true
	return false


func _repo_path(res_path: String) -> String:
	if res_path.begins_with("res://"):
		return res_path.substr("res://".length())
	return res_path
#endregion
