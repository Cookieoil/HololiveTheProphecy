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
## Passive gameplay recorder (see Managers/TelemetryManager.gd). It is a no-op
## until the player has agreed to telemetry, so every hook below is safe to call
## unconditionally.
var telemetry: TelemetryManager = TelemetryManager.new()
## Tester tool table (see Managers/DebugCommandRunner.gd). It holds no board of its
## own - it is handed `state` and `ui` per command - and it *asks* for the two tools
## that need the turn loop's own machinery (re-roll the intents, re-spawn the wave)
## rather than reaching back in here, which would be a cycle.
var _debug: DebugCommandRunner = DebugCommandRunner.new()

#region Enums
## What a round step decided about what happens next. The loop reads one of these per step
## so every exit stays visible on its own line (see _run_game_loop).
enum StepOutcome {
	CONTINUE_ROUND, ## run the next step of this round
	NEXT_TURN,      ## this round is done; the next one starts fresh
	BATTLE_OVER,    ## the run ended; the loop stops
}
#endregion


#region Constants
## Fraction of an enemy's skill animation that plays before the next enemy may
## start its own. Below 1.0 the previous enemy's wind-down overlaps the next
## one's wind-up (the "fast mode" feel), so a three-enemy phase no longer costs
## three full animation tails back to back. 1.0 restores strictly sequential
## turns. Enemy Ultimates always play in full, so the dramatic beat stays intact.
const ENEMY_SKILL_OVERLAP_LEAD: float = 0.6
#endregion


#region Lifecycle Methods
## Wires the runner's two requests. Both handlers read `state` / `ui` when they run
## rather than when they are connected, so it does not matter that the board is
## assigned after this node enters the tree - which is exactly what the test suite
## does (it builds a manager by hand instead of calling setup_game).
func _ready() -> void:
	_debug.intents_reroll_requested.connect(_reroll_and_show_intents)
	_debug.wave_respawn_requested.connect(_respawn_wave_and_show)
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
	p_ui: GameUI,
	config: Dictionary = {}
) -> void:
	state = GameState.new()
	ui = p_ui
	# Seed first: the flag rollout resolved by apply_config() is keyed on the run
	# seed, which keeps an experiment reproducible and needs no player identifier.
	# Seeding up front also means the whole battle can be replayed from this one
	# number, and telemetry can name it.
	state.set_run_seed(GameState.seed_from_config(config))
	state.apply_config(config)

	state.wave_definitions = wave_defs
	# Initialize allies
	state.initialize_allies(ally_data)
	# Open the telemetry run before the first wave spawns, so wave 0 and turn 1
	# are captured from the very first session when the player agreed.
	telemetry.start_run(state)
	# Initialize enemies
	_spawn_wave(0)
	state.build_deck() # the decklist was already applied by state.apply_config(config)

	game_running = true
	await _run_game_loop()

func _spawn_wave(wave_index: int) -> void:
	state.current_wave = wave_index
	if wave_index < state.wave_definitions.size():
		var enemy_data: Array[UnitData] = []
		var wave_units: Array = state.wave_definitions[wave_index]
		for ud: UnitData in wave_units:
			enemy_data.append(ud)
		state.initialize_enemies(enemy_data)
		EventBus.wave_started.emit(wave_index)
#endregion


#region Main Game Loop
## The round driver: one line per step, in the order the game depends on. Every boundary
## in here is pinned by GDTest/TurnLoopTest.gd - read that suite before reordering a step
## or moving a reset, because the three outcome checks below look alike and are not.
func _run_game_loop() -> void:
	_show_intro_once()

	while game_running:
		_begin_turn()                              # Steps 1-3: intents, resets, draw

		await _player_action_phase()               # Step 4 (async; owns its own exits)
		if not game_running:
			break                                  # a lethal action already ended the run

		var after_player: StepOutcome = await _settle_player_phase()
		if after_player == StepOutcome.BATTLE_OVER:
			break
		if after_player == StepOutcome.NEXT_TURN:
			state.turn_number += 1                 # the new wave gets a full turn first
			continue

		_reset_enemy_shields()                     # Step 6
		await _resolve_enemy_turns()               # Step 7 (async - skills may log)
		var after_enemy: StepOutcome = await _settle_enemy_turn()
		if after_enemy == StepOutcome.BATTLE_OVER:
			break

		var after_tick: StepOutcome = await _tick_round() # Step 8: statuses, then re-check
		if after_tick == StepOutcome.BATTLE_OVER:
			break
		state.turn_number += 1


