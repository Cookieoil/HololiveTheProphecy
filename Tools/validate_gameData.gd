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

const ARG_JSON_ONLY: String = "--json-only"
const ARG_STRICT: String = "--strict"
const ARG_SUMMARY: String = "--summary"
const ARG_HELP: String = "--help"

## GitHub Actions environment variables used for CI reporting.
const ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"
const ENV_STEP_SUMMARY: String = "GITHUB_STEP_SUMMARY"

## Keys a typo would silently change: Core/DataLoader.gd falls back to a default
## for any missing key, so these four must always be present on an effect.
const REQUIRED_EFFECT_KEYS: PackedStringArray = ["trigger", "action", "target_mode", "value_source"]

const UNIT_SKILL_SLOTS: PackedStringArray = ["skill_1", "skill_2", "ultimate"]
const WAVE_KEYS: PackedStringArray = ["wave_index", "enemies"]
const WAVE_ENEMY_KEYS: PackedStringArray = ["unit_id", "max_hp_override", "display_name_override"]

## Actions that must resolve at least one unit target.
const TARGETED_ACTIONS: PackedStringArray = [
	"deal_damage", "deal_true_damage", "gain_shield", "reduce_shield", "heal",
	"apply_modifier", "raise_max_hp", "apply_status",
]
## Actions that resolve a numeric amount (so a fixed_amount of 0 does nothing).
const VALUE_ACTIONS: PackedStringArray = [
	"deal_damage", "deal_true_damage", "gain_shield", "reduce_shield", "heal",
	"apply_modifier", "raise_max_hp", "add_bonus", "set_next_skill_bonus",
]
## Actions that consume card_count / card_select_mode / card_mod_type.
const CARD_ACTIONS: PackedStringArray = ["draw_card", "discard_card", "modify_card"]
## Target modes that select N units and therefore need target_count >= 1.
const N_TARGET_MODES: PackedStringArray = ["pick_n_enemy", "pick_n_ally", "cached_or_pick_enemy"]
## Target modes that fill SkillContext.targets for later "cached" effects.
const TARGET_CACHING_MODES: PackedStringArray = [
	"pick_n_enemy", "pick_n_ally", "all_enemies", "all_allies", "caster",
	"cached_or_pick_enemy",
]
## Card categories the UI has art for (see CardIconCatalog).
const CARD_CATEGORIES: PackedStringArray = ["damage", "draw", "buff", "debuff", "shield", "heal"]

## Obvious-typo guards.
const SANITY_MAX_TARGET_COUNT: int = 10
const SANITY_MAX_CARD_VALUE: int = 99
const SANITY_MAX_DICE_SIDES: int = 100
const SANITY_MIN_HP: int = 1
#endregion

#region Private Variables
var _errors: PackedStringArray = PackedStringArray()
var _warnings: PackedStringArray = PackedStringArray()
var _skip_workbook: bool = false
var _strict: bool = false

## Enum allowlists, sourced from the runtime so the two can never drift apart.
var _actions: PackedStringArray = PackedStringArray()
var _target_modes: PackedStringArray = PackedStringArray()
var _value_sources: PackedStringArray = PackedStringArray()
var _conditions: PackedStringArray = PackedStringArray()
var _card_select_modes: PackedStringArray = PackedStringArray()
var _card_mod_types: PackedStringArray = PackedStringArray()
var _merged_modes: PackedStringArray = PackedStringArray()
var _status_ids: PackedStringArray = PackedStringArray()
var _wave_modes: PackedStringArray = PackedStringArray()

## Canonical key sets, sourced from the workbook exporter so unknowns are typos.
var _effect_keys: PackedStringArray = PackedStringArray()
var _skill_keys: PackedStringArray = PackedStringArray()
var _unit_keys: PackedStringArray = PackedStringArray()

## Cross-file registries filled while validating.
var _skill_ids: Dictionary = {}
var _ally_ids: Dictionary = {}
var _enemy_ids: Dictionary = {}
var _used_skill_ids: Dictionary = {}
var _enemy_skill_ids: Dictionary = {}
var _ally_skill_ids: Dictionary = {}
var _skill_meta: Dictionary = {}

var _id_pattern: RegEx = null

## Raw JSON text per res:// path, so diagnostics can be located in the source.
var _raw_text: Dictionary = {}
## Raw parsed JSON, kept so the loaded database can be cross-checked against it.
var _skills_json: Dictionary = {}
var _allies_json: Dictionary = {}
var _enemies_json: Dictionary = {}
var _waves_json: Dictionary = {}
var _config_json: Dictionary = {}

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
	_collect_allowlists()
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
	var exit_code: int = 0
	if not _errors.is_empty():
		print("VALIDATION FAILED (%d error(s), %d warning(s)):" % [_errors.size(), _warnings.size()])
		for message: String in _errors:
			print("  ERROR   %s" % message)
		for message: String in _warnings:
			print("  WARNING %s" % message)
		exit_code = 1
	elif _strict and not _warnings.is_empty():
		print("VALIDATION FAILED --strict (%d warning(s)):" % _warnings.size())
		for message: String in _warnings:
			print("  WARNING %s" % message)
		exit_code = 1
	elif _warnings.is_empty():
		print("VALIDATION PASSED")
	else:
		print("VALIDATION PASSED with %d warning(s):" % _warnings.size())
		for message: String in _warnings:
			print("  WARNING %s" % message)
	_emit_annotations()
	_write_step_summary(exit_code)
	get_tree().quit(exit_code)


func _fail(message: String) -> void:
	_errors.append(message)


## Warnings are de-duplicated so a repeated typo does not flood the log.
func _warn(message: String) -> void:
	if not _warnings.has(message):
		_warnings.append(message)


