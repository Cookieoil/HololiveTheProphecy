class_name Card
extends RefCounted
## This class contains the data for the card
## Card instance is created/destroyed during merging.
## Rule: Merge consumes two cards and produces one. Total count is shrink by 1.
##
## @author TheGreatJellyfish
## @version 5/11/2026

#id will be resued
static var _next_id: int = 0

var id: int = -1
var base_value: int
var current_value: int
var is_merged: bool = false
var is_double_merged: bool = false

#Temporary values added. These are cleared when discarded.
var value_buff: int = 0
var value_debuff: int = 0


## Reset the card id (e.g card#1 -> card#0)
static func reset_id_counter() -> void:
	_next_id = 0


## constructor. Triggers automatically when call .new()
## or .instantiate()
func _init(value: int = 2) -> void:
	base_value = value
	current_value = value
	id = _next_id
	_next_id += 1


## get the actual effective value (included buff/debuff)
## @return - effective value
func get_effective_value() -> int:
	return maxi(1, current_value + value_buff - value_debuff)


## check if the value is odd
## @return - true if odd, false if even
func is_odd() -> bool:
	return get_effective_value() % 2 == 1


## check if playing this card costs an action
## @return - false if it's double_merged, true otherwise
func costs_action() -> bool:
	return not is_double_merged


## clear the temporary value buff/debuff
func clear_temp_buffs() -> void:
	value_buff = 0
	value_debuff = 0


## debug to_string func. See what's the current data on the card
## @return Card ID, current_value, value_buff, value_debuff, merged or dobule_merged
func _to_string() -> String:
	#specialized string array
	var parts: PackedStringArray = []

	parts.append("Card#%d(%d" % [id, current_value])
	if value_buff != 0:
		parts.append("+%d" % value_buff)
	elif value_debuff != 0:
		parts.append("-%d" % value_debuff)
	parts.append(")")

	if is_double_merged:
		parts.append("[DM]")
	elif is_merged:
		parts.append("[M]")
	return "".join(parts)
	
