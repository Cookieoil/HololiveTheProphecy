class_name DataBuilder
extends RefCounted

var errors: PackedStringArray = []
var warnings: PackedStringArray = []

#region Enum maps (moved from the old JSON DataLoader)
const ACTION_MAP := {
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
}
const TARGET_MODE_MAP := {
	"none": EffectBlock.TargetMode.NONE,
	"caster": EffectBlock.TargetMode.CASTER,
	"cached": EffectBlock.TargetMode.CACHED,
	"pick_n_enemy": EffectBlock.TargetMode.PICK_N_ENEMY,
	"pick_n_ally": EffectBlock.TargetMode.PICK_N_ALLY,
	"all_enemies": EffectBlock.TargetMode.ALL_ENEMIES,
	"all_allies": EffectBlock.TargetMode.ALL_ALLIES,
}
const VALUE_SOURCE_MAP := {
	"card_value": EffectBlock.ValueSource.CARD_VALUE,
	"card_value_half": EffectBlock.ValueSource.CARD_VALUE_HALF,
	"card_value_double": EffectBlock.ValueSource.CARD_VALUE_DOUBLE,
	"fixed": EffectBlock.ValueSource.FIXED,
	"target_missing_hp": EffectBlock.ValueSource.TARGET_MISSING_HP,
	"highest_card_in_hand": EffectBlock.ValueSource.HIGHEST_CARD_IN_HAND,
	"lowest_card_in_hand": EffectBlock.ValueSource.LOWEST_CARD_IN_HAND,
	"stored_value": EffectBlock.ValueSource.STORED_VALUE,
}
const MERGED_MODE_MAP := {
	"and_merged_first": SkillData.MergedMode.AND_MERGED_FIRST,
	"and_base_first": SkillData.MergedMode.AND_BASE_FIRST,
	"or": SkillData.MergedMode.OR,
}
const CONDITION_MAP := {
	"none": EffectBlock.Condition.NONE,
	"target_no_shield": EffectBlock.Condition.TARGET_NO_SHIELD,
}
const CARD_SELECT_MAP := {
	"pick_n_card": EffectBlock.CardSelectMode.PICK_N_CARD,
	"auto_highest": EffectBlock.CardSelectMode.AUTO_HIGHEST,
	"auto_top_n": EffectBlock.CardSelectMode.AUTO_TOP_N,
}
const CARD_MOD_MAP := {
	"buff": EffectBlock.CardModType.BUFF,
	"debuff": EffectBlock.CardModType.DEBUFF,
}
#endregion

func build(sheets: Dictionary) -> GameDatabase:
	errors.clear()
	warnings.clear()
	var db := GameDatabase.new()
	var enums := _read_enums(sheets.get("enums", []))
	var skills := _read_skills(sheets.get("skills", []), enums)
	var effects := _read_effects(sheets.get("effects", []), enums)

	# Group effects into skills, ordered by 'order' (ties: sheet row order)
	var by_skill := {}
	for e in effects:
		var sid: String = e.row.get("skill_id", "")
		if not skills.has(sid):
			errors.append("effects.%s: unknown skill '%s'" % [e.row.get("effect_id"), sid])
			continue
		if not by_skill.has(sid):
			by_skill[sid] = []
		by_skill[sid].append(e)
	for sid in by_skill:
		var sd: SkillData = skills[sid]
		var arr: Array = by_skill[sid]
		arr.sort_custom(func(a, b):
			if a.row.get("order", 0) == b.row.get("order", 0):
				return a.row.get("_row", 0) < b.row.get("_row", 0)
			return a.row.get("order", 0) < b.row.get("order", 0))
		for e in arr:
			if e.row.get("trigger") == "merged":
				sd.merged_effects.append(e.block)
			else:
				sd.base_effects.append(e.block)

	db.units = _read_units(sheets.get("units", []), enums, skills)
	db.waves = _read_waves(sheets.get("waves", []), enums, db.units)
	db.config = _read_config(sheets.get("config", []))
	return db

# ── Generic table parsing ──────────────────────────────────────────────

func _read_enums(grid: Array) -> Dictionary:
	var out := {}
	var hi := _find_first_dense_row(grid)
	if hi < 0:
		errors.append("[enums] header row not found")
		return out
	var header: Array = grid[hi]
	for col in range(header.size()):
		var column_name := str(header[col]).strip_edges()
		if column_name.is_empty():
			continue
		var values := PackedStringArray()
		# skip header row AND the ALL-CAPS title row below it
		for r in range(hi + 2, grid.size()):
			var row: Array = grid[r]
			if col < row.size():
				var v := str(row[col]).strip_edges()
				if v != "":
					values.append(v)
		out[column_name] = values
	return out


func _find_first_dense_row(grid: Array) -> int:
	for r in range(mini(grid.size(), 10)):
		var nonempty := 0
		for cell in grid[r]:
			if str(cell).strip_edges() != "":
				nonempty += 1
		if nonempty >= 2:
			return r
	return -1


