class_name GameManager
extends Node
## Orchestrates the full game loop. Holds GameState + GameUI references.
## All player interaction flows through async callables injected into SkillContext.
##
## @author TheGreatJellyfish
## @version 7/13/2026

var state: GameState
var ui: GameUI
var current_intents: Array[EnemyIntent] = []
var game_running: bool = false
var instructions_shown: bool = false

#region Helpers
func _color_unit(unit: Unit) -> String:
	var col = ColorUtils.COLOR_ALLY if unit.is_ally else ColorUtils.COLOR_ENEMY
	return ColorUtils.colorize(unit.data.display_name, col)

func _color_value(value: int, type: String = "hp") -> String:
	var col = ColorUtils.COLOR_HP if type == "hp" else ColorUtils.COLOR_SHIELD
	return ColorUtils.colorize(str(value), col)

func _color_card_value(card: Card) -> String:
	return ColorUtils.colorize(str(card.get_effective_value()), ColorUtils.COLOR_CARD)
	
#endregion

#region Setup
## The game state initializer (kickoff): 
## 1. It takes the starting data to configures the game state.
## 2. Initialize both allies and enemies to assign them unit data.
## 3. Stores the enemy units for waves into the game state so 
## to knows what enemies to bring out in later rounds.
## 4. Setup the game UI (GameUI.tscn)
## 5. Create a new deck for the game.
## 6. Run the game loop (and the turn counter)
## 
## @param ally_data - the unit data for ally 
##                    (enemy data is handled in _spawn_wave).
## @param wave_defs - Array of Array[UnitData]
## @param p_ui - the game 2D scene for UI (GameUI)
func setup_game(
	ally_data: Array[UnitData],
	wave_defs: Array,
	p_ui: GameUI
) -> void:
	state = GameState.new()
	ui = p_ui

	state.wave_definitions = wave_defs
	# Initialize allies
	state.initialize_allies(ally_data)
	# Initialize enemies
	_spawn_wave(0)
	state.build_deck() # Fire-and-forget coroutine

	game_running = true
	_run_game_loop()

func _spawn_wave(wave_index: int) -> void:
	state.current_wave = wave_index
	if wave_index < state.wave_definitions.size():
		var enemy_data: Array[UnitData] = []
		for ud in state.wave_definitions[wave_index]:
			enemy_data.append(ud as UnitData)
		state.initialize_enemies(enemy_data)
		EventBus.wave_started.emit(wave_index)
#endregion


#region Main Game Loop
func _run_game_loop() -> void:
	if state.turn_number == 0 and not instructions_shown:
		_show_instructions()
		instructions_shown = true
	
	while game_running:
		EventBus.turn_started.emit(state.turn_number)
		var turn_header = ColorUtils.colorize("╔══ TURN %d ══╗" % (state.turn_number + 1), ColorUtils.COLOR_HEADER)
		if state.turn_number == 0:
			ui.show_message("\n" + turn_header)
		else:
			ui.show_message("\n\n" + turn_header)

		# ── Step 1: Roll enemy intents ──
		_roll_enemy_intents()
		ui.show_enemy_intents(current_intents)

		# ── Step 2: Reset ally shields & temp effects ──
		for ally in state.allies:
			if not ally.is_dead:
				ally.reset_shield()

		# ── Step 3: Draw to hand limit ──
		var drawn := state.draw_cards_to_limit()
		if not drawn.is_empty():
			var count_str = ColorUtils.colorize(str(drawn.size()), ColorUtils.COLOR_CARD)
			ui.show_message("Drew %s card(s)." % count_str)

		# ── Step 4: Player action phase (async) ──
		state.actions_left = GameState.ACTIONS_PER_TURN
		state.merges_left = GameState.MERGES_PER_TURN
		state.next_skill_bonus = 0
		await _player_action_phase()

		# ── Step 5: Cleanup played cards ──
		state.end_player_turn_cleanup()

		# Check for wave clear before enemy turn
		if state.all_enemies_dead():
			if _try_advance_wave():
				state.turn_number += 1
				continue # loop to next turn (enemies skip this turn)

		# ── Step 6: Reset enemy shields & temp effects ──
		for enemy in state.enemies:
			if not enemy.is_dead:
				enemy.reset_shield()

		# ── Step 7: Enemy turn  (async — skills may log) ──
		_resolve_enemy_turns()
		
		# Post-turn checks
		if state.all_allies_dead():
			ui.show_message(ColorUtils.colorize("\n══ DEFEAT ══", ColorUtils.COLOR_ENEMY))
			EventBus.game_over.emit(false)
			game_running = false
			break
		
		if state.all_enemies_dead():
			if not _try_advance_wave():
				ui.show_message(ColorUtils.colorize("\n══ VICTORY ══", ColorUtils.COLOR_ALLY))
				EventBus.game_over.emit(true)
				game_running = false
				break
				
		# ── Step 8: Clean up ──
		_end_of_turn_cleanup()
		state.turn_number += 1
		