## The how-to-play block is a first-run courtesy: turn 0 shows it once, and the flag is
## kept on the manager so re-entering the loop cannot repeat it.
func _show_intro_once() -> void:
	if state.turn_number == 0 and not instructions_shown:
		_show_instructions()
		instructions_shown = true


## Steps 1-3: roll and preview the enemy intents, reset the round's per-turn state, draw
## up to the hand limit, snapshot the turn for telemetry, and hand it to the player.
func _begin_turn() -> void:
	EventBus.turn_started.emit(state.turn_number)
	ui.show_message(_turn_header())

	# ── Step 1: Roll enemy intents ──
	_roll_enemy_intents()
	ui.show_enemy_intents(current_intents)

	# ── Step 2: Reset ally shields & temp effects ──
	_reset_turn_state()

	# ── Step 3: Draw to hand limit ──
	var drawn: Array[Card] = state.draw_cards_to_limit()
	if not drawn.is_empty():
		var count_str: String = ColorUtils.colorize(str(drawn.size()), ColorUtils.COLOR_CARD)
		ui.show_message("Drew %s card(s)." % count_str)

	# Snapshot the turn the player is about to act in: intents, hand, board.
	telemetry.record_turn_started(state, current_intents, state.get_dice_size(state.turn_number))

	state.actions_left = state.actions_per_turn
	state.merges_left = state.merges_per_turn
	state.next_skill_bonus = 0


## Turn 1 opens flush under the title card; every later turn gets a blank line first.
func _turn_header() -> String:
	var header: String = ColorUtils.colorize(
		"╔══ TURN %d ══╗" % (state.turn_number + 1), ColorUtils.COLOR_HEADER
	)
	if state.turn_number == 0:
		return "\n" + header
	return "\n\n" + header


## Step 2, the start-of-round resets: both sides release the once-per-turn Ultimate lock
## and the allies lose their shields. Enemy shields are deliberately NOT reset here - they
## cover the player phase, so Step 6 clears them instead (see _reset_enemy_shields).
func _reset_turn_state() -> void:
	for ally: Unit in state.allies:
		ally.ult_used_this_turn = false
		if not ally.is_dead:
			ally.reset_shield()
	for enemy: Unit in state.enemies:
		enemy.ult_used_this_turn = false


## Step 5: move the played cards to the discard pile, then settle a board the player just
## cleared. Returns NEXT_TURN when a wave with a successor took over, BATTLE_OVER when the
## final wave fell (the player's own action just won the run, so no enemy turn is left to
## resolve), or CONTINUE_ROUND to let the enemy turn run.
func _settle_player_phase() -> StepOutcome:
	state.end_player_turn_cleanup()
	if not state.all_enemies_dead():
		return StepOutcome.CONTINUE_ROUND
	_close_turn_record()
	if _try_advance_wave():
		return StepOutcome.NEXT_TURN
	await _finish_battle(true, TelemetryManager.REASON_FINAL_WAVE)
	return StepOutcome.BATTLE_OVER


## Step 6: enemy shields cover the player phase, so they are cleared here - after the
## player has finished and immediately before their owners act.
func _reset_enemy_shields() -> void:
	for enemy: Unit in state.enemies:
		if not enemy.is_dead:
			enemy.reset_shield()


## Step 7's post-check. An ally wipe, or a final wave that just fell, ends the run and
## skips the round tick. A wave WITH a successor advances here and still falls through to
## the tick, so statuses fire exactly once per round - the one check that can advance the
## wave and keep the round going.
func _settle_enemy_turn() -> StepOutcome:
	if state.all_allies_dead():
		_close_turn_record()
		await _finish_battle(false, TelemetryManager.REASON_ALL_ALLIES_DEAD)
		return StepOutcome.BATTLE_OVER
	if state.all_enemies_dead() and not _try_advance_wave():
		_close_turn_record()
		await _finish_battle(true, TelemetryManager.REASON_FINAL_WAVE)
		return StepOutcome.BATTLE_OVER
	return StepOutcome.CONTINUE_ROUND


