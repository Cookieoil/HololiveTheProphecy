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
	
#region Design notes
## Note 1:
## Any merged effect whose description says “that target”, “the target”, 
## or “before attacking” (referring to the same enemy the base effect hit) 
## should use TargetMode.CACHED. If it says “all enemies” or “any ally”, 
## use ALL_ENEMIES / PICK_N_ALLY explicitly.
##
## Note 2: 
## For these modes (NONE, CASTER, CACHED, ALL_ENEMIES, ALL_ALLIES), 
## target_count is completely ignored.
##
## Note 3:
## CACHED can only be used in AND_BASE_FIRST merged effects.
## If the merged effect must run before the base effect 
## (bonus damage, shield strip before attack), it must 
## pick its own target via PICK_N_ENEMY / PICK_N_ALLY / ALL_ENEMIES / etc.
#endregion

#region Test Ally Templates
static func create_Striker(hp: int = 14, name: String = "Striker") -> UnitData:
	## Unit stats
	var ud:= UnitData.new()
	ud.display_name = name
	ud.max_hp = hp
	ud.is_enemy = false
	

	## Skill 1
	var s1 := SkillData.new()
	s1.skill_name = "Skill 1 (odd)"
	s1.description = "Deal [Value] damage to 1 enemy."
	s1.merged_description = "And if Merged: Discard a card in hand to draw another card. Gain bonus damage equal to that discarded card’s value."
	s1.merged_mode = SkillData.MergedMode.AND_MERGED_FIRST
	
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
	
static func create_Healer(hp: int = 16, name: String = "Healer") -> UnitData:
	## Unit stats
	var ud:= UnitData.new()
	ud.display_name = name
	ud.max_hp = hp
	ud.is_enemy = false
	
	## Skill 1
	var s1 := SkillData.new()
	s1.skill_name = "Skill 1 (odd)"
	s1.description = "Deal [Value] damage to 1 enemy."
	s1.merged_description = "And if Merged: Decrease that enemy’s value by ([Value] / 2) for the next enemy turn (max 5)."
	s1.merged_mode = SkillData.MergedMode.AND_BASE_FIRST
	
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
		target_mode = EffectBlock.TargetMode.CACHED,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		value_divisor = 2,
		value_cap = 5,
	}))
	
	ud.skill_1 = s1
	
	
	## Skill 2
	var s2 := SkillData.new()
	s2.skill_name = "Skill 2 (even)"
	s2.description = "Shield all allies for [Value]."
	s2.merged_description = "And if Merged: Heal any ally for [Value]."
	s2.merged_mode = SkillData.MergedMode.AND_BASE_FIRST
	
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

static func create_Buff(hp: int = 18, name: String = "Buff") -> UnitData:
	## Unit stats
	var ud:= UnitData.new()
	ud.display_name = name
	ud.max_hp = hp
	ud.is_enemy = false
	
	
	## Skill 1
	var s1 := SkillData.new()
	s1.skill_name = "Skill 1 (odd)"
	s1.description = "Deal [Value] damage to 1 enemy."
	s1.merged_description = "And if Merged: Reduce that target’s shield by [Value × 2] before attacking."
	s1.merged_mode = SkillData.MergedMode.AND_MERGED_FIRST
	
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
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		value_multiplier = 2,
	}))
	
	ud.skill_1 = s1
	
	
	## Skill 2
	var s2 := SkillData.new()
	s2.skill_name = "Skill 2 (even)"
	s2.description = "Increase any card in hand by ([Value] / 2) value."
	s2.merged_description = "Next ally skill played this turn gains ([Value] / 2) value."
	s2.merged_mode = SkillData.MergedMode.AND_BASE_FIRST
	
	# Base effect 2
	s2.base_effects.append(_b({# Increase any card in hand by ([Value] / 2) value.
		action_type = EffectBlock.Action.MODIFY_CARD,
		card_select_mode = EffectBlock.CardSelectMode.PICK_N_CARD,
		card_mod_type = EffectBlock.CardModType.BUFF,
		target_count = 1,
		card_count = 1
	}))
	
	# Merged effect 2
	s2.merged_effects.append(_b({# Next ally skill played this turn gains ([Value] / 2) value.
		action_type = EffectBlock.Action.SET_NEXT_SKILL_BONUS,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		value_divisor = 2,
	}))
	ud.skill_2 = s2
	
	return ud
	
#endregion

