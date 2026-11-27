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
	CACHED_OR_PICK_ENEMY, # Prevent double target prompts
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
	DEAL_TRUE_DAMAGE, # Ignore shield to deal damage directly to HP
	ADD_BONUS, # Add resolved value to ctx.card_value
	APPLY_MODIFIER, # Apply buff/debuff value modifier to the target
	MODIFY_CARD, # Apply buff/debuff value modifier to cards in hand
	DISCARD_CARD, # Discard a card from hand
	DRAW_CARD, # Draw N cards from deck
	SET_NEXT_SKILL_BONUS, # Add to GameState.next_skill_bonus
	RAISE_MAX_HP, # Set target max HP
	APPLY_STATUS, # Apply `status_id` stacks/rounds to the targets
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
	CASTER_SHIELD, # caster's current shield (for shield-slam effects)
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

@export_group("Status")
@export var status_id: String = "" # For apply_status: the buff/debuff id (e.g. "gloom")

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

#region Helpers
## A unit's name in its side's colour. It stays here because it is the adapter that knows
## a `Unit` (its display name and side); the colouring rule itself lives in ColorUtils.
func _color_unit(unit: Unit) -> String:
	return ColorUtils.unit_name(unit.data.display_name, unit.is_ally)
#endregion
#region Phase 1: Resolve Targets
func _resolve_targets(ctx: SkillContext) -> Array[Unit]:
	match target_mode:
		TargetMode.NONE:
			# A block that needs no unit targets must NOT erase targets cached by an
			# earlier block in the same skill. A merged skill like healer_1 / buff_1
			# picks an enemy first, then runs a utility block (add_bonus, target_mode
			# none), then deals cached damage; clearing ctx.targets here would force a
			# second target prompt. Leave the cache untouched.
			return []
			
		TargetMode.CASTER:
			ctx.targets = [ctx.caster]
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
			return results
			
		TargetMode.PICK_N_ALLY:
			var is_ally := ctx.caster.is_ally
			var filter := func(u: Unit) -> bool:
				return u.is_ally == is_ally and not u.is_dead
			var results: Array[Unit] = await ctx.pick_n_target.call(
				target_count, filter
			)
			ctx.targets = results
			return results
			
		# if ally -> get all enemies
		# if enemy -> get all allies
		TargetMode.ALL_ENEMIES:
			var arr := ctx.game_state.get_living_enemies() if ctx.caster.is_ally \
						else ctx.game_state.get_living_allies()
			ctx.targets = arr
			return arr
				
		# if ally -> get all allies
		# if enemy -> get all enemies
		TargetMode.ALL_ALLIES:
			var arr := ctx.game_state.get_living_allies() if ctx.caster.is_ally \
						else ctx.game_state.get_living_enemies()
			ctx.targets = arr
			return arr
				
		TargetMode.CACHED_OR_PICK_ENEMY:
			if not ctx.targets.is_empty():
				return ctx.targets
			var is_ally := ctx.caster.is_ally
			var filter := func(u: Unit) -> bool:
				return u.is_ally != is_ally and not u.is_dead
			ctx.targets = await ctx.pick_n_target.call(target_count, filter)
			return ctx.targets
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
func compute_value_from_inputs(
	card_val: int,
	stored_val: int,
	state: GameState,
	sample_target: Unit = null,
	caster: Unit = null
) -> int:
	var base: int = 0
	match value_source:
		ValueSource.CARD_VALUE:
			base = card_val
		ValueSource.CARD_VALUE_HALF:
			@warning_ignore("integer_division")
			base = maxi(1, card_val / 2) if card_val > 0 else 0
		ValueSource.CARD_VALUE_DOUBLE:
			base = card_val * 2
		ValueSource.FIXED:
			base = fixed_amount
		ValueSource.TARGET_MISSING_HP:
			if sample_target != null:
				base = sample_target.missing_hp
		ValueSource.HIGHEST_CARD_IN_HAND:
			if state != null:
				var c := state.get_highest_card_in_hand()
				if c:
					base = c.get_effective_value()
		ValueSource.LOWEST_CARD_IN_HAND:
			if state != null:
				var low := state.get_lowest_card_in_hand()
				if low:
					base = low.get_effective_value()
		ValueSource.STORED_VALUE:
			base = stored_val
		ValueSource.CASTER_SHIELD:
			if caster != null:
				base = caster.shield
	
	## Method: (base x multiplier / divisor) + offset, capped
	var divisor := maxi(1, value_divisor)
	@warning_ignore("integer_division")
	var result := (base * value_multiplier) / divisor
	if base > 0:
		result = maxi(1, result)
	result += value_offset
	if value_cap >= 0:
		result = mini(result, value_cap)
	return maxi(0, result)

