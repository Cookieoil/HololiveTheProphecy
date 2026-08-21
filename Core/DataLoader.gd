class_name DataLoader
extends RefCounted

const DB_PATH := "res://Data/xlsx/game_data.xlsx"
static var _db: GameDatabase

static func db() -> GameDatabase:
	if _db == null:
		if not ResourceLoader.exists(DB_PATH):
			printerr("[DataLoader] %s has no imported artifact. ", DB_PATH,
				"Open the project in the editor to run the xlsx import, or check",
				" CI output for 'GAME DATA INVALID' errors from the last xlsx change.")
			quit_code(1)
			return null
		_db = ResourceLoader.load(DB_PATH) as GameDatabase
		if _db == null:
			printerr("[DataLoader] loaded %s but it is not a GameDatabase — ",
				"import produced wrong data; reimport the xlsx.")
			quit_code(1)
	return _db

static func quit_code(code: int) -> void:
	if not Engine.is_editor_hint():
		Engine.get_main_loop().quit(code)

static func reload() -> void:
	_db = null
