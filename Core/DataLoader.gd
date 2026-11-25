class_name DataLoader
extends RefCounted
## Runtime loader for the game data JSON files in res://Data/json/.
##
## Those JSON files are the single source of truth; the workbook
## (res://Data/xlsx/game_data.xlsx) is only a bulk-entry authoring tool handled
## by Tools/dataBuilder.gd. Every file has a JSON object at its root, so loading
## is always FileAccess + JSON.parse_string followed by strict typed parsing.
##
## JSON stores enum values as readable strings ("deal_damage", "pick_n_enemy"),
## never numeric ordinals, so the files stay editable by hand or by an AI.
##
## @author TheGreatJellyfish
## @version 11/16/2026

#region Constants
const JSON_DIR: String = "res://Data/json"
const SKILLS_PATH: String = "res://Data/json/skills.json"
const ALLIES_PATH: String = "res://Data/json/allies.json"
const ENEMIES_PATH: String = "res://Data/json/enemies.json"
const WAVES_PATH: String = "res://Data/json/waves.json"
const CONFIG_PATH: String = "res://Data/json/config.json"

const DEFAULT_MAX_MOXIE: int = 20
const DEFAULT_MAX_HP: int = 10

## JSON enum strings -> runtime enums (mirrors the Enums sheet).
const ACTION_MAP: Dictionary = {
	"deal_damage": EffectBlock.Action.DEAL_DAMAGE,
	"gain_shield": EffectBlock.Action.GAIN_SHIELD,
	"reduce_shield": EffectBlock.Action.REDUCE_SHIELD,
	"heal": EffectBlock.Action.HEAL,
	"deal_true_damage": EffectBlock.Action.DEAL_TRUE_DAMAGE,
	"add_bonus": EffectBlock.Action.ADD_BONUS,
	"apply_modifier": EffectBlock.Action.APPLY_MODIFIER,
	"modify_card": EffectBlock.Action.MODIFY_CARD,
	"discard_card": EffectBlock.Action.DISCARD_CARD,
	"draw_card": EffectBlock.Action.DRAW_CARD,
	"set_next_skill_bonus": EffectBlock.Action.SET_NEXT_SKILL_BONUS,
	"raise_max_hp": EffectBlock.Action.RAISE_MAX_HP,
	"apply_status": EffectBlock.Action.APPLY_STATUS,
}
const TARGET_MODE_MAP: Dictionary = {
	"none": EffectBlock.TargetMode.NONE,
	"caster": EffectBlock.TargetMode.CASTER,
	"cached": EffectBlock.TargetMode.CACHED,
	"pick_n_enemy": EffectBlock.TargetMode.PICK_N_ENEMY,
	"pick_n_ally": EffectBlock.TargetMode.PICK_N_ALLY,
	"all_enemies": EffectBlock.TargetMode.ALL_ENEMIES,
	"all_allies": EffectBlock.TargetMode.ALL_ALLIES,
	"cached_or_pick_enemy": EffectBlock.TargetMode.CACHED_OR_PICK_ENEMY,
}
const VALUE_SOURCE_MAP: Dictionary = {
	"card_value": EffectBlock.ValueSource.CARD_VALUE,
	"card_value_half": EffectBlock.ValueSource.CARD_VALUE_HALF,
	"card_value_double": EffectBlock.ValueSource.CARD_VALUE_DOUBLE,
	"fixed": EffectBlock.ValueSource.FIXED,
	"target_missing_hp": EffectBlock.ValueSource.TARGET_MISSING_HP,
	"highest_card_in_hand": EffectBlock.ValueSource.HIGHEST_CARD_IN_HAND,
	"lowest_card_in_hand": EffectBlock.ValueSource.LOWEST_CARD_IN_HAND,
	"stored_value": EffectBlock.ValueSource.STORED_VALUE,
	"caster_shield": EffectBlock.ValueSource.CASTER_SHIELD,
}
const MERGED_MODE_MAP: Dictionary = {
	"and_merged_first": SkillData.MergedMode.AND_MERGED_FIRST,
	"and_base_first": SkillData.MergedMode.AND_BASE_FIRST,
	"or": SkillData.MergedMode.OR,
}
const CONDITION_MAP: Dictionary = {
	"none": EffectBlock.Condition.NONE,
	"target_no_shield": EffectBlock.Condition.TARGET_NO_SHIELD,
}
const CARD_SELECT_MAP: Dictionary = {
	"pick_n_card": EffectBlock.CardSelectMode.PICK_N_CARD,
	"auto_highest": EffectBlock.CardSelectMode.AUTO_HIGHEST,
	"auto_top_n": EffectBlock.CardSelectMode.AUTO_TOP_N,
}
const CARD_MOD_MAP: Dictionary = {
	"buff": EffectBlock.CardModType.BUFF,
	"debuff": EffectBlock.CardModType.DEBUFF,
}
#endregion