func _resolve_value(ctx: SkillContext) -> int:
	var first_target: Unit = ctx.targets[0] if not ctx.targets.is_empty() else null
	return compute_value_from_inputs(ctx.card_value, ctx.stored_value, ctx.game_state, first_target, ctx.caster)
#endregion

#region Phase 4: Execute Action
func execute(ctx: SkillContext) -> void:
	# A prior block in this same skill may have killed the caster (self-damage), or
	# the caster died before the skill resolved. Never keep firing effects from
	# beyond the grave.
	if ctx.caster != null and ctx.caster.is_dead:
		return
	var targets: Array[Unit] = await _resolve_targets(ctx)
	if not _check_condition(ctx):
		var caster_name: String = _color_unit(ctx.caster)
		ctx.log(ColorUtils.colorize("%s - condition not met. Skipped." \
		% caster_name, ColorUtils.COLOR_DEAD))
		return # early exit
	
	var value: int = _resolve_value(ctx)
	
	match action_type:
		Action.DEAL_DAMAGE:
			_deal_damage(ctx, targets, maxi(1, value))
		
		Action.GAIN_SHIELD:
			_gain_shield(ctx, targets, value)
		
		Action.REDUCE_SHIELD:
			_reduce_shield(ctx, targets, value)
			
		Action.HEAL:
			_heal(ctx, targets, value)
			
		Action.DEAL_TRUE_DAMAGE:
			_deal_true_damage(ctx, targets, value)
			
		Action.ADD_BONUS:
			_add_bonus(ctx, value)
			
		Action.APPLY_MODIFIER:
			_apply_modifier(ctx, targets, value)
			
		Action.MODIFY_CARD:
			await _modify_card(ctx, value)
			
		Action.DISCARD_CARD:
			await _discard_card(ctx)
			
		Action.DRAW_CARD:
			_draw_card(ctx)
			
		Action.SET_NEXT_SKILL_BONUS:
			_set_next_skill_bonus(ctx, value)
			
		Action.RAISE_MAX_HP:
			_raise_max_hp(ctx, targets, value)
			
		Action.APPLY_STATUS:
			_apply_status(ctx, targets, value)
			
	if store_resolved_value:
		ctx.stored_value = value
		
func _deal_damage(ctx: SkillContext, targets: Array[Unit], damage: int) -> void:
	for target: Unit in targets:
		if target.is_dead:
			continue
		var hp_lost: int = target.take_damage(damage)
		var caster_name: String = _color_unit(ctx.caster)
		var target_name: String = _color_unit(target)
		var dmg_str: String = ColorUtils.stat_value(damage)
		var lost_str: String = ColorUtils.stat_value(hp_lost)
		var hp_str: String = ColorUtils.stat_value(target.current_hp)
		
		# Base message: "Goblin deals 5 damage to Warrior (HP lost: 4) → HP: 6"
		var log_msg: String = "%s deals %s damage to %s (HP lost: %s) → HP: %s" % [
			caster_name, dmg_str, target_name, lost_str, hp_str
		]
		# If the actual damage dealt (hp_lost) was different from the attempted amount, note it
		if hp_lost != damage:
			var attempted_str: String = ColorUtils.stat_value(damage)
			log_msg += " [Attempted: %s]" % attempted_str
		
		ctx.log(log_msg)
		EventBus.damage_dealt.emit(ctx.caster, target, damage, hp_lost)
		if target.is_dead:
			ctx.log(ColorUtils.colorize("%s is defeated!" % target.data.display_name, ColorUtils.COLOR_DEAD))
			EventBus.unit_died.emit(target)

