@tool
extends EditorPlugin
## Registers the xlsx importer plus an explicit "Tools" menu action that
## re-exports res://Data/xlsx/game_data.xlsx into res://Data/json/.
##
## The JSON files are the single source of truth, so the export is always an
## intentional action instead of something that happens on editor startup.

#region Constants
const XlsxImportPlugin := preload("res://addons/xlsx_importPlugin/xlsx_importPlugin.gd")
const DATA_BUILDER_PATH: String = "res://Tools/dataBuilder.gd"
const XLSX_PATH: String = "res://Data/xlsx/game_data.xlsx"
const MENU_ITEM: String = "Export game_data.xlsx to JSON"
#endregion

#region Private Variables
var import_plugin: EditorImportPlugin
#endregion

#region Lifecycle Methods
func _enter_tree() -> void:
	import_plugin = XlsxImportPlugin.new()
	add_import_plugin(import_plugin)
	add_tool_menu_item(MENU_ITEM, _on_export_requested)
	_restore_missing_json()
	print("[xlsx-plugin] ready (importer registered, '%s' menu item added)" % MENU_ITEM)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	if import_plugin != null:
		remove_import_plugin(import_plugin)
		import_plugin = null
#endregion

#region Private Methods
## Safety net: res://Data/json/ is the source of truth, but if it is missing
## (fresh clone, 'git clean', deleted folder) rebuild only the absent files.
## Existing JSON is never overwritten, so balancing edits stay untouched.
func _restore_missing_json() -> void:
	var missing: bool = false
	for file_name: String in DataBuilder.JSON_FILE_KEYS:
		if not FileAccess.file_exists(DataBuilder.DEFAULT_JSON_DIR.path_join(file_name)):
			missing = true
			break
	if not missing:
		return
	var builder_script: GDScript = load(DATA_BUILDER_PATH)
	if builder_script == null:
		push_error("[xlsx-plugin] cannot load " + DATA_BUILDER_PATH)
		return
	var builder: DataBuilder = builder_script.new()
	var result: Error = builder.export_xlsx_to_json(XLSX_PATH, DataBuilder.DEFAULT_JSON_DIR, false)
	if result != OK:
		for error_text: String in builder.errors:
			push_error("[xlsx-plugin] " + error_text)
		return
	print("[xlsx-plugin] restored missing game data JSON in " + DataBuilder.DEFAULT_JSON_DIR)
	EditorInterface.get_resource_filesystem().scan()
#endregion
## Project > Tools > Export game_data.xlsx to JSON
func _on_export_requested() -> void:
	var builder_script: GDScript = load(DATA_BUILDER_PATH)
	if builder_script == null:
		push_error("[xlsx-plugin] cannot load " + DATA_BUILDER_PATH)
		return
	var builder: DataBuilder = builder_script.new()
	var result: Error = builder.export_xlsx_to_json(XLSX_PATH, DataBuilder.DEFAULT_JSON_DIR, true)
	for warning_text: String in builder.warnings:
		push_warning("[xlsx-plugin] " + warning_text)
	if result != OK:
		for error_text: String in builder.errors:
			push_error("[xlsx-plugin] " + error_text)
		return
	print("[xlsx-plugin] game data JSON written to " + DataBuilder.DEFAULT_JSON_DIR)
	EditorInterface.get_resource_filesystem().scan()
#endregion