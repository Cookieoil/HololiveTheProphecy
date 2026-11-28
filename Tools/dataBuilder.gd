class_name DataBuilder
extends RefCounted
## Converts the bulk-entry workbook (res://Data/xlsx/game_data.xlsx) into the
## JSON files stored in res://Data/json/.
##
## Those JSON files are the single source of truth the game reads at runtime
## (see Core/DataLoader.gd). The workbook is only used for bulk data entry and
## is never touched by the running game.
##
## Column headers double as JSON keys, e.g. the Effects column
## "value_source:value_source" becomes the JSON entry
## "value_source": "card_value". Types declare how a cell is coerced:
##   name:int              -> JSON number (int)
##   name:bool             -> JSON true/false
##   name:string           -> JSON string
##   name:ref:skills       -> JSON string foreign key (validated)
##   name:list:tags        -> JSON array of strings
##   name:action           -> JSON string validated against the Enums sheet
##   name:int=20           -> JSON number, defaulting to 20 when the cell is empty
##
## @author TheGreatJellyfish
## @version 11/16/2026

#region Constants
const DEFAULT_XLSX_PATH: String = "res://Data/xlsx/game_data.xlsx"
const DEFAULT_JSON_DIR: String = "res://Data/json"
const JSON_INDENT: String = "\t"
const HEADER_SCAN_ROWS: int = 10
const DEFAULT_MAX_MOXIE: int = 20

const SKILLS_FILE: String = "skills.json"
const ALLIES_FILE: String = "allies.json"
const ENEMIES_FILE: String = "enemies.json"
const WAVES_FILE: String = "waves.json"
const CONFIG_FILE: String = "config.json"

const REQUIRED_SHEETS: PackedStringArray = [
	"enums", "skills", "effects", "units", "waves", "config",
]
const VALID_TRIGGERS: PackedStringArray = ["base", "merged"]
const UNIT_SKILL_SLOTS: PackedStringArray = ["skill_1", "skill_2", "ultimate"]

## Emitted JSON file -> key inside the bundle returned by build_json_bundle().
const JSON_FILE_KEYS: Dictionary = {
	"skills.json": "skills",
	"allies.json": "allies",
	"enemies.json": "enemies",
	"waves.json": "waves",
	"config.json": "config",
}

## Field order and fallback value used when emitting each JSON object.
## Keeping the order stable keeps hand/AI edits readable.
const SKILL_DEFAULTS: Dictionary = {
	"display_name": "",
	"base_categories": [],
	"description": "",
	"merged_categories": [],
	"merged_description": "",
	"merged_mode": "and_merged_first",
	"condition_threshold": 0,
}

const EFFECT_DEFAULTS: Dictionary = {
	"effect_id": 0,
	"order": 0,
	"trigger": "base",
	"action": "deal_damage",
	"status_id": "",
	"target_mode": "none",
	"target_count": 1,
	"value_source": "card_value",
	"value_multiplier": 1,
	"value_divisor": 1,
	"value_offset": 0,
	"value_cap": -1,
	"fixed_amount": 0,
	"condition": "none",
	"negate_condition": false,
	"card_select_mode": "pick_n_card",
	"card_mod_type": "buff",
	"card_count": 1,
	"store_resolved_value": false,
}

const UNIT_DEFAULTS: Dictionary = {
	"display_name": "",
	"max_hp": 10,
	"max_moxie": DEFAULT_MAX_MOXIE,
	"is_enemy": false,
	"skill_1": "",
	"skill_2": "",
	"ultimate": "",
}
#endregion