func _parse_spec(text: String) -> Dictionary:
	var eq := text.find("=")
	var head := text if eq < 0 else text.substr(0, eq)
	var parts := head.split(":")
	if parts.size() < 2 or parts[0].is_empty() or parts[1].is_empty():
		return {}
	return {
		"name": parts[0],
		"type": parts[1],
		"target": parts[2] if parts.size() > 2 else "",
		"default": text.substr(eq + 1) if eq >= 0 else "",
		"has_default": eq >= 0,
	}


func _find_header_row(grid: Array) -> int:
	for r in range(mini(grid.size(), 10)):
		var hits := 0
		for cell in grid[r]:
			if not _parse_spec(str(cell)).is_empty():
				hits += 1
		if hits >= 2:
			return r
	return -1


func _parse_table(grid: Array, enums: Dictionary, sheet_name: String) -> Array:
	var hi := _find_header_row(grid)
	if hi < 0:
		errors.append("[%s] header row not found (need >=2 cells like 'name:type')" % sheet_name)
		return []
	var header: Array = grid[hi]
	var specs: Array = []
	var pk_idx := -1
	for col in range(header.size()):
		var raw_header := str(header[col]).strip_edges()
		var spec := _parse_spec(raw_header)
		if spec.is_empty():
			if raw_header == "":
				continue                      # phantom gap column — skip entirely
			warnings.append("[%s] header cell '%s' has no type (add e.g. '%s:string')" % [sheet_name, raw_header, raw_header])
			spec = { "name": raw_header, "type": "string", "target": "", "default": "", "has_default": false }
		spec["_col"] = col                    # <-- pin spec to its source column
		if pk_idx < 0:
			pk_idx = specs.size()
		specs.append(spec)
	if specs.is_empty():
		errors.append("[%s] header row found but no specs parsed" % sheet_name)
		return []

	var out: Array = []
	var seen_ids := {}
	for r in range(hi + 2, grid.size()):      # skip header + title row
		var row: Array = grid[r]
		var entry := {"_row": r + 1}
		var has_value := false
		for spec in specs:
			var raw := ""
			if spec._col < row.size():
				raw = str(row[spec._col]).strip_edges()
			if raw != "":
				has_value = true
			entry[spec.name] = _coerce(raw, spec, enums, sheet_name, r + 1)
		if not has_value:
			continue
		var pk := str(entry.get(specs[pk_idx].name, ""))
		if pk != "":
			if seen_ids.has(pk):
				warnings.append("[%s r%d] duplicate id '%s'" % [sheet_name, r + 1, pk])  # warning, not error
			seen_ids[pk] = true
		out.append(entry)
	return out


func _coerce(raw: String, spec: Dictionary, enums: Dictionary, sheet: String, row_num: int) -> Variant:
	var loc := "[%s r%d %s]" % [sheet, row_num, spec.name]
	var v := raw
	if v == "" and spec.has_default:
		v = spec.default
	match spec.type:
		"int":
			if v.is_valid_int():
				return v.to_int()
			if v.is_valid_float() and v.to_float() == floorf(v.to_float()):
				return int(v.to_float())
			if v != "":
				errors.append("%s expected int, got '%s'" % [loc, v])
			return 0
		"float":
			if v.is_valid_float():
				return v.to_float()
			if v != "":
				errors.append("%s expected float, got '%s'" % [loc, v])
			return 0.0
		"bool":
			var l := v.to_lower()
			if l in ["true", "1"]:
				return true
			if l in ["false", "0", ""]:
				return false
			errors.append("%s expected TRUE/FALSE, got '%s'" % [loc, v])
			return false
		"string", "ref":
			return v
		_:
			if enums.has(spec.type):
				if v != "" and not v in enums[spec.type]:
					errors.append("%s '%s' is not a valid %s (see enums sheet)" % [loc, v, spec.type])
				return v
			errors.append("%s unknown type '%s'" % [loc, spec.type])
			return v

# ── Per-sheet readers ──────────────────────────────────────────────────

func _read_skills(grid: Array, enums: Dictionary) -> Dictionary:
	var out := {}
	for row in _parse_table(grid, enums, "skills"):
		var sd := SkillData.new()
		sd.skill_name = row.get("display_name", "")
		sd.description = row.get("description", "")
		sd.merged_description = row.get("merged_description", "")
		sd.merged_mode = MERGED_MODE_MAP.get(row.get("merged_mode", "and_merged_first"), SkillData.MergedMode.AND_MERGED_FIRST)
		sd.condition_threshold = row.get("condition_threshold", 0)
		out[row.get("skill_id", "")] = sd
	return out


