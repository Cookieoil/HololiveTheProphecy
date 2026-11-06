class_name Unit
extends RefCounted
## Runtime instance of a unit on the board. Mutable HP/Shield state.
## This is all just data
signal damaged(hp_lost: int, shield_lost: int)

var data: UnitData
var current_hp: int
var max_hp: int
var shield: int = 0
var value_modifier: int = 0 ## Added to dice rolls; negative = debuff
var slot_index: int = -1 ## Board position (0,1,2)
var is_ally: bool = true

func _init(unit_data: UnitData, slot: int = 0) -> void:
	data = unit_data
	max_hp = unit_data.max_hp
	current_hp = max_hp
	is_ally = not unit_data.is_enemy
	slot_index = slot
	
var is_dead: bool: #true if hp <= 0, false otherwise
	get:
		return current_hp <= 0
		
var missing_hp: int: #return the unit missing HP from max HP
	get:
		return max_hp - current_hp
		
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
	# Maxi pick the largest num, Mini pick the smallest num
	var lost := mini(current_hp, maxi(0, amount))
	current_hp -= lost
	return lost
	
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
	
func _to_string() -> String:
	var status := "DEAD" if is_dead else "HP:%d/%d Sh:%d" % [current_hp, max_hp, shield]
	var mod_str := "" if value_modifier == 0 else " mod:%+d" % value_modifier
	return "%s (%s%s)" % [data.display_name, status, mod_str]