#region Public Variables
## Blocking problems found while reading the workbook. Export stops when set.
var errors: PackedStringArray = []
## Non-blocking notes (duplicate ids, skipped files, ...).
var warnings: PackedStringArray = []
#endregion
#region Public Methods
## Builds every JSON payload from already-read worksheet grids.
## @param sheets - { sheet_name: Array[Array[String]] } produced by XlsxReader
## @return Dictionary - { skills, allies, enemies, waves, config }
func build_json_bundle(sheets: Dictionary) -> Dictionary:
	errors.clear()
	warnings.clear()
	var missing: PackedStringArray = PackedStringArray()
	for sheet_name: String in REQUIRED_SHEETS:
		if not sheets.has(sheet_name):
			missing.append(sheet_name)
	if not missing.is_empty():
		for sheet_name: String in missing:
			errors.append("[dataBuilder] missing sheet '%s' in the workbook" % sheet_name)
		return _empty_bundle()

	var enums: Dictionary = _read_enums(_grid(sheets, "enums"))
	var skills: Dictionary = _read_skills(_grid(sheets, "skills"), enums)
	var effects_by_skill: Dictionary = _read_effects(_grid(sheets, "effects"), enums, skills)
	_attach_effects(skills, effects_by_skill)

	# Units are partitioned into allies.json and enemies.json on is_enemy.
	var units: Dictionary = _read_units(_grid(sheets, "units"), enums, skills)
	var allies: Dictionary = {}
	var enemies: Dictionary = {}
	for unit_id: String in units:
		var unit: Dictionary = units[unit_id]
		if _to_bool(unit.get("is_enemy", false), false):
			enemies[unit_id] = unit
		else:
			allies[unit_id] = unit

	var waves: Dictionary = _read_waves(_grid(sheets, "waves"), enums, units)
	var config: Dictionary = _read_config(_grid(sheets, "config"), units)

	if skills.is_empty():
		errors.append("[skills] no skill rows found")
	if allies.is_empty():
		errors.append("[units] no ally rows found (needs is_enemy = FALSE)")
	if enemies.is_empty():
		warnings.append("[units] no enemy rows found (needs is_enemy = TRUE)")

	return {
		"skills": skills,
		"allies": allies,
		"enemies": enemies,
		"waves": waves,
		"config": config,
	}


## Reads the workbook, validates it and writes the five JSON files.
## @param xlsx_path - workbook to convert (authoring input only)
## @param out_dir - res:// directory that receives the .json files
## @param overwrite_existing - false keeps JSON files already on disk, so a
##        fresh checkout bootstraps data without clobbering hand/AI edits
## @return Error - OK when every file was written or intentionally kept
func export_xlsx_to_json(
	xlsx_path: String = DEFAULT_XLSX_PATH,
	out_dir: String = DEFAULT_JSON_DIR,
	overwrite_existing: bool = true
) -> Error:
	errors.clear()
	warnings.clear()
	if not FileAccess.file_exists(xlsx_path):
		errors.append("[dataBuilder] workbook not found: " + xlsx_path)
		return ERR_FILE_NOT_FOUND
	var sheets: Dictionary = XlsxReader.read_sheets(xlsx_path)
	if sheets.is_empty():
		errors.append("[dataBuilder] no sheet could be read from " + xlsx_path)
		return ERR_PARSE_ERROR
	var bundle: Dictionary = build_json_bundle(sheets)
	if not errors.is_empty():
		return ERR_PARSE_ERROR
	return _write_bundle(bundle, out_dir, overwrite_existing)
#endregion

#region Private Methods
## Writes every bundle entry into out_dir as pretty-printed JSON.
func _write_bundle(bundle: Dictionary, out_dir: String, overwrite_existing: bool) -> Error:
	var absolute_dir: String = ProjectSettings.globalize_path(out_dir)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		errors.append("[dataBuilder] cannot create %s (error %d)" % [out_dir, directory_error])
		return directory_error
	for file_name: String in JSON_FILE_KEYS:
		var bundle_key: String = str(JSON_FILE_KEYS[file_name])
		if not bundle.has(bundle_key):
			errors.append("[dataBuilder] bundle has no '%s' entry for %s" % [bundle_key, file_name])
			return ERR_INVALID_DATA
		var file_path: String = out_dir.path_join(file_name)
		if not overwrite_existing and FileAccess.file_exists(file_path):
			warnings.append("[dataBuilder] kept existing %s" % file_path)
			continue
		var payload: Variant = bundle[bundle_key]
		var text: String = _format_json_value(payload, 0)
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			var open_error: Error = FileAccess.get_open_error()
			errors.append("[dataBuilder] cannot write %s (error %d)" % [file_path, open_error])
			return open_error
		file.store_string(text + "\n")
		file.close()
		print("[dataBuilder] wrote %s" % file_path)
	return OK