## Step 8: every buff/debuff ticks exactly once per round and the turn record closes. The
## tick can finish off the last ally (a status death, not an ally wipe), clear a wave that
## still has a successor, or win the run outright, so the outcome is re-checked here.
func _tick_round() -> StepOutcome:
	_end_of_turn_cleanup()
	_close_turn_record()
	if state.all_allies_dead():
		await _finish_battle(false, TelemetryManager.REASON_STATUS_TICK)
		return StepOutcome.BATTLE_OVER
	if state.all_enemies_dead():
		if _try_advance_wave():
			return StepOutcome.NEXT_TURN
		await _finish_battle(true, TelemetryManager.REASON_FINAL_WAVE)
		return StepOutcome.BATTLE_OVER
	return StepOutcome.NEXT_TURN


## Closes the recorded turn on every way out of the loop, so a lethal last turn
## (which never reaches Step 8) is still captured. The recorder only writes one
## turn_ended per turn number, so calling it on each exit path is safe.
func _close_turn_record() -> void:
	telemetry.record_turn_ended(state)


## A scene reload ("Play Again") or a quit mid-battle never reaches _finish_battle,
## so close the open run as abandoned rather than losing the whole run - which
## enemy and wave players quit on is itself a balance signal.
func _exit_tree() -> void:
	if game_running and state != null:
		telemetry.abandon_run(state)
		
