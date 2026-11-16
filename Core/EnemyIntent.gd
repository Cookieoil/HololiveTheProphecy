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
	recalculate()

func recalculate() -> void:
	effective_value = maxi(1, raw_dice_value + enemy.value_modifier)
	skill = enemy.data.skill_1 if effective_value % 2 == 1 else enemy.data.skill_2
	condition_met = skill != null and skill.condition_threshold > 0 and effective_value >= skill.condition_threshold

func will_trigger_ultimate() -> bool:
	return enemy != null \
		and not enemy.is_dead \
		and enemy.data.ultimate != null \
		and (enemy.moxie + effective_value) >= enemy.max_moxie

func _to_string() -> String:
	var skill_label := "Skill1(odd)" if effective_value % 2 == 1 else "Skill2(even)"
	var cond := " [COND MET]" if condition_met else ""
	var ult := " [ULT READY]" if will_trigger_ultimate() else ""
	return "%s rolls %d (eff:%d) → %s%s%s" % [
		enemy.data.display_name, raw_dice_value, effective_value, skill_label, cond, ult
	]