## Bundle shape used when the workbook cannot be read at all.
func _empty_bundle() -> Dictionary:
	return {
		"skills": {},
		"allies": {},
		"enemies": {},
		"waves": {"waves": []},
		"config": {},
	}


## Safely fetches a worksheet grid out of the sheets dictionary.
func _grid(sheets: Dictionary, sheet_name: String) -> Array:
	var grid_raw: Variant = sheets.get(sheet_name, [])
	if grid_raw is Array:
		var grid: Array = grid_raw
		return grid
	return []

## Reads the Enums sheet into { enum_name: Array[String] }.
func _read_enums(grid: Array) -> Dictionary:
	var enums: Dictionary = {}
	var header_index: int = _find_first_dense_row(grid)
	if header_index < 0:
		errors.append("[enums] header row not found")
		return enums
	var header: Array = _row_at(grid, header_index)
	for column: int in range(header.size()):
		var enum_name: String = str(header[column]).strip_edges()
		if enum_name.is_empty():
			continue
		var values: Array = []
		# Skip the header row and the ALL-CAPS title row underneath it.
		for row_index: int in range(header_index + 2, grid.size()):
			var row: Array = _row_at(grid, row_index)
			if column >= row.size():
				continue
			var value: String = str(row[column]).strip_edges().to_lower()
			if not value.is_empty():
				values.append(value)
		enums[enum_name] = values
	return enums


## First row (within the scan window) holding at least two non-empty cells.
func _find_first_dense_row(grid: Array) -> int:
	for row_index: int in range(mini(grid.size(), HEADER_SCAN_ROWS)):
		var row: Array = _row_at(grid, row_index)
		var non_empty: int = 0
		for cell: Variant in row:
			if not str(cell).strip_edges().is_empty():
				non_empty += 1
		if non_empty >= 2:
			return row_index
	return -1


## First row (within the scan window) holding at least two "name:type" headers.
func _find_header_row(grid: Array) -> int:
	for row_index: int in range(mini(grid.size(), HEADER_SCAN_ROWS)):
		var row: Array = _row_at(grid, row_index)
		var hits: int = 0
		for cell: Variant in row:
			if not _parse_spec(str(cell)).is_empty():
				hits += 1
		if hits >= 2:
			return row_index
	return -1


## Splits "name:type[:target][=default]" into its parts.
func _parse_spec(text: String) -> Dictionary:
	var spec: Dictionary = {}
	var equals_index: int = text.find("=")
	var head: String = text if equals_index < 0 else text.substr(0, equals_index)
	var parts: PackedStringArray = head.split(":")
	if parts.size() < 2:
		return spec
	var field_name: String = parts[0].strip_edges()
	var type_name: String = parts[1].strip_edges()
	if field_name.is_empty() or type_name.is_empty():
		return spec
	spec["name"] = field_name
	spec["type"] = type_name
	spec["target"] = parts[2].strip_edges() if parts.size() > 2 else ""
	spec["default"] = text.substr(equals_index + 1) if equals_index >= 0 else ""
	spec["has_default"] = equals_index >= 0
	return spec


## Returns a grid row as an Array, or an empty Array when out of bounds.
func _row_at(grid: Array, row_index: int) -> Array:
	if row_index < 0 or row_index >= grid.size():
		return []
	var row_raw: Variant = grid[row_index]
	if row_raw is Array:
		var row: Array = row_raw
		return row
	return []


## Coerces a Variant (usually straight from JSON) into an int.
func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is bool:
		var bool_value: bool = value
		return 1 if bool_value else 0
	if value is String:
		var text: String = value
		if text.is_valid_int():
			return text.to_int()
		if text.is_valid_float():
			return int(text.to_float())
	return fallback


## Coerces a Variant (usually straight from JSON) into a bool.
func _to_bool(value: Variant, fallback: bool) -> bool:
	if value is bool:
		var bool_value: bool = value
		return bool_value
	if value is int:
		var int_value: int = value
		return int_value != 0
	if value is float:
		var float_value: float = value
		return not is_zero_approx(float_value)
	if value is String:
		var text: String = value
		var lowered: String = text.strip_edges().to_lower()
		if lowered in ["true", "1", "yes"]:
			return true
		if lowered in ["false", "0", "no"]:
			return false
	return fallback
