class_name EffectBlock
extends SkillEffect
## The universal data skill effect component
## Use configureble resource for all effect scripts
##
## Execution pipeline:
##  Phase 1: Resolve Targets
##  Phase 2: Check Conditions
##  Phase 3: Resolve Values
##  Phase 4: Execute Action
##
## @author TheGreatJellyfish
## @version 6/3/2026

#region Shared Enums
## How to pick targets for this effect:
enum TargetMode {
	NONE, # No unit targets needed
	CASTER, # Caster only
	CACHED, # reuse ctx.targets (empty -> no target)
	PICK_N_ENEMY, # Pick N enemy (no duplicate)
	PICK_N_ALLY, # Pick N allies (no duplicate)
	ALL_ENEMIES, # Quick pick all enemies
	ALL_ALLIES, # Quick pick all allies
}

## Pre_condition check:
enum Condition {
	NONE, # Always execute
	TARGET_NO_SHIELD, # target has 0 shield
}

## What the effect does:
enum Action { 
	DEAL_DAMAGE, # Deal resolved value as damage (min 1)
	GAIN_SHIELD, # Add shield (capped at 20)
	REDUCE_SHIELD, # Strip shield from targets
	HEAL, # Restore HP (capped at max HP)
	LOSE_HP, # Ignore shield to lose HP directly
	ADD_BONUS, # Add resolved value to ctx.card_value
	APPLY_MODIFIER, # Apply buff/debuff value modifier to the target
	MODIFY_CARD, # Apply buff/debuff value modifier to cards in hand
	DISCARD_CARD, # Discard a card from hand
	DRAW_CARD, # Draw N cards from deck
	SET_NEXT_SKILL_BONUS, # Add to GameState.next_skill_bonus
	RAISE_MAX_HP, # Set target max HP
}

## How to compute the numeric amount for an effect:
enum ValueSource {
	CARD_VALUE, # ctx.card_value (post-bonus)
	CARD_VALUE_HALF, # ctx.card_value / 2 (min 1)
	CARD_VALUE_DOUBLE, # ctx.card_value * 2
	FIXED, # block's fixed_amount export
	TARGET_MISSING_HP, # first cached target's missing HP
	HIGHEST_CARD_IN_HAND, # highest card in player's hand
	LOWEST_CARD_IN_HAND, # lowest card in player's hand
	STORED_VALUE, # ctx.stored_value (set by a prior block)
}

## Player can select or automatically choose
enum CardSelectMode {
	PICK_N_CARD, # Player chooses any card in hand
	AUTO_HIGHEST, # Auto-select highest value card
	AUTO_TOP_N, # uto-select top N cards by value
}

## Plus or minus card value (remains until discard, can merged)
enum CardModType {
	BUFF, # Adds to card.value_buff 
	DEBUFF, # Adds to card.value_debuff
}

#endregion

#region Exports
# export_group is just for organize, doesn't do anything
# no need to close tag. Godot handles this automatically
@export_group("Targeting")
@export var target_mode: TargetMode = TargetMode.NONE
@export var target_count: int = 1

@export_group("Conditions")
@export var condition: Condition = Condition.NONE
@export var negate_condition: bool = false

@export_group("Action")
@export var action_type: Action = Action.DEAL_DAMAGE
@export var card_select_mode: CardSelectMode = CardSelectMode.PICK_N_CARD
@export var card_mod_type: CardModType = CardModType.BUFF
@export var card_count: int = 1 # For draw_card and auto_top_n

@export_group("Value")
@export var value_source: ValueSource = ValueSource.CARD_VALUE
@export var fixed_amount: int = 0
@export var value_multiplier: int = 1
@export var value_divisor: int = 1
@export var value_offset: int = 0
@export var value_cap: int  = -1 # -1 = no cap

@export_group("Output")
@export var store_resolved_value: bool = false

#endregion

