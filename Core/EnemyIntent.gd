class_name EnemyIntent
extends RefCounted
## Pre-rolled intent for one enemy this turn.
## Created at step 1 of the turn loop, resolved at step 7.
##
## @author TheGreatJellyfish
## @version 5/18/2026

var enemy: Unit
var raw_dice_value: int          ## The unmodified roll
var effective_value: int         ## After value_modifier applied
var skill: SkillData             ## skill_1 or skill_2 based on odd/even
var condition_met: bool          ## effective_value >= skill.condition_threshold

func _init(p_enemy: Unit, p_dice: int) -> void:
	enemy = p_enemy
	raw_dice_value = p_dice
	effective_value = maxi(1, p_dice + p_enemy.value_modifier)

	# Odd → skill 1, Even → skill 2
	skill = p_enemy.data.skill_1 if effective_value % 2 == 1 else p_enemy.data.skill_2
	condition_met = skill.condition_threshold > 0 and effective_value >= skill.condition_threshold

func _to_string() -> String:
	var skill_label := "Skill1(odd)" if effective_value % 2 == 1 else "Skill2(even)"
	var cond := " [COND MET]" if condition_met else ""
	return "%s rolls %d (eff:%d) → %s%s" % [
		enemy.data.display_name, raw_dice_value, effective_value, skill_label, cond
	]