func _read_effects(grid: Array, enums: Dictionary) -> Array:
	var out: Array = []
	for row in _parse_table(grid, enums, "effects"):
		var block := EffectBlock.new()
		block.target_mode = TARGET_MODE_MAP.get(row.get("target_mode", "none"), EffectBlock.TargetMode.NONE)
		block.target_count = row.get("target_count", 1)
		block.condition = CONDITION_MAP.get(row.get("condition", "none"), EffectBlock.Condition.NONE)
		block.negate_condition = row.get("negate_condition", false)
		block.action_type = ACTION_MAP.get(row.get("action", "deal_damage"), EffectBlock.Action.DEAL_DAMAGE)
		block.card_select_mode = CARD_SELECT_MAP.get(row.get("card_select_mode", "pick_n_card"), EffectBlock.CardSelectMode.PICK_N_CARD)
		block.card_mod_type = CARD_MOD_MAP.get(row.get("card_mod_type", "buff"), EffectBlock.CardModType.BUFF)
		block.card_count = row.get("card_count", 1)
		block.value_source = VALUE_SOURCE_MAP.get(row.get("value_source", "card_value"), EffectBlock.ValueSource.CARD_VALUE)
		block.fixed_amount = row.get("fixed_amount", 0)
		block.value_multiplier = row.get("value_multiplier", 1)
		block.value_divisor = row.get("value_divisor", 1)
		block.value_offset = row.get("value_offset", 0)
		block.value_cap = row.get("value_cap", -1)
		block.store_resolved_value = row.get("store_resolved_value", false)
		out.append({"row": row, "block": block})
	return out


func _read_units(grid: Array, enums: Dictionary, skills: Dictionary) -> Dictionary:
	var out := {}
	for row in _parse_table(grid, enums, "units"):
		var ud := UnitData.new()
		ud.display_name = row.get("display_name", "Unnamed")
		ud.max_hp = row.get("max_hp", 10)
		ud.is_enemy = row.get("is_enemy", false)
		for key in ["skill_1", "skill_2"]:
			var sid: String = row.get(key, "")
			if sid == "":
				ud.set(key, null)
			elif skills.has(sid):
				ud.set(key, skills[sid])
			else:
				errors.append("[units r%d %s] unknown skill '%s'" % [row["_row"], key, sid])
		out[row.get("unit_id", "")] = ud
	return out


func _read_waves(grid: Array, enums: Dictionary, units: Dictionary) -> Array:
	var waves: Array = []
	var by_index := {}
	for row in _parse_table(grid, enums, "waves"):
		var idx: int = row.get("wave_index", 0)
		if not by_index.has(idx):
			by_index[idx] = []
		by_index[idx].append(row)
	var indices := by_index.keys()
	indices.sort()
	for idx in indices:
		var wave: Array = []
		for row in by_index[idx]:
			var uid: String = row.get("unit_id", "")
			var base: UnitData = units.get(uid)
			if base == null:
				errors.append("[waves r%d] unknown unit '%s'" % [row["_row"], uid])
				continue
			var active := base
			var hp_override: int = row.get("max_hp_override", 0)
			var name_override: String = row.get("display_name_override", "")
			if hp_override != 0 or name_override != "":
				active = _clone_unit(base)
				if hp_override != 0:
					active.max_hp = hp_override
				if name_override != "":
					active.display_name = name_override
			wave.append(active)
		waves.append(wave)
	return waves


func _read_config(grid: Array) -> Dictionary:
	var out := {}
	var hi := -1
	for r in range(grid.size()):
		var row: Array = grid[r]
		if row.size() >= 2 and str(row[1]).strip_edges().to_lower() == "key":
			hi = r
			break
	if hi < 0:
		return out
	for r in range(hi + 2, grid.size()):   # skip header + "SETTING/VALUE" title row
		var row: Array = grid[r]
		if row.size() < 3:
			continue
		var key := str(row[1]).strip_edges()
		if key.is_empty():
			continue
		out[key] = _parse_config_value(str(row[2]).strip_edges())
	return out


func _parse_config_value(text: String) -> Variant:
	var t := text.strip_edges()
	if t.find(";") >= 0:
		var list: Array = []
		for part in t.split(";"):
			list.append(_parse_config_value(part))
		return list
	if t.find(":") >= 0:
		var pair: Array = []
		for part in t.split(":"):
			pair.append(_scalar(part))
		return pair
	return _scalar(t)

func _scalar(text: String) -> Variant:
	var t := text.strip_edges()
	if t.is_valid_int():
		return t.to_int()
	if t.is_valid_float():
		return t.to_float()
	if t.to_lower() == "true":
		return true
	if t.to_lower() == "false":
		return false
	return t


func _clone_unit(original: UnitData) -> UnitData:
	var clone := UnitData.new()
	clone.display_name = original.display_name
	clone.max_hp = original.max_hp
	clone.is_enemy = original.is_enemy
	clone.skill_1 = original.skill_1
	clone.skill_2 = original.skill_2
	return clone