#region Phase 1: Resolve Targets
func _resolve_targets(ctx: SkillContext) -> Array[Unit]:
	match target_mode:
		TargetMode.NONE:
			return []
			
		TargetMode.CASTER:
			return [ctx.caster]
			
		TargetMode.CACHED:
			return ctx.targets
			
		TargetMode.PICK_N_ENEMY:
			var is_ally := ctx.caster.is_ally
			var filter := func(u: Unit) -> bool:
				return u.is_ally != is_ally and not u.is_dead
			var results: Array[Unit] = await ctx.pick_n_target.call(
				target_count, filter
			)
			ctx.targets = results
			
		# if ally -> get all enemies
		# if enemy -> get all allies
		TargetMode.ALL_ENEMIES:
			if ctx.caster.is_ally:
				return ctx.game_state.get_living_enemies()
			else:
				return ctx.game_state.get_living_allies()
				
		# if ally -> get all allies
		# if enemy -> get all enemies
		TargetMode.ALL_ALLIES:
			if ctx.caster.is_ally:
				return ctx.game_state.get_living_allies()
			else:
				return ctx.game_state.get_living_enemies()
				
	return []
				
#endregion

#region Phase 2: Check Conditions
func _check_condition(ctx: SkillContext) -> bool:
	var result: bool = true
	
	match condition:
		Condition.NONE:
			result = true
		Condition.TARGET_NO_SHIELD:
			if ctx.targets.is_empty():
				result = false
			else:
				result = ctx.targets[0].shield == 0
				
	if negate_condition:
		result = not result
			
	return result
				
#endregion 

#region Phase 3: Resolve Values
func _resolve_value(ctx: SkillContext) -> int:
	var base: int = 0
	
	match value_source:
		ValueSource.CARD_VALUE:
			base = ctx.card_value
			
		ValueSource.FIXED:
			base = fixed_amount
			
		ValueSource.TARGET_MISSING_HP:
			if not ctx.targets.is_empty():
				base = ctx.targets[0].missing_hp
				
		ValueSource.HIGHEST_CARD_IN_HAND:
			var c:= ctx.game_state.get_highest_card_in_hand()
			if c:
				base = c.get_effective_value()
				
		ValueSource.STORED_VALUE:
			base = ctx.stored_value
			
	## Method: (base x multiplier / divisor) + offset, capped
	var divisor := maxi(1, value_divisor)
	@warning_ignore("integer_division")
	var result := (base * value_multiplier) / divisor
	result = maxi(1, result) # Division can't go below 1 
	result += value_offset
	
	if value_cap >= 0:
		result = mini(result, value_cap)
		
	return maxi(0, result)
#endregion 

#region Phase 4: Execute Action
func execute(ctx: SkillContext) -> void:
	var targets := await _resolve_targets(ctx)
	if not _check_condition(ctx):
		ctx.log("%s - condition not met. Skipped." % [
			ctx.targets[0].data.display_name
		])
		return # Early exit.
	
	var value := _resolve_value(ctx)
	
	match action_type:
		Action.DEAL_DAMAGE:
			_deal_damage(ctx, targets, maxi(1, value))
		
		Action.GAIN_SHIELD:
			_gain_shield(ctx, targets, value)
		
		Action.REDUCE_SHIELD:
			_reduce_shield(ctx, targets, value)
			
		Action.HEAL:
			_heal(ctx, targets, value)
			
		Action.LOSE_HP:
			_lose_hp(ctx, targets, value)
			
		Action.ADD_BONUS:
			_add_bonus(ctx, value)
			
		Action.APPLY_MODIFIER:
			_apply_modifier(ctx, targets, value)
			
		Action.MODIFY_CARD:
			_modify_card(ctx, value)
			
		Action.DISCARD_CARD:
			_discard_card(ctx)
			
		Action.DRAW_CARD:
			_draw_card(ctx)
			
		Action.SET_NEXT_SKILL_BONUS:
			_set_next_skill_bonus(ctx, value)
			
		Action.RAISE_MAX_HP:
			_raise_max_hp(ctx, targets, value)
			
	if store_resolved_value:
		ctx.stored_value = value
		