## Parses one sheet into an Array of row Dictionaries keyed by column name.
## Cell text is coerced according to its "name:type" header.
func _parse_table(grid: Array, enums: Dictionary, sheet_name: String, check_duplicate_ids: bool = true) -> Array:
	var rows_out: Array = []
	var header_index: int = _find_header_row(grid)
	if header_index < 0:
		errors.append("[%s] header row not found (need >=2 cells like 'name:type')" % sheet_name)
		return rows_out
	var specs: Array = _parse_column_specs(_row_at(grid, header_index), sheet_name)
	if specs.is_empty():
		errors.append("[%s] header row found but no column specs parsed" % sheet_name)
		return rows_out

	var primary_key: String = _primary_key_of(specs)
	var seen_ids: Dictionary = {}
	for row_index: int in range(header_index + 2, grid.size()):  # skip header + title row
		var entry: Dictionary = _parse_table_row(
			_row_at(grid, row_index), row_index + 1, specs, enums, sheet_name,
			seen_ids, primary_key, check_duplicate_ids
		)
		if not entry.is_empty():
			rows_out.append(entry)
	return rows_out


## Turns the header row into one spec per column, in sheet order. A cell with no
## `name:type` is a warning and is read as a string; a gap column is skipped outright,
## because a spreadsheet's trailing empties are not columns anybody declared.
func _parse_column_specs(header: Array, sheet_name: String) -> Array:
	var specs: Array = []
	for column: int in range(header.size()):
		var raw_header: String = str(header[column]).strip_edges()
		var spec: Dictionary = _parse_spec(raw_header)
		if spec.is_empty():
			if raw_header.is_empty():
				continue  # phantom gap column, skip entirely
			warnings.append("[%s] header cell '%s' has no type (add e.g. '%s:string')" % [sheet_name, raw_header, raw_header])
			spec = {"name": raw_header, "type": "string", "target": "", "default": "", "has_default": false}
		spec["_col"] = column
		specs.append(spec)
	return specs


## The first named column is the row's id, and therefore the thing duplicate detection
## keys on.
func _primary_key_of(specs: Array) -> String:
	for spec: Dictionary in specs:
		var name_value: String = str(spec.get("name", ""))
		if not name_value.is_empty():
			return name_value
	return ""


## One data row. An all-blank row is not an entry (spreadsheets keep them around), so it
## comes back empty and the caller skips it.
func _parse_table_row(
	row: Array,
	row_number: int,
	specs: Array,
	enums: Dictionary,
	sheet_name: String,
	seen_ids: Dictionary,
	primary_key: String,
	check_duplicate_ids: bool
) -> Dictionary:
	var entry: Dictionary = {"_row": row_number}
	var has_value: bool = false
	for spec: Dictionary in specs:
		var column_index: int = _to_int(spec.get("_col", -1), -1)
		var raw: String = ""
		if column_index >= 0 and column_index < row.size():
			raw = str(row[column_index]).strip_edges()
		if not raw.is_empty():
			has_value = true
		var field_name: String = str(spec.get("name", ""))
		if field_name.is_empty():
			continue
		entry[field_name] = _coerce(raw, spec, enums, sheet_name, row_number)
	if not has_value:
		return {}
	_warn_duplicate_id(entry, row_number, primary_key, seen_ids, sheet_name, check_duplicate_ids)
	return entry


## Two rows with the same id mean one of them silently wins in the emitted JSON, which is
## worth saying out loud even though it is not fatal.
func _warn_duplicate_id(
	entry: Dictionary,
	row_number: int,
	primary_key: String,
	seen_ids: Dictionary,
	sheet_name: String,
	enabled: bool
) -> void:
	if not enabled or primary_key.is_empty():
		return
	var id_value: String = str(entry.get(primary_key, "")).strip_edges()
	if id_value.is_empty():
		return
	if seen_ids.has(id_value):
		warnings.append("[%s r%d] duplicate id '%s'" % [sheet_name, row_number, id_value])
	seen_ids[id_value] = true


