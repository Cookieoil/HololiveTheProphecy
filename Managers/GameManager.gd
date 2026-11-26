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

#region Constants
## JSON/config string -> WaveTransition (config.json stores readable names).
const WAVE_MODE_MAP: Dictionary = {
	"full_turn": GameState.WaveTransition.FULL_TURN,
	"immediate_skip": GameState.WaveTransition.IMMEDIATE_SKIP,
}

## Fraction of an enemy's skill animation that plays before the next enemy may
## start its own. Below 1.0 the previous enemy's wind-down overlaps the next
## one's wind-up (the "fast mode" feel), so a three-enemy phase no longer costs
## three full animation tails back to back. 1.0 restores strictly sequential
## turns. Enemy Ultimates always play in full, so the dramatic beat stays intact.
const ENEMY_SKILL_OVERLAP_LEAD: float = 0.6
#endregion

#region Helpers
func _color_unit(unit: Unit) -> String:
	var col: String = ColorUtils.COLOR_ALLY if unit.is_ally else ColorUtils.COLOR_ENEMY
	return ColorUtils.colorize(unit.data.display_name, col)

func _color_value(value: int, type: String = "hp") -> String:
	var col: String = ColorUtils.COLOR_HP if type == "hp" else ColorUtils.COLOR_SHIELD
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
	p_ui: GameUI,
	config: Dictionary = {}
) -> void:
	state = GameState.new()
	ui = p_ui
	_apply_config(config)

	state.wave_definitions = wave_defs
	# Initialize allies
	state.initialize_allies(ally_data)
	# Initialize enemies
	_spawn_wave(0)
	state.build_deck() # decklist already set by _apply_config

	game_running = true
	await _run_game_loop()

func _apply_config(config: Dictionary) -> void:
	if config.is_empty():
		return
	state.max_hand_size = maxi(1, _config_int(config, "hand_size", GameState.MAX_HAND_SIZE))
	state.actions_per_turn = maxi(0, _config_int(config, "actions_per_turn", GameState.ACTIONS_PER_TURN))
	state.merges_per_turn = maxi(0, _config_int(config, "merges_per_turn", GameState.MERGES_PER_TURN))

	var decklist: Array = _config_decklist(config)
	if not decklist.is_empty():
		state.CURRENT_DECKLIST = decklist

	var progression: Array[int] = _config_int_list(config, "dice_progression")
	if not progression.is_empty():
		state.set_dice_progression(progression)

	if config.has("wave_transition_mode"):
		var mode_key: String = str(config["wave_transition_mode"]).strip_edges().to_lower()
		var wave_mode: int = WAVE_MODE_MAP.get(mode_key, GameState.WaveTransition.FULL_TURN)
		state.wave_transition_mode = wave_mode


## Reads an int config entry. JSON always parses numbers as float, so the value
## is coerced instead of assigned straight into a typed int field.
func _config_int(config: Dictionary, key: String, fallback: int) -> int:
	return _coerce_int(config.get(key, fallback), fallback)


## Coerces any JSON scalar (float, int, bool, String) into an int.
func _coerce_int(value: Variant, fallback: int) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is bool:
		var bool_value: bool = value
		return 1 if bool_value else 0
	if value is String:
		var text: String = value
		if text.is_valid_int():
			return text.to_int()
		if text.is_valid_float():
			return int(text.to_float())
	return fallback


## Coerces the JSON decklist ([[value, count], ...]) into typed int pairs.
func _config_decklist(config: Dictionary) -> Array:
	var parsed: Array = []
	var raw_list: Variant = config.get("decklist", [])
	if not (raw_list is Array):
		return parsed
	var entries: Array = raw_list
	for entry: Variant in entries:
		if not (entry is Array):
			continue
		var pair: Array = entry
		if pair.size() < 2:
			continue
		var card_value: int = _coerce_int(pair[0], 0)
		var card_count: int = _coerce_int(pair[1], 0)
		if card_count <= 0:
			continue
		parsed.append([card_value, card_count])
	return parsed