func _show_instructions() -> void:
	var msg = """
[color=#FFFFFF]═══════════ HOW TO PLAY ═══════════[/color]

[color=#00FF00]Allies[/color] have two skills: [color=#FFFF00]odd[/color] card → Skill 1, [color=#FFFF00]even[/color] card → Skill 2.

[color=#FFFF00]play <card#> <ally#>[/color]			- Play a card on an ally to trigger its odd/even skill.
[color=#FFFF00]merge <card#> <card#>[/color]	- Merge any two cards in hand. Merged card can only merged with same-value card.
[color=#FFFF00]convert[/color]									- Convert 1 action into 1 merge.
[color=#FFFF00]end[/color]											- End your turn to start the enemy turn.
[color=#FFFF00]stats[/color]										- Show full units' stats (ally/enemy HP, shield).
[color=#FFFF00]hand[/color]										- Show your cards in hand.

[color=#00BFFF]Goal:[/color] Defeat all enemies with at least one ally alive.
"""
	ui.show_message(msg)
#endregion


#region Player Action Phase
func _player_action_phase() -> void:
	ui.show_game_state(state)
	ui.show_hand_and_resources(state)
		
	while true:
		var action: Dictionary = await ui.get_player_action(state)
	
		match action.get("type", ""):
			"play":
				await _handle_play(action["card"], action["target_ally"])
				await ui.show_hand_and_resources(state)
				
			"merge":
				await _handle_merge(action["card_a"], action["card_b"])
				ui.show_hand_and_resources(state)
				
			"convert":
				await _handle_convert()
				
			"stats":
				await ui.show_game_state(state)
				
			"hand":
				await ui.show_hand_and_resources(state)
				
			"end_turn":
				await ui.show_message("Ending player turn.")
				break
			_:
				await ui.show_message("Unknown action.")
				

func _handle_play(card: Card, ally: Unit) -> void:
	if ally.is_dead:
		ui.show_message(ColorUtils.colorize("That ally is defeated.", ColorUtils.COLOR_DEAD))
		return
	if not state.play_card_on_ally(card, ally):
		ui.show_message("Can't play that card (no actions)")
		return
	
	EventBus.card_played.emit(card, ally)
	
	# Determine skill
	var skill: SkillData = ally.data.skill_1 if card.is_odd() else ally.data.skill_2
	var card_str = ColorUtils.colorize(str(card.get_effective_value()) + " V", ColorUtils.COLOR_CARD)
	var ally_str = _color_unit(ally)
	var skill_str = ColorUtils.colorize(skill.skill_name, ColorUtils.COLOR_HEADER)
	var merged_str = ""
	if card.is_double_merged:
		merged_str = ColorUtils.colorize("Double merged ", ColorUtils.COLOR_CARD)
	elif card.is_merged:
		merged_str = ColorUtils.colorize("Merged ", ColorUtils.COLOR_CARD)
	else:
		merged_str = ""

	ui.show_message("%s plays (%s) → %s%s" % [
		ally_str, card_str, merged_str, skill_str
	])
	
	if skill.skill_name == "Skill 1 (odd)":
		ui.show_message(ColorUtils.colorize("> " + ally.data.skill_1.description, ColorUtils.COLOR_DEAD))
	else:
		ui.show_message(ColorUtils.colorize("> " + ally.data.skill_2.description, ColorUtils.COLOR_DEAD))
		
	# Build context
	var ctx := _build_ally_context(ally, card)
	
	# Resolve
	await _resolve_skill(skill, ctx)


