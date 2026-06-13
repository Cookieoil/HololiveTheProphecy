class_name GameManager
extends Node
## Orchestrates the full game loop. Holds GameState + GameUI references.
## All player interaction flows through async callables injected into SkillContext.
##
## @author TheGreatJellyfish
## @version 5/17/2026

var state: GameState
var ui: GameUI
var current_intents: Array[EnemyIntent] = []
var game_running: bool = false


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
	state.build_deck()

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
	while game_running:
		state.turn_number += 1
		EventBus.turn_started.emit(state.turn_number)
		ui.show_message("\n╔══ TURN %d ══╗" % state.turn_number)

		# ── Step 1: Roll enemy intents ──
		_roll_enemy_intents()
		ui.show_enemy_intents(current_intents)

		# ── Step 2: Reset ally shields ──
		for ally in state.allies:
			if not ally.is_dead:
				ally.reset_shield()

		# ── Step 3: Draw to hand limit ──
		var drawn := state.draw_cards_to_limit()
		if not drawn.is_empty():
			ui.show_message("Drew %d card(s)." % drawn.size())

		# ── Step 4: Player action phase ──
		state.actions_left = GameState.ACTIONS_PER_TURN
		state.merges_left = GameState.MERGES_PER_TURN
		_player_action_phase()

		# ── Step 5: Cleanup played cards ──
		state.end_player_turn_cleanup()

		# ── Check for wave clear BEFORE enemy turn ──
		if state.all_enemies_dead():
			if _try_advance_wave():
				continue # loop to next turn (enemies skip this turn)

		# ── Step 6: Reset enemy shields ──
		for enemy in state.enemies:
			if not enemy.is_dead:
				enemy.reset_shield()

		# ── Step 7: Enemy turn ──
		_resolve_enemy_turns()

		# ── Step 8: Check win/lose ──
		if state.all_allies_dead():
			ui.show_message("\n══ DEFEAT ══")
			EventBus.game_over.emit(false)
			game_running = false
			break

		if state.all_enemies_dead():
			if not _try_advance_wave():
				ui.show_message("\n══ VICTORY ══")
				EventBus.game_over.emit(true)
				game_running = false
				break

		# ── Step 9: End-of-turn cleanup ──
		_end_of_turn_cleanup()
#endregion


#region Player Action Phase
func _player_action_phase() -> void:
	while true:
		ui.show_game_state(state)
		var action: Dictionary = ui.get_player_action(state)

		match action.get("type", ""):
			"play":
				_handle_play(action["card"], action["target_ally"])
			"merge":
				_handle_merge(action["card_a"], action["card_b"])
			"convert":
				_handle_convert()
			"end_turn":
				ui.show_message("Ending player turn.")
				break
			_:
				ui.show_message("Unknown action.")


func _handle_play(card: Card, ally: Unit) -> void:
	if ally.is_dead:
		ui.show_message("That ally is defeated.")
		return
	if not state.play_card_on_ally(card, ally):
		ui.show_message("Can't play that card (no actions?).")
		return

	EventBus.card_played.emit(card, ally)

	# Determine skill
	var skill: SkillData = ally.data.skill_1 if card.is_odd() else ally.data.skill_2
	ui.show_message("%s plays %s on %s → %s" % [
		card, ally.data.display_name,
		skill.skill_name,
		"(merged)" if card.is_merged else "(unmerged)"
	])

	# Build context
	var ctx := _build_ally_context(ally, card)

	# Resolve
	_resolve_skill(skill, ctx)


func _handle_merge(a: Card, b: Card) -> void:
	if state.merges_left <= 0:
		ui.show_message("No merges left this turn.")
		return
	var result := state.try_merge(a, b)
	if result == null:
		ui.show_message("Invalid merge.")
		return
	state.merges_left -= 1
	ui.show_message("Merged → %s" % result)


func _handle_convert() -> void:
	if state.actions_left <= 0:
		ui.show_message("No actions left to convert.")
		return
	state.actions_left -= 1
	state.merges_left += 1
	ui.show_message("Converted 1 action → 1 merge. (Actions:%d Merges:%d)" % [
		state.actions_left, state.merges_left
	])