#region Private Variables
static var _db: GameDatabase = null
static var _errors: PackedStringArray = PackedStringArray()
#endregion
#region Public Methods
## Returns the cached database, loading the JSON files on first use.
static func db() -> GameDatabase:
	if _db != null:
		return _db
	var database: GameDatabase = load_database()
	_db = database
	if not _errors.is_empty():
		var missing_data: bool = false
		for message: String in _errors:
			printerr(message)
			if message.contains("missing data file"):
				missing_data = true
		if missing_data:
			printerr("[DataLoader] Regenerate the JSON with: godot --headless --path . --script res://Tools/export_xlsx_to_json.gd")
		if not Engine.is_editor_hint():
			quit_code(1)
	return database


## Reads every JSON file and rebuilds a fresh GameDatabase.
## Problems are collected in get_errors() instead of aborting immediately so
## tooling can report them all at once. Always reads from disk (no cache).
static func load_database() -> GameDatabase:
	_errors.clear()
	var database: GameDatabase = GameDatabase.new()
	database.skills = _build_skills(_read_json_object(SKILLS_PATH))
	database.allies = _build_units(_read_json_object(ALLIES_PATH), false, database.skills)
	database.enemies = _build_units(_read_json_object(ENEMIES_PATH), true, database.skills)
	database.units = {}
	database.units.merge(database.allies, true)
	database.units.merge(database.enemies, true)
	database.waves = _build_waves(_read_json_object(WAVES_PATH), database.units)
	database.config = _build_config(_read_json_object(CONFIG_PATH), database.units)
	if database.skills.is_empty():
		_errors.append("[DataLoader] skills.json produced no skills")
	if database.units.is_empty():
		_errors.append("[DataLoader] no units loaded from allies.json / enemies.json")
	if database.waves.is_empty():
		_errors.append("[DataLoader] waves.json produced no waves")
	return database


## Problems collected by the most recent db() or load_database() call.
static func get_errors() -> PackedStringArray:
	return _errors.duplicate()


## Drops the cached database so the next db() call re-reads the JSON files.
static func reload() -> void:
	_db = null
	_errors.clear()


## Quits the running game with the given exit code (no-op inside the editor).
static func quit_code(code: int) -> void:
	if Engine.is_editor_hint():
		return
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		tree.quit(code)
#endregion

