extends Node
## Validates game_data.xlsx without touching the import system.
## Exit code 0 = valid, 1 = invalid. Safe on fresh checkouts.
##
## Usage: godot --headless --path . "res://Tools/validator.tscn"

const XLSX_PATH := "res://Data/xlsx/game_data.xlsx"
# Load by path, NOT by class_name: on a fresh checkout (no .godot/), the
# global script-class cache may not exist yet — as we learned the hard way.
const XlsxReaderScript : Script = preload("res://Tools/xlsx_reader.gd")
const DataBuilderScript : Script = preload("res://Tools/dataBuilder.gd")

func _ready() -> void:
	# Give the engine node engine tree one idle frame to fully index 
	# and compile broken global classes (like ColorUtils)
	await get_tree().process_frame
	_run_validation()
	
func _run_validation() -> void:
	print("=== Game data validation: %s ===" % XLSX_PATH)

	var sheets: Dictionary = XlsxReaderScript.call("read_sheets", XLSX_PATH)
	if sheets.is_empty():
		print("VALIDATION FAILED: could not read any sheets from %s" % XLSX_PATH)
		get_tree().quit(1)
		return
	print("sheets read: %s" % str(sheets.keys()))

	var builder: RefCounted = DataBuilderScript.new()
	var db: Resource = builder.build(sheets)
	var errors: Array = builder.errors

	# Structural smoke checks on the built database, independent of builder errors
	if db != null:
		if db.get("units") is Dictionary and db.get("units").is_empty():
			errors.append("units registry is empty")
		if db.get("waves") is Array and db.get("waves").is_empty():
			errors.append("waves registry is empty")
		if db.get("config") is Dictionary:
			var cfg: Dictionary = db.get("config")
			var units: Dictionary = db.get("units")
			for ally_id in cfg.get("allies", []):
				if not units.has(ally_id):
					errors.append("config.allies references unknown unit '%s'" % ally_id)

	if errors.is_empty():
		print("VALIDATION PASSED")
		get_tree().quit(0)
	else:
		print("VALIDATION FAILED (%d errors):" % errors.size())
		for e in errors:
			print("  - %s" % e)
		get_tree().quit(1)
