class_name GameDataValidator
extends RefCounted
## Pure schema and semantic rules for the game data in res://Data/json/.
##
## Split out of Tools/validate_gameData.gd, which had grown the rules, the file I/O, the
## CLI and the CI reporting into one 1262-line Node. This half reads nothing: `validate()`
## takes an already-parsed bundle and returns {errors, warnings}, which is what lets
## GDTest/GameDataValidatorTest.gd exercise every rule in memory - no files, no scene
## tree, no exit code. The runner (Tools/validate_gameData.gd) keeps the I/O, the
## DataLoader integration check, the CLI and the reporting.
##
## Every allowlist is pulled from the runtime (DataLoader, Unit, GameState, DataBuilder),
## so validation can never drift away from what the game actually accepts.
##
## @author TheGreatJellyfish
## @version 11/28/2026

#region Constants
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


#region Public Variables
## Every problem the most recent `validate()` found.
var errors: PackedStringArray = PackedStringArray()
## Every warning the most recent `validate()` found, de-duplicated so a repeated typo
## does not flood the log.
var warnings: PackedStringArray = PackedStringArray()
## The bundle the most recent `validate()` read, so a caller can report its shape (the
## runner's CI summary and its loader consistency check) without re-reading the files.
var skills: Dictionary = {}
var allies: Dictionary = {}
var enemies: Dictionary = {}
var waves: Dictionary = {}
var config: Dictionary = {}
#endregion


#region Private Variables
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
#endregion


#region Public Methods
## Validates one already-parsed bundle and returns what it found. Starts from a clean
## slate, so a second call cannot accumulate the first call's diagnostics.
## @param bundle - {skills, allies, enemies, waves, config} as parsed JSON objects
## @return {errors: PackedStringArray, warnings: PackedStringArray}
func validate(bundle: Dictionary) -> Dictionary:
	reset()
	skills = as_dict(bundle.get("skills", {}))
	allies = as_dict(bundle.get("allies", {}))
	enemies = as_dict(bundle.get("enemies", {}))
	waves = as_dict(bundle.get("waves", {}))
	config = as_dict(bundle.get("config", {}))
	_validate_skills(skills)
	_validate_units(allies, "allies.json", false, _ally_ids)
	_validate_units(enemies, "enemies.json", true, _enemy_ids)
	_validate_unit_collisions()
	_validate_skill_usage()
	_validate_waves(waves)
	_validate_config(config)
	return {"errors": errors.duplicate(), "warnings": warnings.duplicate()}


## Clears every diagnostic and every cross-file registry, so a run starts from a clean
## slate. The allowlists are re-collected as well, because they are what a rule compares
## a value against.
func reset() -> void:
	errors = PackedStringArray()
	warnings = PackedStringArray()
	_skill_ids.clear()
	_ally_ids.clear()
	_enemy_ids.clear()
	_used_skill_ids.clear()
	_enemy_skill_ids.clear()
	_ally_skill_ids.clear()
	_skill_meta.clear()
	collect_allowlists()


## Records one problem. Public because the runner reports its own failures - a missing
## file, a workbook that will not parse, a DataLoader error - into the same list.
func fail(message: String) -> void:
	errors.append(message)


## Records one warning, de-duplicated. Public for the same reason as `fail`.
func warn(message: String) -> void:
	if not warnings.has(message):
		warnings.append(message)


## Describes a JSON value for a diagnostic: "number", "string", "object", ...
static func type_name(value: Variant) -> String:
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


## Reads a Dictionary out of a parsed JSON value, or {} when it is anything else.
static func as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		var result: Dictionary = value
		return result
	return {}


## Reads an Array out of a parsed JSON value, or [] when it is anything else.
static func as_array(value: Variant) -> Array:
	if value is Array:
		var result: Array = value
		return result
	return []
#endregion


