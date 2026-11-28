class_name GameDataValidatorRunner
extends Node
## Headless, offline validator for the whole game-data pipeline.
##
## res://Data/json/ is the single source of truth the game reads at runtime,
## while res://Data/xlsx/game_data.xlsx is only a bulk-entry authoring tool.
## This scene checks BOTH layers, lists every problem it finds and exits with a
## non-zero code so CI can block a bad push:
##
##   1. Raw JSON schema + semantics (types, enum strings, cross references,
##      numeric ranges, effect/status/wave/config edge cases).
##   2. Core/DataLoader.gd integration (the exact path the running game uses).
##   3. Optional workbook smoke test through Tools/dataBuilder.gd.
##
## Usage:
##   godot --headless --path . "res://Tools/validator.tscn"
##   godot --headless --path . "res://Tools/validator.tscn" -- --json-only
##   godot --headless --path . "res://Tools/validator.tscn" -- --strict
##
## Exit code 0 = valid, 1 = invalid.
##
## @author TheGreatJellyfish
## @version 11/17/2026

#region Constants
const JSON_DIR: String = "res://Data/json"
const SKILLS_PATH: String = JSON_DIR + "/skills.json"
const ALLIES_PATH: String = JSON_DIR + "/allies.json"
const ENEMIES_PATH: String = JSON_DIR + "/enemies.json"
const WAVES_PATH: String = JSON_DIR + "/waves.json"
const CONFIG_PATH: String = JSON_DIR + "/config.json"

const WORKBOOK_PATH: String = "res://Data/xlsx/game_data.xlsx"
const DATA_BUILDER_PATH: String = "res://Tools/dataBuilder.gd"

## Diagnostic needle -> the res:// path it belongs to, in the order a message is matched,
## so Tools/ValidationReporter.gd can attribute a message to a repo file (and locate its
## line) without knowing this layout. A dict keeps the order: skills first.
const DIAGNOSTIC_PATHS: Dictionary = {
	"skills.json": SKILLS_PATH,
	"allies.json": ALLIES_PATH,
	"enemies.json": ENEMIES_PATH,
	"waves.json": WAVES_PATH,
	"config.json": CONFIG_PATH,
	"workbook": WORKBOOK_PATH,
}

const ARG_JSON_ONLY: String = "--json-only"
const ARG_STRICT: String = "--strict"
const ARG_SUMMARY: String = "--summary"
const ARG_HELP: String = "--help"

## GitHub Actions environment variables used for CI reporting.
const ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"
const ENV_STEP_SUMMARY: String = "GITHUB_STEP_SUMMARY"

#endregion

#region Private Variables
var _errors: PackedStringArray = PackedStringArray()
var _warnings: PackedStringArray = PackedStringArray()
var _skip_workbook: bool = false
var _strict: bool = false
## The rule engine (Tools/GameDataValidator.gd). It owns the rule diagnostics; this Node
## owns the file reads, the workbook smoke test, the DataLoader integration check, the
## CLI and the reporting, and records its own failures into the same run.
var _rules: GameDataValidator = GameDataValidator.new()

## Raw JSON text per res:// path, so diagnostics can be located in the source.
var _raw_text: Dictionary = {}

var _summary_path: String = ""
var _help_requested: bool = false
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_parse_arguments()
	if _help_requested:
		_print_usage()
		get_tree().quit(0)
		return
	_rules.collect_allowlists()
	print("=== Game data validation ===")
	if _skip_workbook:
		print("--- workbook: skipped (--json-only) ---")
	else:
		_validate_workbook()
	_validate_runtime_json()
	_check_loader_integration()
	_report()

## Flags arrive after "--", i.e. OS.get_cmdline_user_args(). The summary path
## also falls back to GITHUB_STEP_SUMMARY, so CI needs no extra arguments.
func _parse_arguments() -> void:
	_summary_path = OS.get_environment(ENV_STEP_SUMMARY)
	var arguments: PackedStringArray = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	var index: int = 0
	while index < arguments.size():
		var flag: String = arguments[index].strip_edges().to_lower()
		if flag == ARG_JSON_ONLY:
			_skip_workbook = true
		elif flag == ARG_STRICT:
			_strict = true
		elif flag == ARG_HELP:
			_help_requested = true
		elif flag == ARG_SUMMARY and index + 1 < arguments.size():
			_summary_path = arguments[index + 1]
			index += 1
		index += 1
