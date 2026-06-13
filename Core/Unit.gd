class_name Unit
extends RefCounted
## Runtime instance of a unit on the board. Mutable HP/Shield state.
## This is all just data

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
		
## Absores via shield, the returns actual hp lose
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var absorbed := mini(shield, amount) # no negative shields
	shield -= absorbed # minus shield by damage
	var remaining := amount - absorbed # leak damage to unit hp
	var hp_lost := mini(current_hp, remaining) # minus leak damage
	current_hp -= hp_lost
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
	shield == 0
	
## Directly reduce shield (e.g. Buff merged skill 1). Can't go below 0.
## Returns amount actually removed.
func reduce_shield(amount: int) -> int:
	# Maxi pick the largest num, Mini pick the smallest num
	var removed := mini(shield, maxi(0, amount))
	shield -= removed
	return removed

## Lose HP directly, bypassing shields. Can't go below 0.
## Returns actual HP lost.
func lose_hp(amount: int) -> int:
	# Maxi pick the largest num, Mini pick the smallest num
	var lost := mini(current_hp, maxi(0, amount))
	current_hp -= lost
	return lost
	
func _to_string() -> String:
	var status := "DEAD" if is_dead else "HP:%d/%d Sh:%d" % [current_hp, max_hp, shield]
	var mod_str := "" if value_modifier == 0 else " mod:%+d" % value_modifier
	return "%s (%s%s)" % [data.display_name, status, mod_str]
