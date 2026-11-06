# StatusIconCatalog.gd
class_name StatusIconCatalog
extends Resource
## Catalog for character buff/debuff status icons (separate from card IconCatalog).
## Provides lookup and automatic inspection of Unit buff/debuff state.

const PLACEHOLDER_ICON: Texture2D = preload("res://Trash/icon.svg")

@export var default_icon: Texture2D = PLACEHOLDER_ICON
@export var buff_icons: Dictionary = {}   # status_id (String) -> Texture2D
@export var debuff_icons: Dictionary = {} # status_id (String) -> Texture2D


func get_status_icon(status_id: String) -> Texture2D:
	if buff_icons.has(status_id) and buff_icons[status_id] != null:
		return buff_icons[status_id]
	if debuff_icons.has(status_id) and debuff_icons[status_id] != null:
		return debuff_icons[status_id]
	return default_icon if default_icon != null else PLACEHOLDER_ICON


func is_debuff_id(status_id: String) -> bool:
	if debuff_icons.has(status_id):
		return true
	var lower := status_id.to_lower()
	for kw in ["debuff", "weak", "vuln", "poison", "burn", "bleed", "stun", "slow", "curse", "down"]:
		if lower.contains(kw):
			return true
	return false


## Extracts active buffs/debuffs from a Unit instance.
## Returns Array[Dictionary] with keys: { "id": String, "count": int, "is_debuff": bool, "icon": Texture2D }
func extract_unit_statuses(unit: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if unit == null:
		return result

	var seen_ids: Dictionary = {}

	# 1. Check common dictionary / array containers if present on Unit
	for container_prop in ["statuses", "status_effects", "active_effects", "buffs", "debuffs"]:
		if container_prop in unit:
			var val: Variant = unit.get(container_prop)
			var force_debuff: bool = (container_prop == "debuffs")
			if val is Dictionary:
				for k in val.keys():
					var raw_entry: Variant = val[k]
					var count: int = _extract_count(raw_entry)
					if count > 0:
						var id_str := str(k)
						seen_ids[id_str] = true
						result.append({
							"id": id_str,
							"count": count,
							"is_debuff": force_debuff or is_debuff_id(id_str),
							"icon": get_status_icon(id_str)
						})
			elif val is Array:
				for item in val:
					var info := _parse_status_object(item, force_debuff)
					if not info.is_empty():
						seen_ids[info["id"]] = true
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

	for entry in candidate_props:
		var prop_name: String = entry["prop"]
		var status_id: String = entry["id"]
		if seen_ids.has(status_id) or not (prop_name in unit):
			continue
		var raw_val: Variant = unit.get(prop_name)
		var is_active: bool = false
		var display_count: int = 1

		if raw_val is bool:
			is_active = raw_val
			display_count = 1
		elif raw_val is int or raw_val is float:
			is_active = raw_val > 0
			# Next-attack buffs display "1" at the top-left to indicate 1 use remaining
			display_count = 1 if entry["one_shot"] else int(raw_val)

		var charges_prop: String = entry["charges_prop"]
		if charges_prop != "" and (charges_prop in unit):
			var c_val: int = int(unit.get(charges_prop))
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
		for prop_dict in unit.get_property_list():
			if not (prop_dict.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var p_name: String = prop_dict.name
			var lower := p_name.to_lower()
			if lower.contains("buff") or lower.contains("debuff") or lower.contains("bonus"):
				var v: Variant = unit.get(p_name)
				if (v is bool and v) or ((v is int or v is float) and v > 0):
					result.append({
						"id": p_name,
						"count": 1,
						"is_debuff": lower.contains("debuff"),
						"icon": get_status_icon(p_name)
					})

	return result


func _extract_count(raw: Variant) -> int:
	if raw is int or raw is float:
		return int(raw)
	if raw is bool:
		return 1 if raw else 0
	if raw is Dictionary:
		for k in ["stacks", "charges", "turns", "duration", "count", "amount", "value"]:
			if raw.has(k) and int(raw[k]) > 0:
				return int(raw[k])
		return 1
	if raw is Object:
		for k in ["stacks", "charges", "turns", "duration", "count"]:
			if k in raw and int(raw.get(k)) > 0:
				return int(raw.get(k))
		return 1
	return 0


func _parse_status_object(item: Variant, force_debuff: bool) -> Dictionary:
	if item is String:
		return {
			"id": item,
			"count": 1,
			"is_debuff": force_debuff or is_debuff_id(item),
			"icon": get_status_icon(item)
		}
	if item is Dictionary:
		var id_str: String = str(item.get("id", item.get("name", "buff")))
		var cnt: int = maxi(1, _extract_count(item))
		var debuff: bool = force_debuff or bool(item.get("is_debuff", is_debuff_id(id_str)))
		return {
			"id": id_str,
			"count": cnt,
			"is_debuff": debuff,
			"icon": get_status_icon(id_str)
		}
	if item is Object:
		var id_str: String = "buff"
		if "id" in item:
			id_str = str(item.get("id"))
		elif "name" in item:
			id_str = str(item.get("name"))
		var cnt: int = maxi(1, _extract_count(item))
		var debuff: bool = force_debuff or (bool(item.get("is_debuff")) if "is_debuff" in item else is_debuff_id(id_str))
		return {
			"id": id_str,
			"count": cnt,
			"is_debuff": debuff,
			"icon": get_status_icon(id_str)
		}
	return {}
