extends SceneTree
## Headless link check for the spine-godot GDExtension: proves the runtime in
## `bin/` loaded, exposes the Spine classes the game scripts call through
## `ClassDB`/`call()`, and can actually load both committed skeleton resources.
##
## Usage:
##   godot --headless --path . --script res://Tools/check_spine_runtime.gd
##
## Exit code 0 = the runtime and every skeleton resource loaded, 1 = otherwise.
##
## @author TheGreatJellyfish
## @version 11/20/2026

#region Constants
const REQUIRED_CLASSES: PackedStringArray = [
	"SpineSprite",
	"SpineBoneNode",
	"SpineSkeletonDataResource",
	"SpineAtlasResource",
	"SpineSkeletonFileResource",
]
## Every committed character folder that a unit can resolve to at runtime.
const SKELETON_RESOURCES: PackedStringArray = [
	"res://Scenes/BattleUnit/Spine/300101_zhujue/300101_zhujue.tres",
	"res://Scenes/BattleUnit/Spine/300402_hongnujian/300402_hongnujian.tres",
]
#endregion

#region Lifecycle Methods
func _initialize() -> void:
	var failures: PackedStringArray = PackedStringArray()
	_check_classes(failures)
	_check_resources(failures)

	if failures.is_empty():
		print("SPINE RUNTIME CHECK PASSED")
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


func _check_resources(failures: PackedStringArray) -> void:
	for path: String in SKELETON_RESOURCES:
		if not ResourceLoader.exists(path):
			failures.append("missing resource %s" % path)
			continue
		var data: Resource = load(path)
		if data == null:
			failures.append("could not load %s" % path)
			continue
		var raw_skeleton_file: Variant = data.get("skeleton_file_res")
		if not (raw_skeleton_file is Resource):
			failures.append("%s has no skeleton_file_res" % path)
			continue
		print("resource OK: %s (%s)" % [path, data.get_class()])
#endregion
