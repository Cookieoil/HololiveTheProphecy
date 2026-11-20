# StatusIconCatalog.gd
class_name StatusIconCatalog
extends Resource
## Catalog for character buff/debuff status icons (separate from CardIconCatalog).
## Provides lookup and automatic inspection of Unit buff/debuff state.
##
## Two dictionaries drive it:
##   buff_icons   -> status_id : Texture2D (rendered in a blue badge frame)
##   debuff_icons -> status_id : Texture2D (rendered in a red badge frame)
## Anything unregistered falls back to `default_icon`, so a brand new status
## still shows a badge instead of an empty slot.
##
## @author TheGreatJellyfish
## @version 11/16/2026

#region Constants
const PLACEHOLDER_ICON: Texture2D = preload("res://Scenes/BattleScene/Assets/icon.svg")
## Sample icons shipped with the project. icon.svg is 128x128 and icon2.png is
## 1000x1000; the UI badge scales both into the same square, so mismatched
## dimensions (or aspect ratios) never break the layout.
const SAMPLE_ICON_SVG: Texture2D = preload("res://Scenes/BattleScene/Assets/icon.svg")
const SAMPLE_ICON_PNG: Texture2D = preload("res://Scenes/BattleScene/Assets/icon2.png")

## Keyword heuristics: a status id containing one of these counts as a debuff
## even before it is registered in `debuff_icons`.
const DEBUFF_KEYWORDS: PackedStringArray = [
	"debuff", "weak", "vuln", "poison", "burn", "bleed", "stun", "slow",
	"curse", "down", "gloom", "decay", "wither",
]
#endregion

#region Exports
@export var default_icon: Texture2D = PLACEHOLDER_ICON
@export var buff_icons: Dictionary[String, Texture2D] = {}   # status_id (String) -> Texture2D
@export var debuff_icons: Dictionary[String, Texture2D] = {} # status_id (String) -> Texture2D
#endregion

#region Lifecycle Methods
## Registers the project's sample statuses, so a bare
## `StatusIconCatalog.new()` already resolves icons. Values authored in a
## .tres are assigned after _init(), so they always win.
func _init() -> void:
	register_default_icons()
#endregion

#region Public Methods
## Adds the sample status mappings without overwriting authored entries.
func register_default_icons() -> void:
	if not buff_icons.has(Unit.STATUS_REGENERATION):
		buff_icons[Unit.STATUS_REGENERATION] = SAMPLE_ICON_PNG
	if not debuff_icons.has(Unit.STATUS_GLOOM):
		debuff_icons[Unit.STATUS_GLOOM] = SAMPLE_ICON_SVG


## Never returns null: unknown ids (and empty slots) fall back to the default.
func get_status_icon(status_id: String) -> Texture2D:
	var id: String = status_id.strip_edges().to_lower()
	var buff_icon: Texture2D = buff_icons.get(id, null)
	if buff_icon != null:
		return buff_icon
	var debuff_icon: Texture2D = debuff_icons.get(id, null)
	if debuff_icon != null:
		return debuff_icon
	return default_icon if default_icon != null else PLACEHOLDER_ICON


## Registered buff ids win over the keyword heuristics.
func is_debuff_id(status_id: String) -> bool:
	var id: String = status_id.strip_edges().to_lower()
	if buff_icons.has(id):
		return false
	if debuff_icons.has(id):
		return true
	for keyword: String in DEBUFF_KEYWORDS:
		if id.contains(keyword):
			return true
	return false