#endregion

#region Private Methods
## Prints the report and quits with the matching exit code.
func _report() -> void:
	print("")
	# The rule engine keeps its own diagnostics, so the two lists are merged here: this
	# node's own failures (a missing file, the workbook, the loader) first, then the rules'.
	var errors: PackedStringArray = _all_errors()
	var warnings: PackedStringArray = _all_warnings()
	var exit_code: int = 0
	if not errors.is_empty():
		print("VALIDATION FAILED (%d error(s), %d warning(s)):" % [errors.size(), warnings.size()])
		for message: String in errors:
			print("  ERROR   %s" % message)
		for message: String in warnings:
			print("  WARNING %s" % message)
		exit_code = 1
	elif _strict and not warnings.is_empty():
		print("VALIDATION FAILED --strict (%d warning(s)):" % warnings.size())
		for message: String in warnings:
			print("  WARNING %s" % message)
		exit_code = 1
	elif warnings.is_empty():
		print("VALIDATION PASSED")
	else:
		print("VALIDATION PASSED with %d warning(s):" % warnings.size())
		for message: String in warnings:
			print("  WARNING %s" % message)
	ValidationReporter.emit_annotations(errors, warnings, _raw_text, DIAGNOSTIC_PATHS)
	_write_step_summary(exit_code)
	get_tree().quit(exit_code)

func _fail(message: String) -> void:
	_errors.append(message)

## Warnings are de-duplicated so a repeated typo does not flood the log.
func _warn(message: String) -> void:
	if not _warnings.has(message):
		_warnings.append(message)

## Every problem found: this node's own first (a missing file, the workbook, the loader),
## then the rule engine's, which is the order the run happened in.
func _all_errors() -> PackedStringArray:
	var merged: PackedStringArray = _errors.duplicate()
	merged.append_array(_rules.errors)
	return merged

## Every warning found, merged the same way.
func _all_warnings() -> PackedStringArray:
	var merged: PackedStringArray = _warnings.duplicate()
	merged.append_array(_rules.warnings)
	return merged

## Smoke test for the bulk-entry workbook (authoring tool, never read at runtime).
## Only its own internal consistency is checked (the JSON is authoritative), so a
## stale workbook that still parses cleanly will not fail the build.
func _validate_workbook() -> void:
	print("--- workbook: %s ---" % WORKBOOK_PATH)
	if not FileAccess.file_exists(WORKBOOK_PATH):
		_fail("workbook not found: %s" % WORKBOOK_PATH)
		return
	var builder_script: GDScript = load(DATA_BUILDER_PATH)
	if builder_script == null:
		_fail("cannot load %s" % DATA_BUILDER_PATH)
		return
	var builder: DataBuilder = builder_script.new()
	var sheets: Dictionary = XlsxReader.read_sheets(WORKBOOK_PATH)
	if sheets.is_empty():
		_fail("could not read any sheet from %s" % WORKBOOK_PATH)
		return
	var missing_sheets: PackedStringArray = PackedStringArray()
	for sheet_name: String in DataBuilder.REQUIRED_SHEETS:
		if not sheets.has(sheet_name):
			missing_sheets.append(sheet_name)
	if not missing_sheets.is_empty():
		_fail("workbook is missing required sheet(s): %s" % ", ".join(missing_sheets))
	var bundle: Dictionary = builder.build_json_bundle(sheets)
	for warning_text: String in builder.warnings:
		_warn("[workbook] %s" % warning_text)
	if not builder.errors.is_empty():
		for error_text: String in builder.errors:
			_fail("[workbook] %s" % error_text)
		return
	print("workbook OK: %d skills, %d allies, %d enemies" % [
		_bundle_count(bundle, "skills"),
		_bundle_count(bundle, "allies"),
		_bundle_count(bundle, "enemies"),
	])

func _bundle_count(bundle: Dictionary, key: String) -> int:
	var entries: Dictionary = GameDataValidator.as_dict(bundle.get(key, {}))
	return entries.size()