## Converts one raw cell into the JSON value described by its column spec.
func _coerce(raw: String, spec: Dictionary, enums: Dictionary, sheet: String, row_number: int) -> Variant:
	var type_name: String = str(spec.get("type", "string"))
	var location: String = "[%s r%d %s]" % [sheet, row_number, str(spec.get("name", ""))]
	var value: String = _cell_text(raw, spec)
	match type_name:
		"int":
			return _coerce_int(value, location)
		"float":
			return _coerce_float(value, location)
		"bool":
			return _coerce_bool(value, location)
		"string", "ref":
			return value
		"list", "array":
			return _coerce_list(value, spec, enums, location)
		_:
			return _coerce_enum_or_unknown(value, type_name, enums, location)


## An empty cell falls back to the column's declared default, if it has one.
func _cell_text(raw: String, spec: Dictionary) -> String:
	if not raw.is_empty():
		return raw
	if _to_bool(spec.get("has_default", false), false):
		return str(spec.get("default", ""))
	return raw


## An `int` column also accepts a float that happens to be whole ("3.0"), because that is
## what a spreadsheet cell holding 3 often reads as.
func _coerce_int(value: String, location: String) -> Variant:
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float() and value.to_float() == floorf(value.to_float()):
		return int(value.to_float())
	if not value.is_empty():
		errors.append("%s expected int, got '%s'" % [location, value])
	return 0


func _coerce_float(value: String, location: String) -> Variant:
	if value.is_valid_float():
		return value.to_float()
	if not value.is_empty():
		errors.append("%s expected float, got '%s'" % [location, value])
	return 0.0


func _coerce_bool(value: String, location: String) -> Variant:
	var lowered: String = value.to_lower()
	if lowered in ["true", "1"]:
		return true
	if lowered in ["false", "0", ""]:
		return false
	errors.append("%s expected TRUE/FALSE, got '%s'" % [location, value])
	return false


## A `list`/`array` cell is split on `;` when it has one, otherwise on `,`. When the column
## names an enum target, every element is checked against it: a typo in the workbook is
## otherwise only visible as a skill that does nothing at runtime.
func _coerce_list(value: String, spec: Dictionary, enums: Dictionary, location: String) -> Variant:
	var items: Array = []
	if value.is_empty():
		return items
	var enum_target: String = str(spec.get("target", ""))
	var separator: String = ";" if value.find(";") >= 0 else ","
	for item: String in value.split(separator):
		var tag: String = item.strip_edges().to_lower()
		if tag.is_empty():
			continue
		if not enum_target.is_empty() and _has_enum(enums, enum_target) and not _enum_contains(enums, enum_target, tag):
			errors.append("%s '%s' is not a valid %s (see enums sheet)" % [location, tag, enum_target])
		items.append(tag)
	return items


## A column whose type is an enum declared on the Enums sheet, or a type nobody declared.
func _coerce_enum_or_unknown(value: String, type_name: String, enums: Dictionary, location: String) -> Variant:
	if _has_enum(enums, type_name):
		if not value.is_empty() and not _enum_contains(enums, type_name, value):
			errors.append("%s '%s' is not a valid %s (see enums sheet)" % [location, value, type_name])
		return value
	errors.append("%s unknown column type '%s'" % [location, type_name])
	return value


## true when the Enums sheet declares this enum column.
func _has_enum(enums: Dictionary, enum_name: String) -> bool:
	return enums.has(enum_name)


## true when value is listed for enum_name in the Enums sheet.
func _enum_contains(enums: Dictionary, enum_name: String, value: String) -> bool:
	if not enums.has(enum_name):
		return false
	var values_raw: Variant = enums[enum_name]
	if values_raw is Array:
		var values: Array = values_raw
		return values.has(value)
	return false


## Builds an ordered JSON record for one row. Arrays are copied so the shared
## default literals are never mutated.
func _ordered_record(row: Dictionary, defaults: Dictionary) -> Dictionary:
	var record: Dictionary = {}
	for field_name: String in defaults:
		var fallback: Variant = defaults[field_name]
		var value: Variant = row.get(field_name, fallback)
		if value is Array:
			var source_array: Array = value
			record[field_name] = source_array.duplicate()
		else:
			record[field_name] = value
	return record