func _handle_merge(a: Card, b: Card) -> void:
	if state.merges_left <= 0:
		ui.show_message("No merges left this turn.")
		return
	var error = state.get_merge_error(a, b)
	if error != "":
		ui.show_message("Invalid merge: " + error)
		return
	
	# Proceed with the merge
	var result = state.try_merge(a, b)
	state.merges_left -= 1
	var result_str = _color_card_value(result)
	ui.show_message("Merged → %s" % result_str)


func _handle_convert() -> void:
	if state.actions_left <= 0:
		ui.show_message("No actions left to convert")
		return
	state.actions_left -= 1
	state.merges_left += 1
	ui.show_message("Converted 1 action → 1 merge. (Actions:%d Merges:%d)" % [
		state.actions_left, state.merges_left
	])
#endregion


#region Context Builders
func _build_ally_context(ally: Unit, card: Card) -> SkillContext:
	var ctx := SkillContext.new(ally, card, state)

	# Apply turn-wide bonus from Buff Skill 2 merged
	if state.next_skill_bonus > 0:
		ctx.card_value += state.next_skill_bonus
		var bonus_str = ColorUtils.colorize("+" + str(state.next_skill_bonus), ColorUtils.COLOR_CARD)
		ui.show_message("  %s bonus value from Buff!" % bonus_str)
		state.next_skill_bonus = 0

	# Pick_n_target:
	ctx.pick_n_target = func(count: int, filter: Callable) -> Array[Unit]:
		var units: Array[Unit] = []
		for u in state.allies:
			if filter.call(u):
				units.append(u)
		for u in state.enemies:
			if filter.call(u):
				units.append(u)
		if units.is_empty():
			return []
		return await ui.ask_pick_targets(units, count)
		
	# Pick_n_card:
	ctx.pick_n_card = func(count: int, filter: Callable) -> Array[Card]:
		var units: Array[Card] = []
		for c in state.hand:
			if filter.call(c):
				units.append(c)
		if units.is_empty():
			return []
		return await ui.ask_pick_cards(units, count)
		
	ctx.log_message = func(msg: String) -> void:
		ui.show_message("  " + msg)
	
	return ctx


func _build_enemy_context(enemy: Unit, intent: EnemyIntent) -> SkillContext:
	var ctx := SkillContext.new(enemy, null, state)
	ctx.card_value = intent.effective_value
	ctx.is_merged = intent.condition_met

	# Enemy targeting is random — inject auto-target callables
	ctx.pick_n_target = func(_count: int, _filter: Callable) -> Array[Unit]:
		var target := state.get_living_allies()
		target.shuffle()
		var result: Array[Unit] = []
		
		for i in mini(_count, target.size()):
			result.append(target[i])
			
		if not result.is_empty():
			var names := result.map(func(t: Unit) -> String: return t.data.display_name)
			var joined = ", ".join(names)
			var colored = ColorUtils.colorize(joined, ColorUtils.COLOR_ALLY)
			ui.show_message(" Targets: %s" % colored)
		return result
	
	ctx.pick_n_card = func(count: int, _filter: Callable) -> Array[Card]:
		return state.get_top_n_cards(count)
		
	ctx.log_message = func(msg: String) -> void:
		ui.show_message("  " + msg)
	
	return ctx
#endregion