## Validates the raw JSON files the runtime loader consumes.
func _validate_runtime_json() -> void:
	print("--- runtime json: %s ---" % JSON_DIR)
	# Deliberately no reset here: the workbook check above may already have recorded
	# failures, and the reads below append their own before the rules run.
	var bundle: Dictionary = {
		"skills": _read_json_object(SKILLS_PATH, "skills.json"),
		"allies": _read_json_object(ALLIES_PATH, "allies.json"),
		"enemies": _read_json_object(ENEMIES_PATH, "enemies.json"),
		"waves": _read_json_object(WAVES_PATH, "waves.json"),
		"config": _read_json_object(CONFIG_PATH, "config.json"),
	}
	_validate_bundle(bundle)

## Hands an already-parsed bundle to the rule engine. The engine starts from a clean slate
## of its own, so the workbook failures recorded above survive in this node's list and are
## merged back in by `_all_errors()`.
func _validate_bundle(bundle: Dictionary) -> void:
	_rules.validate(bundle)

## Reads a JSON file whose root must be an object.
func _read_json_object(path: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("%s is missing (%s)" % [label, path])
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("%s cannot be opened (error %d)" % [label, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()
	_raw_text[path] = text
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		_fail("%s is not valid JSON" % label)
		return {}
	if not (parsed is Dictionary):
		_fail("%s root must be a JSON object (found %s)" % [label, GameDataValidator.type_name(parsed)])
		return {}
	var data: Dictionary = parsed
	if data.is_empty():
		_fail("%s is empty" % label)
	return data

## Runs the exact loader path the running game uses, so a data file that passes
## the schema checks but still breaks DataLoader is caught too.
func _check_loader_integration() -> void:
	print("--- DataLoader integration ---")
	var database: GameDatabase = DataLoader.load_database()
	for error_text: String in DataLoader.get_errors():
		_fail("[loader] %s" % error_text)
	if database == null:
		_fail("[loader] DataLoader.load_database() returned no database")
		return
	print("loader built %d skills, %d allies, %d enemies, %d waves" % [
		database.skills.size(),
		database.allies.size(),
		database.enemies.size(),
		database.waves.size(),
	])
	if database.units.is_empty():
		_fail("[loader] units registry is empty")
	if database.config.is_empty():
		_fail("[loader] config registry is empty")
	var config_allies: Array = GameDataValidator.as_array(database.config.get("allies", []))
	for ally_raw: Variant in config_allies:
		var ally_id: String = str(ally_raw)
		if not database.units.has(ally_id):
			_fail("[loader] config.allies references unknown unit '%s'" % ally_id)
	_validate_loader_consistency(database)

## Prints the accepted command line flags.
func _print_usage() -> void:
	print("Game data validator")
	print("")
	print("Usage: godot --headless --path . \"res://Tools/validator.tscn\" [-- <flags>]")
	print("")
	print("Flags:")
	print("  %-12s validate the JSON + DataLoader only, skip the workbook" % ARG_JSON_ONLY)
	print("  %-12s treat warnings as errors (exit code 1)" % ARG_STRICT)
	print("  %-12s write a Markdown job summary to <path>" % ARG_SUMMARY)
	print("  %-12s show this help and exit 0" % ARG_HELP)
	print("")
	print("In GitHub Actions (GITHUB_ACTIONS=true) every error and warning is also")
	print("emitted as a workflow annotation, so it shows up inline on the PR diff.")

## Appends the report Tools/ValidationReporter.gd rendered to the GitHub Actions job
## summary, when a summary path is configured (--summary or GITHUB_STEP_SUMMARY). This
## wrapper is the only part of the reporting that touches the disk; the formatting and
## the line locator are pure.
func _write_step_summary(exit_code: int) -> void:
	if _summary_path.is_empty():
		return
	var counts: Dictionary = {
		"skills": _rules.skills.size(),
		"allies": _rules.allies.size(),
		"enemies": _rules.enemies.size(),
		"waves": GameDataValidator.as_array(_rules.waves.get("waves", [])).size(),
	}
	var file: FileAccess = FileAccess.open(_summary_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(ValidationReporter.step_summary(exit_code, _all_errors(), _all_warnings(), counts))
	file.close()

## Proves the loaded database matches the raw JSON one-to-one (nothing was
## silently dropped) and that loading is deterministic across reloads.
func _validate_loader_consistency(database: GameDatabase) -> void:
	if database == null:
		return
	if database.skills.size() != _rules.skills.size():
		_fail("[loader] skills.json declares %d skill(s) but %d were loaded" % [_rules.skills.size(), database.skills.size()])
	for skill_key: Variant in _rules.skills.keys():
		var skill_id: String = str(skill_key)
		if not database.skills.has(skill_id):
			continue
		var raw_entry: Dictionary = GameDataValidator.as_dict(_rules.skills[skill_key])
		var raw_effects: int = GameDataValidator.as_array(raw_entry.get("effects", [])).size()
		var skill_raw: Variant = database.skills[skill_id]
		if not (skill_raw is SkillData):
			continue
		var skill: SkillData = skill_raw
		var loaded_effects: int = skill.base_effects.size() + skill.merged_effects.size()
		if raw_effects != loaded_effects:
			_fail("[loader] skills.json '%s' declares %d effect(s) but %d were loaded (an effect was dropped)" % [skill_id, raw_effects, loaded_effects])
	_validate_loaded_units(_rules.allies, "allies.json", database.allies)
	_validate_loaded_units(_rules.enemies, "enemies.json", database.enemies)
	var raw_waves: int = GameDataValidator.as_array(_rules.waves.get("waves", [])).size()
	if database.waves.size() != raw_waves:
		_fail("[loader] waves.json declares %d wave(s) but %d were loaded" % [raw_waves, database.waves.size()])
	var raw_decklist: int = GameDataValidator.as_array(_rules.config.get("decklist", [])).size()
	var loaded_decklist: int = GameDataValidator.as_array(database.config.get("decklist", [])).size()
	if raw_decklist != loaded_decklist:
		_fail("[loader] config.json declares %d decklist entry(ies) but %d were loaded" % [raw_decklist, loaded_decklist])
	if _database_fingerprint(DataLoader.load_database()) != _database_fingerprint(database):
		_fail("[loader] loading the same files twice produced different databases (non-deterministic parse)")

func _validate_loaded_units(units_json: Dictionary, label: String, loaded: Dictionary) -> void:
	if loaded.size() != units_json.size():
		_fail("[loader] %s declares %d unit(s) but %d were loaded" % [label, units_json.size(), loaded.size()])
	for unit_key: Variant in units_json.keys():
		var unit_id: String = str(unit_key)
		if not loaded.has(unit_id):
			continue
		var entry: Dictionary = GameDataValidator.as_dict(units_json[unit_key])
		var unit_raw: Variant = loaded[unit_id]
		if not (unit_raw is UnitData):
			continue
		var unit: UnitData = unit_raw
		var context: String = "%s '%s'" % [label, unit_id]
		for slot: String in GameDataValidator.UNIT_SKILL_SLOTS:
			# A non-string slot is already an error from the rule pass, so this pass only
			# needs to know whether there is anything to resolve.
			var slot_raw: Variant = entry.get(slot, "")
			var slot_text: String = slot_raw if slot_raw is String else ""
			if slot_text.strip_edges().is_empty():
				continue
			var resolved: bool = true
			match slot:
				"skill_1":
					resolved = unit.skill_1 != null
				"skill_2":
					resolved = unit.skill_2 != null
				_:
					resolved = unit.ultimate != null
			if not resolved:
				_fail("[loader] %s %s did not resolve to a loaded skill" % [context, slot])

## Stable text digest of everything the runtime cares about in a database.
func _database_fingerprint(database: GameDatabase) -> String:
	if database == null:
		return "null"
	var parts: PackedStringArray = PackedStringArray()
	parts.append("skills=%d" % database.skills.size())
	for skill_key: Variant in database.skills.keys():
		var skill_raw: Variant = database.skills[skill_key]
		if skill_raw is SkillData:
			var skill: SkillData = skill_raw
			parts.append("s:%s:%d:%d" % [str(skill_key), skill.base_effects.size(), skill.merged_effects.size()])
	parts.append("units=%d" % database.units.size())
	parts.append("waves=%d" % database.waves.size())
	for wave_raw: Variant in database.waves:
		parts.append("w:%d" % GameDataValidator.as_array(wave_raw).size())
	parts.append("decklist=%d" % GameDataValidator.as_array(database.config.get("decklist", [])).size())
	parts.append("allies=%d" % GameDataValidator.as_array(database.config.get("allies", [])).size())
	parts.append("dice=%d" % GameDataValidator.as_array(database.config.get("dice_progression", [])).size())
	return "|".join(parts)
#endregion
