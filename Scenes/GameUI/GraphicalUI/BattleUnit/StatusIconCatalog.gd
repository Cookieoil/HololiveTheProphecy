# StatusIconCatalog.gd
class_name StatusIconCatalog
extends Resource
## Catalog for character buff/debuff status icons (separate from card IconCatalog).
## Provides lookup and automatic inspection of Unit buff/debuff state.

const PLACEHOLDER_ICON: Texture2D = preload("res://Scenes/GameUI/GraphicalUI/BattleScene/Assests/icon.svg")

@export var default_icon: Texture2D = PLACEHOLDER_ICON
@export var buff_icons: Dictionary[String, Texture2D] = {}   # status_id (String) -> Texture2D
@export var debuff_icons: Dictionary[String, Texture2D] = {} # status_id (String) -> Texture2D


func get_status_icon(status_id: String) -> Texture2D:
	if buff_icons.has(status_id) and buff_icons[status_id] != null:
		return buff_icons[status_id]
	if debuff_icons.has(status_id) and debuff_icons[status_id] != null:
		return debuff_icons[status_id]
	return default_icon if default_icon != null else PLACEHOLDER_ICON


func is_debuff_id(status_id: String) -> bool:
	if debuff_icons.has(status_id):
		return true
	var lower: String = status_id.to_lower()
	for kw: String in ["debuff", "weak", "vuln", "poison", "burn", "bleed", "stun", "slow", "curse", "down"]:
		if lower.contains(kw):
			return true
	return false


## Extracts active buffs/debuffs from a Unit instance.
## Returns Array[Dictionary] with keys: { "id": String, "count": int, "is_debuff": bool, "icon": Texture2D }
func extract_unit_statuses(unit: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if unit == null:
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
							"is_debuff": force_debuff or is_debuff_id(id_str),
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