#region Skill Resolution
func _resolve_skill(skill: SkillData, ctx: SkillContext) -> void:
	if ctx.is_merged:
		match skill.merged_mode:
			SkillData.MergedMode.AND_MERGED_FIRST:
				for effect in skill.merged_effects:
					await effect.execute(ctx)
				for effect in skill.base_effects:
					await effect.execute(ctx)
			SkillData.MergedMode.AND_BASE_FIRST:
				for effect in skill.base_effects:
					await effect.execute(ctx)
				for effect in skill.merged_effects:
					await effect.execute(ctx)
			SkillData.MergedMode.OR:
				for effect in skill.merged_effects:
					await effect.execute(ctx)
	else:
		for effect in skill.base_effects:
			await effect.execute(ctx)

	EventBus.skill_resolved.emit(ctx.caster, skill.skill_name)
#endregion


#region Enemy Turn
func _roll_enemy_intents() -> void:
	current_intents.clear()
	var dice_sides := state.get_dice_size(state.turn_number) # 0-based
	var dice_str = ColorUtils.colorize("d" + str(dice_sides), ColorUtils.COLOR_CARD)
	ui.show_message("(Rolling %s)" % dice_str)
	for enemy in state.enemies:
		if enemy.is_dead:
			continue
		var roll := DiceRoller.roll(dice_sides)
		var intent := EnemyIntent.new(enemy, roll)
		current_intents.append(intent)


func _resolve_enemy_turns() -> void:
	for intent in current_intents:
		if intent.enemy.is_dead:
			continue
		var enemy_name = _color_unit(intent.enemy)
		var dice_value = ColorUtils.colorize(str(intent.effective_value) + " V", ColorUtils.COLOR_CARD)
		var skill_name = ColorUtils.colorize(intent.skill.skill_name, ColorUtils.COLOR_HEADER)
		var condition_met = ""
		if intent.condition_met == true:
			condition_met = ColorUtils.colorize("Merged ", ColorUtils.COLOR_CARD)
		ui.show_message("\n[%d] %s plays (%s) → %s%s" % [
			intent.enemy.slot_index, enemy_name, dice_value, condition_met, skill_name
		])
	
		if intent.skill.skill_name == "Skill 1 (odd)":
			ui.show_message(ColorUtils.colorize("> " + intent.enemy.data.skill_1.description, ColorUtils.COLOR_DEAD))
		else:
			ui.show_message(ColorUtils.colorize("> " + intent.enemy.data.skill_2.description, ColorUtils.COLOR_DEAD))
			
		var ctx := _build_enemy_context(intent.enemy, intent)
		_resolve_skill(intent.skill, ctx)
	
		# Clear value modifiers after this enemy's action resolves
		intent.enemy.clear_value_modifier()
	
		# Check ally deaths
		if state.all_allies_dead():
			break
#endregion

#region Wave Management
## Returns true if a new wave was spawned (enemy turn should be skipped).
func _try_advance_wave() -> bool:
	var next_wave := state.current_wave + 1
	if next_wave >= state.wave_definitions.size():
		return false # no more waves
	
	var wave_header = ColorUtils.colorize("★ WAVE %d CLEARED! ★" % (state.current_wave + 1), ColorUtils.COLOR_HEADER)
	ui.show_message("\n" + wave_header)
	
	# Clear all shields
	for ally in state.allies:
		ally.reset_shield()
	
	match state.wave_transition_mode:
		GameState.WaveTransition.FULL_TURN:
			# Spawn next wave at the START of the next turn
			_spawn_wave(next_wave)
			ui.show_message(ColorUtils.colorize("New enemies appear! Player gets a full turn first.", ColorUtils.COLOR_HEADER))
		GameState.WaveTransition.IMMEDIATE_SKIP:
			# Spawn now, but they do nothing this turn
			_spawn_wave(next_wave)
			ui.show_message(ColorUtils.colorize("New enemies appear! They skip their first turn.", ColorUtils.COLOR_HEADER))
	
	return true
#endregion

#region Cleanup
func _end_of_turn_cleanup() -> void:
	pass
	
#endregion