## One-based workbook row number stored on parsed rows.
func _row_number(row: Dictionary) -> int:
	return _to_int(row.get("_row", 0), 0)
## Skills sheet -> { skill_id: ordered record with an empty "effects" array }.
func _read_skills(grid: Array, enums: Dictionary) -> Dictionary:
	var skills: Dictionary = {}
	for row: Dictionary in _parse_table(grid, enums, "skills"):
		var skill_id: String = str(row.get("skill_id", "")).strip_edges()
		if skill_id.is_empty():
			errors.append("[skills r%d] missing skill_id" % _row_number(row))
			continue
		var record: Dictionary = _ordered_record(row, SKILL_DEFAULTS)
		record["effects"] = []
		skills[skill_id] = record
	return skills


## Effects sheet -> { skill_id: Array[effect record] }.
## The skill_id foreign key is validated and then dropped from the record: the
## effect lives inside its parent skill in skills.json.
func _read_effects(grid: Array, enums: Dictionary, skills: Dictionary) -> Dictionary:
	var grouped: Dictionary = {}
	for row: Dictionary in _parse_table(grid, enums, "effects"):
		var skill_id: String = str(row.get("skill_id", "")).strip_edges()
		var effect_id: int = _to_int(row.get("effect_id", 0), 0)
		var context: String = "[effects r%d effect_id %d]" % [_row_number(row), effect_id]
		if skill_id.is_empty():
			errors.append(context + " missing skill_id")
			continue
		if not skills.has(skill_id):
			errors.append(context + " references unknown skill '%s'" % skill_id)
			continue
		var trigger: String = str(row.get("trigger", "")).strip_edges().to_lower()
		if trigger.is_empty():
			trigger = "base"
		if not VALID_TRIGGERS.has(trigger):
			errors.append(context + " trigger must be 'base' or 'merged', got '%s'" % trigger)
		elif _has_enum(enums, "trigger") and not _enum_contains(enums, "trigger", trigger):
			errors.append(context + " '%s' is not a valid trigger (see enums sheet)" % trigger)
		var record: Dictionary = _ordered_record(row, EFFECT_DEFAULTS)
		record["effect_id"] = effect_id
		record["trigger"] = trigger
		record["order"] = _to_int(row.get("order", 0), 0)
		var divisor: int = _to_int(row.get("value_divisor", 1), 1)
		if divisor < 1:
			warnings.append(context + " value_divisor clamped to 1")
			divisor = 1
		record["value_divisor"] = divisor
		record["_row"] = _row_number(row)
		if not grouped.has(skill_id):
			grouped[skill_id] = []
		var bucket: Array = grouped[skill_id]
		bucket.append(record)
	return grouped


## Embeds each skill's effects into skills.json: base effects first, then
## merged effects, each group ordered by 'order' (ties: workbook row order).
func _attach_effects(skills: Dictionary, effects_by_skill: Dictionary) -> void:
	for skill_id: String in skills:
		var skill: Dictionary = skills[skill_id]
		var effects: Array = []
		if effects_by_skill.has(skill_id):
			var bucket_raw: Variant = effects_by_skill[skill_id]
			if bucket_raw is Array:
				effects = bucket_raw
		effects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var trigger_a: int = 0 if str(a.get("trigger", "base")) == "base" else 1
			var trigger_b: int = 0 if str(b.get("trigger", "base")) == "base" else 1
			if trigger_a != trigger_b:
				return trigger_a < trigger_b
			var order_a: int = _to_int(a.get("order", 0), 0)
			var order_b: int = _to_int(b.get("order", 0), 0)
			if order_a != order_b:
				return order_a < order_b
			return _to_int(a.get("_row", 0), 0) < _to_int(b.get("_row", 0), 0)
		)
		for index: int in effects.size():
			var effect: Dictionary = effects[index]
			effect.erase("_row")
		skill["effects"] = effects


