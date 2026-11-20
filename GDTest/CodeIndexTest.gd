class_name CodeIndexTest
extends GdUnitTestSuite
## Fixture tests for Tools/CodeIndexParser.gd, the pure parsing layer behind the
## generated navigation set (Docs/). Each fixture is an inline script so the test
## never depends on the current state of the game code, and the expectations are
## hard-coded line numbers, which is what makes them meaningful.
##
## @author TheGreatJellyfish
## @version 11/18/2026

const SCRIPT_PATH: String = "res://Fixture/Thing.gd"
const SCENE_PATH: String = "res://Fixture/Thing.tscn"

## A script with a header doc, every declaration kind and a wrapped signature.
func _script_fixture() -> String:
	return "\n".join([
		"class_name FixtureThing",
		"extends RefCounted",
		"## Header summary line.",
		"##",
		"## @author Nobody",
		"",
		"const LIMIT: int = 3",
		"",
		"signal changed(old_value: int, new_value: int)",
		"",
		"@export var speed: float = 200.0",
		"@onready var label: Label = $Label",
		"",
		"enum Mode {",
		"\tFIRST,",
		"\tSECOND = 5,",
		"}",
		"",
		"static var _cache: Dictionary = {}",
		"",
		"func apply(",
		"\tamount: int,",
		"\tbonus: int = 0",
		") -> int:",
		"\treturn amount + bonus",
		"",
		"func _helper() -> void:",
		"\tpass",
	])


## The same declarations, but the only `##` block belongs to an @export var.
func _member_doc_fixture() -> String:
	return "\n".join([
		"class_name FixturePlain",
		"extends Node",
		"",
		"@export var debug_menu_enabled: bool = true",
		"## Tester tools. Turn off for a build that must not show them.",
		"@export var other_flag: bool = true",
		"",
		"func go() -> void:",
		"\tpass",
	])


func _function_named(info: Dictionary, name: String) -> Dictionary:
	for entry: Variant in CodeIndexParser.dict_array(info, "functions"):
		if entry is Dictionary:
			var record: Dictionary = entry
			if CodeIndexParser.dict_string(record, "name") == name:
				return record
	return {}


## Narrows one element of a parsed array into a Dictionary, so the strict typing
## rules stay satisfied without casts scattered through the assertions.
func _entry_at(entries: Array, index: int) -> Dictionary:
	var value: Variant = entries[index]
	if value is Dictionary:
		var record: Dictionary = value
		return record
	return {}


func _scene_fixture() -> String:
	return "\n".join([
		"[gd_scene load_steps=3 format=3 uid=\"uid://abc\"]",
		"",
		"[ext_resource type=\"Script\" uid=\"uid://script\" path=\"res://Fixture/Thing.gd\" id=\"1_root\"]",
		"[ext_resource type=\"PackedScene\" path=\"res://Scenes/Cards/CardUI.tscn\" id=\"2_card\"]",
		"",
		"[node name=\"Root\" type=\"Node\"]",
		"script = ExtResource(\"1_root\")",
		"",
		"[node name=\"HUD\" type=\"CanvasLayer\" parent=\".\"]",
		"",
		"[node name=\"Bar\" type=\"HBoxContainer\" parent=\"HUD\"]",
		"",
		"[node name=\"Card\" parent=\"HUD/Bar\" instance=ExtResource(\"2_card\")]",
		"",
		"[connection signal=\"pressed\" from=\"HUD/Bar/Card\" to=\".\" method=\"_on_pressed\"]",
	])


func test_script_header_doc_becomes_the_summary() -> void:
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, _script_fixture())
	assert_str(CodeIndexParser.dict_string(info, "summary")).is_equal("Header summary line.")
	assert_str(CodeIndexParser.dict_string(info, "class_name")).is_equal("FixtureThing")
	assert_int(CodeIndexParser.dict_int(info, "class_line")).is_equal(1)
	assert_str(CodeIndexParser.dict_string(info, "extends")).is_equal("RefCounted")


func test_member_doc_is_not_the_file_summary() -> void:
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, _member_doc_fixture())
	# The only `##` block documents an @export, so the file has no header doc and
	# the role falls back to a structural summary instead of a wrong sentence.
	assert_str(CodeIndexParser.dict_string(info, "summary")).is_empty()
	assert_str(CodeIndexParser.script_role(info)).is_equal("extends Node, 2 export(s), 1 function(s)")