func _gain_shield(ctx: SkillContext, targets: Array[Unit], amount: int) -> void:
	for target: Unit in targets:
		if target.is_dead:
			continue
		var gained: int = target.gain_shield(amount)
		var target_name: String = _color_unit(target)
		var gained_str: String = ColorUtils.stat_value(gained, "shield")
		var shield_str: String = ColorUtils.colorize(str(target.shield) + " V", ColorUtils.COLOR_SHIELD)
		
		# Base message: "Enemy A gains 5 Shield (Total: 8 V)"
		var log_msg: String = "%s gains %s Shield (Total: %s)" % [target_name, gained_str, shield_str]
		
		# Only append the attempted amount if it was modified/capped
		if gained != amount:
			var amt_str: String = ColorUtils.stat_value(amount, "shield")
			log_msg += " [Attempted: %s]" % amt_str
			
		ctx.log(log_msg)
		EventBus.shield_gained.emit(target, gained)
		

func _reduce_shield(ctx: SkillContext, targets: Array[Unit], amount: int) -> void:
	for target: Unit in targets:
		if target.is_dead:
			continue
		var removed: int = target.reduce_shield(amount)
		var target_name: String = _color_unit(target)
		var rem_str: String = ColorUtils.stat_value(removed, "shield")
		var shield_str: String = ColorUtils.colorize(str(target.shield) + " V", ColorUtils.COLOR_SHIELD)
		
		# Base message: "Reduced [Target]'s shield by 3 (Total: 5 V)"
		var log_msg: String = "Reduced %s's shield by %s (Total: %s)" % [
			target_name, rem_str, shield_str
		]
		if removed != amount:
			var amt_str: String = ColorUtils.stat_value(amount, "shield")
			log_msg += " [Attempted: %s]" % amt_str
		
		ctx.log(log_msg)
		EventBus.shield_reduced.emit(target, removed)


func _heal(ctx: SkillContext, targets: Array[Unit], amount: int) -> void:
	for target: Unit in targets:
		if target.is_dead:
			continue
		var restored: int = target.heal(amount)
		var caster_name: String = _color_unit(ctx.caster)
		var target_name: String = _color_unit(target)
		var rest_str: String = ColorUtils.stat_value(restored)
		var hp_str: String = ColorUtils.colorize(str(target.current_hp) + " HP", ColorUtils.COLOR_HP)
		
		# Base message: "Priest heals Warrior for 8 (Total: 12 HP)"
		var log_msg: String = "%s heals %s for %s (Total: %s)" % [
			caster_name, target_name, rest_str, hp_str
		]
		if restored != amount:
			var amt_str: String = ColorUtils.stat_value(amount)
			log_msg += " [Attempted: %s]" % amt_str
		
		ctx.log(log_msg)
		EventBus.unit_healed.emit(target, restored)


func _deal_true_damage(ctx: SkillContext, targets: Array[Unit], amount: int) -> void:
	for target: Unit in targets:
		if target.is_dead:
			continue
		var true_damage: int = target.deal_true_damage(amount)
		var target_name: String = _color_unit(target)
		var dmg_str: String = ColorUtils.stat_value(true_damage)
		var hp_str: String = ColorUtils.colorize(str(target.current_hp) + " HP", ColorUtils.COLOR_HP)
		
		# Base message: "Warrior loses 8 health (Total: 8 HP)"
		var log_msg: String = "%s loses %s health (Total: %s)" % [
			target_name, dmg_str, hp_str
		]
		if true_damage != amount:
			var amt_str: String = ColorUtils.stat_value(amount)
			log_msg += " [Attempted: %s]" % amt_str
		
		ctx.log(log_msg)
		if target.is_dead:
			var suffix: String = " by self-damage!" if target == ctx.caster else "!"
			ctx.log(ColorUtils.colorize("%s is defeated%s" % [target.data.display_name, suffix], ColorUtils.COLOR_DEAD))
			EventBus.unit_died.emit(target)


func _add_bonus(ctx: SkillContext, value: int) -> void:
	if value == 0:
		return
	ctx.card_value += value
	var val_colored: String = ColorUtils.colorize(str(value), ColorUtils.COLOR_CARD)
	var total_colored: String = ColorUtils.colorize(str(ctx.card_value) + " V", ColorUtils.COLOR_CARD)
	ctx.log("+%s bonus value (total: %s)." % [val_colored, total_colored])


