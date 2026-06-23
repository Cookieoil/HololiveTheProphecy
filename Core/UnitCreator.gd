class_name UnitCreator
extends RefCounted
## Use this class to create new unit.
## Details: Create UnitData templates (blueprints) from EffectBlock configs.
## This class should only return UnitData resources.
## Let the GameManager decides which templates to use and when to spawn themn.
##
## @author TheGreatJellyfish
## @version 6/13/2026

## Creates a configured EffectBlock from a property dictionary.
static func _b(props: Dictionary = {}) -> EffectBlock:
	var block := EffectBlock.new()
	for key in props:
		block.set(key, props[key])
	return block
	
#region Test Ally Templates
static func create_Striker() -> UnitData:
	## Unit stats
	var ud:= UnitData.new()
	ud.display_name = "Striker"
	ud.max_hp = 14
	ud.is_enemy = false
	

	## Skill 1
	var s1 := SkillData.new()
	s1.skill_name = "Skill 1 (odd)"
	s1.description = "Deal [Value] damage to 1 enemy."
	s1.merged_description = "And if Merged: Discard a card in hand to draw another card. Gain bonus damage equal to that discarded card’s value."
	s1.merged_mode = SkillData.MergedMode.AND
	
	# Base effect 1
	s1.base_effects.append(_b({ # Deal damage to 1 selected enemy
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		target_count = 1
	}))
	
	# Merged effect 1
	s1.merged_effects.append(_b({ # Discard 1 selected card, store its value
		action_type = EffectBlock.Action.DISCARD_CARD,
		card_select_mode = EffectBlock.CardSelectMode.PICK_N_CARD,
		target_count = 1,
		store_resolved_value = true
	}))
	
	s1.merged_effects.append(_b({ # Draw card
		action_type = EffectBlock.Action.DRAW_CARD,
		card_count = 1,
	}))
	
	s1.merged_effects.append(_b({ # add damage bonus = to the stored value
		action_type = EffectBlock.Action.ADD_BONUS,
		value_source = EffectBlock.ValueSource.STORED_VALUE,
	}))
	ud.skill_1 = s1


	## Skill 2
	var s2 := SkillData.new()
	s2.skill_name = "Skill 2 (even)"
	s2.description = "Deal [Value - 1] damage to 2 enemies."
	s2.merged_description = "Or if Merged: Instead, deal [Value - 2] damage to all 3 enemies."
	s2.merged_mode = SkillData.MergedMode.OR
	
	# Base effect 2
	s2.base_effects.append(_b({
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		target_count = 2,
		value_offset = -1
	}))
	
	# Merged effect 2
	s2.merged_effects.append(_b({
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.ALL_ENEMIES,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		value_offset = -2
	}))
	ud.skill_2 = s2
	
	return ud
	
static func create_Healer() -> UnitData:
	## Unit stats
	var ud:= UnitData.new()
	ud.display_name = "Healer"
	ud.max_hp = 16
	ud.is_enemy = false
	

	## Skill 1
	var s1 := SkillData.new()
	s1.skill_name = "Skill 1 (odd)"
	s1.description = "Deal [Value] damage to 1 enemy."
	s1.merged_description = "And if Merged: Decrease that enemy’s value by ([Value] / 2) for the next enemy turn (max 5).
"
	s1.merged_mode = SkillData.MergedMode.AND
	
	# Base effect 1
	s1.base_effects.append(_b({ # Deal damage to 1 selected enemy
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		target_count = 1
	}))
	
	# Merged effect 1
	s1.merged_effects.append(_b({ # Decrease that enemy’s value by ([Value] / 2) for the next enemy turn (max 5)
		action_type = EffectBlock.Action.APPLY_MODIFIER,
		card_select_mode = EffectBlock.CardSelectMode.PICK_N_CARD,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		value_divisor = 2,
		value_cap = 5,
		target_count = 1,
	}))
	
	ud.skill_1 = s1


	## Skill 2
	var s2 := SkillData.new()
	s2.skill_name = "Skill 2 (even)"
	s2.description = "Shield all allies for [Value]."
	s2.merged_description = "And if Merged: Heal any ally for [Value]."
	s2.merged_mode = SkillData.MergedMode.AND
	
	# Base effect 2
	s2.base_effects.append(_b({
		action_type = EffectBlock.Action.GAIN_SHIELD,
		target_mode = EffectBlock.TargetMode.ALL_ALLIES,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
	}))
	
	# Merged effect 2
	s2.merged_effects.append(_b({
		action_type = EffectBlock.Action.HEAL,
		target_mode = EffectBlock.TargetMode.PICK_N_ALLY,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		target_count = 1
	}))
	ud.skill_2 = s2
	
	return ud
	
static func create_Buff() -> UnitData:
	## Unit stats
	var ud:= UnitData.new()
	ud.display_name = "Buff"
	ud.max_hp = 18
	ud.is_enemy = false
	

	## Skill 1
	var s1 := SkillData.new()
	s1.skill_name = "Skill 1 (odd)"
	s1.description = "Deal [Value] damage to 1 enemy."
	s1.merged_description = "And if Merged: Reduce that target’s shield by [Value × 2] before attacking."
	s1.merged_mode = SkillData.MergedMode.AND
	
	# Base effect 1
	s1.base_effects.append(_b({ # Deal damage to 1 selected enemy
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		target_count = 1
	}))
	
	# Merged effect 1
	s1.merged_effects.append(_b({ # Reduce that target’s shield by [Value × 2] before attacking.
		action_type = EffectBlock.Action.REDUCE_SHIELD,
		card_select_mode = EffectBlock.CardSelectMode.PICK_N_CARD,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		value_multiplier = 2,
		target_count = 1,
	}))
	
	ud.skill_1 = s1


	## Skill 2
	var s2 := SkillData.new()
	s2.skill_name = "Skill 2 (even)"
	s2.description = "Increase any card in hand by ([Value] / 2) value."
	s2.merged_description = "Next ally skill played this turn gains ([Value] / 2) value."
	s2.merged_mode = SkillData.MergedMode.AND
	
	# Base effect 2
	s2.base_effects.append(_b({
		action_type = EffectBlock.Action.SET_NEXT_SKILL_BONUS,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		value_divisor = 2,
	}))
	
	# Merged effect 2
	s2.merged_effects.append(_b({
		action_type = EffectBlock.Action.MODIFY_CARD,
		card_select_mode = EffectBlock.CardSelectMode.PICK_N_CARD,
		card_mod_type = EffectBlock.CardModType.BUFF,
		target_mode = EffectBlock.TargetMode.PICK_N_ALLY,
		target_count = 1,
		card_count = 1
	}))
	ud.skill_2 = s2
	
	return ud
#endregion