func _keys_of(source: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		result.append(str(key))
	return result


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var result: Dictionary = value
		return result
	return {}


func _as_array(value: Variant) -> Array:
	if value is Array:
		var result: Array = value
		return result
	return []


func _dict_int(source: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = source.get(key, fallback)
	if raw is int:
		var int_value: int = raw
		return int_value
	if raw is float:
		var float_value: float = raw
		return int(float_value)
	return fallback


func _dict_bool(source: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = source.get(key, fallback)
	if raw is bool:
		var flag: bool = raw
		return flag
	return fallback


func _type_name(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "boolean"
	if value is int:
		return "integer"
	if value is float:
		return "number"
	if value is String:
		return "string"
	if value is Array:
		return "array"
	if value is Dictionary:
		return "object"
	return "unknown"


func _is_snake_case_id(text: String) -> bool:
	if _id_pattern == null:
		_id_pattern = RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	return _id_pattern.search(text) != null


## Pulls every allowlist straight from the runtime so validation can never drift
## away from what DataLoader, EffectBlock and Unit actually accept.
func _collect_allowlists() -> void:
	_actions = _keys_of(DataLoader.ACTION_MAP)
	_target_modes = _keys_of(DataLoader.TARGET_MODE_MAP)
	_value_sources = _keys_of(DataLoader.VALUE_SOURCE_MAP)
	_conditions = _keys_of(DataLoader.CONDITION_MAP)
	_card_select_modes = _keys_of(DataLoader.CARD_SELECT_MAP)
	_card_mod_types = _keys_of(DataLoader.CARD_MOD_MAP)
	_merged_modes = _keys_of(DataLoader.MERGED_MODE_MAP)
	_status_ids = _keys_of(Unit.STATUS_DEFS)
	_wave_modes = _keys_of(GameManager.WAVE_MODE_MAP)
	_effect_keys = _keys_of(DataBuilder.EFFECT_DEFAULTS)
	_skill_keys = _keys_of(DataBuilder.SKILL_DEFAULTS)
	_unit_keys = _keys_of(DataBuilder.UNIT_DEFAULTS)


func _warn_unknown_keys(source: Dictionary, known: PackedStringArray, context: String, extra: PackedStringArray) -> void:
	for key: Variant in source.keys():
		var key_name: String = str(key)
		if known.has(key_name) or extra.has(key_name):
			continue
		_warn("%s: unknown key '%s' (typo?)" % [context, key_name])


## Coerces a raw JSON scalar into an int, reporting anything else. JSON numbers
## always arrive as float, so whole floats are accepted and truncated halves are
## rejected (they are almost always an authoring mistake).
func _int_value(raw: Variant, context: String, fallback: int) -> int:
	if raw is bool:
		_fail("%s: must be a number, not a boolean" % context)
		return fallback
	if raw is int:
		var int_value: int = raw
		return int_value
	if raw is float:
		var float_value: float = raw
		if absf(float_value - roundf(float_value)) > 0.0001:
			_fail("%s: must be a whole number (found %s)" % [context, str(float_value)])
		return int(roundf(float_value))
	if raw is String:
		var text: String = raw
		if text.is_valid_int():
			_warn("%s: is a string; write it as a JSON number" % context)
			return text.to_int()
		_fail("%s: must be a number (found string \"%s\")" % [context, text])
		return fallback
	_fail("%s: must be a number (found %s)" % [context, _type_name(raw)])
	return fallback


func _int_field(source: Dictionary, key: String, context: String, default_value: int, required: bool) -> int:
	if not source.has(key):
		if required:
			_fail("%s: missing required '%s'" % [context, key])
		else:
			_warn("%s: missing '%s' (defaults to %d)" % [context, key, default_value])
		return default_value
	return _int_value(source[key], "%s.%s" % [context, key], default_value)


func _string_field(source: Dictionary, key: String, context: String, required: bool) -> String:
	if not source.has(key):
		if required:
			_fail("%s: missing required '%s'" % [context, key])
		return ""
	var raw: Variant = source[key]
	if raw is String:
		var text: String = raw
		return text
	_fail("%s: '%s' must be a string (found %s)" % [context, key, _type_name(raw)])
	return ""


func _bool_field(source: Dictionary, key: String, context: String, default_value: bool) -> bool:
	if not source.has(key):
		return default_value
	var raw: Variant = source[key]
	if raw is bool:
		var flag: bool = raw
		return flag
	_fail("%s: '%s' must be true/false (found %s)" % [context, key, _type_name(raw)])
	return default_value


## Enum strings are compared exactly (no case folding / trimming) because
## DataLoader also matches them exactly: a case or space typo must be an error.
func _enum_field(source: Dictionary, key: String, context: String, allowed: PackedStringArray, default_value: String, required: bool) -> String:
	if not source.has(key):
		if required:
			_fail("%s: missing required '%s'" % [context, key])
		return default_value
	var value: String = _string_field(source, key, context, true)
	if value.is_empty():
		_fail("%s: '%s' must not be empty" % [context, key])
		return default_value
	if not allowed.has(value):
		_fail("%s: unknown '%s' value '%s' (expected one of: %s)" % [context, key, value, ", ".join(allowed)])
		return default_value
	return value


func _array_field(source: Dictionary, key: String, context: String, required: bool) -> Array:
	if not source.has(key):
		if required:
			_fail("%s: missing required '%s'" % [context, key])
		return []
	var raw: Variant = source[key]
	if raw is Array:
		var values: Array = raw
		return values
	_fail("%s: '%s' must be an array (found %s)" % [context, key, _type_name(raw)])
	return []


func _require_effect_keys(effect: Dictionary, context: String) -> void:
	for key: String in REQUIRED_EFFECT_KEYS:
		if not effect.has(key):
			_fail("%s: missing required '%s' (DataLoader would silently default it)" % [context, key])


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
		print("  workbook warning: %s" % warning_text)
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
	var entries: Dictionary = _as_dictionary(bundle.get(key, {}))
	return entries.size()


## Validates the raw JSON files the runtime loader consumes.
func _validate_runtime_json() -> void:
	print("--- runtime json: %s ---" % JSON_DIR)
	_skills_json = _read_json_object(SKILLS_PATH, "skills.json")
	_allies_json = _read_json_object(ALLIES_PATH, "allies.json")
	_enemies_json = _read_json_object(ENEMIES_PATH, "enemies.json")
	_waves_json = _read_json_object(WAVES_PATH, "waves.json")
	_config_json = _read_json_object(CONFIG_PATH, "config.json")

	_validate_skills(_skills_json)
	_validate_units(_allies_json, "allies.json", false, _ally_ids)
	_validate_units(_enemies_json, "enemies.json", true, _enemy_ids)
	_validate_unit_collisions()
	_validate_skill_usage()
	_validate_waves(_waves_json)
	_validate_config(_config_json)


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
		_fail("%s root must be a JSON object (found %s)" % [label, _type_name(parsed)])
		return {}
	var data: Dictionary = parsed
	if data.is_empty():
		_fail("%s is empty" % label)
	return data


func _validate_skills(skills: Dictionary) -> void:
	if skills.is_empty():
		return
	print("checking %d skill(s)" % skills.size())
	var effect_id_owners: Dictionary = {}
	for skill_key: Variant in skills.keys():
		var skill_id: String = str(skill_key)
		var context: String = "skills.json '%s'" % skill_id
		_skill_ids[skill_id] = true
		if not _is_snake_case_id(skill_id):
			_warn("%s: id is not lower snake_case" % context)
		var entry_raw: Variant = skills[skill_key]
		if not (entry_raw is Dictionary):
			_fail("%s: must be an object (found %s)" % [context, _type_name(entry_raw)])
			continue
		var entry: Dictionary = entry_raw
		_validate_skill(skill_id, entry, effect_id_owners)


func _validate_skill(skill_id: String, entry: Dictionary, effect_id_owners: Dictionary) -> void:
	var context: String = "skills.json '%s'" % skill_id
	_warn_unknown_keys(entry, _skill_keys, context, PackedStringArray(["effects"]))

	var display_name: String = _string_field(entry, "display_name", context, false)
	if display_name.is_empty():
		_warn("%s: 'display_name' is empty" % context)
	if not entry.has("description"):
		_warn("%s: missing 'description'" % context)

	var merged_mode: String = _enum_field(entry, "merged_mode", context, _merged_modes, "and_merged_first", false)
	var threshold: int = _int_field(entry, "condition_threshold", context, 0, false)
	if threshold < 0:
		_fail("%s: 'condition_threshold' must be >= 0 (found %d)" % [context, threshold])
	_skill_meta[skill_id] = {"threshold": threshold}

	_validate_categories(_array_field(entry, "base_categories", context, false), "%s base_categories" % context)
	var merged_categories: Array = _array_field(entry, "merged_categories", context, false)
	_validate_categories(merged_categories, "%s merged_categories" % context)

	var merged_description: String = _string_field(entry, "merged_description", context, false)
	if not entry.has("merged_description"):
		_warn("%s: missing 'merged_description'" % context)

	var effects: Array = _array_field(entry, "effects", context, true)
	if effects.is_empty():
		if entry.has("effects"):
			_fail("%s: 'effects' must hold at least one effect" % context)
		return
	_validate_effects(skill_id, effects, effect_id_owners)

	var meta: Dictionary = _as_dictionary(_skill_meta.get(skill_id, {}))
	var merged_count: int = _dict_int(meta, "merged", 0)
	var base_count: int = _dict_int(meta, "base", 0)
	if merged_count == 0:
		if merged_mode == "or":
			_warn("%s: merged_mode 'or' but there are no merged effects (merging only swaps categories)" % context)
		if not merged_categories.is_empty():
			_warn("%s: merged_categories are set but there are no merged effects" % context)
	else:
		if merged_description.is_empty():
			_warn("%s: merged effects exist but 'merged_description' is empty" % context)
		if base_count == 0 and merged_mode != "or":
			_warn("%s: merged effects exist but there are no base effects" % context)


func _validate_categories(categories: Array, context: String) -> void:
	var seen: Dictionary = {}
	for index: int in categories.size():
		var item_context: String = "%s[%d]" % [context, index]
		var item_raw: Variant = categories[index]
		if not (item_raw is String):
			_fail("%s: category must be a string (found %s)" % [item_context, _type_name(item_raw)])
			continue
		var category: String = item_raw
		if category.is_empty():
			_fail("%s: category must not be empty" % item_context)
			continue
		if seen.has(category):
			_warn("%s: duplicate category '%s'" % [item_context, category])
		seen[category] = true
		if not CARD_CATEGORIES.has(category):
			_warn("%s: unknown card category '%s' (icons exist for: %s)" % [item_context, category, ", ".join(CARD_CATEGORIES)])


## Validates every effect of one skill, plus the cross-effect rules (cached
## targets, stored values, duplicate orders) that no single effect can check.
func _validate_effects(skill_id: String, effects: Array, effect_id_owners: Dictionary) -> void:
	var context: String = "skills.json '%s'" % skill_id
	var producers: Dictionary = {"targets": false, "stored": false}
	var consumers: PackedStringArray = PackedStringArray()
	var seen_effect_ids: Dictionary = {}
	var orders: Dictionary = {"base": {}, "merged": {}}
	var base_count: int = 0
	var merged_count: int = 0
	for index: int in effects.size():
		var item_raw: Variant = effects[index]
		var effect_context: String = "%s effect[%d]" % [context, index]
		if not (item_raw is Dictionary):
			_fail("%s: must be an object (found %s)" % [effect_context, _type_name(item_raw)])
			continue
		var effect: Dictionary = item_raw
		var trigger: String = _string_field(effect, "trigger", effect_context, false).strip_edges().to_lower()
		if not effect.has("trigger"):
			_fail("%s: missing required 'trigger' (DataLoader would treat it as 'base')" % effect_context)
		elif trigger != "base" and trigger != "merged":
			_fail("%s: 'trigger' must be 'base' or 'merged' (found '%s')" % [effect_context, trigger])
			trigger = ""
		if trigger == "base":
			base_count += 1
		elif trigger == "merged":
			merged_count += 1
		if trigger == "base" or trigger == "merged":
			var order: int = _int_field(effect, "order", effect_context, index, false)
			if order < 0:
				_fail("%s: 'order' must be >= 0 (found %d)" % [effect_context, order])
			var known_orders: Dictionary = _as_dictionary(orders[trigger])
			if known_orders.has(order):
				_warn("%s: duplicate 'order' %d in the %s effects (JSON array order breaks the tie)" % [effect_context, order, trigger])
			else:
				known_orders[order] = true
				orders[trigger] = known_orders
		_validate_effect(effect_context, effect, producers, consumers, effect_id_owners, seen_effect_ids)

	if consumers.has("cached") and not _dict_bool(producers, "targets", false):
		_warn("%s: 'cached' targeting is used but no effect caches targets in this skill" % context)
	if consumers.has("stored_value") and not _dict_bool(producers, "stored", false):
		_warn("%s: 'stored_value' is used but no effect sets 'store_resolved_value' in this skill" % context)

	var meta: Dictionary = _as_dictionary(_skill_meta.get(skill_id, {}))
	meta["base"] = base_count
	meta["merged"] = merged_count
	_skill_meta[skill_id] = meta


func _validate_effect(
	context: String,
	effect: Dictionary,
	producers: Dictionary,
	consumers: PackedStringArray,
	effect_id_owners: Dictionary,
	seen_effect_ids: Dictionary
) -> void:
	_warn_unknown_keys(effect, _effect_keys, context, PackedStringArray())
	_require_effect_keys(effect, context)

	var action: String = _enum_field(effect, "action", context, _actions, "deal_damage", false)
	var target_mode: String = _enum_field(effect, "target_mode", context, _target_modes, "none", false)
	var value_source: String = _enum_field(effect, "value_source", context, _value_sources, "card_value", false)
	var condition: String = _enum_field(effect, "condition", context, _conditions, "none", false)
	_enum_field(effect, "card_select_mode", context, _card_select_modes, "pick_n_card", false)
	_enum_field(effect, "card_mod_type", context, _card_mod_types, "buff", false)
	var negate_condition: bool = _bool_field(effect, "negate_condition", context, false)
	var store_value: bool = _bool_field(effect, "store_resolved_value", context, false)

	var effect_id: int = _int_field(effect, "effect_id", context, -1, false)
	if effect_id >= 0:
		if seen_effect_ids.has(effect_id):
			_fail("%s: duplicate effect_id %d inside this skill" % [context, effect_id])
		else:
			seen_effect_ids[effect_id] = true
		if effect_id_owners.has(effect_id):
			_warn("%s: effect_id %d is also used by %s" % [context, effect_id, str(effect_id_owners[effect_id])])
		else:
			effect_id_owners[effect_id] = context

	var target_count: int = _int_field(effect, "target_count", context, 1, false)
	if target_count < 0:
		_fail("%s: 'target_count' must be >= 0 (found %d)" % [context, target_count])
	if target_count > SANITY_MAX_TARGET_COUNT:
		_warn("%s: 'target_count' %d looks too high" % [context, target_count])
	var value_multiplier: int = _int_field(effect, "value_multiplier", context, 1, false)
	if value_multiplier < 0:
		_fail("%s: 'value_multiplier' must be >= 0 (found %d)" % [context, value_multiplier])
	var value_divisor: int = _int_field(effect, "value_divisor", context, 1, false)
	if value_divisor < 1:
		_fail("%s: 'value_divisor' must be >= 1 (found %d); DataLoader silently clamps it to 1" % [context, value_divisor])
	_int_field(effect, "value_offset", context, 0, false)
	var value_cap: int = _int_field(effect, "value_cap", context, -1, false)
	if value_cap < -1:
		_fail("%s: 'value_cap' must be -1 (off) or >= 0 (found %d)" % [context, value_cap])
	elif value_cap == 0:
		_warn("%s: 'value_cap' is 0, so the resolved value is always 0" % context)
	var fixed_amount: int = _int_field(effect, "fixed_amount", context, 0, false)
	var card_count: int = _int_field(effect, "card_count", context, 1, false)
	if card_count < 0:
		_fail("%s: 'card_count' must be >= 0 (found %d)" % [context, card_count])

	if TARGETED_ACTIONS.has(action):
		if target_mode == "none":
			_fail("%s: action '%s' needs a target but target_mode is 'none'" % [context, action])
		if N_TARGET_MODES.has(target_mode) and target_count < 1:
			_fail("%s: target_mode '%s' needs target_count >= 1 (found %d)" % [context, target_mode, target_count])
		if not N_TARGET_MODES.has(target_mode) and target_count > 0:
			_warn("%s: target_count is %d but target_mode '%s' ignores it" % [context, target_count, target_mode])
	if CARD_ACTIONS.has(action) and card_count < 1:
		_fail("%s: action '%s' needs card_count >= 1 (found %d)" % [context, action, card_count])
	if (action == "draw_card" or action == "discard_card") and target_mode != "none":
		_warn("%s: action '%s' ignores unit targets but target_mode is '%s'" % [context, action, target_mode])

	if action == "apply_status":
		var status_id: String = _string_field(effect, "status_id", context, true).strip_edges().to_lower()
		if status_id.is_empty():
			_fail("%s: action 'apply_status' needs a non-empty 'status_id'" % context)
		elif not _status_ids.has(status_id):
			_fail("%s: unknown status_id '%s' (known: %s)" % [context, status_id, ", ".join(_status_ids)])
	elif effect.has("status_id") and not _string_field(effect, "status_id", context, false).strip_edges().is_empty():
		_warn("%s: 'status_id' is only used by apply_status" % context)

	if condition == "none" and negate_condition:
		_warn("%s: 'negate_condition' is true but 'condition' is 'none'" % context)
	if value_source == "fixed" and VALUE_ACTIONS.has(action):
		if fixed_amount == 0:
			_warn("%s: value_source 'fixed' with fixed_amount 0 resolves to nothing" % context)
		elif fixed_amount < 0:
			_warn("%s: negative fixed_amount %d" % [context, fixed_amount])

	if target_mode == "cached" or value_source == "target_missing_hp":
		consumers.append("cached")
	if TARGET_CACHING_MODES.has(target_mode):
		producers["targets"] = true
	if value_source == "stored_value":
		consumers.append("stored_value")
	if store_value:
		producers["stored"] = true


func _validate_units(units_json: Dictionary, label: String, is_enemy_file: bool, id_bucket: Dictionary) -> void:
	if units_json.is_empty():
		return
	print("checking %d unit(s) in %s" % [units_json.size(), label])
	for unit_key: Variant in units_json.keys():
		var unit_id: String = str(unit_key)
		var context: String = "%s '%s'" % [label, unit_id]
		id_bucket[unit_id] = is_enemy_file
		if unit_id.is_empty():
			_fail("%s: unit id must not be empty" % label)
			continue
		if not _is_snake_case_id(unit_id):
			_warn("%s: unit id is not lower snake_case" % context)
		var entry_raw: Variant = units_json[unit_key]
		if not (entry_raw is Dictionary):
			_fail("%s: must be an object (found %s)" % [context, _type_name(entry_raw)])
			continue
		var entry: Dictionary = entry_raw
		_warn_unknown_keys(entry, _unit_keys, context, PackedStringArray())

		var display_name: String = _string_field(entry, "display_name", context, false)
		if display_name.is_empty():
			_warn("%s: 'display_name' is empty" % context)

		var max_hp: int = _int_field(entry, "max_hp", context, 10, false)
		if max_hp < SANITY_MIN_HP:
			_fail("%s: 'max_hp' must be >= %d (found %d)" % [context, SANITY_MIN_HP, max_hp])
		var max_moxie: int = _int_field(entry, "max_moxie", context, 20, false)
		if max_moxie < 1:
			_fail("%s: 'max_moxie' must be >= 1 (found %d)" % [context, max_moxie])

		if entry.has("is_enemy"):
			var declared_enemy: bool = _bool_field(entry, "is_enemy", context, is_enemy_file)
			if declared_enemy != is_enemy_file:
				_fail("%s: 'is_enemy' is %s but the unit lives in %s (expected %s)" % [
					context, str(declared_enemy), label, str(is_enemy_file),
				])
		else:
			_warn("%s: missing 'is_enemy' (DataLoader infers %s from the file)" % [context, str(is_enemy_file)])

		var skill_count: int = 0
		for slot: String in UNIT_SKILL_SLOTS:
			var slot_context: String = "%s %s" % [context, slot]
			var skill_id: String = _string_field(entry, slot, slot_context, false).strip_edges()
			if skill_id.is_empty():
				if not entry.has(slot):
					_warn("%s: missing '%s'" % [context, slot])
				elif slot != "ultimate":
					_fail("%s: '%s' must not be empty" % [context, slot])
				continue
			if not _skill_ids.has(skill_id):
				_fail("%s: references unknown skill '%s'" % [slot_context, skill_id])
				continue
			skill_count += 1
			_used_skill_ids[skill_id] = true
			if is_enemy_file:
				_enemy_skill_ids[skill_id] = true
			else:
				_ally_skill_ids[skill_id] = true
		if skill_count == 0:
			_fail("%s: defines no usable skill" % context)


func _validate_unit_collisions() -> void:
	for unit_id: String in _ally_ids.keys():
		if _enemy_ids.has(unit_id):
			_fail("unit id '%s' is defined in both allies.json and enemies.json (they collide in GameDatabase.units)" % unit_id)


## Cross-checks the skills against the units that use them.
func _validate_skill_usage() -> void:
	for skill_id: String in _skill_ids.keys():
		if not _used_skill_ids.has(skill_id):
			_warn("skills.json '%s' is not referenced by any unit (dead skill)" % skill_id)
	for skill_id: String in _enemy_skill_ids.keys():
		var meta: Dictionary = _as_dictionary(_skill_meta.get(skill_id, {}))
		if _dict_int(meta, "merged", 0) > 0 and _dict_int(meta, "threshold", 0) <= 0:
			_warn("skills.json '%s' is an enemy skill with merged effects but condition_threshold 0, so EnemyIntent never marks the merge condition (set a threshold > 0)" % skill_id)
	for skill_id: String in _ally_skill_ids.keys():
		var meta: Dictionary = _as_dictionary(_skill_meta.get(skill_id, {}))
		if _dict_int(meta, "threshold", 0) > 0:
			_warn("skills.json '%s' is an ally skill with condition_threshold > 0, but allies merge by card value and ignore the threshold" % skill_id)


func _validate_waves(waves_json: Dictionary) -> void:
	if waves_json.is_empty():
		return
	_warn_unknown_keys(waves_json, PackedStringArray(["waves"]), "waves.json", PackedStringArray())
	var waves: Array = _array_field(waves_json, "waves", "waves.json", true)
	if waves.is_empty():
		if waves_json.has("waves"):
			_fail("waves.json: 'waves' must hold at least one wave")
		return
	print("checking %d wave(s)" % waves.size())
	for index: int in waves.size():
		var context: String = "waves.json wave[%d]" % index
		var wave_raw: Variant = waves[index]
		if not (wave_raw is Dictionary):
			_fail("%s: must be an object (found %s)" % [context, _type_name(wave_raw)])
			continue
		var wave: Dictionary = wave_raw
		_warn_unknown_keys(wave, WAVE_KEYS, context, PackedStringArray())
		if wave.has("wave_index"):
			var wave_index: int = _int_field(wave, "wave_index", context, index, false)
			if wave_index != index:
				_warn("%s: 'wave_index' is %d but it sits at position %d (DataLoader uses array order)" % [context, wave_index, index])
		var enemies: Array = _array_field(wave, "enemies", context, true)
		if enemies.is_empty():
			if wave.has("enemies"):
				_fail("%s: 'enemies' is empty (the wave would be cleared instantly)" % context)
			continue
		for enemy_index: int in enemies.size():
			_validate_wave_enemy(context, enemies[enemy_index], enemy_index)


func _validate_wave_enemy(wave_context: String, item_raw: Variant, index: int) -> void:
	var context: String = "%s enemy[%d]" % [wave_context, index]
	if not (item_raw is Dictionary):
		_fail("%s: must be an object (found %s)" % [context, _type_name(item_raw)])
		return
	var entry: Dictionary = item_raw
	_warn_unknown_keys(entry, WAVE_ENEMY_KEYS, context, PackedStringArray())
	var unit_id: String = _string_field(entry, "unit_id", context, true).strip_edges()
	if unit_id.is_empty():
		_fail("%s: 'unit_id' must not be empty" % context)
		return
	if not _enemy_ids.has(unit_id):
		if _ally_ids.has(unit_id):
			_fail("%s: '%s' is an ally; waves may only spawn enemies" % [context, unit_id])
		else:
			_fail("%s: references unknown unit '%s'" % [context, unit_id])
		return
	if entry.has("max_hp_override"):
		var hp_override: int = _int_field(entry, "max_hp_override", context, 0, false)
		if hp_override < 1:
			_fail("%s: 'max_hp_override' must be >= 1 (found %d)" % [context, hp_override])
	if entry.has("display_name_override"):
		var name_override: String = _string_field(entry, "display_name_override", context, false).strip_edges()
		if name_override.is_empty():
			_fail("%s: 'display_name_override' must not be empty" % context)


func _validate_config(config_json: Dictionary) -> void:
	if config_json.is_empty():
		return
	print("checking config.json")
	var hand_size: int = _int_field(config_json, "hand_size", "config.json", GameState.MAX_HAND_SIZE, false)
	if hand_size < 1:
		_fail("config.json: 'hand_size' must be >= 1 (found %d)" % hand_size)
	var actions: int = _int_field(config_json, "actions_per_turn", "config.json", GameState.ACTIONS_PER_TURN, false)
	if actions < 0:
		_fail("config.json: 'actions_per_turn' must be >= 0 (found %d)" % actions)
	var merges: int = _int_field(config_json, "merges_per_turn", "config.json", GameState.MERGES_PER_TURN, false)
	if merges < 0:
		_fail("config.json: 'merges_per_turn' must be >= 0 (found %d)" % merges)

	_validate_decklist(config_json)
	_validate_dice_progression(config_json)
	_validate_config_allies(config_json)

	if not config_json.has("wave_transition_mode"):
		_warn("config.json: missing 'wave_transition_mode' (defaults to 'full_turn')")
	else:
		var mode: String = _string_field(config_json, "wave_transition_mode", "config.json", false).strip_edges().to_lower()
		if not _wave_modes.has(mode):
			_fail("config.json: unknown wave_transition_mode '%s' (expected one of: %s)" % [mode, ", ".join(_wave_modes)])


func _validate_decklist(config_json: Dictionary) -> void:
	if not config_json.has("decklist"):
		_fail("config.json: missing required 'decklist' (the starting deck)")
		return
	var decklist: Array = _array_field(config_json, "decklist", "config.json", true)
	if decklist.is_empty():
		_fail("config.json: 'decklist' must hold at least one [value, count] pair")
		return
	var total: int = 0
	for index: int in decklist.size():
		var context: String = "config.json decklist[%d]" % index
		var pair_raw: Variant = decklist[index]
		if not (pair_raw is Array):
			_fail("%s: must be a [value, count] array (found %s)" % [context, _type_name(pair_raw)])
			continue
		var pair: Array = pair_raw
		if pair.size() != 2:
			_fail("%s: needs exactly 2 numbers [value, count] (found %d)" % [context, pair.size()])
			continue
		var value: int = _int_value(pair[0], "%s value" % context, 0)
		var count: int = _int_value(pair[1], "%s count" % context, 0)
		if value < 1:
			_fail("%s: card value must be >= 1 (found %d)" % [context, value])
		elif value > SANITY_MAX_CARD_VALUE:
			_warn("%s: card value %d looks too high" % [context, value])
		if count < 1:
			_fail("%s: card count must be >= 1 (found %d)" % [context, count])
		else:
			total += count
	if total < 1:
		_fail("config.json: decklist holds no cards")
	elif total < GameState.MAX_HAND_SIZE:
		_warn("config.json: decklist holds only %d card(s), fewer than one starting hand" % total)


func _validate_dice_progression(config_json: Dictionary) -> void:
	if not config_json.has("dice_progression"):
		_fail("config.json: missing required 'dice_progression' (enemy dice per turn)")
		return
	var progression: Array = _array_field(config_json, "dice_progression", "config.json", true)
	if progression.is_empty():
		_fail("config.json: 'dice_progression' must hold at least one dice size")
		return
	var previous: int = 0
	for index: int in progression.size():
		var context: String = "config.json dice_progression[%d]" % index
		var sides: int = _int_value(progression[index], context, 0)
		if sides < 1:
			_fail("%s: dice size must be >= 1 (found %d)" % [context, sides])
			continue
		if sides > SANITY_MAX_DICE_SIDES:
			_warn("%s: dice size %d looks too high" % [context, sides])
		if sides < previous:
			_warn("%s: dice size %d is smaller than the previous entry %d" % [context, sides, previous])
		previous = sides


func _validate_config_allies(config_json: Dictionary) -> void:
	if not config_json.has("allies"):
		_fail("config.json: missing required 'allies' (the starting team)")
		return
	var allies: Array = _array_field(config_json, "allies", "config.json", true)
	if allies.is_empty():
		_fail("config.json: 'allies' must name at least one unit")
		return
	var seen: Dictionary = {}
	for index: int in allies.size():
		var context: String = "config.json allies[%d]" % index
		var ally_raw: Variant = allies[index]
		if not (ally_raw is String):
			_fail("%s: must be a string unit id (found %s)" % [context, _type_name(ally_raw)])
			continue
		var ally_text: String = ally_raw
		var ally_id: String = ally_text.strip_edges()
		if ally_id.is_empty():
			_fail("%s: unit id must not be empty" % context)
			continue
		if seen.has(ally_id):
			_fail("%s: duplicate ally '%s'" % [context, ally_id])
			continue
		seen[ally_id] = true
		if not _ally_ids.has(ally_id):
			if _enemy_ids.has(ally_id):
				_fail("%s: '%s' is an enemy and cannot be a starting ally" % [context, ally_id])
			else:
				_fail("%s: references unknown unit '%s'" % [context, ally_id])


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
	var config_allies: Array = _as_array(database.config.get("allies", []))
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


## Emits GitHub Actions workflow commands so failures annotate the exact file
## (and, when it can be located, line) inside the pull request.
func _emit_annotations() -> void:
	if OS.get_environment(ENV_GITHUB_ACTIONS) != "true":
		return
	for message: String in _errors:
		_emit_annotation("error", message)
	for message: String in _warnings:
		_emit_annotation("warning", message)


func _emit_annotation(severity: String, message: String) -> void:
	var text: String = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
	var file: String = _diagnostic_file(message)
	var line: int = _diagnostic_line(message)
	if file.is_empty():
		print("::%s title=Game data::%s" % [severity, text])
	elif line > 0:
		print("::%s file=%s,line=%d,title=Game data::%s" % [severity, file, line, text])
	else:
		print("::%s file=%s,title=Game data::%s" % [severity, file, text])


## Maps a diagnostic message to the repo-relative data file it belongs to.
func _diagnostic_file(message: String) -> String:
	if message.contains("skills.json"):
		return _repo_path(SKILLS_PATH)
	if message.contains("allies.json"):
		return _repo_path(ALLIES_PATH)
	if message.contains("enemies.json"):
		return _repo_path(ENEMIES_PATH)
	if message.contains("waves.json"):
		return _repo_path(WAVES_PATH)
	if message.contains("config.json"):
		return _repo_path(CONFIG_PATH)
	if message.contains("workbook"):
		return _repo_path(WORKBOOK_PATH)
	return ""


func _repo_path(res_path: String) -> String:
	if res_path.begins_with("res://"):
		return res_path.substr("res://".length())
	return res_path


## Best-effort 1-based source line for a diagnostic, 0 when it cannot be located.
func _diagnostic_line(message: String) -> int:
	if message.contains("skills.json"):
		var skill_id: String = _first_quoted(message)
		if skill_id.is_empty():
			return 0
		var skill_line: int = _line_of(SKILLS_PATH, "\"%s\": {" % skill_id, 0)
		var effect_index: int = _bracket_index(message, "effect[")
		if effect_index >= 0:
			var effect_line: int = _line_of(SKILLS_PATH, "\"effect_id\":", effect_index, maxi(0, skill_line - 1))
			if effect_line > 0:
				return effect_line
		return skill_line
	if message.contains("allies.json") or message.contains("enemies.json"):
		var unit_path: String = ALLIES_PATH if message.contains("allies.json") else ENEMIES_PATH
		var unit_id: String = _first_quoted(message)
		if unit_id.is_empty():
			return 0
		return _line_of(unit_path, "\"%s\": {" % unit_id, 0)
	if message.contains("waves.json"):
		return _waves_line(message)
	if message.contains("config.json"):
		return _config_line(message)
	return 0


func _waves_line(message: String) -> int:
	var wave_index: int = _bracket_index(message, "wave[")
	if wave_index < 0:
		return _line_of(WAVES_PATH, "\"waves\"", 0)
	var wave_line: int = _line_of(WAVES_PATH, "\"wave_index\"", wave_index)
	var enemy_index: int = _bracket_index(message, "enemy[")
	if enemy_index >= 0 and wave_line > 0:
		var enemy_line: int = _line_of(WAVES_PATH, "\"unit_id\"", enemy_index, wave_line - 1)
		if enemy_line > 0:
			return enemy_line
	return wave_line


func _config_line(message: String) -> int:
	var key: String = _first_quoted(message)
	if key.is_empty():
		for candidate: String in ["decklist", "dice_progression", "allies", "hand_size", "actions_per_turn", "merges_per_turn", "wave_transition_mode"]:
			if message.contains(candidate):
				key = candidate
				break
	if key.is_empty():
		return 0
	return _line_of(CONFIG_PATH, "\"%s\"" % key, 0)


## 1-based line of the `occurrence`-th (0-based) line at or after `from_line`
## that contains `needle`, or 0 when it is not found.
func _line_of(path: String, needle: String, occurrence: int, from_line: int = 0) -> int:
	var text: String = str(_raw_text.get(path, ""))
	if text.is_empty():
		return 0
	var lines: PackedStringArray = text.split("\n")
	var found: int = 0
	for index: int in lines.size():
		if index < from_line:
			continue
		if lines[index].contains(needle):
			if found == occurrence:
				return index + 1
			found += 1
	return 0


## The first 'single quoted' token of a diagnostic message, or "".
func _first_quoted(message: String) -> String:
	var start: int = message.find("'")
	if start < 0:
		return ""
	var end: int = message.find("'", start + 1)
	if end < 0:
		return ""
	return message.substr(start + 1, end - start - 1)


## The integer inside the first "<marker>N]" token, or -1 when absent.
func _bracket_index(message: String, marker: String) -> int:
	var start: int = message.find(marker)
	if start < 0:
		return -1
	start += marker.length()
	var end: int = message.find("]", start)
	if end < 0:
		return -1
	var digits: String = message.substr(start, end - start)
	if not digits.is_valid_int():
		return -1
	return digits.to_int()


## Appends a Markdown report to the GitHub Actions job summary so the result is
## readable on the run page without digging through the raw log.
func _write_step_summary(exit_code: int) -> void:
	if _summary_path.is_empty():
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("## Game data validation")
	lines.append("")
	if exit_code == 0:
		lines.append("Result: **PASSED** (%d warning(s))" % _warnings.size())
	else:
		lines.append("Result: **FAILED** (%d error(s), %d warning(s))" % [_errors.size(), _warnings.size()])
	lines.append("")
	lines.append("| Skills | Allies | Enemies | Waves |")
	lines.append("| --- | --- | --- | --- |")
	lines.append("| %d | %d | %d | %d |" % [
		_skills_json.size(),
		_allies_json.size(),
		_enemies_json.size(),
		_as_array(_waves_json.get("waves", [])).size(),
	])
	lines.append("")
	if not _errors.is_empty():
		lines.append("### Errors")
		lines.append("")
		for message: String in _errors:
			lines.append("- `%s`" % message)
		lines.append("")
	if not _warnings.is_empty():
		lines.append("### Warnings")
		lines.append("")
		for message: String in _warnings:
			lines.append("- `%s`" % message)
		lines.append("")
	var file: FileAccess = FileAccess.open(_summary_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()


## Proves the loaded database matches the raw JSON one-to-one (nothing was
## silently dropped) and that loading is deterministic across reloads.
func _validate_loader_consistency(database: GameDatabase) -> void:
	if database == null:
		return
	if database.skills.size() != _skills_json.size():
		_fail("[loader] skills.json declares %d skill(s) but %d were loaded" % [_skills_json.size(), database.skills.size()])
	for skill_key: Variant in _skills_json.keys():
		var skill_id: String = str(skill_key)
		if not database.skills.has(skill_id):
			continue
		var raw_entry: Dictionary = _as_dictionary(_skills_json[skill_key])
		var raw_effects: int = _as_array(raw_entry.get("effects", [])).size()
		var skill_raw: Variant = database.skills[skill_id]
		if not (skill_raw is SkillData):
			continue
		var skill: SkillData = skill_raw
		var loaded_effects: int = skill.base_effects.size() + skill.merged_effects.size()
		if raw_effects != loaded_effects:
			_fail("[loader] skills.json '%s' declares %d effect(s) but %d were loaded (an effect was dropped)" % [skill_id, raw_effects, loaded_effects])
	_validate_loaded_units(_allies_json, "allies.json", database.allies)
	_validate_loaded_units(_enemies_json, "enemies.json", database.enemies)
	var raw_waves: int = _as_array(_waves_json.get("waves", [])).size()
	if database.waves.size() != raw_waves:
		_fail("[loader] waves.json declares %d wave(s) but %d were loaded" % [raw_waves, database.waves.size()])
	var raw_decklist: int = _as_array(_config_json.get("decklist", [])).size()
	var loaded_decklist: int = _as_array(database.config.get("decklist", [])).size()
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
		var entry: Dictionary = _as_dictionary(units_json[unit_key])
		var unit_raw: Variant = loaded[unit_id]
		if not (unit_raw is UnitData):
			continue
		var unit: UnitData = unit_raw
		var context: String = "%s '%s'" % [label, unit_id]
		for slot: String in UNIT_SKILL_SLOTS:
			if _string_field(entry, slot, context, false).strip_edges().is_empty():
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
		parts.append("w:%d" % _as_array(wave_raw).size())
	parts.append("decklist=%d" % _as_array(database.config.get("decklist", [])).size())
	parts.append("allies=%d" % _as_array(database.config.get("allies", [])).size())
	parts.append("dice=%d" % _as_array(database.config.get("dice_progression", [])).size())
	return "|".join(parts)
#endregion