func _apply_modifier(ctx: SkillContext, targets: Array[Unit], value: int) -> void:
	if value == 0: return
	for target: Unit in targets:
		if target.is_dead:
			continue
		target.apply_value_modifier(-value)
		var target_name: String = _color_unit(target)
		var mod_str: String = ColorUtils.colorize(str(target.value_modifier) + " V", ColorUtils.COLOR_DEAD)
		ctx.log("Applied -%d value debuff to %s (total mod: %s)" % [
			value, target_name, mod_str
		])


## Presentation cue: shows the player which cards the game picked for them
## (auto_top_n / auto_highest) since no prompt was shown.
func _flash_auto_selected(ctx: SkillContext, cards: Array[Card]) -> void:
	if cards.is_empty() or not ctx.flash_cards.is_valid():
		return
	await ctx.flash_cards.call(cards)


func _modify_card(ctx: SkillContext, value: int) -> void:
	match card_select_mode:
		CardSelectMode.PICK_N_CARD:
			if ctx.game_state.hand.is_empty():
				ctx.log("No cards in hand to modify.")
				return
			var filter: Callable = func(_c: Card) -> bool: return true
			var chosen: Array[Card] = await ctx.pick_n_card.call(card_count, filter)
			if chosen.is_empty():
				ctx.log("No card chosen.")
				return
			for card: Card in chosen:
				_apply_card_mod(ctx, card, value)

		CardSelectMode.AUTO_TOP_N:
			var top_cards: Array[Card] = ctx.game_state.get_top_n_cards(card_count)
			if top_cards.is_empty():
				ctx.log("No cards in hand to modify.")
				return
			await _flash_auto_selected(ctx, top_cards)
			for card: Card in top_cards:
				_apply_card_mod(ctx, card, value)

		CardSelectMode.AUTO_HIGHEST:
			var highest: Card = ctx.game_state.get_highest_card_in_hand()
			if highest == null:
				ctx.log("No cards in hand to modify.")
				return
			var single: Array[Card] = [highest]
			await _flash_auto_selected(ctx, single)
			_apply_card_mod(ctx, highest, value)


func _apply_card_mod(ctx: SkillContext, card: Card, value: int) -> void:
	var old_val: int = card.get_effective_value()
	var card_str: String = card.format_value(old_val)
	var val_str: String = ColorUtils.colorize(str(value), ColorUtils.COLOR_CARD)
	match card_mod_type:
		CardModType.BUFF:
			card.value_buff += value
		CardModType.DEBUFF:
			card.value_debuff += value
	
	var new_val: int = card.get_effective_value()
	var new_val_str: String = card.format_value(new_val)
	
	var verb: String = "Boosted" if card_mod_type == CardModType.BUFF else "Reduced"
	ctx.log("%s %s by %s → new value: %s" % [verb, card_str, val_str, new_val_str])
	EventBus.card_value_changed.emit(card, old_val, card.get_effective_value())


func _discard_card(ctx: SkillContext) -> void:
	if ctx.game_state.hand.is_empty():
		ctx.log("No cards in hand to discard.")
		return

	var chosen_cards: Array[Card] = []
	var auto_selected: bool = false
	match card_select_mode:
		CardSelectMode.PICK_N_CARD:
			var filter: Callable = func(_c: Card) -> bool: return true
			chosen_cards = await ctx.pick_n_card.call(card_count, filter)
		CardSelectMode.AUTO_HIGHEST:
			auto_selected = true
			var c: Card = ctx.game_state.get_highest_card_in_hand()
			if c != null:
				chosen_cards = [c]
		CardSelectMode.AUTO_TOP_N:
			auto_selected = true
			chosen_cards = ctx.game_state.get_top_n_cards(card_count)

	if chosen_cards.is_empty():
		ctx.log("No card discarded.")
		return

	if auto_selected:
		await _flash_auto_selected(ctx, chosen_cards)

	if store_resolved_value and not chosen_cards.is_empty():
		ctx.stored_value = chosen_cards[0].get_effective_value()

	for card: Card in chosen_cards:
		ctx.game_state.discard_card(card)
		var old_val: int = card.get_effective_value()
		var card_str: String = card.format_value(old_val)
		var log_msg: String = "Discarded %s." % card_str
		if store_resolved_value:
			var stored_value: String = ColorUtils.colorize(str(ctx.stored_value) + " V", ColorUtils.COLOR_CARD)
			log_msg += " (stored value: %s)" % stored_value
		ctx.log(log_msg)
		EventBus.card_discarded.emit(card)


