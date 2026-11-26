class_name Unit
extends RefCounted
## Runtime instance of a unit on the board. Mutable HP/Shield state.
## This is all just data
##
## @author TheGreatJellyfish
## @version 11/16/2026

#region Signals
signal damaged(hp_lost: int, shield_lost: int)
signal moxie_changed(current: int, maximum: int)
## Fired whenever the status dictionary changes (applied / stacked / ticked / cleared).
signal statuses_changed()
#endregion

#region Constants
## Known buff/debuff definitions keyed by the status id used in skills.json
## ("apply_status" effects). "count_mode" decides what the icon counter means:
##   duration -> the number counts down at the end of every round, then expires
##   stacks   -> the number accumulates every time the status is applied
## Unknown ids still work, they just tick without an extra effect.
const COUNT_MODE_DURATION: String = "duration"
const COUNT_MODE_STACKS: String = "stacks"
const DEFAULT_COUNT_MODE: String = COUNT_MODE_STACKS
const STATUS_REGENERATION: String = "regeneration"
const STATUS_GLOOM: String = "gloom"
const REGENERATION_HEAL_PER_TICK: int = 3
const GLOOM_DAMAGE_PER_STACK: int = 1
const STATUS_DEFS: Dictionary = {
	STATUS_REGENERATION: {
		"is_debuff": false,
		"count_mode": COUNT_MODE_DURATION,
		"heal_per_tick": REGENERATION_HEAL_PER_TICK,
	},
	STATUS_GLOOM: {
		"is_debuff": true,
		"count_mode": COUNT_MODE_STACKS,
		"damage_per_stack": GLOOM_DAMAGE_PER_STACK,
	},
}
#endregion

#region Public Variables
var data: UnitData
var current_hp: int
var max_hp: int
var shield: int = 0
var moxie: int = 0
var max_moxie: int = 20
var ult_used_this_turn: bool = false
var value_modifier: int = 0 ## Added to dice rolls; negative = debuff
var slot_index: int = -1 ## Board position (0,1,2)
var is_ally: bool = true

## Active statuses: status_id (String) -> {
##   "count": int, "count_mode": String, "is_debuff": bool
## }
var statuses: Dictionary = {}

var can_cast_ultimate: bool:
	get:
		return not is_dead \
			and data != null \
			and data.ultimate != null \
			and moxie >= max_moxie \
			and not ult_used_this_turn
var is_dead: bool: #true if hp <= 0, false otherwise
	get:
		return current_hp <= 0
		
var missing_hp: int: #return the unit missing HP from max HP
	get:
		return max_hp - current_hp
		
		
		
#endregion


#region Lifecycle Methods
func _init(unit_data: UnitData, slot: int = 0) -> void:
	data = unit_data
	max_hp = unit_data.max_hp
	current_hp = max_hp
	max_moxie = unit_data.max_moxie if unit_data.max_moxie > 0 else 20
	moxie = 0
	is_ally = not unit_data.is_enemy
	slot_index = slot
	
#endregion