func test_declarations_are_classified_by_kind() -> void:
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, _script_fixture())
	assert_int(CodeIndexParser.dict_array(info, "constants").size()).is_equal(1)
	assert_int(CodeIndexParser.dict_array(info, "signals").size()).is_equal(1)
	assert_int(CodeIndexParser.dict_array(info, "exports").size()).is_equal(1)
	assert_int(CodeIndexParser.dict_array(info, "onready").size()).is_equal(1)
	assert_int(CodeIndexParser.dict_array(info, "variables").size()).is_equal(1)
	assert_int(CodeIndexParser.dict_array(info, "functions").size()).is_equal(2)

	var exported: Dictionary = _entry_at(CodeIndexParser.dict_array(info, "exports"), 0)
	assert_str(CodeIndexParser.dict_string(exported, "name")).is_equal("speed")
	assert_str(CodeIndexParser.dict_string(exported, "type")).is_equal("float")
	var wired: Dictionary = _entry_at(CodeIndexParser.dict_array(info, "onready"), 0)
	assert_str(CodeIndexParser.dict_string(wired, "name")).is_equal("label")
	var cached: Dictionary = _entry_at(CodeIndexParser.dict_array(info, "variables"), 0)
	assert_str(CodeIndexParser.dict_string(cached, "name")).is_equal("_cache")
	assert_str(CodeIndexParser.dict_string(cached, "type")).is_equal("Dictionary")


func test_wrapped_signature_keeps_arguments_and_return_type() -> void:
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, _script_fixture())
	var apply: Dictionary = _function_named(info, "apply")
	assert_bool(apply.is_empty()).is_false()
	assert_str(CodeIndexParser.dict_string(apply, "args")).is_equal("amount: int, bonus: int = 0")
	assert_str(CodeIndexParser.dict_string(apply, "returns")).is_equal("int")
	assert_int(CodeIndexParser.dict_int(apply, "line")).is_equal(21)
	# The range stops on the last body line, not on the next declaration.
	assert_int(CodeIndexParser.dict_int(apply, "end")).is_equal(25)
	assert_str(CodeIndexParser.line_range(apply)).is_equal("21-25")


func test_last_function_range_reaches_the_end_of_the_file() -> void:
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, _script_fixture())
	var helper: Dictionary = _function_named(info, "_helper")
	assert_bool(CodeIndexParser.dict_bool(helper, "private")).is_true()
	assert_int(CodeIndexParser.dict_int(helper, "line")).is_equal(27)
	assert_int(CodeIndexParser.dict_int(helper, "end")).is_equal(28)


func test_enum_block_range_and_values() -> void:
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, _script_fixture())
	var enums: Array = CodeIndexParser.dict_array(info, "enums")
	assert_int(enums.size()).is_equal(1)
	var mode: Dictionary = _entry_at(enums, 0)
	assert_str(CodeIndexParser.dict_string(mode, "name")).is_equal("Mode")
	assert_int(CodeIndexParser.dict_int(mode, "line")).is_equal(14)
	assert_int(CodeIndexParser.dict_int(mode, "end")).is_equal(17)
	assert_array(CodeIndexParser.dict_string_array(mode, "values")).contains_exactly(["FIRST", "SECOND"])


func test_one_line_enum_is_parsed() -> void:
	var text: String = "\n".join([
		"class_name FixtureInline",
		"extends RefCounted",
		"enum Scope { ALLIES, ENEMIES, ALL }",
	])
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, text)
	var scope: Dictionary = _entry_at(CodeIndexParser.dict_array(info, "enums"), 0)
	assert_str(CodeIndexParser.dict_string(scope, "name")).is_equal("Scope")
	assert_int(CodeIndexParser.dict_int(scope, "end")).is_equal(3)
	assert_array(CodeIndexParser.dict_string_array(scope, "values")).contains_exactly(["ALLIES", "ENEMIES", "ALL"])


func test_inner_class_is_listed_without_flattening_members() -> void:
	var text: String = "\n".join([
		"extends GdUnitTestSuite",
		"",
		"class RecordingUI extends GameUI:",
		"\tfunc _init() -> void:",
		"\t\tpass",
		"",
		"func test_something() -> void:",
		"\tpass",
	])
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, text)
	var inner: Array = CodeIndexParser.dict_array(info, "inner_classes")
	assert_int(inner.size()).is_equal(1)
	var inner_entry: Dictionary = _entry_at(inner, 0)
	assert_str(CodeIndexParser.dict_string(inner_entry, "name")).is_equal("RecordingUI")
	assert_str(CodeIndexParser.dict_string(inner_entry, "extends")).is_equal("GameUI")
	# Only the outer function is indexed; the inner body is not a declaration.
	assert_int(CodeIndexParser.dict_array(info, "functions").size()).is_equal(1)


func test_crlf_input_matches_lf_input() -> void:
	var lf: String = _script_fixture()
	var info_lf: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, lf)
	var info_crlf: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, lf.replace("\n", "\r\n"))
	assert_int(CodeIndexParser.dict_int(info_crlf, "lines")).is_equal(CodeIndexParser.dict_int(info_lf, "lines"))
	assert_int(CodeIndexParser.dict_array(info_crlf, "functions").size()).is_equal(2)
	assert_str(CodeIndexParser.line_range(_entry_at(CodeIndexParser.dict_array(info_crlf, "functions"), 0))).is_equal("21-25")


func test_scene_script_reference_uses_the_path_not_the_uid() -> void:
	var scene: Dictionary = CodeIndexParser.parse_scene(SCENE_PATH, _scene_fixture())
	assert_str(CodeIndexParser.dict_string(scene, "root_name")).is_equal("Root")
	assert_str(CodeIndexParser.dict_string(scene, "root_type")).is_equal("Node")
	# `uid="uid://script"` must not be mistaken for the `id="1_root"` mapping.
	assert_str(CodeIndexParser.dict_string(scene, "script")).is_equal("Fixture/Thing.gd")
	assert_int(CodeIndexParser.dict_int(scene, "nodes")).is_equal(4)