## Coerces a JSON array of numbers into a typed int array.
func _config_int_list(config: Dictionary, key: String) -> Array[int]:
	var parsed: Array[int] = []
	var raw_list: Variant = config.get(key, [])
	if not (raw_list is Array):
		return parsed
	var entries: Array = raw_list
	for entry: Variant in entries:
		parsed.append(_coerce_int(entry, 0))
	return parsed
		
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
func _run_game_loop() -> void:
	if state.turn_number == 0 and not instructions_shown:
		_show_instructions()
		instructions_shown = true
	
	while game_running:
		EventBus.turn_started.emit(state.turn_number)
		var turn_header: String = ColorUtils.colorize("╔══ TURN %d ══╗" % (state.turn_number + 1), ColorUtils.COLOR_HEADER)
		if state.turn_number == 0:
			ui.show_message("\n" + turn_header)
		else:
			ui.show_message("\n\n" + turn_header)

		# ── Step 1: Roll enemy intents ──
		_roll_enemy_intents()
		ui.show_enemy_intents(current_intents)

		# ── Step 2: Reset ally shields & temp effects ──
		for ally: Unit in state.allies:
			ally.ult_used_this_turn = false
			if not ally.is_dead:
				ally.reset_shield()
		for enemy: Unit in state.enemies:
			enemy.ult_used_this_turn = false

		# ── Step 3: Draw to hand limit ──
		var drawn: Array[Card] = state.draw_cards_to_limit()
		if not drawn.is_empty():
			var count_str: String = ColorUtils.colorize(str(drawn.size()), ColorUtils.COLOR_CARD)
			ui.show_message("Drew %s card(s)." % count_str)

		# ── Step 4: Player action phase (async) ──
		state.actions_left = state.actions_per_turn
		state.merges_left = state.merges_per_turn
		state.next_skill_bonus = 0
		await _player_action_phase()

		# ── Step 5: Cleanup played cards ──
		state.end_player_turn_cleanup()

		# Check for wave clear before enemy turn. A wave with no successor ends the
		# battle right here: the player's own action just won it, so there is no
		# enemy turn left to resolve and no next turn to start.
		if state.all_enemies_dead():
			if _try_advance_wave():
				state.turn_number += 1
				continue # loop to next turn (enemies skip this turn)
			await _finish_battle(true)
			break

		# ── Step 6: Reset enemy shields & temp effects ──
		for enemy: Unit in state.enemies:
			if not enemy.is_dead:
				enemy.reset_shield()

		# ── Step 7: Enemy turn  (async — skills may log) ──
		await _resolve_enemy_turns()
		
		# Post-turn checks
		if state.all_allies_dead():
			await _finish_battle(false)
			break
		
		if state.all_enemies_dead():
			if not _try_advance_wave():
				await _finish_battle(true)
				break
				
		# ── Step 8: Clean up (statuses tick once per round) ──
		_end_of_turn_cleanup()

		# A status tick can finish off the last unit, so re-check the outcome.
		if state.all_allies_dead():
			await _finish_battle(false)
			break

		if state.all_enemies_dead():
			if _try_advance_wave():
				state.turn_number += 1
				continue
			await _finish_battle(true)
			break

		state.turn_number += 1
		
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
		var action: Dictionary = await ui.get_player_action(state)
		var action_type: String = str(action.get("type", ""))
	
		match action_type:
			"play":
				var play_card: Card = action["card"]
				var target_ally: Unit = action["target_ally"]
				await _handle_play(play_card, target_ally)
				if _resolve_enemy_clear_after_action():
					break # final wave cleared: the battle is won
				
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
					break
				
			"stats":
				ui.show_game_state(state)
				
			"hand":
				pass

			"debug":
				_handle_debug_command(action)
				# A debug tool can clear a wave (or finish off the last enemy), so
				# run the exact same wave check the "play" branch does instead of
				# inventing a second path for it.
				if _resolve_enemy_clear_after_action():
					break
				
			"end_turn":
				ui.show_message("Ending player turn.")
				break
			_:
				ui.show_message("Unknown action.")
				
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
	var ally_str: String = _color_unit(ally)
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
		ui.show_message("  %s → %s" % [_color_unit(ally), moxie_str])
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

	var ally_str: String = _color_unit(ally)
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
	state.merges_left -= 1
	# Presentation first: the hand plays the merge, then the counters refresh. The
	# merged card is reused by that refresh, so the merge is not interrupted by it.
	ui.on_cards_merged(a, b, result, state)
	var result_str: String = _color_card_value(result)
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
## Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a
## four-digit cap.
const DEBUG_HAND_CAP_LIMIT: int = 20
## Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope
## without this manager having to reference a UI class.
const DEBUG_SCOPE_ALLIES: int = 0
const DEBUG_SCOPE_ENEMIES: int = 1
const DEBUG_SCOPE_ALL: int = 2
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