#region Public Methods
func gain_moxie(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var old := moxie
	moxie = mini(max_moxie, moxie + amount)
	var gained := moxie - old
	if gained > 0:
		moxie_changed.emit(moxie, max_moxie)
	return gained

func consume_moxie() -> void:
	moxie = 0
	ult_used_this_turn = true
	moxie_changed.emit(moxie, max_moxie)


## Empties the Moxie gauge and releases the once-per-turn Ultimate lock, without
## pretending an Ultimate was cast. Used when a unit dies and when the battle
## ends, so no residual Moxie crystals (or "ULT READY" glow) outlive the unit or
## the fight. Emits `moxie_changed` only when something actually changed.
func clear_moxie() -> void:
	var changed: bool = moxie != 0 or ult_used_this_turn
	moxie = 0
	ult_used_this_turn = false
	if changed:
		moxie_changed.emit(moxie, max_moxie)


## Tester/debug hook: forces the Moxie gauge to `value` and clears the once-per-turn
## Ultimate lock, so a tester can fire an Ultimate on demand instead of waiting for
## it to charge (or to re-test the same one).
## @param value the Moxie to show, clamped to 0..max_moxie
func set_moxie(value: int) -> void:
	moxie = clampi(value, 0, max_moxie)
	ult_used_this_turn = false
	moxie_changed.emit(moxie, max_moxie)
	
## Absorbs via shield, then applies the remainder to HP. Emits `damaged`
## after both values have been updated so UnitUI can react (flinch + bar drop).
## Also fires when the shield fully absorbed the hit.
## @param amount        the incoming damage
## @param ignore_shield true to bypass the shield (e.g. true damage)
## @return the HP actually lost
func take_damage(amount: int, ignore_shield: bool = false) -> int:
	if is_dead or amount <= 0:
		return 0

	var shield_lost := 0
	if not ignore_shield:
		shield_lost = mini(shield, amount)
		shield -= shield_lost

	var hp_lost := mini(current_hp, amount - shield_lost)
	current_hp -= hp_lost

	if hp_lost > 0 or shield_lost > 0:
		damaged.emit(hp_lost, shield_lost)

	# A dead unit never keeps buffs/debuffs or a Moxie gauge around, so its orb
	# drains to empty instead of freezing on the crystals it died holding.
	if is_dead:
		clear_statuses()
		clear_moxie()

	return hp_lost
	
## Capped at max_hp. Returns actual HP restored.
func heal(amount: int) -> int:
	var restored := mini(max_hp - current_hp, maxi(0, amount))
	current_hp += restored
	return restored
	
func gain_shield(amount: int) -> int:
	if amount <= 0 or is_dead:
		return 0
		
	var old_shield := shield
	shield += amount
	var actual_gained := shield - old_shield
	return actual_gained
	
func reset_shield() -> void:
	shield = 0
	
## Directly reduce shield (e.g. Buff merged skill 1). Can't go below 0.
## @param amount	 the damage amount unit received
## @return removed	 return the amount of deduced shield from that damage
func reduce_shield(amount: int) -> int:
	# Maxi pick the largest num, Mini pick the smallest num
	var removed := mini(shield, maxi(0, amount))
	shield -= removed
	return removed

## Deal damage to HP directly, bypassing shields. Can't go below 0.
## @param amount	 the int true damage amount unit received
## @return lost		 return the int amount of hp lost from that damage.
func deal_true_damage(amount: int) -> int:
	return take_damage(amount, true)
	
## Modify the value based on the amount
## @param amount	the int amount to modify the value
func apply_value_modifier(amount: int) -> void:
	value_modifier += amount

## Reset the value modifer to 0
func clear_value_modifier() -> void:
	value_modifier = 0

## raise the unit max HP based on the new max HP
## @param new_max	the int new max HP
func raise_max_hp(new_max: int) -> void:
	max_hp = maxi(1, new_max)
	current_hp = mini(current_hp, max_hp)
	
## Applies (or stacks) a status. Duration statuses add to their remaining
## rounds, stack statuses add to their stack count.
## @param status_id  the status id (case/spacing insensitive)
## @param amount     stacks or rounds to add (min 1)
## @return the resulting count (0 when nothing was applied)
func apply_status(status_id: String, amount: int = 1) -> int:
	var id: String = _normalize_status_id(status_id)
	if id.is_empty() or amount <= 0 or is_dead:
		return 0

	var def: Dictionary = _status_def(id)
	var new_count: int = get_status_count(id) + amount

	statuses[id] = {
		"count": new_count,
		"count_mode": _def_string(def, "count_mode", DEFAULT_COUNT_MODE),
		"is_debuff": _def_bool(def, "is_debuff", false),
	}
	statuses_changed.emit()
	return new_count


## @return how many stacks/rounds of status_id the unit currently has (0 = none)
func get_status_count(status_id: String) -> int:
	var id: String = _normalize_status_id(status_id)
	if not statuses.has(id):
		return 0
	return _entry_count(statuses[id])


func has_status(status_id: String) -> bool:
	return get_status_count(status_id) > 0


## Removes every status (used when a unit dies so no badge lingers).
func clear_statuses() -> void:
	if statuses.is_empty():
		return
	statuses.clear()
	statuses_changed.emit()


## Runs every active status once, at the end of a round.
## "duration" statuses fire their effect then lose 1 round (expiring at 0),
## "stacks" statuses fire their effect and keep their stacks.
## @return structured events for the log/UI layer:
##         [{ "status_id": String, "kind": String, "amount": int, "count": int }]
func tick_round_end_statuses() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_dead or statuses.is_empty():
		return events

	for raw_id: Variant in statuses.keys():
		var status_id: String = str(raw_id)
		var entry_raw: Variant = statuses.get(status_id, {})
		if not (entry_raw is Dictionary):
			continue
		var entry: Dictionary = entry_raw
		var count: int = _entry_count(entry)
		if count <= 0:
			continue

		var def: Dictionary = _status_def(status_id)
		var effect_amount: int = 0
		var kind: String = ""

		if status_id == STATUS_REGENERATION:
			kind = "heal"
			effect_amount = _def_int(def, "heal_per_tick", REGENERATION_HEAL_PER_TICK)
		elif status_id == STATUS_GLOOM:
			kind = "damage"
			effect_amount = count * _def_int(def, "damage_per_stack", GLOOM_DAMAGE_PER_STACK)

		if kind == "heal" and effect_amount > 0:
			var restored: int = heal(effect_amount)
			events.append({
				"status_id": status_id, "kind": "heal",
				"amount": restored, "count": count,
			})
		elif kind == "damage" and effect_amount > 0:
			var lost: int = deal_true_damage(effect_amount)
			events.append({
				"status_id": status_id, "kind": "damage",
				"amount": lost, "count": count,
			})
			# A dead unit keeps no badges.
			if is_dead:
				clear_statuses()
				return events

		if _def_string(def, "count_mode", DEFAULT_COUNT_MODE) == COUNT_MODE_DURATION:
			var remaining: int = count - 1
			if remaining <= 0:
				statuses.erase(status_id)
				events.append({
					"status_id": status_id, "kind": "expired",
					"amount": 0, "count": 0,
				})
			else:
				entry["count"] = remaining
				statuses[status_id] = entry

	statuses_changed.emit()
	return events
#endregion


#region Private Methods
func _to_string() -> String:
	var status := "DEAD" if is_dead else "HP:%d/%d Sh:%d" % [current_hp, max_hp, shield]
	var mod_str := "" if value_modifier == 0 else " mod:%+d" % value_modifier
	var status_str := "" if statuses.is_empty() else " " + str(statuses)
	return "%s (%s%s%s)" % [data.display_name, status, mod_str, status_str]


## "Regeneration " -> "regeneration" so ids stay forgiving for hand/AI edits.
func _normalize_status_id(status_id: String) -> String:
	return status_id.strip_edges().to_lower()


## Definition dictionary for a status id, or {} when it is not registered yet.
func _status_def(status_id: String) -> Dictionary:
	if not STATUS_DEFS.has(status_id):
		return {}
	var def_raw: Variant = STATUS_DEFS[status_id]
	if def_raw is Dictionary:
		var def: Dictionary = def_raw
		return def
	return {}


func _def_int(def: Dictionary, key: String, fallback: int) -> int:
	if not def.has(key):
		return fallback
	return _coerce_int(def[key], fallback)


func _def_bool(def: Dictionary, key: String, fallback: bool) -> bool:
	if not def.has(key):
		return fallback
	var raw: Variant = def[key]
	if raw is bool:
		var bool_value: bool = raw
		return bool_value
	return fallback


func _def_string(def: Dictionary, key: String, fallback: String) -> String:
	if not def.has(key):
		return fallback
	return str(def[key])


## Reads the counter out of one status entry.
func _entry_count(entry_raw: Variant) -> int:
	if not (entry_raw is Dictionary):
		return _coerce_int(entry_raw, 0)
	var entry: Dictionary = entry_raw
	return _coerce_int(entry.get("count", 0), 0)


## Coerces a Variant into an int (JSON numbers arrive as float).
func _coerce_int(value: Variant, fallback: int) -> int:
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
#endregion
