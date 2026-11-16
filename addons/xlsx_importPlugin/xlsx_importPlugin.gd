@tool
extends EditorImportPlugin
## Keeps the .xlsx import artifact valid while emitting the runtime JSON files.
##
## res://Data/json/ is the single source of truth, so this importer never
## overwrites JSON that already exists (a fresh checkout would otherwise
## clobber balancing edits with stale workbook data). Re-exporting the workbook
## is an explicit action:
##   Project > Tools > Export game_data.xlsx to JSON
##   godot --headless --path . --script res://Tools/export_xlsx_to_json.gd

#region Constants
const DB_SCRIPT_PATH: String = "res://Data/gameDatabase.gd"
#endregion

#region Public Methods
func _get_importer_name() -> String: return "game.xlsx"
func _get_visible_name() -> String: return "Game Data"
func _get_recognized_extensions() -> PackedStringArray: return ["xlsx"]
func _get_save_extension() -> String: return "res"          # binary!
func _get_resource_type() -> String: return "Resource"
func _get_preset_count() -> int: return 1
func _get_preset_name(i) -> String: return "Default"
func _get_import_options(path, preset) -> Array: return []
func _get_option_visibility(path, opt, opts) -> bool: return true
func _get_priority() -> float: return 1.0
func _get_import_order() -> int: return 0

func _import(source_file, save_path, options, platform_variants, gen_files) -> int:
	var builder: DataBuilder = DataBuilder.new()
	var export_result: Error = builder.export_xlsx_to_json(source_file, DataBuilder.DEFAULT_JSON_DIR, false)
	for warning_text: String in builder.warnings:
		print("[xlsx_import] " + warning_text)
	if export_result != OK:
		for error_text: String in builder.errors:
			push_error("[xlsx_import] " + error_text)
		print("[xlsx_import] JSON not regenerated; existing res://Data/json files are kept.")
	else:
		print("[xlsx_import] JSON export checked (missing files only).")

	# --- keep the .res artifact the .import file expects ---
	var database: GameDatabase = GameDatabase.new()
	var database_script: GDScript = load(DB_SCRIPT_PATH)
	if database_script == null:
		push_error("[xlsx_import] failed to load " + DB_SCRIPT_PATH)
		return ERR_CANT_CREATE
	database.set_script(database_script)
	var save_result: Error = ResourceSaver.save(database, "%s.res" % save_path)
	if save_result != OK:
		push_error("[xlsx_import] could not save import artifact (error %d)" % save_result)
	return save_result
#endregion