## Tester-only mutations behind the in-game Debug menu (scenes/HUD/DebugMenuPopup.gd).
##
## They are applied *inside* the normal player-action loop rather than by the UI: the
## loop then refreshes the hand/HUD itself and re-awaits input, exactly like it does
## for a real action. That is what keeps `current_intents`, the wave machine and the
## HUD in step — a debug tool never mutates the model behind the loop's back.
##
## Command ids are the CMD_* constants on DebugMenuPopup; the two lists stay in sync.
## @param action - { "command": String, "args": Dictionary }
func _handle_debug_command(action: Dictionary) -> void:
	# A release build refuses every tool here, not just in the UI: the turn loop is
	# the authority, so hiding the overlay is not the only line of defence.
	if not debug_tools_enabled():
		_debug_log("Debug tools are disabled in release builds.")
		return
	var command: String = str(action.get("command", ""))
	var args: Dictionary = _coerce_dict(action.get("args", {}))

	match command:
		"spawn_random":
			_debug_spawn_random(_coerce_int(args.get("count", 1), 1))
		"spawn_custom":
			_debug_spawn_custom(
				_coerce_int(args.get("value", 3), 3),
				_coerce_int(args.get("tier", 0), 0)
			)
		"draw":
			_debug_draw(state.draw_n_cards(maxi(0, _coerce_int(args.get("count", 1), 1))))
		"draw_to_max":
			_debug_draw(state.draw_cards_to_limit())
		"buff_hand":
			_debug_buff_hand(_coerce_int(args.get("amount", 1), 1))
		"discard_random":
			_debug_discard_random()
		"clear_hand":
			_debug_clear_hand()
		"grant_actions":
			state.actions_left += _coerce_int(args.get("amount", 1), 1)
			_debug_log("Actions: %d, Merges: %d" % [state.actions_left, state.merges_left])
		"grant_merges":
			state.merges_left += _coerce_int(args.get("amount", 1), 1)
			_debug_log("Actions: %d, Merges: %d" % [state.actions_left, state.merges_left])
		"step_max_hand":
			var cap_delta: int = _coerce_int(args.get("delta", 1), 1)
			state.max_hand_size = clampi(state.max_hand_size + cap_delta, 1, DEBUG_HAND_CAP_LIMIT)
			_debug_log("Hand cap: %d card(s)." % state.max_hand_size)
		"grant_next_bonus":
			state.next_skill_bonus += _coerce_int(args.get("amount", 1), 1)
			_debug_log("Next skill bonus: +%d" % state.next_skill_bonus)
		"step_dice":
			state.dice_size_modifier += _coerce_int(args.get("delta", 1), 1)
			_debug_log("Dice size modifier: %+d (next rolls use d%d)." % [
				state.dice_size_modifier, state.get_dice_size(state.turn_number)
			])
			# Re-roll so the tester sees the new dice size immediately instead of
			# waiting for the next turn.
			_roll_enemy_intents()
			ui.show_enemy_intents(current_intents)
		"fill_moxie":
			_debug_set_moxie(_debug_targets(args), true)
		"drain_moxie":
			_debug_set_moxie(_debug_targets(args), false)
		"heal_full":
			_debug_heal(_debug_targets(args))
		"damage":
			_debug_damage(_debug_targets(args), _coerce_int(args.get("amount", 1), 1), false)
		"true_damage":
			_debug_damage(_debug_targets(args), _coerce_int(args.get("amount", 1), 1), true)
		"add_shield":
			_debug_shield(_debug_targets(args), _coerce_int(args.get("amount", 1), 1))
		"clear_shield":
			_debug_clear_shield(_debug_targets(args))
		"kill":
			_debug_kill(_debug_targets(args))
		"apply_status":
			_debug_apply_status(
				_debug_targets(args),
				str(args.get("status_id", "")),
				_coerce_int(args.get("amount", 1), 1)
			)
		"clear_statuses":
			_debug_clear_statuses(_debug_targets(args))
		"reroll_intents":
			_roll_enemy_intents()
			ui.show_enemy_intents(current_intents)
			_debug_log("Rerolled the enemy intents.")
		"respawn_wave":
			_spawn_wave(state.current_wave)
			ui.show_game_state(state)
			_roll_enemy_intents()
			ui.show_enemy_intents(current_intents)
			_debug_log("Respawned wave %d." % (state.current_wave + 1))
		"clear_wave":
			# Let the turn loop's own all-enemies-dead check advance the wave or
			# declare victory, so this needs no wave code of its own.
			_debug_kill(state.get_living_enemies())
		_:
			_debug_log("Unknown debug command '%s'." % command)