func _draw_card(ctx: SkillContext) -> void:
	var drawn: Array[Card] = ctx.game_state.draw_n_cards(card_count)
	for card: Card in drawn:
		var old_var: int = card.get_effective_value()
		var card_str: String = card.format_value(old_var)
		ctx.log("Drew %s." % card_str)
		EventBus.card_drawn.emit(card)
	if drawn.is_empty():
		ctx.log(ColorUtils.colorize("Deck and discard empty — nothing to draw.", ColorUtils.COLOR_DEAD))


func _set_next_skill_bonus(ctx: SkillContext, value: int) -> void:
	ctx.game_state.next_skill_bonus += value
	var val_str: String = ColorUtils.colorize(str(value), ColorUtils.COLOR_CARD)
	ctx.log("Next skill played this turn gains %s value." % val_str)


## Applies a buff/debuff status to the resolved targets. The resolved value is
## used as the number of stacks (or rounds) added.
func _apply_status(ctx: SkillContext, targets: Array[Unit], value: int) -> void:
	var id: String = status_id.strip_edges().to_lower()
	if id.is_empty():
		ctx.log(ColorUtils.colorize("apply_status effect has no status_id.", ColorUtils.COLOR_DEAD))
		return
	var amount: int = maxi(1, value)
	for target: Unit in targets:
		if target.is_dead:
			continue
		var new_count: int = target.apply_status(id, amount)
		var target_name: String = _color_unit(target)
		var amount_str: String = ColorUtils.stat_value(amount)
		var total_str: String = ColorUtils.colorize(str(new_count), ColorUtils.COLOR_CARD)
		ctx.log("%s gains %s %s (total: %s)" % [
			target_name, amount_str, id.capitalize(), total_str
		])
		EventBus.unit_statuses_changed.emit(target)


func _raise_max_hp(ctx: SkillContext, targets: Array[Unit], value: int) -> void:
	for target: Unit in targets:
		target.raise_max_hp(value)
		var target_name: String = _color_unit(target)
		var val_str: String = ColorUtils.stat_value(value)
		var hp_str: String = ColorUtils.stat_value(target.current_hp)
		var max_str: String = ColorUtils.stat_value(target.max_hp)
		ctx.log("%s max HP raised to %s → HP: %s/%s" % [
			target_name, val_str, hp_str, max_str
		])
#endregion 

#region Auto-Generated Description
func get_description() -> String:
	var parts: PackedStringArray = []

	# Condition prefix
	if condition != Condition.NONE:
		var cond_raw: String = Condition.keys()[condition]
		var cond_name: String = cond_raw.replace("_", " ").to_lower()
		if negate_condition:
			parts.append("If NOT %s:" % cond_name)
		else:
			parts.append("If %s:" % cond_name)

	# Action verb
	var action_raw: String = Action.keys()[action_type]
	var action_name: String = action_raw.replace("_", " ").capitalize()
	if action_type == Action.APPLY_STATUS and not status_id.strip_edges().is_empty():
		action_name = "%s (%s)" % [action_name, status_id.strip_edges()]
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
		var card_sel_raw: String = CardSelectMode.keys()[card_select_mode]
		parts.append("(%s)" % card_sel_raw.to_lower())

	# Target description
	if target_mode != TargetMode.NONE:
		var target_raw: String = TargetMode.keys()[target_mode]
		var target_name: String = target_raw.replace("_", " ").to_lower()
		if target_mode == TargetMode.PICK_N_ENEMY:
			parts.append("to %d %s" % [target_count, target_name])
		else:
			parts.append("to %s" % target_name)

	return " ".join(parts)


func _describe_value() -> String:
	var source_raw: String = ValueSource.keys()[value_source]
	var source_name: String = source_raw.replace("_", " ").capitalize()
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
