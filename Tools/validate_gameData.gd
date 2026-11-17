extends Node
## Validates the game data pipeline:
##   1. the bulk-entry workbook (res://Data/xlsx/game_data.xlsx) parses cleanly
##   2. the runtime JSON (res://Data/json/) loads into a usable GameDatabase
##
## Exit code 0 = valid, 1 = invalid. Safe on fresh checkouts.
##
## Usage: godot --headless --path . "res://Tools/validator.tscn"

#region Constants
const XLSX_PATH: String = "res://Data/xlsx/game_data.xlsx"
const DATA_BUILDER_PATH: String = "res://Tools/dataBuilder.gd"
#endregion

#region Private Variables
var _errors: PackedStringArray = PackedStringArray()
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_validate_workbook()
	_validate_json()
	if _errors.is_empty():
		print("VALIDATION PASSED")
		get_tree().quit(0)
		return
	print("VALIDATION FAILED (%d errors):" % _errors.size())
	for message: String in _errors:
		print("  - %s" % message)
	get_tree().quit(1)
#endregion

#region Private Methods
## Checks that the workbook parses and that its foreign keys resolve.
func _validate_workbook() -> void:
	print("=== Workbook: %s ===" % XLSX_PATH)
	if not FileAccess.file_exists(XLSX_PATH):
		_errors.append("workbook not found: %s" % XLSX_PATH)
		return
	var builder_script: GDScript = load(DATA_BUILDER_PATH)
	if builder_script == null:
		_errors.append("cannot load " + DATA_BUILDER_PATH)
		return
	var builder: DataBuilder = builder_script.new()
	var sheets: Dictionary = XlsxReader.read_sheets(XLSX_PATH)
	if sheets.is_empty():
		_errors.append("could not read any sheet from %s" % XLSX_PATH)
		return
	print("sheets read: %s" % str(sheets.keys()))
	var bundle: Dictionary = builder.build_json_bundle(sheets)
	for warning_text: String in builder.warnings:
		print("  warning: %s" % warning_text)
	for error_text: String in builder.errors:
		_errors.append("[workbook] %s" % error_text)
	if builder.errors.is_empty():
		print("workbook OK: %d skills, %d allies, %d enemies" % [
			_count(bundle, "skills"), _count(bundle, "allies"), _count(bundle, "enemies"),
		])


## Checks that the runtime JSON files load and cross-reference correctly.
func _validate_json() -> void:
	print("=== Runtime JSON: %s ===" % DataLoader.JSON_DIR)
	var db: GameDatabase = DataLoader.load_database()
	for error_text: String in DataLoader.get_errors():
		_errors.append("[json] %s" % error_text)
	if db == null:
		_errors.append("[json] DataLoader returned no database")
		return
	print("loaded %d skills, %d allies, %d enemies, %d waves" % [
		db.skills.size(), db.allies.size(), db.enemies.size(), db.waves.size(),
	])
	if db.skills.is_empty():
		_errors.append("[json] skills registry is empty")
	if db.units.is_empty():
		_errors.append("[json] units registry is empty")
	if db.waves.is_empty():
		_errors.append("[json] waves registry is empty")
	var allies: Array = db.config.get("allies", [])
	for ally_id: String in allies:
		if not db.units.has(ally_id):
			_errors.append("[json] config.allies references unknown unit '%s'" % ally_id)


## Size of a Dictionary entry inside the JSON bundle.
func _count(bundle: Dictionary, key: String) -> int:
	var value: Variant = bundle.get(key, {})
	if value is Dictionary:
		var entries: Dictionary = value
		return entries.size()
	return 0
#endregion
