extends SceneTree
## Headless Excel -> JSON exporter for the game data pipeline.
##
## Usage:
##   godot --headless --path . --script res://Tools/export_xlsx_to_json.gd
##
## The workbook (res://Data/xlsx/game_data.xlsx) is only used for bulk data
## entry. res://Data/json/ is the single source of truth the game loads at
## runtime, so only run this after intentionally re-exporting the workbook.

#region Constants
const DATA_BUILDER_PATH: String = "res://Tools/dataBuilder.gd"
#endregion

#region Lifecycle Methods
func _initialize() -> void:
	var builder_script: GDScript = load(DATA_BUILDER_PATH)
	if builder_script == null:
		printerr("[export] cannot load " + DATA_BUILDER_PATH)
		quit(1)
		return
	var builder: DataBuilder = builder_script.new()
	var result: Error = builder.export_xlsx_to_json()
	for warning_text: String in builder.warnings:
		print("[export] warning: " + warning_text)
	if result != OK:
		for error_text: String in builder.errors:
			printerr("[export] error: " + error_text)
		printerr("[export] FAILED (error %d)" % result)
		quit(1)
		return
	print("[export] game data JSON written to %s" % DataBuilder.DEFAULT_JSON_DIR)
	quit(0)
#endregion