## Extracts active buffs/debuffs from a Unit instance.
## Returns Array[Dictionary] with keys: { "id": String, "count": int, "is_debuff": bool, "icon": Texture2D }
func extract_unit_statuses(unit: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if unit == null:
		return result

	# Dead units never keep badges around.
	if _object_bool(unit, "is_dead", false):
		return result

	var seen_ids: Dictionary[String, bool] = {}

	# 1. Check common dictionary / array containers if present on Unit
	for container_prop: String in ["statuses", "status_effects", "active_effects", "buffs", "debuffs"]:
		if container_prop in unit:
			var val: Variant = unit.get(container_prop)
			var force_debuff: bool = (container_prop == "debuffs")
			if val is Dictionary:
				var dict_val: Dictionary = val
				for k: Variant in dict_val.keys():
					var raw_entry: Variant = dict_val[k]
					var count: int = _extract_count(raw_entry)
					if count > 0:
						var id_str: String = str(k)
						seen_ids[id_str] = true
						result.append({
							"id": id_str,
							"count": count,
							"is_debuff": force_debuff or _entry_is_debuff(raw_entry, id_str),
							"icon": get_status_icon(id_str)
						})
			elif val is Array:
				var arr_val: Array = val
				for item: Variant in arr_val:
					var info: Dictionary = _parse_status_object(item, force_debuff)
					if not info.is_empty():
						var info_id: String = info["id"]
						seen_ids[info_id] = true
						result.append(info)

	# 2. Check flat numeric/boolean buff properties on Unit (e.g. Striker's next-attack buff)
	var candidate_props: Array[Dictionary] = [
		{"prop": "attack_buff", "id": "attack_up", "charges_prop": "attack_buff_charges", "one_shot": true},
		{"prop": "damage_buff", "id": "attack_up", "charges_prop": "damage_buff_charges", "one_shot": true},
		{"prop": "bonus_damage", "id": "attack_up", "charges_prop": "bonus_damage_charges", "one_shot": true},
		{"prop": "next_attack_bonus", "id": "attack_up", "charges_prop": "", "one_shot": true},
		{"prop": "next_attack_buff", "id": "attack_up", "charges_prop": "", "one_shot": true},
		{"prop": "buff_amount", "id": "attack_up", "charges_prop": "buff_stacks", "one_shot": true},
		{"prop": "buff_value", "id": "attack_up", "charges_prop": "buff_turns", "one_shot": true},
		{"prop": "strength", "id": "strength", "charges_prop": "", "one_shot": false},
		{"prop": "empowered", "id": "attack_up", "charges_prop": "", "one_shot": true},
		{"prop": "is_buffed", "id": "attack_up", "charges_prop": "", "one_shot": true},
		{"prop": "vulnerable", "id": "vulnerable", "charges_prop": "", "one_shot": false},
		{"prop": "weak", "id": "weak", "charges_prop": "", "one_shot": false},
	]

	for entry: Dictionary in candidate_props:
		var prop_name: String = entry["prop"]
		var status_id: String = entry["id"]
		if seen_ids.has(status_id) or not (prop_name in unit):
			continue
		var raw_val: Variant = unit.get(prop_name)
		var is_active: bool = false
		var display_count: int = 1
		var one_shot: bool = entry["one_shot"]

		if raw_val is bool:
			var b_val: bool = raw_val
			is_active = b_val
			display_count = 1
		elif raw_val is int:
			var i_val: int = raw_val
			is_active = i_val > 0
			display_count = 1 if one_shot else i_val
		elif raw_val is float:
			var f_val: float = raw_val
			is_active = f_val > 0.0
			# Next-attack buffs display "1" at the top-left to indicate 1 use remaining
			display_count = 1 if one_shot else int(f_val)

		var charges_prop: String = entry["charges_prop"]
		if charges_prop != "" and (charges_prop in unit):
			var raw_charges: Variant = unit.get(charges_prop)
			var c_val: int = 0
			if raw_charges is int:
				var ci: int = raw_charges
				c_val = ci
			elif raw_charges is float:
				var cf: float = raw_charges
				c_val = int(cf)
			if c_val > 0:
				display_count = c_val

		if is_active:
			seen_ids[status_id] = true
			result.append({
				"id": status_id,
				"count": maxi(1, display_count),
				"is_debuff": is_debuff_id(status_id),
				"icon": get_status_icon(status_id)
			})

	# 3. Dynamic fallback: scan script variables for any custom *buff* or *debuff* property > 0
	if result.is_empty():
		for prop_dict: Dictionary in unit.get_property_list():
			var usage_val: int = prop_dict["usage"]
			if not (usage_val & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var p_name: String = prop_dict["name"]
			var lower: String = p_name.to_lower()
			if lower.contains("buff") or lower.contains("debuff") or lower.contains("bonus"):
				var v: Variant = unit.get(p_name)
				var v_active: bool = false
				if v is bool:
					var vb: bool = v
					v_active = vb
				elif v is int:
					var vi: int = v
					v_active = vi > 0
				elif v is float:
					var vf: float = v
					v_active = vf > 0.0
				if v_active:
					result.append({
						"id": p_name,
						"count": 1,
						"is_debuff": lower.contains("debuff"),
						"icon": get_status_icon(p_name)
					})

	return result


#endregion


#region Private Methods
## Honors an explicit "is_debuff" flag on a status entry, otherwise falls back
## to the id heuristics.
func _entry_is_debuff(entry_raw: Variant, status_id: String) -> bool:
	if entry_raw is Dictionary:
		var entry: Dictionary = entry_raw
		var flag_raw: Variant = entry.get("is_debuff", null)
		if flag_raw is bool:
			var flag: bool = flag_raw
			return flag
	return is_debuff_id(status_id)


## Safely reads a boolean property off an Object (dead-unit guard).
func _object_bool(target: Object, prop_name: String, fallback: bool) -> bool:
	if not (prop_name in target):
		return fallback
	var raw: Variant = target.get(prop_name)
	if raw is bool:
		var bool_value: bool = raw
		return bool_value
	return fallback


func _extract_count(raw: Variant) -> int:
	if raw is int:
		var ri: int = raw
		return ri
	if raw is float:
		var rf: float = raw
		return int(rf)
	if raw is bool:
		var rb: bool = raw
		return 1 if rb else 0
	if raw is Dictionary:
		var rd: Dictionary = raw
		for k: String in ["stacks", "charges", "turns", "duration", "count", "amount", "value"]:
			if rd.has(k):
				var kv: int = _extract_scalar_int(rd[k])
				if kv > 0:
					return kv
		return 1
	if raw is Object:
		var ro: Object = raw
		for k: String in ["stacks", "charges", "turns", "duration", "count"]:
			if k in ro:
				var kv: int = _extract_scalar_int(ro.get(k))
				if kv > 0:
					return kv
		return 1
	return 0


func _extract_scalar_int(v: Variant) -> int:
	if v is int:
		var vi: int = v
		return vi
	if v is float:
		var vf: float = v
		return int(vf)
	if v is bool:
		var vb: bool = v
		return 1 if vb else 0
	return 0


func _parse_status_object(item: Variant, force_debuff: bool) -> Dictionary:
	if item is String:
		var s_item: String = item
		return {
			"id": s_item,
			"count": 1,
			"is_debuff": force_debuff or is_debuff_id(s_item),
			"icon": get_status_icon(s_item)
		}
	if item is Dictionary:
		var d_item: Dictionary = item
		var id_str: String = str(d_item.get("id", d_item.get("name", "buff")))
		var cnt: int = maxi(1, _extract_count(d_item))
		var raw_debuff: Variant = d_item.get("is_debuff", is_debuff_id(id_str))
		var debuff_flag: bool = is_debuff_id(id_str)
		if raw_debuff is bool:
			var rb: bool = raw_debuff
			debuff_flag = rb
		var debuff: bool = force_debuff or debuff_flag
		return {
			"id": id_str,
			"count": cnt,
			"is_debuff": debuff,
			"icon": get_status_icon(id_str)
		}
	if item is Object:
		var o_item: Object = item
		var id_str: String = "buff"
		if "id" in o_item:
			id_str = str(o_item.get("id"))
		elif "name" in o_item:
			id_str = str(o_item.get("name"))
		var cnt: int = maxi(1, _extract_count(o_item))
		var obj_debuff: bool = is_debuff_id(id_str)
		if "is_debuff" in o_item:
			var raw_od: Variant = o_item.get("is_debuff")
			if raw_od is bool:
				var od_bool: bool = raw_od
				obj_debuff = od_bool
		var debuff: bool = force_debuff or obj_debuff
		return {
			"id": id_str,
			"count": cnt,
			"is_debuff": debuff,
			"icon": get_status_icon(id_str)
		}
	return {}
#endregion