func _deal_damage(ctx: SkillContext, targets: Array[Unit], damage: int) -> void:
	for target in targets:
		if target.is_dead:
			continue
		var hp_lost := target.take_damage(damage)
		ctx.log("%s deals %d damage to %s (HP lost: %d) → %s" % [
			ctx.caster.data.display_name, damage,
			target.data.display_name, hp_lost, target
		])
		EventBus.damage_dealt.emit(ctx.caster, target, damage, hp_lost)
		if target.is_dead:
			ctx.log("Enemy %s is defeated!" % target.data.display_name)
			EventBus.unit_died.emit(target)
			
			
func _gain_shield(ctx: SkillContext, targets: Array[Unit], amount: int) -> void:
	for target in targets:
		if target.is_dead:
			continue
		var gained := target.gain_shield(amount)
		ctx.log("%s gains %d shield (actual: %d) → Sh:%d" % [
			target.data.display_name, amount, gained, target.shield
		])
		EventBus.shield_gained.emit(target, gained)
		
func _reduce_shield(ctx: SkillContext, targets: Array[Unit], amount: int) -> void:
	for target in targets:
		if target.is_dead:
			continue
		var removed := target.reduce_shield(amount)
		ctx.log("Reduced %s's shield by %d (removed: %d) → Sh:%d" % [
			target.data.display_name, amount, removed, target.shield
		])
		EventBus.shield_reduced.emit(target, removed)


func _heal(ctx: SkillContext, targets: Array[Unit], amount: int) -> void:
	for target in targets:
		if target.is_dead:
			continue
		var restored := target.heal(amount)
		ctx.log("%s heals %s for %d (restored: %d) → %s" % [
			ctx.caster.data.display_name, target.data.display_name,
			amount, restored, target
		])
		EventBus.unit_healed.emit(target, restored)


func _lose_hp(ctx: SkillContext, targets: Array[Unit], amount: int) -> void:
	for target in targets:
		if target.is_dead:
			continue
		var lost := target.lose_hp(amount)
		ctx.log("%s loses %d HP → %s" % [
			target.data.display_name, lost, target
		])
		if target.is_dead:
			ctx.log("%s is defeated by self-damage!" % target.data.display_name)
			EventBus.unit_died.emit(target)


func _add_bonus(ctx: SkillContext, value: int) -> void:
	ctx.card_value += value
	ctx.log("+%d bonus value (total: %d)." % [value, ctx.card_value])


func _apply_modifier(ctx: SkillContext, targets: Array[Unit], value: int) -> void:
	for target in targets:
		if target.is_dead:
			continue
		target.apply_value_modifier(-value)
		ctx.log("Applied -%d value debuff to %s (total mod: %+d)" % [
			value, target.data.display_name, target.value_modifier
		])


func _modify_card(ctx: SkillContext, value: int) -> void:
	match card_select_mode:
		CardSelectMode.PICK_N_CARD:
			if ctx.game_state.hand.is_empty():
				ctx.log("No cards in hand to modify.")
				return
			var filter := func(_c: Card) -> bool: return true
			var chosen: Card = await ctx.pick_n_card.call(card_count, filter)
			if chosen == null:
				ctx.log("No card chosen.")
				return
			_apply_card_mod(ctx, chosen, value)

		CardSelectMode.AUTO_TOP_N:
			var top_cards := ctx.game_state.get_top_n_cards(card_count)
			if top_cards.is_empty():
				ctx.log("No cards in hand to modify.")
				return
			for card in top_cards:
				_apply_card_mod(ctx, card, value)

		CardSelectMode.AUTO_HIGHEST:
			var highest := ctx.game_state.get_highest_card_in_hand()
			if highest == null:
				ctx.log("No cards in hand to modify.")
				return
			_apply_card_mod(ctx, highest, value)


func _apply_card_mod(ctx: SkillContext, card: Card, value: int) -> void:
	var old_val := card.get_effective_value()
	match card_mod_type:
		CardModType.BUFF:
			card.value_buff += value
			ctx.log("Boosted %s by +%d → effective value: %d" % [
				card, value, card.get_effective_value()
			])
		CardModType.DEBUFF:
			card.value_debuff += value
			ctx.log("Reduced %s by %d → effective value: %d" % [
				card, value, card.get_effective_value()
			])
	EventBus.card_value_changed.emit(card, old_val, card.get_effective_value())