#endregion


#region Skill Resolution
func _build_ally_context(ally: Unit, card: Card) -> SkillContext:
	var ctx := SkillContext.new(ally, card, state)

	# Apply turn-wide bonus from Buff Skill 2 merged
	if state.next_skill_bonus > 0:
		ctx.card_value += state.next_skill_bonus
		ui.show_message("  +%d bonus value from Buff!" % state.next_skill_bonus)
		state.next_skill_bonus = 0

	# Inject async hooks
	ctx.request_n_target = func(count: int, filter: Callable) -> Array[Unit]:
		return ui.ask_N_target(state, count, filter)
	ctx.request_all_targets = func(count: int, filter: Callable) -> Array[Unit]:
		return ui.get_living_enemies(state, count, filter)
	ctx.request_card_choice = func(filter: Callable) -> Card:
		return ui.ask_card_choice(state, filter)
	ctx.log_message = func(msg: String) -> void:
		ui.show_message("  " + msg)

	return ctx


func _build_enemy_context(enemy: Unit, intent: EnemyIntent) -> SkillContext:
	var ctx := SkillContext.new(enemy, null, state)
	ctx.card_value = intent.effective_value
	ctx.is_merged = intent.condition_met

	# Enemy targeting is random — inject auto-target callables
	ctx.request_n_target = func(_count: int, _filter: Callable) -> Array[Unit]:
		var target := state.get_living_allies()
		target.shuffle()
		var result: Array[Unit] = []
		for i in mini(_count, target.size()):
			result.append(target[i])
		if not result.is_empty():
			var names := result.map(func(t: Unit) -> String: return \
			t.data.display_name)
			
			ui.show_message(" Targets: $s" % ", " .join(names))
		return result

	ctx.request_all_targets = func(_count: int, _filter: Callable) -> Array[Unit]:
		return state.get_living_allies() # "all allies" for enemy AoE
		
	ctx.request_card_choice = func(_filter: Callable) -> Card:
		return state.get_highest_card_in_hand() # enemies auto-pick highest
		
	ctx.log_message = func(msg: String) -> void:
		ui.show_message("  " + msg)

	return ctx

func _resolve_skill(skill: SkillData, ctx: SkillContext) -> void:
	if ctx.is_merged:
		match skill.merged_mode:
			SkillData.MergedMode.AND:
				for effect in skill.merged_effects:
					effect.execute(ctx)
				for effect in skill.base_effects:
					effect.execute(ctx)
			SkillData.MergedMode.INSTEAD:
				for effect in skill.merged_effects:
					effect.execute(ctx)
	else:
		for effect in skill.base_effects:
			effect.execute(ctx)

	EventBus.skill_resolved.emit(ctx.caster, skill.skill_name)
#endregion


#region Enemy Turn
func _roll_enemy_intents() -> void:
	current_intents.clear()
	var dice_sides := state.get_dice_size(state.turn_number - 1) # 0-based
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
		ui.show_message("\n%s acts! (Value: %d)" % [
			intent.enemy.data.display_name, intent.effective_value
		])

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

	ui.show_message("\n★ WAVE %d CLEARED! ★" % (state.current_wave + 1))

	# Clear all shields
	for ally in state.allies:
		ally.reset_shield()

	match state.wave_transition_mode:
		GameState.WaveTransition.FULL_TURN:
			# Spawn next wave at the START of the next turn
			_spawn_wave(next_wave)
			ui.show_message("New enemies appear! Player gets a full turn first.")
		GameState.WaveTransition.IMMEDIATE_SKIP:
			# Spawn now, but they do nothing this turn
			_spawn_wave(next_wave)
			ui.show_message("New enemies appear! They skip their first turn.")

	return true
#endregion


#region Cleanup
func _end_of_turn_cleanup() -> void:
	# Any per-turn state resets go here.
	# Value modifiers are already cleared per-enemy after their action.
	pass
#endregion