#region Private Methods
func _keys_of(source: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		result.append(str(key))
	return result


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


## Reads a String out of a Dictionary of resolved fields.
func _dict_string(source: Dictionary, key: String) -> String:
	return str(source.get(key, ""))


func _is_snake_case_id(text: String) -> bool:
	if _id_pattern == null:
		_id_pattern = RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	return _id_pattern.search(text) != null


## Pulls every allowlist straight from the runtime so validation can never drift away
## away from what DataLoader, EffectBlock and Unit actually accept.
func collect_allowlists() -> void:
	_actions = _keys_of(DataLoader.ACTION_MAP)
	_target_modes = _keys_of(DataLoader.TARGET_MODE_MAP)
	_value_sources = _keys_of(DataLoader.VALUE_SOURCE_MAP)
	_conditions = _keys_of(DataLoader.CONDITION_MAP)
	_card_select_modes = _keys_of(DataLoader.CARD_SELECT_MAP)
	_card_mod_types = _keys_of(DataLoader.CARD_MOD_MAP)
	_merged_modes = _keys_of(DataLoader.MERGED_MODE_MAP)
	_status_ids = _keys_of(Unit.STATUS_DEFS)
	_wave_modes = _keys_of(GameState.WAVE_MODE_MAP)
	_effect_keys = _keys_of(DataBuilder.EFFECT_DEFAULTS)
	_skill_keys = _keys_of(DataBuilder.SKILL_DEFAULTS)
	_unit_keys = _keys_of(DataBuilder.UNIT_DEFAULTS)


func _warn_unknown_keys(source: Dictionary, known: PackedStringArray, context: String, extra: PackedStringArray) -> void:
	for key: Variant in source.keys():
		var key_name: String = str(key)
		if known.has(key_name) or extra.has(key_name):
			continue
		warn("%s: unknown key '%s' (typo?)" % [context, key_name])


## Coerces a raw JSON scalar into an int, reporting anything else. JSON numbers
## always arrive as float, so whole floats are accepted and truncated halves are
## rejected (they are almost always an authoring mistake).
func _int_value(raw: Variant, context: String, fallback: int) -> int:
	if raw is bool:
		fail("%s: must be a number, not a boolean" % context)
		return fallback
	if raw is int:
		var int_value: int = raw
		return int_value
	if raw is float:
		var float_value: float = raw
		if absf(float_value - roundf(float_value)) > 0.0001:
			fail("%s: must be a whole number (found %s)" % [context, str(float_value)])
		return int(roundf(float_value))
	if raw is String:
		var text: String = raw
		if text.is_valid_int():
			warn("%s: is a string; write it as a JSON number" % context)
			return text.to_int()
		fail("%s: must be a number (found string \"%s\")" % [context, text])
		return fallback
	fail("%s: must be a number (found %s)" % [context, type_name(raw)])
	return fallback


func _int_field(source: Dictionary, key: String, context: String, default_value: int, required: bool) -> int:
	if not source.has(key):
		if required:
			fail("%s: missing required '%s'" % [context, key])
		else:
			warn("%s: missing '%s' (defaults to %d)" % [context, key, default_value])
		return default_value
	return _int_value(source[key], "%s.%s" % [context, key], default_value)


func _string_field(source: Dictionary, key: String, context: String, required: bool) -> String:
	if not source.has(key):
		if required:
			fail("%s: missing required '%s'" % [context, key])
		return ""
	var raw: Variant = source[key]
	if raw is String:
		var text: String = raw
		return text
	fail("%s: '%s' must be a string (found %s)" % [context, key, type_name(raw)])
	return ""


func _bool_field(source: Dictionary, key: String, context: String, default_value: bool) -> bool:
	if not source.has(key):
		return default_value
	var raw: Variant = source[key]
	if raw is bool:
		var flag: bool = raw
		return flag
	fail("%s: '%s' must be true/false (found %s)" % [context, key, type_name(raw)])
	return default_value


## Enum strings are compared exactly (no case folding / trimming) because
## DataLoader also matches them exactly: a case or space typo must be an error.
func _enum_field(source: Dictionary, key: String, context: String, allowed: PackedStringArray, default_value: String, required: bool) -> String:
	if not source.has(key):
		if required:
			fail("%s: missing required '%s'" % [context, key])
		return default_value
	var value: String = _string_field(source, key, context, true)
	if value.is_empty():
		fail("%s: '%s' must not be empty" % [context, key])
		return default_value
	if not allowed.has(value):
		fail("%s: unknown '%s' value '%s' (expected one of: %s)" % [context, key, value, ", ".join(allowed)])
		return default_value
	return value


func _array_field(source: Dictionary, key: String, context: String, required: bool) -> Array:
	if not source.has(key):
		if required:
			fail("%s: missing required '%s'" % [context, key])
		return []
	var raw: Variant = source[key]
	if raw is Array:
		var values: Array = raw
		return values
	fail("%s: '%s' must be an array (found %s)" % [context, key, type_name(raw)])
	return []


func _require_effect_keys(effect: Dictionary, context: String) -> void:
	for key: String in REQUIRED_EFFECT_KEYS:
		if not effect.has(key):
			fail("%s: missing required '%s' (DataLoader would silently default it)" % [context, key])



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
			warn("%s: id is not lower snake_case" % context)
		var entry_raw: Variant = skills[skill_key]
		if not (entry_raw is Dictionary):
			fail("%s: must be an object (found %s)" % [context, type_name(entry_raw)])
			continue
		var entry: Dictionary = entry_raw
		_validate_skill(skill_id, entry, effect_id_owners)


func _validate_skill(skill_id: String, entry: Dictionary, effect_id_owners: Dictionary) -> void:
	var context: String = "skills.json '%s'" % skill_id
	_warn_unknown_keys(entry, _skill_keys, context, PackedStringArray(["effects"]))

	var display_name: String = _string_field(entry, "display_name", context, false)
	if display_name.is_empty():
		warn("%s: 'display_name' is empty" % context)
	if not entry.has("description"):
		warn("%s: missing 'description'" % context)

	var merged_mode: String = _enum_field(entry, "merged_mode", context, _merged_modes, "and_merged_first", false)
	var threshold: int = _int_field(entry, "condition_threshold", context, 0, false)
	if threshold < 0:
		fail("%s: 'condition_threshold' must be >= 0 (found %d)" % [context, threshold])
	_skill_meta[skill_id] = {"threshold": threshold}

	_validate_categories(_array_field(entry, "base_categories", context, false), "%s base_categories" % context)
	var merged_categories: Array = _array_field(entry, "merged_categories", context, false)
	_validate_categories(merged_categories, "%s merged_categories" % context)

	var merged_description: String = _string_field(entry, "merged_description", context, false)
	if not entry.has("merged_description"):
		warn("%s: missing 'merged_description'" % context)

	var effects: Array = _array_field(entry, "effects", context, true)
	if effects.is_empty():
		if entry.has("effects"):
			fail("%s: 'effects' must hold at least one effect" % context)
		return
	_validate_effects(skill_id, effects, effect_id_owners)

	var meta: Dictionary = as_dict(_skill_meta.get(skill_id, {}))
	var merged_count: int = _dict_int(meta, "merged", 0)
	var base_count: int = _dict_int(meta, "base", 0)
	if merged_count == 0:
		if merged_mode == "or":
			warn("%s: merged_mode 'or' but there are no merged effects (merging only swaps categories)" % context)
		if not merged_categories.is_empty():
			warn("%s: merged_categories are set but there are no merged effects" % context)
	else:
		if merged_description.is_empty():
			warn("%s: merged effects exist but 'merged_description' is empty" % context)
		if base_count == 0 and merged_mode != "or":
			warn("%s: merged effects exist but there are no base effects" % context)


func _validate_categories(categories: Array, context: String) -> void:
	var seen: Dictionary = {}
	for index: int in categories.size():
		var item_context: String = "%s[%d]" % [context, index]
		var item_raw: Variant = categories[index]
		if not (item_raw is String):
			fail("%s: category must be a string (found %s)" % [item_context, type_name(item_raw)])
			continue
		var category: String = item_raw
		if category.is_empty():
			fail("%s: category must not be empty" % item_context)
			continue
		if seen.has(category):
			warn("%s: duplicate category '%s'" % [item_context, category])
		seen[category] = true
		if not CARD_CATEGORIES.has(category):
			warn("%s: unknown card category '%s' (icons exist for: %s)" % [item_context, category, ", ".join(CARD_CATEGORIES)])


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
			fail("%s: must be an object (found %s)" % [effect_context, type_name(item_raw)])
			continue
		var effect: Dictionary = item_raw
		var trigger: String = _string_field(effect, "trigger", effect_context, false).strip_edges().to_lower()
		if not effect.has("trigger"):
			fail("%s: missing required 'trigger' (DataLoader would treat it as 'base')" % effect_context)
		elif trigger != "base" and trigger != "merged":
			fail("%s: 'trigger' must be 'base' or 'merged' (found '%s')" % [effect_context, trigger])
			trigger = ""
		if trigger == "base":
			base_count += 1
		elif trigger == "merged":
			merged_count += 1
		if trigger == "base" or trigger == "merged":
			var order: int = _int_field(effect, "order", effect_context, index, false)
			if order < 0:
				fail("%s: 'order' must be >= 0 (found %d)" % [effect_context, order])
			var known_orders: Dictionary = as_dict(orders[trigger])
			if known_orders.has(order):
				warn("%s: duplicate 'order' %d in the %s effects (JSON array order breaks the tie)" % [effect_context, order, trigger])
			else:
				known_orders[order] = true
				orders[trigger] = known_orders
		_validate_effect(effect_context, effect, producers, consumers, effect_id_owners, seen_effect_ids)

	if consumers.has("cached") and not _dict_bool(producers, "targets", false):
		warn("%s: 'cached' targeting is used but no effect caches targets in this skill" % context)
	if consumers.has("stored_value") and not _dict_bool(producers, "stored", false):
		warn("%s: 'stored_value' is used but no effect sets 'store_resolved_value' in this skill" % context)

	var meta: Dictionary = as_dict(_skill_meta.get(skill_id, {}))
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

	var fields: Dictionary = _check_effect_enums(context, effect)
	var numbers: Dictionary = _check_effect_numbers(context, effect)
	_check_effect_id(context, effect, effect_id_owners, seen_effect_ids)
	var action: String = _dict_string(fields, "action")
	var target_mode: String = _dict_string(fields, "target_mode")
	_check_effect_targeting(
		context, action, target_mode,
		_dict_int(numbers, "target_count", 0), _dict_int(numbers, "card_count", 0)
	)
	_check_effect_status(context, effect, action)
	_check_effect_value_warnings(context, fields, numbers, action)
	_record_effect_flow(
		producers, consumers, target_mode,
		_dict_string(fields, "value_source"), _dict_bool(fields, "store_resolved_value", false)
	)


## The enum fields and the two flags every other check reads, resolved once.
func _check_effect_enums(context: String, effect: Dictionary) -> Dictionary:
	return {
		"action": _enum_field(effect, "action", context, _actions, "deal_damage", false),
		"target_mode": _enum_field(effect, "target_mode", context, _target_modes, "none", false),
		"value_source": _enum_field(effect, "value_source", context, _value_sources, "card_value", false),
		"condition": _enum_field(effect, "condition", context, _conditions, "none", false),
		"card_select_mode": _enum_field(effect, "card_select_mode", context, _card_select_modes, "pick_n_card", false),
		"card_mod_type": _enum_field(effect, "card_mod_type", context, _card_mod_types, "buff", false),
		"negate_condition": _bool_field(effect, "negate_condition", context, false),
		"store_resolved_value": _bool_field(effect, "store_resolved_value", context, false),
	}


## The effect id: unique inside its own skill is an error, reused across skills a warning.
func _check_effect_id(context: String, effect: Dictionary, effect_id_owners: Dictionary, seen_effect_ids: Dictionary) -> void:
	var effect_id: int = _int_field(effect, "effect_id", context, -1, false)
	if effect_id < 0:
		return
	if seen_effect_ids.has(effect_id):
		fail("%s: duplicate effect_id %d inside this skill" % [context, effect_id])
	else:
		seen_effect_ids[effect_id] = true
	if effect_id_owners.has(effect_id):
		warn("%s: effect_id %d is also used by %s" % [context, effect_id, str(effect_id_owners[effect_id])])
	else:
		effect_id_owners[effect_id] = context


## Every numeric bound, returned so the later checks reuse the resolved values.
func _check_effect_numbers(context: String, effect: Dictionary) -> Dictionary:
	var target_count: int = _int_field(effect, "target_count", context, 1, false)
	if target_count < 0:
		fail("%s: 'target_count' must be >= 0 (found %d)" % [context, target_count])
	if target_count > SANITY_MAX_TARGET_COUNT:
		warn("%s: 'target_count' %d looks too high" % [context, target_count])
	var value_multiplier: int = _int_field(effect, "value_multiplier", context, 1, false)
	if value_multiplier < 0:
		fail("%s: 'value_multiplier' must be >= 0 (found %d)" % [context, value_multiplier])
	var value_divisor: int = _int_field(effect, "value_divisor", context, 1, false)
	if value_divisor < 1:
		fail("%s: 'value_divisor' must be >= 1 (found %d); DataLoader silently clamps it to 1" % [context, value_divisor])
	_int_field(effect, "value_offset", context, 0, false)
	var value_cap: int = _int_field(effect, "value_cap", context, -1, false)
	if value_cap < -1:
		fail("%s: 'value_cap' must be -1 (off) or >= 0 (found %d)" % [context, value_cap])
	elif value_cap == 0:
		warn("%s: 'value_cap' is 0, so the resolved value is always 0" % context)
	var card_count: int = _int_field(effect, "card_count", context, 1, false)
	if card_count < 0:
		fail("%s: 'card_count' must be >= 0 (found %d)" % [context, card_count])
	return {
		"target_count": target_count,
		"card_count": card_count,
		"fixed_amount": _int_field(effect, "fixed_amount", context, 0, false),
	}


## What the action itself requires of its target mode and its card count.
func _check_effect_targeting(context: String, action: String, target_mode: String, target_count: int, card_count: int) -> void:
	if TARGETED_ACTIONS.has(action):
		if target_mode == "none":
			fail("%s: action '%s' needs a target but target_mode is 'none'" % [context, action])
		if N_TARGET_MODES.has(target_mode) and target_count < 1:
			fail("%s: target_mode '%s' needs target_count >= 1 (found %d)" % [context, target_mode, target_count])
		if not N_TARGET_MODES.has(target_mode) and target_count > 0:
			warn("%s: target_count is %d but target_mode '%s' ignores it" % [context, target_count, target_mode])
	if CARD_ACTIONS.has(action) and card_count < 1:
		fail("%s: action '%s' needs card_count >= 1 (found %d)" % [context, action, card_count])
	if (action == "draw_card" or action == "discard_card") and target_mode != "none":
		warn("%s: action '%s' ignores unit targets but target_mode is '%s'" % [context, action, target_mode])


## The status field, which only `apply_status` reads.
func _check_effect_status(context: String, effect: Dictionary, action: String) -> void:
	if action == "apply_status":
		var status_id: String = _string_field(effect, "status_id", context, true).strip_edges().to_lower()
		if status_id.is_empty():
			fail("%s: action 'apply_status' needs a non-empty 'status_id'" % context)
		elif not _status_ids.has(status_id):
			fail("%s: unknown status_id '%s' (known: %s)" % [context, status_id, ", ".join(_status_ids)])
	elif effect.has("status_id") and not _string_field(effect, "status_id", context, false).strip_edges().is_empty():
		warn("%s: 'status_id' is only used by apply_status" % context)


## The warnings that depend on two fields at once: a negated `none` condition, and a fixed
## value that resolves to nothing.
func _check_effect_value_warnings(context: String, fields: Dictionary, numbers: Dictionary, action: String) -> void:
	if _dict_string(fields, "condition") == "none" and _dict_bool(fields, "negate_condition", false):
		warn("%s: 'negate_condition' is true but 'condition' is 'none'" % context)
	if _dict_string(fields, "value_source") != "fixed" or not VALUE_ACTIONS.has(action):
		return
	var fixed_amount: int = _dict_int(numbers, "fixed_amount", 0)
	if fixed_amount == 0:
		warn("%s: value_source 'fixed' with fixed_amount 0 resolves to nothing" % context)
	elif fixed_amount < 0:
		warn("%s: negative fixed_amount %d" % [context, fixed_amount])


## Mirrors the effect onto the enclosing skill's producer/consumer flags, which is how
## `_validate_effects` can tell that a `cached` target or a `stored_value` has no source.
func _record_effect_flow(producers: Dictionary, consumers: PackedStringArray, target_mode: String, value_source: String, store_value: bool) -> void:
	if target_mode == "cached" or value_source == "target_missing_hp":
		consumers.append("cached")
	if TARGET_CACHING_MODES.has(target_mode):
		producers["targets"] = true
	if value_source == "stored_value":
		consumers.append("stored_value")
	if store_value:
		producers["stored"] = true


## Validates one units.json-style file. The per-entry checks are split into the unit's own
## fields and its skill slots, so the loop here stays a loop.
func _validate_units(units_json: Dictionary, label: String, is_enemy_file: bool, id_bucket: Dictionary) -> void:
	if units_json.is_empty():
		return
	print("checking %d unit(s) in %s" % [units_json.size(), label])
	for unit_key: Variant in units_json.keys():
		var unit_id: String = str(unit_key)
		var context: String = "%s '%s'" % [label, unit_id]
		id_bucket[unit_id] = is_enemy_file
		if unit_id.is_empty():
			fail("%s: unit id must not be empty" % label)
			continue
		if not _is_snake_case_id(unit_id):
			warn("%s: unit id is not lower snake_case" % context)
		var entry_raw: Variant = units_json[unit_key]
		if not (entry_raw is Dictionary):
			fail("%s: must be an object (found %s)" % [context, type_name(entry_raw)])
			continue
		var entry: Dictionary = entry_raw
		_warn_unknown_keys(entry, _unit_keys, context, PackedStringArray())
		_validate_unit_entry(context, entry, label, is_enemy_file)
		if _validate_unit_skills(context, entry, is_enemy_file) == 0:
			fail("%s: defines no usable skill" % context)


## A unit's own fields: its display name, its two stat ceilings, and the `is_enemy` flag,
## which the file it lives in decides.
func _validate_unit_entry(context: String, entry: Dictionary, label: String, is_enemy_file: bool) -> void:
	var display_name: String = _string_field(entry, "display_name", context, false)
	if display_name.is_empty():
		warn("%s: 'display_name' is empty" % context)
	var max_hp: int = _int_field(entry, "max_hp", context, 10, false)
	if max_hp < SANITY_MIN_HP:
		fail("%s: 'max_hp' must be >= %d (found %d)" % [context, SANITY_MIN_HP, max_hp])
	var max_moxie: int = _int_field(entry, "max_moxie", context, 20, false)
	if max_moxie < 1:
		fail("%s: 'max_moxie' must be >= 1 (found %d)" % [context, max_moxie])
	if not entry.has("is_enemy"):
		warn("%s: missing 'is_enemy' (DataLoader infers %s from the file)" % [context, str(is_enemy_file)])
		return
	var declared_enemy: bool = _bool_field(entry, "is_enemy", context, is_enemy_file)
	if declared_enemy != is_enemy_file:
		fail("%s: 'is_enemy' is %s but the unit lives in %s (expected %s)" % [
			context, str(declared_enemy), label, str(is_enemy_file),
		])


## The three skill slots: each must resolve to a loaded skill, and at least one must.
## Returns how many did, so the caller can report a unit that defines no usable skill.
func _validate_unit_skills(context: String, entry: Dictionary, is_enemy_file: bool) -> int:
	var skill_count: int = 0
	for slot: String in UNIT_SKILL_SLOTS:
		var slot_context: String = "%s %s" % [context, slot]
		var skill_id: String = _string_field(entry, slot, slot_context, false).strip_edges()
		if skill_id.is_empty():
			if not entry.has(slot):
				warn("%s: missing '%s'" % [context, slot])
			elif slot != "ultimate":
				fail("%s: '%s' must not be empty" % [context, slot])
			continue
		if not _skill_ids.has(skill_id):
			fail("%s: references unknown skill '%s'" % [slot_context, skill_id])
			continue
		skill_count += 1
		_used_skill_ids[skill_id] = true
		if is_enemy_file:
			_enemy_skill_ids[skill_id] = true
		else:
			_ally_skill_ids[skill_id] = true
	return skill_count


func _validate_unit_collisions() -> void:
	for unit_id: String in _ally_ids.keys():
		if _enemy_ids.has(unit_id):
			fail("unit id '%s' is defined in both allies.json and enemies.json (they collide in GameDatabase.units)" % unit_id)


## Cross-checks the skills against the units that use them.
func _validate_skill_usage() -> void:
	for skill_id: String in _skill_ids.keys():
		if not _used_skill_ids.has(skill_id):
			warn("skills.json '%s' is not referenced by any unit (dead skill)" % skill_id)
	for skill_id: String in _enemy_skill_ids.keys():
		var meta: Dictionary = as_dict(_skill_meta.get(skill_id, {}))
		if _dict_int(meta, "merged", 0) > 0 and _dict_int(meta, "threshold", 0) <= 0:
			warn("skills.json '%s' is an enemy skill with merged effects but condition_threshold 0, so EnemyIntent never marks the merge condition (set a threshold > 0)" % skill_id)
	for skill_id: String in _ally_skill_ids.keys():
		var meta: Dictionary = as_dict(_skill_meta.get(skill_id, {}))
		if _dict_int(meta, "threshold", 0) > 0:
			warn("skills.json '%s' is an ally skill with condition_threshold > 0, but allies merge by card value and ignore the threshold" % skill_id)


func _validate_waves(waves_json: Dictionary) -> void:
	if waves_json.is_empty():
		return
	_warn_unknown_keys(waves_json, PackedStringArray(["waves"]), "waves.json", PackedStringArray())
	var waves: Array = _array_field(waves_json, "waves", "waves.json", true)
	if waves.is_empty():
		if waves_json.has("waves"):
			fail("waves.json: 'waves' must hold at least one wave")
		return
	print("checking %d wave(s)" % waves.size())
	for index: int in waves.size():
		var context: String = "waves.json wave[%d]" % index
		var wave_raw: Variant = waves[index]
		if not (wave_raw is Dictionary):
			fail("%s: must be an object (found %s)" % [context, type_name(wave_raw)])
			continue
		var wave: Dictionary = wave_raw
		_warn_unknown_keys(wave, WAVE_KEYS, context, PackedStringArray())
		if wave.has("wave_index"):
			var wave_index: int = _int_field(wave, "wave_index", context, index, false)
			if wave_index != index:
				warn("%s: 'wave_index' is %d but it sits at position %d (DataLoader uses array order)" % [context, wave_index, index])
		var enemies: Array = _array_field(wave, "enemies", context, true)
		if enemies.is_empty():
			if wave.has("enemies"):
				fail("%s: 'enemies' is empty (the wave would be cleared instantly)" % context)
			continue
		for enemy_index: int in enemies.size():
			_validate_wave_enemy(context, enemies[enemy_index], enemy_index)


func _validate_wave_enemy(wave_context: String, item_raw: Variant, index: int) -> void:
	var context: String = "%s enemy[%d]" % [wave_context, index]
	if not (item_raw is Dictionary):
		fail("%s: must be an object (found %s)" % [context, type_name(item_raw)])
		return
	var entry: Dictionary = item_raw
	_warn_unknown_keys(entry, WAVE_ENEMY_KEYS, context, PackedStringArray())
	var unit_id: String = _string_field(entry, "unit_id", context, true).strip_edges()
	if unit_id.is_empty():
		fail("%s: 'unit_id' must not be empty" % context)
		return
	if not _enemy_ids.has(unit_id):
		if _ally_ids.has(unit_id):
			fail("%s: '%s' is an ally; waves may only spawn enemies" % [context, unit_id])
		else:
			fail("%s: references unknown unit '%s'" % [context, unit_id])
		return
	if entry.has("max_hp_override"):
		var hp_override: int = _int_field(entry, "max_hp_override", context, 0, false)
		if hp_override < 1:
			fail("%s: 'max_hp_override' must be >= 1 (found %d)" % [context, hp_override])
	if entry.has("display_name_override"):
		var name_override: String = _string_field(entry, "display_name_override", context, false).strip_edges()
		if name_override.is_empty():
			fail("%s: 'display_name_override' must not be empty" % context)


func _validate_config(config_json: Dictionary) -> void:
	if config_json.is_empty():
		return
	print("checking config.json")
	var hand_size: int = _int_field(config_json, "hand_size", "config.json", GameState.MAX_HAND_SIZE, false)
	if hand_size < 1:
		fail("config.json: 'hand_size' must be >= 1 (found %d)" % hand_size)
	var actions: int = _int_field(config_json, "actions_per_turn", "config.json", GameState.ACTIONS_PER_TURN, false)
	if actions < 0:
		fail("config.json: 'actions_per_turn' must be >= 0 (found %d)" % actions)
	var merges: int = _int_field(config_json, "merges_per_turn", "config.json", GameState.MERGES_PER_TURN, false)
	if merges < 0:
		fail("config.json: 'merges_per_turn' must be >= 0 (found %d)" % merges)

	_validate_decklist(config_json)
	_validate_dice_progression(config_json)
	_validate_config_allies(config_json)

	if not config_json.has("wave_transition_mode"):
		warn("config.json: missing 'wave_transition_mode' (defaults to 'full_turn')")
	else:
		var mode: String = _string_field(config_json, "wave_transition_mode", "config.json", false).strip_edges().to_lower()
		if not _wave_modes.has(mode):
			fail("config.json: unknown wave_transition_mode '%s' (expected one of: %s)" % [mode, ", ".join(_wave_modes)])


func _validate_decklist(config_json: Dictionary) -> void:
	if not config_json.has("decklist"):
		fail("config.json: missing required 'decklist' (the starting deck)")
		return
	var decklist: Array = _array_field(config_json, "decklist", "config.json", true)
	if decklist.is_empty():
		fail("config.json: 'decklist' must hold at least one [value, count] pair")
		return
	var total: int = 0
	for index: int in decklist.size():
		var context: String = "config.json decklist[%d]" % index
		var pair_raw: Variant = decklist[index]
		if not (pair_raw is Array):
			fail("%s: must be a [value, count] array (found %s)" % [context, type_name(pair_raw)])
			continue
		var pair: Array = pair_raw
		if pair.size() != 2:
			fail("%s: needs exactly 2 numbers [value, count] (found %d)" % [context, pair.size()])
			continue
		var value: int = _int_value(pair[0], "%s value" % context, 0)
		var count: int = _int_value(pair[1], "%s count" % context, 0)
		if value < 1:
			fail("%s: card value must be >= 1 (found %d)" % [context, value])
		elif value > SANITY_MAX_CARD_VALUE:
			warn("%s: card value %d looks too high" % [context, value])
		if count < 1:
			fail("%s: card count must be >= 1 (found %d)" % [context, count])
		else:
			total += count
	if total < 1:
		fail("config.json: decklist holds no cards")
	elif total < GameState.MAX_HAND_SIZE:
		warn("config.json: decklist holds only %d card(s), fewer than one starting hand" % total)


func _validate_dice_progression(config_json: Dictionary) -> void:
	if not config_json.has("dice_progression"):
		fail("config.json: missing required 'dice_progression' (enemy dice per turn)")
		return
	var progression: Array = _array_field(config_json, "dice_progression", "config.json", true)
	if progression.is_empty():
		fail("config.json: 'dice_progression' must hold at least one dice size")
		return
	var previous: int = 0
	for index: int in progression.size():
		var context: String = "config.json dice_progression[%d]" % index
		var sides: int = _int_value(progression[index], context, 0)
		if sides < 1:
			fail("%s: dice size must be >= 1 (found %d)" % [context, sides])
			continue
		if sides > SANITY_MAX_DICE_SIDES:
			warn("%s: dice size %d looks too high" % [context, sides])
		if sides < previous:
			warn("%s: dice size %d is smaller than the previous entry %d" % [context, sides, previous])
		previous = sides


func _validate_config_allies(config_json: Dictionary) -> void:
	if not config_json.has("allies"):
		fail("config.json: missing required 'allies' (the starting team)")
		return
	var allies: Array = _array_field(config_json, "allies", "config.json", true)
	if allies.is_empty():
		fail("config.json: 'allies' must name at least one unit")
		return
	var seen: Dictionary = {}
	for index: int in allies.size():
		var context: String = "config.json allies[%d]" % index
		var ally_raw: Variant = allies[index]
		if not (ally_raw is String):
			fail("%s: must be a string unit id (found %s)" % [context, type_name(ally_raw)])
			continue
		var ally_text: String = ally_raw
		var ally_id: String = ally_text.strip_edges()
		if ally_id.is_empty():
			fail("%s: unit id must not be empty" % context)
			continue
		if seen.has(ally_id):
			fail("%s: duplicate ally '%s'" % [context, ally_id])
			continue
		seen[ally_id] = true
		if not _ally_ids.has(ally_id):
			if _enemy_ids.has(ally_id):
				fail("%s: '%s' is an enemy and cannot be a starting ally" % [context, ally_id])
			else:
				fail("%s: references unknown unit '%s'" % [context, ally_id])

#endregion
