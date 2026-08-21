@tool
extends EditorImportPlugin

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
	var builder := DataBuilder.new()
	var db: GameDatabase = builder.build(XlsxReader.read_sheets(source_file))
	
	if builder.errors.size() > 0:
		for e in builder.errors: push_error(e)
		return ERR_PARSE_ERROR
	
	# --- re-attach the script explicitly; class_name construction can silently
	# produce a script-less object during editor import passes ---
	const GD_SCRIPT_PATH := "res://Data/gameDatabase.gd"
	var gd_script := load(GD_SCRIPT_PATH)
	if gd_script == null:
		push_error("[xlsx_import] failed to load " + GD_SCRIPT_PATH)
		return ERR_CANT_CREATE
	db.set_script(gd_script)
	
	print("[xlsx_import] script attached: ", db.get_script().resource_path)
	var err := ResourceSaver.save(db, "%s.res" % save_path)
	print("[xlsx_import] save err=%d, size=%d" % [
		err,
		FileAccess.get_file_as_bytes("%s.res" % save_path).size()
	])
	return err