#region Test Enemy Templates
static func create_NormalEnemy(hp: int = 10, name: String = "Normal Enemy") -> UnitData:
	## Unit stats
	var ud:= UnitData.new()
	ud.display_name = name
	ud.max_hp = hp
	ud.is_enemy = true
	
	## Skill 1
	var s1 := SkillData.new()
	s1.skill_name = "Skill 1 (odd)"
	s1.description = "Deal [Value] damage to 1 ally."
	s1.merged_description = "And if [Value] ≥ 6: If the target doesn’t have shield, attack gains bonus damage equal to target’s Missing HP (max 5)."
	s1.merged_mode = SkillData.MergedMode.AND_MERGED_FIRST
	s1.condition_threshold = 6
	
	# Base effect 1
	s1.base_effects.append(_b({ # Deal damage to 1 selected enemy
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		value_source = EffectBlock.ValueSource.CARD_VALUE,
		target_count = 1
	}))
	
	# Merged effect 1
	s1.merged_effects.append(_b({ # If the target doesn’t have shield, attack gains bonus damage equal to target’s Missing HP (max 5).
		action_type = EffectBlock.Action.ADD_BONUS,
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		value_source = EffectBlock.ValueSource.TARGET_MISSING_HP,
		condition = EffectBlock.Condition.TARGET_NO_SHIELD,
		value_cap = 5,
	}))
	
	ud.skill_1 = s1


	## Skill 2
	var s2 := SkillData.new()
	s2.skill_name = "Skill 2 (even)"
	s2.description = "Gain Shield equal to [Value]."
	s2.merged_description = "And if [Value] ≥ 6: Reduce 1 value to two highest-value cards in the player's hand."
	s2.merged_mode = SkillData.MergedMode.AND_BASE_FIRST
	s2.condition_threshold = 6
	
	# Base effect 2
	s2.base_effects.append(_b({ # Gain Shield equal to [Value].
		action_type = EffectBlock.Action.GAIN_SHIELD,
		target_mode = EffectBlock.TargetMode.CASTER,
	}))
	
	# Merged effect 2
	s2.merged_effects.append(_b({ #  Reduce 1 value to two highest-value cards in the player's hand.
		action_type = EffectBlock.Action.MODIFY_CARD,
		card_select_mode = EffectBlock.CardSelectMode.AUTO_TOP_N,
		card_mod_type = EffectBlock.CardModType.DEBUFF,
		value_source = EffectBlock.ValueSource.FIXED,
		fixed_amount = 1,
		card_count = 2
	}))
	ud.skill_2 = s2
	
	return ud
	
static func create_BossEnemy(hp: int = 30, name: String = "Boss Enemy") -> UnitData:
	## Unit stats
	var ud:= UnitData.new()
	ud.display_name = name
	ud.max_hp = hp
	ud.is_enemy = true
	
	## Skill 1
	var s1 := SkillData.new()
	s1.skill_name = "Skill 1 (odd)"
	s1.description = "Boss loses 1 Health. Deal [Value + 1] damage to 1 ally."
	s1.merged_description = "And if [Value] ≥ 6: Attack gains bonus damage equal to the highest value card in the player’s hand."
	s1.merged_mode = SkillData.MergedMode.AND_MERGED_FIRST
	s1.condition_threshold = 6
	
	# Base effect 1
	
	s1.base_effects.append(_b({ # Boss loses 1 Health.
		action_type = EffectBlock.Action.DEAL_TRUE_DAMAGE,
		target_mode = EffectBlock.TargetMode.CASTER,
		value_source = EffectBlock.ValueSource.FIXED,
		fixed_amount = 1
	}))
	
	s1.base_effects.append(_b({ # Deal [Value + 1] damage to 1 ally.
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		value_offset = 1
	}))
	
	# Merged effect 1
	s1.merged_effects.append(_b({ # Attack gains bonus damage equal to the highest value card in the player’s hand.
		action_type = EffectBlock.Action.ADD_BONUS,
		value_source = EffectBlock.ValueSource.HIGHEST_CARD_IN_HAND,
	}))
	
	ud.skill_1 = s1


	## Skill 2
	var s2 := SkillData.new()
	s2.skill_name = "Skill 2 (even)"
	s2.description = "Boss loses 2 Health. Deal [Value] damage to all allies."
	s2.merged_description = "Shield all enemies for [Value]."
	s2.merged_mode = SkillData.MergedMode.AND_BASE_FIRST
	s2.condition_threshold = 6
	
	# Base effect 2
	s2.base_effects.append(_b({ # Boss loses 2 Health.
		action_type = EffectBlock.Action.DEAL_TRUE_DAMAGE,
		target_mode = EffectBlock.TargetMode.CASTER,
		value_source = EffectBlock.ValueSource.FIXED,
		fixed_amount = 2
	}))
	
	s2.base_effects.append(_b({ # Deal [Value] damage to all allies.
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.ALL_ENEMIES,
	}))
	
	s2.merged_effects.append(_b({ # Shield all enemies for [Value].
		action_type = EffectBlock.Action.GAIN_SHIELD,
		target_mode = EffectBlock.TargetMode.ALL_ALLIES,
	}))
	
	ud.skill_2 = s2
	
	return ud
#endregion