## Coerces a Variant into a Dictionary (payloads cross the UI boundary as Variant).
func _coerce_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dict: Dictionary = value
		return dict
	return {}


## Resolves a { "scope": int, "slot": int } payload into the affected units.
## slot >= 0 always means one specific slot of its own row; slot -1 means the whole
## scope. A payload with no target selects the ally row only, so a malformed command
## can never sweep the whole board.
func _debug_targets(args: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	var scope: int = _coerce_int(args.get("scope", DEBUG_SCOPE_ALLIES), DEBUG_SCOPE_ALLIES)
	var slot: int = _coerce_int(args.get("slot", -1), -1)

	if slot >= 0:
		var row: Array[Unit] = state.allies if scope == DEBUG_SCOPE_ALLIES else state.enemies
		if slot < row.size():
			result.append(row[slot])
		return result

	if scope == DEBUG_SCOPE_ALLIES or scope == DEBUG_SCOPE_ALL:
		result.append_array(state.allies)
	if scope == DEBUG_SCOPE_ENEMIES or scope == DEBUG_SCOPE_ALL:
		result.append_array(state.enemies)
	return result


## One-line confirmation in the message log, so a tester can see what a tool did.
func _debug_log(message: String) -> void:
	ui.show_message(ColorUtils.colorize("[debug] ", ColorUtils.COLOR_HEADER) + message)


## "Striker 12/12, Healer 8/10" — the HP line every unit tool reports.
func _debug_hp_summary(units: Array[Unit]) -> String:
	var parts := PackedStringArray()
	for unit: Unit in units:
		parts.append("%s %d/%d" % [unit.data.display_name, unit.current_hp, unit.max_hp])
	return ", ".join(parts)


func _debug_spawn_random(count: int) -> void:
	var spawned: int = 0
	for _i: int in maxi(0, count):
		state.hand.append(state.spawn_debug_card(randi_range(1, 6)))
		spawned += 1
	if spawned == 0:
		return
	_debug_log("Spawned %d random card(s). Hand %d / %d." % [
		spawned, state.hand.size(), state.max_hand_size
	])


func _debug_spawn_custom(value: int, tier: int) -> void:
	# tier: 0 = base V, 1 = merged MV, 2 = double-merged DMV
	var card: Card = state.spawn_debug_card(value, tier >= 1, tier >= 2)
	state.hand.append(card)
	_debug_log("Spawned %s%s. Hand %d / %d." % [
		str(card.get_effective_value()),
		card.get_suffix(),
		state.hand.size(),
		state.max_hand_size,
	])


func _debug_draw(drawn: Array[Card]) -> void:
	if drawn.is_empty():
		_debug_log("Nothing left to draw (deck and discard are both empty).")
		return
	_debug_log("Drew %d card(s). Hand %d / %d." % [
		drawn.size(), state.hand.size(), state.max_hand_size
	])


func _debug_buff_hand(amount: int) -> void:
	if state.hand.is_empty():
		_debug_log("Hand is empty, nothing to buff.")
		return
	for card: Card in state.hand:
		var before: int = card.get_effective_value()
		card.value_buff += amount
		# CardUI re-renders the number on this signal.
		EventBus.card_value_changed.emit(card, before, card.get_effective_value())
	_debug_log("Buffed %d card(s) by +%d." % [state.hand.size(), amount])


func _debug_discard_random() -> void:
	if state.hand.is_empty():
		_debug_log("Hand is empty, nothing to discard.")
		return
	var index: int = randi_range(0, state.hand.size() - 1)
	var card: Card = state.hand[index]
	state.discard_card(card)
	_debug_log("Discarded %s from hand." % ColorUtils.colorize(
		str(card.get_effective_value()) + card.get_suffix(), ColorUtils.COLOR_CARD
	))


func _debug_clear_hand() -> void:
	if state.hand.is_empty():
		_debug_log("Hand is already empty.")
		return
	var cleared: int = state.hand.size()
	for card: Card in state.hand.duplicate():
		state.discard_card(card)
	_debug_log("Discarded %d card(s) from hand." % cleared)


func _debug_set_moxie(units: Array[Unit], fill: bool) -> void:
	for unit: Unit in units:
		unit.set_moxie(unit.max_moxie if fill else 0)
		EventBus.moxie_changed.emit(unit, unit.moxie, unit.max_moxie)
	_debug_log(
		("Filled Moxie (Ultimates ready) on %d unit(s)." if fill else "Zeroed Moxie on %d unit(s).")
		% units.size()
	)


func _debug_heal(units: Array[Unit]) -> void:
	for unit: Unit in units:
		var restored: int = unit.heal(unit.max_hp)
		if restored > 0:
			EventBus.unit_healed.emit(unit, restored)
	_debug_log("Full heal -> %s" % _debug_hp_summary(units))


func _debug_damage(units: Array[Unit], amount: int, true_damage: bool) -> void:
	for unit: Unit in units:
		var lost: int = unit.deal_true_damage(amount) if true_damage else unit.take_damage(amount)
		if lost > 0:
			EventBus.damage_dealt.emit(unit, unit, amount, lost)
		if unit.is_dead:
			EventBus.unit_died.emit(unit)
	_debug_log("%s %d -> %s" % [
		"True damage" if true_damage else "Damage", amount, _debug_hp_summary(units)
	])


func _debug_shield(units: Array[Unit], amount: int) -> void:
	for unit: Unit in units:
		var gained: int = unit.gain_shield(amount)
		if gained > 0:
			EventBus.shield_gained.emit(unit, gained)
	_debug_log("Shield +%d -> %s" % [amount, _debug_hp_summary(units)])


func _debug_clear_shield(units: Array[Unit]) -> void:
	for unit: Unit in units:
		var removed: int = unit.reduce_shield(unit.shield)
		if removed > 0:
			EventBus.shield_reduced.emit(unit, removed)
	_debug_log("Cleared shield on %d unit(s)." % units.size())


func _debug_kill(units: Array[Unit]) -> void:
	var killed: int = 0
	for unit: Unit in units:
		if unit.is_dead:
			continue
		unit.deal_true_damage(unit.current_hp)
		unit.reset_shield()
		EventBus.unit_died.emit(unit)
		killed += 1
	if killed == 0:
		_debug_log("Nothing to defeat: the target is already down.")
		return
	_debug_log("Defeated %d unit(s)." % killed)


func _debug_apply_status(units: Array[Unit], status_id: String, amount: int) -> void:
	var applied: int = 0
	for unit: Unit in units:
		if unit.apply_status(status_id, amount) > 0:
			EventBus.unit_statuses_changed.emit(unit)
			applied += 1
	if applied == 0:
		_debug_log("No %s applied (defeated units reject statuses)." % status_id)
		return
	_debug_log("%s +%d on %d unit(s)." % [status_id.capitalize(), amount, applied])


func _debug_clear_statuses(units: Array[Unit]) -> void:
	for unit: Unit in units:
		unit.clear_statuses()
		EventBus.unit_statuses_changed.emit(unit)
	_debug_log("Cleared statuses on %d unit(s)." % units.size())
#endregion


#region Context Builders
func _build_ally_context(ally: Unit, card: Card) -> SkillContext:
	var ctx: SkillContext = SkillContext.new(ally, card, state)

	# Apply turn-wide bonus from Buff Skill 2 merged
	if state.next_skill_bonus > 0:
		ctx.card_value += state.next_skill_bonus
		var bonus_str: String = ColorUtils.colorize("+" + str(state.next_skill_bonus), ColorUtils.COLOR_CARD)
		ui.show_message("  %s bonus value from Buff!" % bonus_str)
		state.next_skill_bonus = 0

	# Pick_n_target:
	ctx.pick_n_target = func(count: int, filter: Callable) -> Array[Unit]:
		var units: Array[Unit] = []
		for u: Unit in state.allies:
			if filter.call(u):
				units.append(u)
		for u: Unit in state.enemies:
			if filter.call(u):
				units.append(u)
		if units.is_empty():
			return []
		return await ui.ask_pick_targets(units, count)
		
	# Pick_n_card:
	ctx.pick_n_card = func(count: int, filter: Callable) -> Array[Card]:
		var units: Array[Card] = []
		for c: Card in state.hand:
			if filter.call(c):
				units.append(c)
		if units.is_empty():
			return []
		return await ui.ask_pick_cards(units, count)

	# Flash_cards: reveal cards the game picked automatically (no prompt shown).
	ctx.flash_cards = func(cards: Array[Card]) -> void:
		if cards.is_empty():
			return
		await ui.flash_auto_selected_cards(cards)
		
	ctx.log_message = func(msg: String) -> void:
		ui.show_message("  " + msg)
	
	return ctx


func _build_enemy_context(enemy: Unit, intent: EnemyIntent) -> SkillContext:
	var ctx: SkillContext = SkillContext.new(enemy, null, state)
	ctx.card_value = intent.effective_value
	ctx.is_merged = intent.condition_met

	# Enemy targeting is random — inject auto-target callables
	ctx.pick_n_target = func(_count: int, _filter: Callable) -> Array[Unit]:
		var target: Array[Unit] = state.get_living_allies()
		target.shuffle()
		var result: Array[Unit] = []
		
		for i: int in mini(_count, target.size()):
			result.append(target[i])
			
		if not result.is_empty():
			var names: Array = result.map(func(t: Unit) -> String: return t.data.display_name)
			var joined: String = ", ".join(PackedStringArray(names))
			var colored: String = ColorUtils.colorize(joined, ColorUtils.COLOR_ALLY)
			ui.show_message(" Targets: %s" % colored)
		return result
	
	ctx.pick_n_card = func(count: int, _filter: Callable) -> Array[Card]:
		# Enemies never get a hand prompt, so auto-pick the top cards and reveal
		# them with the hostile (red) flash, since an enemy caused the change.
		var auto_cards: Array[Card] = state.get_top_n_cards(count)
		if not auto_cards.is_empty():
			await ui.flash_auto_selected_cards(auto_cards, true)
		return auto_cards

	# Flash_cards: reveal cards the game picked automatically (no prompt shown).
	# Enemy-caused changes flash red (hostile) so the player sees the hit.
	ctx.flash_cards = func(cards: Array[Card]) -> void:
		if cards.is_empty():
			return
		await ui.flash_auto_selected_cards(cards, true)
		
	ctx.log_message = func(msg: String) -> void:
		ui.show_message("  " + msg)
	
	return ctx
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
		var roll: int = DiceRoller.roll(dice_sides)
		var intent: EnemyIntent = EnemyIntent.new(enemy, roll)
		current_intents.append(intent)


func _resolve_enemy_turns() -> void:
	for intent: EnemyIntent in current_intents:
		# Hide this enemy's intent the moment its action begins.
		ui.clear_unit_intent(intent.enemy)
	
		if intent.enemy.is_dead:
			continue
			
		var enemy_name: String = _color_unit(intent.enemy)
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
		await _resolve_skill(intent.skill, ctx)
	
		# Use effective_value, matching EnemyIntent's odd/even skill selection.
		var skill_index: int = 1 if intent.effective_value % 2 == 1 else 2
		var rank: int = 1 if intent.condition_met else 0
	
		# Return at the impact beat instead of the end of the animation, so the
		# next enemy starts its attack while this one is still winding down.
		await ui.play_unit_skill(intent.enemy, skill_index, rank, ENEMY_SKILL_OVERLAP_LEAD)
	
		# Clear value modifiers after this enemy's action resolves
		intent.enemy.clear_value_modifier()
		if state.all_allies_dead():
			break
			
		if not intent.enemy.is_dead:
			var gained: int = intent.enemy.gain_moxie(intent.effective_value)
			if gained > 0:
				EventBus.moxie_changed.emit(intent.enemy, intent.enemy.moxie, intent.enemy.max_moxie)
			if intent.enemy.can_cast_ultimate:
				await _execute_enemy_ultimate(intent.enemy)
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
	
	var enemy_name: String = _color_unit(enemy)
	var ult_str: String = ColorUtils.colorize("ULTIMATE: %s" % ult.skill_name, ColorUtils.COLOR_ENEMY)
	ui.show_message("\n%s unleashes %s!" % [enemy_name, ult_str])
	if ult.description != "":
		ui.show_message(ColorUtils.colorize("> " + ult.description, ColorUtils.COLOR_DEAD))
	
	var dummy_intent: EnemyIntent = EnemyIntent.new(enemy, 0)
	var ctx: SkillContext = _build_enemy_context(enemy, dummy_intent)
	ctx.card_value = 0
	ctx.is_merged = false
	
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
func _finish_battle(victory: bool) -> void:
	game_running = false

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


## Formats one status tick result and mirrors it onto the EventBus.
func _log_status_event(unit: Unit, event: Dictionary) -> void:
	var status_id: String = str(event.get("status_id", ""))
	var kind: String = str(event.get("kind", ""))
	var amount: int = _coerce_int(event.get("amount", 0), 0)
	var count: int = _coerce_int(event.get("count", 0), 0)
	var unit_name: String = _color_unit(unit)
	var label: String = ColorUtils.colorize(status_id.capitalize(), ColorUtils.COLOR_HEADER)

	match kind:
		"heal":
			var healed_str: String = _color_value(amount)
			var hp_str: String = _color_value(unit.current_hp)
			ui.show_message("  %s: %s restores %s HP (HP: %s, %d round(s) left)" % [
				label, unit_name, healed_str, hp_str, maxi(0, count - 1)
			])
			EventBus.unit_healed.emit(unit, amount)
		"damage":
			var lost_str: String = _color_value(amount)
			var hurt_hp_str: String = _color_value(unit.current_hp)
			ui.show_message("  %s: %s loses %s HP (HP: %s, %d stack(s))" % [
				label, unit_name, lost_str, hurt_hp_str, count
			])
			EventBus.damage_dealt.emit(unit, unit, count, amount)
			if unit.is_dead:
				ui.show_message(ColorUtils.colorize("  %s is defeated by %s!" % [
					unit.data.display_name, status_id.capitalize()
				], ColorUtils.COLOR_DEAD))
				EventBus.unit_died.emit(unit)
		"expired":
			ui.show_message("  %s: %s expired on %s." % [
				label, status_id.capitalize(), unit_name
			])
	EventBus.unit_statuses_changed.emit(unit)

#endregion