## Units sheet -> { unit_id: ordered record }. Skill slots stay as string ids so
## allies.json / enemies.json can be balanced without duplicating skill data.
func _read_units(grid: Array, enums: Dictionary, skills: Dictionary) -> Dictionary:
	var units: Dictionary = {}
	for row: Dictionary in _parse_table(grid, enums, "units"):
		var unit_id: String = str(row.get("unit_id", "")).strip_edges()
		if unit_id.is_empty():
			errors.append("[units r%d] missing unit_id" % _row_number(row))
			continue
		var record: Dictionary = _ordered_record(row, UNIT_DEFAULTS)
		var display_name: String = str(record.get("display_name", "")).strip_edges()
		record["display_name"] = unit_id if display_name.is_empty() else display_name
		record["max_hp"] = maxi(1, _to_int(record.get("max_hp", 10), 10))
		var max_moxie: int = _to_int(record.get("max_moxie", DEFAULT_MAX_MOXIE), DEFAULT_MAX_MOXIE)
		record["max_moxie"] = max_moxie if max_moxie > 0 else DEFAULT_MAX_MOXIE
		record["is_enemy"] = _to_bool(record.get("is_enemy", false), false)
		for slot: String in UNIT_SKILL_SLOTS:
			var skill_id: String = str(record.get(slot, "")).strip_edges()
			if skill_id.is_empty():
				record[slot] = ""
				continue
			if not skills.has(skill_id):
				errors.append("[units r%d] %s references unknown skill '%s'" % [_row_number(row), slot, skill_id])
			record[slot] = skill_id
		units[unit_id] = record
	return units
## Waves sheet -> { "waves": [ {wave_index, enemies: [...] } ] }.
## Overrides are only emitted when set, keeping normal waves compact.
func _read_waves(grid: Array, enums: Dictionary, units: Dictionary) -> Dictionary:
	var by_index: Dictionary = {}
	for row: Dictionary in _parse_table(grid, enums, "waves", false):
		var wave_index: int = _to_int(row.get("wave_index", 0), 0)
		var unit_id: String = str(row.get("unit_id", "")).strip_edges()
		if not units.has(unit_id):
			errors.append("[waves r%d] unknown unit '%s'" % [_row_number(row), unit_id])
			continue
		var enemy: Dictionary = {"unit_id": unit_id}
		var hp_override: int = _to_int(row.get("max_hp_override", 0), 0)
		if hp_override > 0:
			enemy["max_hp_override"] = hp_override
		var name_override: String = str(row.get("display_name_override", "")).strip_edges()
		if not name_override.is_empty():
			enemy["display_name_override"] = name_override
		if not by_index.has(wave_index):
			by_index[wave_index] = []
		var bucket: Array = by_index[wave_index]
		bucket.append(enemy)
	if by_index.is_empty():
		warnings.append("[waves] no wave rows found")
		return {"waves": []}
	var indices: Array = by_index.keys()
	indices.sort()
	var waves: Array = []
	for wave_index: int in indices:
		var bucket_raw: Variant = by_index[wave_index]
		var wave_record: Dictionary = {"wave_index": wave_index}
		if bucket_raw is Array:
			var bucket: Array = bucket_raw
			wave_record["enemies"] = bucket
		else:
			wave_record["enemies"] = []
		if wave_index != waves.size():
			warnings.append("[waves] wave_index %d is out of sequence (expected %d)" % [wave_index, waves.size()])
		waves.append(wave_record)
	return {"waves": waves}


## Config sheet -> flat JSON object built from its key/value rows.
func _read_config(grid: Array, units: Dictionary) -> Dictionary:
	var config: Dictionary = {}
	var header_index: int = _find_config_header(grid)
	if header_index < 0:
		errors.append("[config] header row with 'key' not found")
		return config
	for row_index: int in range(header_index + 2, grid.size()):  # skip header + title row
		var row: Array = _row_at(grid, row_index)
		if row.size() < 3:
			continue
		var key: String = str(row[1]).strip_edges()
		if key.is_empty():
			continue
		config[key] = _parse_config_value(str(row[2]).strip_edges())
	if not config.has("allies"):
		return config
	config["allies"] = _normalise_config_allies(config["allies"], units)
	return config


## The Config sheet's header is the first row whose second cell says `key`.
func _find_config_header(grid: Array) -> int:
	for row_index: int in range(grid.size()):
		var row: Array = _row_at(grid, row_index)
		if row.size() >= 2 and str(row[1]).strip_edges().to_lower() == "key":
			return row_index
	return -1


