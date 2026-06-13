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
static func create_striker() -> UnitData:
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
	s2.merged_mode = SkillData.MergedMode.AND
	
	# Base effect 2
	s2.base_effects.append(_b({
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.PICK_N_ENEMY,
		target_count = 2,
		value_offset = -1
	}))
	
	# Merged effect 2
	s2.merged_effects.append(_b({
		action_type = EffectBlock.Action.DEAL_DAMAGE,
		target_mode = EffectBlock.TargetMode.ALL_ENEMIES,
		value_offset = -2
	}))
	ud.skill_2 = s2
	
	return ud
#endregion