func _discard_card(ctx: SkillContext) -> void:
	if ctx.game_state.hand.is_empty():
		ctx.log("No cards in hand to discard.")
		return

	var chosen: Card = null
	match card_select_mode:
		CardSelectMode.PICK_N_CARD:
			var filter := func(_c: Card) -> bool: return true
			chosen = await ctx.pick_n_card.call(card_count, filter)
		CardSelectMode.AUTO_HIGHEST:
			chosen = ctx.game_state.get_highest_card_in_hand()
		CardSelectMode.AUTO_TOP_N:
			# For discard, TOP_N not typically used; fall back to highest.
			chosen = ctx.game_state.get_highest_card_in_hand()

	if chosen == null:
		ctx.log("No card discarded.")
		return

	# Store value BEFORE discarding (Phase 5 uses the resolved value,
	# but for discard the "value" is the card's effective value, not
	# the block's resolved value). We handle this specially here.
	if store_resolved_value:
		ctx.stored_value = chosen.get_effective_value()

	ctx.game_state.discard_card(chosen)
	ctx.log("Discarded %s.%s" % [
		chosen,
		" (stored value: %d)" % ctx.stored_value if store_resolved_value else ""
	])
	EventBus.card_discarded.emit(chosen)


func _draw_card(ctx: SkillContext) -> void:
	var drawn := ctx.game_state.draw_n_cards(card_count)
	for card in drawn:
		ctx.log("Drew %s." % card)
		EventBus.card_drawn.emit(card)
	if drawn.is_empty():
		ctx.log("Deck and discard empty — nothing to draw.")


func _set_next_skill_bonus(ctx: SkillContext, value: int) -> void:
	ctx.game_state.next_skill_bonus += value
	ctx.log("Next skill played this turn gains +%d value." % value)


func _raise_max_hp(ctx: SkillContext, targets: Array[Unit], value: int) -> void:
	for target in targets:
		target.raise_max_hp(value)
		ctx.log("%s max HP raised to %d → %s" % [
			target.data.display_name, value, target
		])
#endregion 

#region Auto-Generated Description
func get_description() -> String:
	var parts: PackedStringArray = []

	# Condition prefix
	if condition != Condition.NONE:
		var cond_name : String = Condition.keys()[condition].replace("_", " ").to_lower()
		if negate_condition:
			parts.append("If NOT %s:" % cond_name)
		else:
			parts.append("If %s:" % cond_name)

	# Action verb
	var action_name : String = Action.keys()[action_type].replace("_", " ").capitalize()
	parts.append(action_name)

	# Value description
	if action_type not in [Action.DISCARD_CARD, Action.DRAW_CARD]:
		var val_desc := _describe_value()
		if val_desc != "":
			parts.append(val_desc)

	# Draw/discard count
	if action_type == Action.DRAW_CARD:
		parts.append("%d card(s)" % card_count)
	elif action_type == Action.DISCARD_CARD:
		parts.append("(%s)" % CardSelectMode.keys()[card_select_mode].to_lower())

	# Target description
	if target_mode != TargetMode.NONE:
		var target_name : String = TargetMode.keys()[target_mode].replace("_", " ").to_lower()
		if target_mode == TargetMode.PICK_N_ENEMY:
			parts.append("to %d %s" % [target_count, target_name])
		else:
			parts.append("to %s" % target_name)

	return " ".join(parts)


func _describe_value() -> String:
	var source_name : String = ValueSource.keys()[value_source].replace("_", " ").capitalize()
	var desc := "[%s" % source_name

	if value_multiplier != 1:
		desc += " × %d" % value_multiplier
	if value_divisor != 1:
		desc += " / %d" % value_divisor
	if value_offset > 0:
		desc += " + %d" % value_offset
	elif value_offset < 0:
		desc += " - %d" % abs(value_offset)
	if value_cap >= 0:
		desc += ", cap %d" % value_cap

	desc += "]"
	return desc
#endregion 