func _show_instructions() -> void:
	var msg: String = """
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
		# Snapshot everything the player can see *before* they choose, so the
		# recorded decision carries the alternatives it was chosen over.
		telemetry.begin_decision(state, current_intents)
		var action: Dictionary = await ui.get_player_action(state)
		telemetry.note_action_received()
		var action_type: String = str(action.get("type", ""))
		var end_phase: bool = false

		match action_type:
			"play":
				var play_card: Card = action["card"]
				var target_ally: Unit = action["target_ally"]
				await _handle_play(play_card, target_ally)
				if _resolve_enemy_clear_after_action():
					end_phase = true # final wave cleared: the battle is won

			"merge":
				var card_a: Card = action["card_a"]
				var card_b: Card = action["card_b"]
				_handle_merge(card_a, card_b)

			"convert":
				_handle_convert()

			"ultimate":
				var caster: Unit = action["caster"]
				await _handle_ally_ultimate(caster)
				# An Ultimate can clear the board too, so it runs the same wave /
				# victory check a played card does instead of leaving the phase open.
				if _resolve_enemy_clear_after_action():
					end_phase = true

			"stats":
				ui.show_game_state(state)

			"hand":
				pass

			"debug":
				# Every tester tool taints the run, so balance views can ignore it.
				telemetry.mark_debug_tainted()
				_handle_debug_command(action)
				# A result preview ends the battle right here, through the same exit
				# a real ending uses (see _finish_battle).
				if _debug.result_request != DebugCommandRunner.RESULT_NONE:
					var preview_victory: bool = _debug.result_request == DebugCommandRunner.RESULT_VICTORY
					_debug.result_request = DebugCommandRunner.RESULT_NONE
					await _finish_battle(preview_victory, TelemetryManager.REASON_DEBUG_PREVIEW)
					end_phase = true
				elif _resolve_enemy_clear_after_action():
					# A debug tool can clear a wave (or finish off the last enemy),
					# so run the exact same wave check the "play" branch does.
					end_phase = true

			"end_turn":
				ui.show_message("Ending player turn.")
				end_phase = true
			_:
				ui.show_message("Unknown action.")

		# Close the decision window before leaving the phase, so the player's
		# action is recorded even when it ended the battle.
		telemetry.end_decision(action, state)
		if end_phase:
			break
		ui.show_hand_and_resources(state)


## Shared post-action check for every action that can kill enemies (a played card,
## an ally Ultimate, or a debug tool). Returns true when the player phase must end
## because the board was cleared.
##
## A wave that still has a successor is advanced here in IMMEDIATE_SKIP mode (the
## new enemies sit out the rest of the turn). A final-wave clear ends the phase,
## which lets the game loop declare the battle over instead of leaving the player
## parked on a won board until they press End Turn.
func _resolve_enemy_clear_after_action() -> bool:
	if not state.all_enemies_dead():
		return false
	if state.wave_transition_mode == GameState.WaveTransition.IMMEDIATE_SKIP \
			and _try_advance_wave():
		current_intents.clear() # New wave skips acting this turn
		ui.show_game_state(state)
		ui.show_enemy_intents(current_intents)
		return false
	return true # FULL_TURN / FINAL_WAVE: exit player phase immediately


func _handle_play(card: Card, ally: Unit) -> void:
	if ally.is_dead:
		ui.show_message(ColorUtils.colorize("That ally is defeated.", ColorUtils.COLOR_DEAD))
		return
	if not state.play_card_on_ally(card, ally):
		ui.show_message("Can't play that card (no actions)")
		return

	ui.on_card_played(card, state)
	EventBus.card_played.emit(card, ally)
	
	# Determine skill
	var skill: SkillData = ally.data.skill_1 if card.is_odd() else ally.data.skill_2
	var card_str: String = ColorUtils.colorize(str(card.get_effective_value()) + " V", ColorUtils.COLOR_CARD)
	var ally_str: String = ColorUtils.unit_name(ally.data.display_name, ally.is_ally)
	var skill_str: String = ColorUtils.colorize(skill.skill_name, ColorUtils.COLOR_HEADER)
	var merged_str: String = ""
	if card.is_double_merged:
		merged_str = ColorUtils.colorize("Double merged ", ColorUtils.COLOR_CARD)
	elif card.is_merged:
		merged_str = ColorUtils.colorize("Merged ", ColorUtils.COLOR_CARD)
	else:
		merged_str = ""

	ui.show_message("%s plays (%s) → %s%s" % [
		ally_str, card_str, merged_str, skill_str
	])
	
	if card.is_merged:
		ui.show_message(ColorUtils.colorize("> " + skill.description, ColorUtils.COLOR_DEAD))
		ui.show_message(ColorUtils.colorize("> " + skill.merged_description, ColorUtils.COLOR_DEAD))
	else:
		ui.show_message(ColorUtils.colorize("> " + skill.description, ColorUtils.COLOR_DEAD))
		
	# Build context
	var ctx: SkillContext = _build_ally_context(ally, card)
	
	# Resolve gameplay first, then submit the dramatic presentation cue.
	await _resolve_skill(skill, ctx)
	for intent: EnemyIntent in current_intents:
		intent.recalculate()
	ui.show_enemy_intents(current_intents)

	var rank: int = 0
	if card.is_double_merged:
		rank = 2
	elif card.is_merged:
		rank = 1

	await ui.play_unit_skill(
		ally,
		1 if card.is_odd() else 2,
		rank
	)

	# A skill that just won the battle does not charge the gauge: the fight is
	# over, so no fresh Moxie (or "ULT READY" glow) may appear behind the result
	# screen. Clearing a wave that still has a successor charges normally.
	if _is_final_wave_cleared():
		return

	var moxie_gained: int = ally.gain_moxie(card.get_effective_value())
	if moxie_gained > 0:
		EventBus.moxie_changed.emit(ally, ally.moxie, ally.max_moxie)
		var moxie_str: String = ColorUtils.colorize(
			"+%d Moxie (%d/%d)" % [moxie_gained, ally.moxie, ally.max_moxie],
			ColorUtils.COLOR_CARD
		)
		ui.show_message("  %s → %s" % [ColorUtils.unit_name(ally.data.display_name, ally.is_ally), moxie_str])
	_refresh_enemy_intents()

func _handle_ally_ultimate(ally: Unit) -> void:
	if ally == null or ally.is_dead:
		ui.show_message(ColorUtils.colorize("That ally is defeated.", ColorUtils.COLOR_DEAD))
		return
	if not ally.can_cast_ultimate:
		ui.show_message("Ultimate not ready (%d/%d Moxie)." % [ally.moxie, ally.max_moxie])
		return

	var ult: SkillData = ally.data.ultimate
	ally.consume_moxie()
	EventBus.moxie_changed.emit(ally, ally.moxie, ally.max_moxie)
	EventBus.ultimate_cast.emit(ally, ult.skill_name)

	var ally_str: String = ColorUtils.unit_name(ally.data.display_name, ally.is_ally)
	var ult_str: String = ColorUtils.colorize("★ ULTIMATE: %s ★" % ult.skill_name, ColorUtils.COLOR_CARD)
	ui.show_message("%s unleashes %s!" % [ally_str, ult_str])
	if ult.description != "":
		ui.show_message(ColorUtils.colorize("> " + ult.description, ColorUtils.COLOR_DEAD))

	# Preserve next_skill_bonus unless this Ultimate itself adds to it (e.g. buff_ult)
	var saved_bonus: int = state.next_skill_bonus
	state.next_skill_bonus = 0
	var ctx: SkillContext = _build_ally_context(ally, null)

	await _resolve_skill(ult, ctx)
	state.next_skill_bonus += saved_bonus

	await ui.play_unit_ultimate(ally)
	_refresh_enemy_intents()

func _refresh_enemy_intents() -> void:
	for intent: EnemyIntent in current_intents:
		intent.recalculate()
	ui.show_enemy_intents(current_intents)
	
func _handle_merge(a: Card, b: Card) -> void:
	if state.merges_left <= 0:
		ui.show_message("No merges left this turn.")
		return
	var error: String = state.get_merge_error(a, b)
	if error != "":
		ui.show_message("Invalid merge: " + error)
		return
	
	# Proceed with the merge
	var result: Card = state.try_merge(a, b)
	if result == null:
		ui.show_message("Invalid merge.")
		return
	telemetry.note_merge_result(result)
	state.merges_left -= 1
	# Presentation first: the hand plays the merge, then the counters refresh. The
	# merged card is reused by that refresh, so the merge is not interrupted by it.
	ui.on_cards_merged(a, b, result, state)
	var result_str: String = ColorUtils.card_value(result.get_effective_value())
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


#region Debug Commands
## The tester tools themselves live in Managers/DebugCommandRunner.gd, which also owns
## the constants naming their scopes and their result previews
## (`DebugCommandRunner.SCOPE_*` / `DebugCommandRunner.RESULT_*`). What stays here is
## the build-type gate, because the turn loop - not the UI - is what refuses a tool in
## a release build.
## Values for `debug_build_override`: the engine decides, or the suite forces the
## release / debug answer so the gate below can be exercised without an export.
const DEBUG_BUILD_ENGINE: int = -1
const DEBUG_BUILD_FORCED_OFF: int = 0
const DEBUG_BUILD_FORCED_ON: int = 1
## Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the
## only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to
## `DEBUG_BUILD_FORCED_OFF` to prove a release build refuses every debug command. It
## cannot be written from exported data, so it can never re-enable the tools in a
## release build.
static var debug_build_override: int = DEBUG_BUILD_ENGINE


## Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the
## "debug" action). Editor runs and debug exports report `true`; a **release** export
## reports `false`, so a shipped build can never open the overlay or apply a debug
## command — even if `BattleScene.debug_menu_enabled` was left on in the inspector or
## the scene file was edited by hand. The headless gdUnit4 run uses the editor binary,
## so the tools stay available to the suite.
static func debug_tools_enabled() -> bool:
	if debug_build_override >= 0:
		return debug_build_override == DEBUG_BUILD_FORCED_ON
	return OS.is_debug_build()


## Applies one tester tool. The tools themselves live in Managers/DebugCommandRunner.gd;
## this entry point stays here because the turn loop is the authority - a release build
## refuses every command here, not just in the UI, so hiding the overlay is not the only
## line of defence. The runner is handed the board and the UI per command, so a debug
## tool still mutates nothing behind the loop's back.
## @param action - { "command": String, "args": Dictionary }
func _handle_debug_command(action: Dictionary) -> void:
	if not debug_tools_enabled():
		_debug.log_line(ui, "Debug tools are disabled in release builds.")
		return
	_debug.apply(action, state, ui)


## The runner asked for the enemy intents to be re-rolled, so a tester sees a new dice
## size (or a respawned wave's rolls) immediately instead of on the next turn.
func _reroll_and_show_intents() -> void:
	_roll_enemy_intents()
	ui.show_enemy_intents(current_intents)


## The runner asked for the current wave to be re-spawned: rebuild the enemy row,
## redraw the board and roll fresh intents for it.
func _respawn_wave_and_show() -> void:
	_spawn_wave(state.current_wave)
	ui.show_game_state(state)
	_reroll_and_show_intents()
#endregion


#region Context Builders
## The target/card/flash callables a skill resolves through live in
## Managers/SkillContextFactory.gd, which is handed the board, the UI and the recorder per
## call - the same shape as the debug tools. These two keep every call site (and the
## suites that drive them) reading exactly as before.
func _build_ally_context(ally: Unit, card: Card) -> SkillContext:
	return SkillContextFactory.build_ally_context(ally, card, state, ui, telemetry)


func _build_enemy_context(enemy: Unit, intent: EnemyIntent) -> SkillContext:
	return SkillContextFactory.build_enemy_context(enemy, intent, state, ui)
#endregion

#region Skill Resolution
func _resolve_skill(skill: SkillData, ctx: SkillContext) -> void:
	if ctx.is_merged:
		match skill.merged_mode:
			SkillData.MergedMode.AND_MERGED_FIRST:
				for effect: SkillEffect in skill.merged_effects:
					await effect.execute(ctx)
				for effect: SkillEffect in skill.base_effects:
					await effect.execute(ctx)
			SkillData.MergedMode.AND_BASE_FIRST:
				for effect: SkillEffect in skill.base_effects:
					await effect.execute(ctx)
				for effect: SkillEffect in skill.merged_effects:
					await effect.execute(ctx)
			SkillData.MergedMode.OR:
				for effect: SkillEffect in skill.merged_effects:
					await effect.execute(ctx)
	else:
		for effect: SkillEffect in skill.base_effects:
			await effect.execute(ctx)

	EventBus.skill_resolved.emit(ctx.caster, skill.skill_name)
#endregion


#region Enemy Turn
func _roll_enemy_intents() -> void:
	current_intents.clear()
	var dice_sides: int = state.get_dice_size(state.turn_number) # 0-based
	var dice_str: String = ColorUtils.colorize("d" + str(dice_sides), ColorUtils.COLOR_CARD)
	ui.show_message("(Rolling %s)" % dice_str)
	for enemy: Unit in state.enemies:
		if enemy.is_dead:
			continue
		var roll: int = DiceRoller.roll(dice_sides, state.rng)
		var intent: EnemyIntent = EnemyIntent.new(enemy, roll)
		current_intents.append(intent)


func _resolve_enemy_turns() -> void:
	for intent: EnemyIntent in current_intents:
		# Hide this enemy's intent the moment its action begins.
		ui.clear_unit_intent(intent.enemy)
	
		if intent.enemy.is_dead:
			continue
			
		var enemy_name: String = ColorUtils.unit_name(intent.enemy.data.display_name, intent.enemy.is_ally)
		var dice_value: String = ColorUtils.colorize(str(intent.effective_value) + " V", ColorUtils.COLOR_CARD)
		var skill_name: String = ColorUtils.colorize(intent.skill.skill_name, ColorUtils.COLOR_HEADER)
		var condition_met: String = ""
		if intent.condition_met == true:
			condition_met = ColorUtils.colorize("Merged ", ColorUtils.COLOR_CARD)
		ui.show_message("\n[%d] %s plays (%s) → %s%s" % [
			intent.enemy.slot_index, enemy_name, dice_value, condition_met, skill_name
		])
	
		ui.show_message(ColorUtils.colorize("> " + intent.skill.description, ColorUtils.COLOR_DEAD))
		if intent.condition_met and not intent.skill.merged_description.is_empty():
			ui.show_message(ColorUtils.colorize("> " + intent.skill.merged_description, ColorUtils.COLOR_DEAD))
			
		var ctx: SkillContext = _build_enemy_context(intent.enemy, intent)
		# Open the enemy action window so the damage it deals is attributed to this
		# enemy and this skill (the situational matchup table).
		telemetry.begin_enemy_action(intent.enemy, intent.skill, intent)
		await _resolve_skill(intent.skill, ctx)
	
		# Use effective_value, matching EnemyIntent's odd/even skill selection.
		var skill_index: int = 1 if intent.effective_value % 2 == 1 else 2
		var rank: int = 1 if intent.condition_met else 0
	
		# Return at the impact beat instead of the end of the animation, so the
		# next enemy starts its attack while this one is still winding down.
		await ui.play_unit_skill(intent.enemy, skill_index, rank, ENEMY_SKILL_OVERLAP_LEAD)
	
		# Clear value modifiers after this enemy's action resolves
		intent.enemy.clear_value_modifier()
		# This enemy's own skill is done: close its damage-attribution window.
		telemetry.end_enemy_action()
		if state.all_allies_dead():
			break
			
		if not intent.enemy.is_dead:
			var gained: int = intent.enemy.gain_moxie(intent.effective_value)
			if gained > 0:
				EventBus.moxie_changed.emit(intent.enemy, intent.enemy.moxie, intent.enemy.max_moxie)
			if intent.enemy.can_cast_ultimate:
				await _execute_enemy_ultimate(intent.enemy)
				telemetry.end_enemy_action()
				if state.all_allies_dead():
					break
					
		# Check ally deaths
		if state.all_allies_dead():
			break

func _execute_enemy_ultimate(enemy: Unit) -> void:
	var ult: SkillData = enemy.data.ultimate
	enemy.consume_moxie()
	EventBus.moxie_changed.emit(enemy, enemy.moxie, enemy.max_moxie)
	EventBus.ultimate_cast.emit(enemy, ult.skill_name)
	
	var enemy_name: String = ColorUtils.unit_name(enemy.data.display_name, enemy.is_ally)
	var ult_str: String = ColorUtils.colorize("ULTIMATE: %s" % ult.skill_name, ColorUtils.COLOR_ENEMY)
	ui.show_message("\n%s unleashes %s!" % [enemy_name, ult_str])
	if ult.description != "":
		ui.show_message(ColorUtils.colorize("> " + ult.description, ColorUtils.COLOR_DEAD))
	
	var dummy_intent: EnemyIntent = EnemyIntent.new(enemy, 0)
	var ctx: SkillContext = _build_enemy_context(enemy, dummy_intent)
	ctx.card_value = 0
	ctx.is_merged = false

	telemetry.begin_enemy_action(enemy, ult, null)
	await _resolve_skill(ult, ctx)
	await ui.play_unit_ultimate(enemy)
#endregion

#region Wave Management
## Returns true if a new wave was spawned (enemy turn should be skipped).
func _try_advance_wave() -> bool:
	var next_wave: int = state.current_wave + 1
	if next_wave >= state.wave_definitions.size():
		return false # no more waves
	
	var wave_header: String = ColorUtils.colorize("★ WAVE %d CLEARED! ★" % (state.current_wave + 1), ColorUtils.COLOR_HEADER)
	ui.show_message("\n" + wave_header)
	
	# Clear all shields
	for ally: Unit in state.allies:
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

#region Battle End
## Single exit for every way a battle can end - Victory or Defeat, whether the
## last unit fell to a played card, an ally Ultimate, the enemy turn or a status
## tick. It parks the loop, wipes the leftover turn state (pending enemy intents
## and every unit's Moxie gauge) so nothing on the board still claims a turn is
## coming, then hands the result to the UI for the Victory / Defeat cutscene.
func _finish_battle(victory: bool, reason: String = "") -> void:
	game_running = false

	# Close the telemetry run first, while the board still holds the final state
	# (intents were just cleared, Moxie is about to be wiped). `reason` names how
	# the battle ended for the balance report.
	telemetry.end_run(victory, reason, state)

	# No enemy is acting anymore, so no intent preview (and no orb preview
	# segment) may survive the hit that ended the fight.
	current_intents.clear()
	ui.show_enemy_intents(current_intents)

	# A finished battle holds no Moxie: every survivor's gauge is emptied, so no
	# orb is left glowing "ULT READY" or holding frozen crystals behind the
	# result screen. Each clear emits the unit's own `moxie_changed`.
	_clear_all_moxie()

	# The player phase may have been cut short by the winning action, so the hand
	# and counters are refreshed once more before the result is shown.
	ui.show_hand_and_resources(state)

	var banner: String = "\n══ VICTORY ══" if victory else "\n══ DEFEAT ══"
	var color: String = ColorUtils.COLOR_ALLY if victory else ColorUtils.COLOR_ENEMY
	ui.show_message(ColorUtils.colorize(banner, color))
	EventBus.game_over.emit(victory)
	await ui.show_battle_result(victory)


## Empties every ally's and enemy's Moxie gauge.
func _clear_all_moxie() -> void:
	for ally: Unit in state.allies:
		ally.clear_moxie()
	for enemy: Unit in state.enemies:
		enemy.clear_moxie()


## True while a later wave still exists to spawn after the current one.
func _has_remaining_waves() -> bool:
	return state.current_wave + 1 < state.wave_definitions.size()


## True when the final wave has been cleared, i.e. the battle is won: no enemy is
## alive and there is no next wave to advance into.
func _is_final_wave_cleared() -> bool:
	return state.all_enemies_dead() and not _has_remaining_waves()
#endregion


#region Cleanup
## Step 8 of the round loop: every buff/debuff ticks exactly once per round.
## "duration" statuses (Regeneration) apply their effect then count down,
## "stacks" statuses (Gloom) keep their stacks and hit their owner for
## one HP per stack (true damage, so shields never absorb it).
func _end_of_turn_cleanup() -> void:
	var ticked_units: Array[Unit] = []
	ticked_units.append_array(state.allies)
	ticked_units.append_array(state.enemies)

	var header_shown: bool = false
	for unit: Unit in ticked_units:
		if unit.is_dead:
			continue
		var events: Array[Dictionary] = unit.tick_round_end_statuses()
		if events.is_empty():
			continue
		if not header_shown:
			ui.show_message("\n" + ColorUtils.colorize("── End of Round ──", ColorUtils.COLOR_HEADER))
			header_shown = true
		for event: Dictionary in events:
			_log_status_event(unit, event)


## Formats one status tick result and mirrors it onto the EventBus. The tick's numbers
## are read back out of the event Dictionary, so they arrive as Variants.
func _log_status_event(unit: Unit, event: Dictionary) -> void:
	var status_id: String = str(event.get("status_id", ""))
	var kind: String = str(event.get("kind", ""))
	var amount: int = TelemetrySchema.to_int(event.get("amount", 0))
	var count: int = TelemetrySchema.to_int(event.get("count", 0))
	var unit_name: String = ColorUtils.unit_name(unit.data.display_name, unit.is_ally)
	var label: String = ColorUtils.colorize(status_id.capitalize(), ColorUtils.COLOR_HEADER)

	match kind:
		"heal":
			var healed_str: String = ColorUtils.stat_value(amount)
			var hp_str: String = ColorUtils.stat_value(unit.current_hp)
			ui.show_message("  %s: %s restores %s HP (HP: %s, %d round(s) left)" % [
				label, unit_name, healed_str, hp_str, maxi(0, count - 1)
			])
			EventBus.unit_healed.emit(unit, amount)
		"damage":
			var lost_str: String = ColorUtils.stat_value(amount)
			var hurt_hp_str: String = ColorUtils.stat_value(unit.current_hp)
			ui.show_message("  %s: %s loses %s HP (HP: %s, %d stack(s))" % [
				label, unit_name, lost_str, hurt_hp_str, count
			])
			# Tell telemetry which status is dealing the hit, so a death by a
			# damage-over-time tick is attributed to that status rather than
			# being recorded as a mysterious unknown.
			telemetry.begin_status_tick(status_id)
			EventBus.damage_dealt.emit(unit, unit, count, amount)
			if unit.is_dead:
				ui.show_message(ColorUtils.colorize("  %s is defeated by %s!" % [
					unit.data.display_name, status_id.capitalize()
				], ColorUtils.COLOR_DEAD))
				EventBus.unit_died.emit(unit)
			telemetry.end_status_tick()
		"expired":
			ui.show_message("  %s: %s expired on %s." % [
				label, status_id.capitalize(), unit_name
			])
	EventBus.unit_statuses_changed.emit(unit)

#endregion
