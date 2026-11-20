extends SceneTree
## Headless link and compatibility gate for the spine-godot GDExtension.
##
## Proves three things:
##   1. the runtime in `bin/` loaded and exposes the Spine classes the game
##      scripts call through `ClassDB` / `call()`;
##   2. every committed rig under `res://Scenes/BattleUnit/Spine/` actually
##      loads its skeleton data — a rig exported from a different Spine version
##      loads as a resource but fails here with "Skeleton version X does not
##      match runtime version Y";
##   3. every rig is exported from the Spine version the runtime expects, and
##      carries the combat rig from the I-1 spec (reported as a note, so a rig
##      that is still being authored does not fail the gate).
##
## Usage:
##   godot --headless --path . --script res://Tools/check_spine_runtime.gd
##
## Exit code 0 = the runtime and every committed rig are usable, 1 = otherwise.
##
## @author TheGreatJellyfish
## @version 11/20/2026

#region Constants
## Classes the game scripts touch through `ClassDB` or dynamic `call()`.
const REQUIRED_CLASSES: PackedStringArray = [
	"SpineSprite",
	"SpineBoneNode",
	"SpineSkeletonDataResource",
	"SpineAtlasResource",
	"SpineSkeletonFileResource",
]
## Folder scanned for `<char_id>/<char_id>.tres` rigs.
const RIG_DIR: String = "res://Scenes/BattleUnit/Spine/"
## Major.minor of the spine-godot runtime in `bin/`. A rig exported from any
## other Spine version is rejected by the runtime at load time.
const REQUIRED_SPINE_VERSION: String = "4.3"
## Combat-rig contract (task I-1). Reported, not enforced, until the rigs land.
const REQUIRED_BONES: PackedStringArray = ["Center_Hit_Point", "Cast_Origin_Point"]
const REQUIRED_EVENTS: PackedStringArray = ["event_vfx_spawn", "event_hit_frame"]
#endregion

#region Lifecycle Methods
func _initialize() -> void:
	var failures: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()
	_check_classes(failures)

	var rigs: PackedStringArray = PackedStringArray()
	_collect_rigs(RIG_DIR, rigs)

	if rigs.is_empty():
		print("note: no rigs under %s — every unit falls back to its icon art." % RIG_DIR)
	else:
		for path: String in rigs:
			_check_rig(path, failures, notes)

	if not notes.is_empty():
		print("")
		print("Combat rig notes (task I-1, not fatal):")
		for note: String in notes:
			print("  - %s" % note)

	print("")
	if failures.is_empty():
		print("SPINE RUNTIME CHECK PASSED (%d rig(s), runtime %s)" % [rigs.size(), REQUIRED_SPINE_VERSION])
		quit(0)
		return
	print("SPINE RUNTIME CHECK FAILED:")
	for line: String in failures:
		print("  - %s" % line)
	quit(1)
#endregion

#region Private Methods
func _check_classes(failures: PackedStringArray) -> void:
	for clazz: String in REQUIRED_CLASSES:
		if ClassDB.class_exists(clazz):
			print("class OK: %s" % clazz)
			continue
		failures.append("missing class %s (bin/spine_godot_extension.gdextension not loaded?)" % clazz)


func _collect_rigs(dir_path: String, result: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var base: String = dir_path if dir_path.ends_with("/") else dir_path + "/"
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			_collect_rigs(base + entry + "/", result)
		elif entry.ends_with(".tres"):
			result.append(base + entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _check_rig(path: String, failures: PackedStringArray, notes: PackedStringArray) -> void:
	var resource: Resource = load(path)
	if resource == null:
		failures.append("could not load %s" % path)
		return

	if not resource.has_method("is_skeleton_data_loaded"):
		failures.append("%s is not a Spine skeleton resource" % path)
		return

	# The runtime logs a version mismatch and leaves the skeleton unloaded, so
	# this is the check that catches a rig exported from the wrong version.
	if resource.call("is_skeleton_data_loaded") != true:
		var reported: String = str(resource.call("get_version"))
		if reported.is_empty():
			reported = "unknown"
		failures.append(
			"%s failed to load its skeleton (data reports Spine %s, runtime is %s)"
			% [path, reported, REQUIRED_SPINE_VERSION]
		)
		return

	var version: String = str(resource.call("get_version"))
	if not version.begins_with(REQUIRED_SPINE_VERSION + "."):
		failures.append(
			"%s exports Spine %s but the runtime is %s" % [path, version, REQUIRED_SPINE_VERSION]
		)
		return

	var animations: Array = resource.call("get_animations")
	if animations.is_empty():
		failures.append("%s contains no animations" % path)
		return

	print("rig OK: %s (Spine %s, %d animation(s))" % [path, version, animations.size()])

	for bone: String in REQUIRED_BONES:
		if resource.call("find_bone", bone) == null:
			notes.append("%s has no '%s' bone" % [path, bone])
	for event_name: String in REQUIRED_EVENTS:
		if resource.call("find_event", event_name) == null:
			notes.append("%s has no '%s' event" % [path, event_name])
#endregion