#region Private Methods
## Reads a JSON file whose root must be an object.
## @return Dictionary - parsed object, or an empty Dictionary plus an error
static func _read_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_errors.append("[DataLoader] missing data file: " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("[DataLoader] cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_errors.append("[DataLoader] %s does not contain a JSON object at its root" % path)
		return {}
	var data: Dictionary = parsed
	return data


## Coerces a JSON value into an int. JSON numbers always parse as float, so
## every integer must be converted explicitly instead of assigned directly.
static func _get_int(source: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = source.get(key, fallback)
	return _to_int(value, fallback)


## Coerces any JSON scalar (float, int, bool, String) into an int.
static func _to_int(value: Variant, fallback: int) -> int:
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


## Coerces a JSON value into a bool.
static func _get_bool(source: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = source.get(key, fallback)
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
		if lowered in ["true", "1"]:
			return true
		if lowered in ["false", "0"]:
			return false
	return fallback


## Coerces a JSON value into a String.
static func _get_string(source: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = source.get(key, fallback)
	if value is String:
		var text: String = value
		return text
	if value == null:
		return fallback
	return str(value)


## Coerces a JSON array of strings into a PackedStringArray.
static func _get_string_array(source: Dictionary, key: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var value: Variant = source.get(key, [])
	if not (value is Array):
		return result
	var listed: Array = value
	for item: Variant in listed:
		var text: String = str(item).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


## Reads a JSON array field, tolerating missing or malformed values.
static func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		var listed: Array = value
		return listed
	return []
## skills.json -> { skill_id: SkillData } with every effect block embedded.
static func _build_skills(skills_json: Dictionary) -> Dictionary:
	var skills: Dictionary = {}
	for skill_id: String in skills_json:
		var entry_raw: Variant = skills_json[skill_id]
		if not (entry_raw is Dictionary):
			_errors.append("[DataLoader] skills.json '%s' is not an object" % skill_id)
			continue
		var entry: Dictionary = entry_raw
		var skill: SkillData = SkillData.new()
		skill.skill_name = _get_string(entry, "display_name", skill_id)
		skill.description = _get_string(entry, "description", "")
		skill.merged_description = _get_string(entry, "merged_description", "")
		var merged_mode_key: String = _get_string(entry, "merged_mode", "and_merged_first")
		skill.merged_mode = _resolve_enum(
			MERGED_MODE_MAP, merged_mode_key, SkillData.MergedMode.AND_MERGED_FIRST,
			"skills.json '%s' merged_mode" % skill_id
		)
		skill.condition_threshold = _get_int(entry, "condition_threshold", 0)
		skill.base_categories = _get_string_array(entry, "base_categories")
		skill.merged_categories = _get_string_array(entry, "merged_categories")
		_add_effects(skill, entry, skill_id)
		skills[skill_id] = skill
	return skills


## Routes every embedded effect of one skill into base_effects or
## merged_effects, keeping the declared execution order.
static func _add_effects(skill: SkillData, entry: Dictionary, skill_id: String) -> void:
	var effects: Array = _sorted_effects(entry)
	for item: Variant in effects:
		if not (item is Dictionary):
			_errors.append("[DataLoader] skills.json '%s' has a non-object effect" % skill_id)
			continue
		var effect_data: Dictionary = item
		var block: EffectBlock = _build_effect_block(effect_data, skill_id)
		var trigger: String = _get_string(effect_data, "trigger", "base").strip_edges().to_lower()
		if trigger == "merged":
			skill.merged_effects.append(block)
		elif trigger == "base":
			skill.base_effects.append(block)
		else:
			_errors.append("[DataLoader] skills.json '%s' has unknown trigger '%s'" % [skill_id, trigger])


## Returns the embedded effect list ordered by "order", falling back to the JSON
## array order (and keeping array order for ties) so hand edits stay predictable.
static func _sorted_effects(entry: Dictionary) -> Array:
	var raw_effects: Array = _get_array(entry, "effects")
	if raw_effects.size() <= 1:
		return raw_effects
	var wrapped: Array = []
	for index: int in raw_effects.size():
		var item: Variant = raw_effects[index]
		var order: int = index
		if item is Dictionary:
			var effect_data: Dictionary = item
			order = _get_int(effect_data, "order", index)
		wrapped.append({"order": order, "index": index, "data": item})
	wrapped.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a: int = _get_int(a, "order", 0)
		var order_b: int = _get_int(b, "order", 0)
		if order_a != order_b:
			return order_a < order_b
		return _get_int(a, "index", 0) < _get_int(b, "index", 0)
	)
	var ordered: Array = []
	for wrapper: Dictionary in wrapped:
		ordered.append(wrapper["data"])
	return ordered


## Builds one EffectBlock from its JSON object.
static func _build_effect_block(data: Dictionary, skill_id: String) -> EffectBlock:
	var context: String = "skills.json '%s' effect" % skill_id
	var block: EffectBlock = EffectBlock.new()
	block.action_type = _resolve_enum(
		ACTION_MAP, _get_string(data, "action", "deal_damage"),
		EffectBlock.Action.DEAL_DAMAGE, context + " action"
	)
	block.target_mode = _resolve_enum(
		TARGET_MODE_MAP, _get_string(data, "target_mode", "none"),
		EffectBlock.TargetMode.NONE, context + " target_mode"
	)
	block.target_count = _get_int(data, "target_count", 1)
	block.value_source = _resolve_enum(
		VALUE_SOURCE_MAP, _get_string(data, "value_source", "card_value"),
		EffectBlock.ValueSource.CARD_VALUE, context + " value_source"
	)
	block.value_multiplier = _get_int(data, "value_multiplier", 1)
	block.value_divisor = maxi(1, _get_int(data, "value_divisor", 1))
	block.value_offset = _get_int(data, "value_offset", 0)
	block.value_cap = _get_int(data, "value_cap", -1)
	block.fixed_amount = _get_int(data, "fixed_amount", 0)
	block.condition = _resolve_enum(
		CONDITION_MAP, _get_string(data, "condition", "none"),
		EffectBlock.Condition.NONE, context + " condition"
	)
	block.negate_condition = _get_bool(data, "negate_condition", false)
	block.card_select_mode = _resolve_enum(
		CARD_SELECT_MAP, _get_string(data, "card_select_mode", "pick_n_card"),
		EffectBlock.CardSelectMode.PICK_N_CARD, context + " card_select_mode"
	)
	block.card_mod_type = _resolve_enum(
		CARD_MOD_MAP, _get_string(data, "card_mod_type", "buff"),
		EffectBlock.CardModType.BUFF, context + " card_mod_type"
	)
	block.card_count = _get_int(data, "card_count", 1)
	block.status_id = _get_string(data, "status_id", "")
	block.store_resolved_value = _get_bool(data, "store_resolved_value", false)
	return block


## Looks a JSON enum string up in its map, reporting unknown values instead of
## silently falling back (typos in a hand-edited JSON are caught immediately).
static func _resolve_enum(source_map: Dictionary, key: String, fallback: Variant, context: String) -> Variant:
	if not source_map.has(key):
		_errors.append("[DataLoader] %s: unknown value '%s'" % [context, key])
		return fallback
	return source_map[key]
## allies.json / enemies.json -> { unit_id: UnitData } with resolved skills.
## @param default_is_enemy - used when a unit omits "is_enemy"
static func _build_units(units_json: Dictionary, default_is_enemy: bool, skills: Dictionary) -> Dictionary:
	var units: Dictionary = {}
	for unit_id: String in units_json:
		var entry_raw: Variant = units_json[unit_id]
		if not (entry_raw is Dictionary):
			_errors.append("[DataLoader] unit '%s' is not an object" % unit_id)
			continue
		var entry: Dictionary = entry_raw
		var unit: UnitData = UnitData.new()
		unit.display_name = _get_string(entry, "display_name", unit_id)
		unit.max_hp = maxi(1, _get_int(entry, "max_hp", DEFAULT_MAX_HP))
		unit.max_moxie = maxi(1, _get_int(entry, "max_moxie", DEFAULT_MAX_MOXIE))
		unit.is_enemy = _get_bool(entry, "is_enemy", default_is_enemy)
		unit.skill_1 = _resolve_skill(entry, "skill_1", skills, unit_id)
		unit.skill_2 = _resolve_skill(entry, "skill_2", skills, unit_id)
		unit.ultimate = _resolve_skill(entry, "ultimate", skills, unit_id)
		units[unit_id] = unit
	return units


## Resolves one skill slot id against the loaded skills.
static func _resolve_skill(entry: Dictionary, slot: String, skills: Dictionary, unit_id: String) -> SkillData:
	var skill_id: String = _get_string(entry, slot, "").strip_edges()
	if skill_id.is_empty():
		return null
	if not skills.has(skill_id):
		_errors.append("[DataLoader] unit '%s' slot %s references unknown skill '%s'" % [unit_id, slot, skill_id])
		return null
	var skill: SkillData = skills[skill_id]
	return skill


## waves.json -> Array of Array[UnitData], applying hp/name overrides.
static func _build_waves(waves_json: Dictionary, units: Dictionary) -> Array:
	var waves: Array = []
	var raw_waves: Array = _get_array(waves_json, "waves")
	for index: int in raw_waves.size():
		var wave_raw: Variant = raw_waves[index]
		if not (wave_raw is Dictionary):
			_errors.append("[DataLoader] waves.json entry %d is not an object" % index)
			continue
		var wave_entry: Dictionary = wave_raw
		var wave_units: Array[UnitData] = []
		var enemies_raw: Array = _get_array(wave_entry, "enemies")
		for enemy_raw: Variant in enemies_raw:
			if not (enemy_raw is Dictionary):
				_errors.append("[DataLoader] waves.json wave %d has a non-object enemy" % index)
				continue
			var enemy_entry: Dictionary = enemy_raw
			var unit_id: String = _get_string(enemy_entry, "unit_id", "").strip_edges()
			if not units.has(unit_id):
				_errors.append("[DataLoader] waves.json wave %d references unknown unit '%s'" % [index, unit_id])
				continue
			var base_unit: UnitData = units[unit_id]
			var hp_override: int = _get_int(enemy_entry, "max_hp_override", 0)
			var name_override: String = _get_string(enemy_entry, "display_name_override", "").strip_edges()
			if hp_override <= 0 and name_override.is_empty():
				wave_units.append(base_unit)
				continue
			var variant_unit: UnitData = _clone_unit(base_unit)
			if hp_override > 0:
				variant_unit.max_hp = hp_override
			if not name_override.is_empty():
				variant_unit.display_name = name_override
			wave_units.append(variant_unit)
		waves.append(wave_units)
	return waves


## Copies a UnitData template so wave overrides never mutate the base unit.
static func _clone_unit(original: UnitData) -> UnitData:
	var clone: UnitData = UnitData.new()
	clone.display_name = original.display_name
	clone.max_hp = original.max_hp
	clone.portrait = original.portrait
	clone.skill_1 = original.skill_1
	clone.skill_2 = original.skill_2
	clone.ultimate = original.ultimate
	clone.max_moxie = original.max_moxie
	clone.is_enemy = original.is_enemy
	return clone
## config.json -> normalised config Dictionary. Every number is converted from
## the float JSON always produces, so GameState receives real ints.
static func _build_config(config_json: Dictionary, units: Dictionary) -> Dictionary:
	var config: Dictionary = {}
	if config_json.is_empty():
		_errors.append("[DataLoader] config.json is empty")
		return config
	config["hand_size"] = maxi(1, _get_int(config_json, "hand_size", GameState.MAX_HAND_SIZE))
	config["actions_per_turn"] = maxi(0, _get_int(config_json, "actions_per_turn", GameState.ACTIONS_PER_TURN))
	config["merges_per_turn"] = maxi(0, _get_int(config_json, "merges_per_turn", GameState.MERGES_PER_TURN))

	var decklist: Array = []
	var raw_decklist: Array = _get_array(config_json, "decklist")
	for entry: Variant in raw_decklist:
		if not (entry is Array):
			_errors.append("[DataLoader] config.json decklist entry is not a [value, count] pair")
			continue
		var pair: Array = entry
		if pair.size() < 2:
			_errors.append("[DataLoader] config.json decklist entry needs 2 values")
			continue
		var card_value: int = _to_int(pair[0], 0)
		var card_count: int = _to_int(pair[1], 0)
		if card_count <= 0:
			continue
		decklist.append([card_value, card_count])
	config["decklist"] = decklist
	if decklist.is_empty():
		_errors.append("[DataLoader] config.json decklist is empty")

	var progression: Array[int] = []
	var raw_progression: Array = _get_array(config_json, "dice_progression")
	for entry: Variant in raw_progression:
		progression.append(_to_int(entry, 0))
	config["dice_progression"] = progression
	if progression.is_empty():
		_errors.append("[DataLoader] config.json dice_progression is empty")

	var allies: Array = []
	var raw_allies: Array = _get_array(config_json, "allies")
	for entry: Variant in raw_allies:
		var ally_id: String = str(entry).strip_edges()
		if ally_id.is_empty():
			continue
		if not units.has(ally_id):
			_errors.append("[DataLoader] config.json allies references unknown unit '%s'" % ally_id)
			continue
		allies.append(ally_id)
	config["allies"] = allies
	if allies.is_empty():
		_errors.append("[DataLoader] config.json allies list is empty")

	config["wave_transition_mode"] = _get_string(config_json, "wave_transition_mode", "full_turn")

	# Keep unknown keys so new settings work without touching the loader.
	for key: String in config_json:
		if not config.has(key):
			config[key] = config_json[key]
	return config
#endregion