func test_scene_node_depths_and_instance() -> void:
	var scene: Dictionary = CodeIndexParser.parse_scene(SCENE_PATH, _scene_fixture())
	var nodes: Array = CodeIndexParser.dict_array(scene, "node_list")
	assert_int(nodes.size()).is_equal(4)
	assert_int(CodeIndexParser.dict_int(_entry_at(nodes, 0), "depth")).is_equal(0)
	assert_int(CodeIndexParser.dict_int(_entry_at(nodes, 1), "depth")).is_equal(1)
	# A child of a direct child of the root is two levels down, not one.
	assert_int(CodeIndexParser.dict_int(_entry_at(nodes, 2), "depth")).is_equal(2)
	assert_int(CodeIndexParser.dict_int(_entry_at(nodes, 3), "depth")).is_equal(3)
	assert_str(CodeIndexParser.dict_string(_entry_at(nodes, 3), "instance")).is_equal("Scenes/Cards/CardUI.tscn")


func test_scene_without_a_script_still_parses() -> void:
	var text: String = "\n".join([
		"[gd_scene format=3]",
		"",
		"[node name=\"Alone\" type=\"Node2D\"]",
	])
	var scene: Dictionary = CodeIndexParser.parse_scene(SCENE_PATH, text)
	assert_str(CodeIndexParser.dict_string(scene, "script")).is_empty()
	assert_int(CodeIndexParser.dict_int(scene, "nodes")).is_equal(1)


func test_data_file_shape_entries_and_keys() -> void:
	var text: String = "{\n  \"a\": { \"display_name\": \"A\", \"max_hp\": 10 },\n  \"b\": { \"display_name\": \"B\", \"max_hp\": 4 }\n}"
	var data: Dictionary = CodeIndexParser.parse_data_file("res://Data/json/units.json", text)
	assert_str(CodeIndexParser.dict_string(data, "shape")).is_equal("object")
	assert_int(CodeIndexParser.dict_int(data, "entries")).is_equal(2)
	assert_array(CodeIndexParser.dict_string_array(data, "keys")).contains_exactly(["display_name", "max_hp"])
	assert_array(CodeIndexParser.dict_string_array(data, "root_keys")).contains_exactly(["a", "b"])


func test_data_file_array_shape() -> void:
	var data: Dictionary = CodeIndexParser.parse_data_file("res://Data/json/waves.json", "[{ \"wave_index\": 1, \"enemies\": [] }]")
	assert_str(CodeIndexParser.dict_string(data, "shape")).is_equal("array")
	assert_int(CodeIndexParser.dict_int(data, "entries")).is_equal(1)
	assert_array(CodeIndexParser.dict_string_array(data, "keys")).contains_exactly(["enemies", "wave_index"])


func test_page_file_names_are_derived_from_the_source_path() -> void:
	assert_str(CodeIndexParser.script_page_file("Core/Card.gd")).is_equal("Core/Card.md")
	assert_str(CodeIndexParser.script_page_file("Scenes/Cards/CardUI.gd")).is_equal("Scenes/Cards/CardUI.md")
	assert_str(CodeIndexParser.scene_page_file("Scenes/BattleScene/BattleScene.tscn")).is_equal("Scenes/BattleScene/BattleScene.scene.md")


func test_dependency_scan_ignores_comments() -> void:
	var text: String = "\n".join([
		"extends RefCounted",
		"## A doc comment that mentions CardUI and Card.",
		"func go() -> void:",
		"\tvar used: CardUI = null",
		"\tpass",
	])
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, text)
	var infos: Array[Dictionary] = [info]
	var texts: Dictionary = {SCRIPT_PATH: text}
	CodeIndexParser.apply_dependencies(infos, texts, PackedStringArray(["Card", "CardUI", "Unit"]))
	assert_array(CodeIndexParser.dict_string_array(info, "uses")).contains_exactly(["CardUI"])


func test_resource_refs_are_deduplicated_and_skip_addons() -> void:
	var text: String = "\n".join([
		"extends Node",
		"const A: PackedScene = preload(\"res://Scenes/Cards/CardUI.tscn\")",
		"const B: PackedScene = preload(\"res://Scenes/Cards/CardUI.tscn\")",
		"const C: GDScript = preload(\"res://addons/gdUnit4/src/GdUnitTestSuite.gd\")",
	])
	var info: Dictionary = CodeIndexParser.parse_script(SCRIPT_PATH, text)
	var infos: Array[Dictionary] = [info]
	var texts: Dictionary = {SCRIPT_PATH: text}
	CodeIndexParser.apply_dependencies(infos, texts, PackedStringArray())
	assert_array(CodeIndexParser.dict_string_array(info, "refs")).contains_exactly(["res://Scenes/Cards/CardUI.tscn"])