## Normalises allies so the runtime always receives an Array of known ids, whether the
## cell held a list or a single id. An unknown id is an error rather than a silent drop:
## a typo here would otherwise only show up as a shorter roster in game.
func _normalise_config_allies(raw: Variant, units: Dictionary) -> Array:
	var allies: Array = []
	if raw is Array:
		var listed: Array = raw
		for item: Variant in listed:
			var listed_id: String = str(item).strip_edges()
			if listed_id.is_empty():
				continue
			if not units.has(listed_id):
				errors.append("[config] allies references unknown unit '%s'" % listed_id)
				continue
			allies.append(listed_id)
	else:
		var single_id: String = str(raw).strip_edges()
		if not single_id.is_empty():
			if units.has(single_id):
				allies.append(single_id)
			else:
				errors.append("[config] allies references unknown unit '%s'" % single_id)
	if allies.is_empty():
		errors.append("[config] allies list is empty")
	return allies
## Splits a Config cell into JSON values: ";" = list, ":" = [value, count]
## pair, "," = list, anything else = scalar.
func _parse_config_value(text: String) -> Variant:
	var trimmed: String = text.strip_edges()
	if trimmed.find(";") >= 0:
		var list: Array = []
		for part: String in trimmed.split(";"):
			list.append(_parse_config_value(part))
		return list
	if trimmed.find(":") >= 0:
		var pair: Array = []
		for part: String in trimmed.split(":"):
			pair.append(_scalar(part))
		return pair
	if trimmed.find(",") >= 0:
		var list: Array = []
		for part: String in trimmed.split(","):
			list.append(_scalar(part))
		return list
	return _scalar(trimmed)


## Coerces a single Config cell fragment into int, float, bool or String.
func _scalar(text: String) -> Variant:
	var trimmed: String = text.strip_edges()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	if trimmed.is_valid_float():
		return trimmed.to_float()
	var lowered: String = trimmed.to_lower()
	if lowered == "true":
		return true
	if lowered == "false":
		return false
	return trimmed


## Pretty-prints a bundle value: objects stay multi-line while arrays of
## scalars (categories, decklist, dice progression, ...) are kept on one line
## so the JSON stays easy to balance by hand or with an AI editor.
func _format_json_value(value: Variant, indent_level: int) -> String:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return _format_json_object(dictionary, indent_level)
	if value is Array:
		var array_value: Array = value
		return _format_json_array(array_value, indent_level)
	return JSON.stringify(value, "", false)


func _format_json_object(source: Dictionary, indent_level: int) -> String:
	if source.is_empty():
		return "{}"
	var entry_pad: String = JSON_INDENT.repeat(indent_level + 1)
	var closing_pad: String = JSON_INDENT.repeat(indent_level)
	var entries: PackedStringArray = PackedStringArray()
	for key: String in source:
		var value_text: String = _format_json_value(source[key], indent_level + 1)
		entries.append("%s%s: %s" % [entry_pad, JSON.stringify(key, "", false), value_text])
	return "{\n" + ",\n".join(entries) + "\n" + closing_pad + "}"


func _format_json_array(source: Array, indent_level: int) -> String:
	if source.is_empty():
		return "[]"
	if _is_inline_array(source):
		var inline_items: PackedStringArray = PackedStringArray()
		for item: Variant in source:
			inline_items.append(_format_json_value(item, indent_level + 1))
		return "[" + ", ".join(inline_items) + "]"
	var item_pad: String = JSON_INDENT.repeat(indent_level + 1)
	var closing_pad: String = JSON_INDENT.repeat(indent_level)
	var lines: PackedStringArray = PackedStringArray()
	for item: Variant in source:
		lines.append(item_pad + _format_json_value(item, indent_level + 1))
	return "[\n" + ",\n".join(lines) + "\n" + closing_pad + "]"


## true when the array holds no objects (directly or one level deep).
func _is_inline_array(source: Array) -> bool:
	for item: Variant in source:
		if item is Dictionary:
			return false
		if item is Array:
			var nested: Array = item
			for nested_item: Variant in nested:
				if nested_item is Dictionary or nested_item is Array:
					return false
	return true
#endregion