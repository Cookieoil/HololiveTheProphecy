class_name DebugCommandRunner
extends RefCounted
## Tester-only mutations behind the in-game Debug menu (Scenes/HUD/DebugMenuPopup.gd).
##
## Extracted from Managers/GameManager.gd, which had grown a 360-line tester toolset
## inside the turn loop. The split keeps the loop readable and lets this table be read
## (and tested) on its own, while GameManager stays the authority that applies it:
## a command is still applied *inside* the normal player-action loop, so the loop
## refreshes the hand/HUD itself and re-awaits input exactly like it does for a real
## action, and a debug tool can never mutate the model behind the loop's back.
##
## Two of the tools need machinery only the turn loop owns - re-rolling the enemy
## intents and re-spawning the current wave. Rather than reach back into the manager
## (which would be a cycle), this runner *asks* for them with a signal, the same
## request pattern the Debug panel itself uses. GameManager connects both in `_ready`.
##
## `state` and `ui` are passed to `apply()` instead of being stored, so the runner has
## no lifetime of its own and cannot hold a stale board between turns. That is also
## what lets a test drive a command without running `setup_game()` first.
##
## Command ids are the CMD_* constants on DebugMenuPopup; the two lists stay in sync.
##
## @author TheGreatJellyfish
## @version 11/28/2026

#region Signals
## The command needs the enemy intents re-rolled (and the new ones shown).
signal intents_reroll_requested
## The command needs the current wave re-spawned (and the board redrawn).
signal wave_respawn_requested
#endregion

#region Constants
## Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a
## four-digit cap.
const HAND_CAP_LIMIT: int = 20
## Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope
## without this runner having to reference a UI class.
const SCOPE_ALLIES: int = 0
const SCOPE_ENEMIES: int = 1
const SCOPE_ALL: int = 2
## Result-screen preview requested by the Debug menu: 0 = none, 1 = Victory,
## 2 = Defeat. The panel only asks; the player-action loop applies it, so a preview
## leaves the battle through exactly the same exit a real ending uses.
const RESULT_NONE: int = 0
const RESULT_VICTORY: int = 1
const RESULT_DEFEAT: int = 2
#endregion

#region Public Variables
## Result-screen preview this run asked for, read and cleared by the player-action
## loop (see GameManager._player_action_phase). `RESULT_NONE` when there is none.
var result_request: int = RESULT_NONE
#endregion

#region Public Methods
## Applies one tester tool. The caller has already decided the build is allowed to run
## tools (GameManager owns that gate), so this only mutates and reports.
##
## The table is split by what a command touches - the hand and the resources, a unit,
## or the turn loop - so each list stays short enough to read at a glance and adding a
## tool does not push one function over the repository's size ceiling.
## @param action - { "command": String, "args": Dictionary }
func apply(action: Dictionary, state: GameState, ui: GameUI) -> void:
	var command: String = str(action.get("command", ""))
	var args: Dictionary = _to_dict(action.get("args", {}))
	if _apply_hand_command(command, args, state, ui):
		return
	if _apply_unit_command(command, args, state, ui):
		return
	if _apply_loop_command(command, args, state, ui):
		return
	log_line(ui, "Unknown debug command '%s'." % command)
#endregion


#region Private Methods
## The hand, deck and resource tools: everything that changes what the player is
## holding or what they can spend. Returns false when the command is not one of them.
func _apply_hand_command(command: String, args: Dictionary, state: GameState, ui: GameUI) -> bool:
	match command:
		"spawn_random":
			_spawn_random(state, ui, _to_int(args.get("count", 1), 1))
		"spawn_custom":
			_spawn_custom(state, ui, _to_int(args.get("value", 3), 3), _to_int(args.get("tier", 0), 0))
		"draw":
			_draw(state, ui, state.draw_n_cards(maxi(0, _to_int(args.get("count", 1), 1))))
		"draw_to_max":
			_draw(state, ui, state.draw_cards_to_limit())
		"buff_hand":
			_buff_hand(state, ui, _to_int(args.get("amount", 1), 1))
		"discard_random":
			_discard_random(state, ui)
		"clear_hand":
			_clear_hand(state, ui)
		"grant_actions":
			state.actions_left += _to_int(args.get("amount", 1), 1)
			log_line(ui, "Actions: %d, Merges: %d" % [state.actions_left, state.merges_left])
		"grant_merges":
			state.merges_left += _to_int(args.get("amount", 1), 1)
			log_line(ui, "Actions: %d, Merges: %d" % [state.actions_left, state.merges_left])
		"step_max_hand":
			var cap_delta: int = _to_int(args.get("delta", 1), 1)
			state.max_hand_size = clampi(state.max_hand_size + cap_delta, 1, HAND_CAP_LIMIT)
			log_line(ui, "Hand cap: %d card(s)." % state.max_hand_size)
		"grant_next_bonus":
			state.next_skill_bonus += _to_int(args.get("amount", 1), 1)
			log_line(ui, "Next skill bonus: +%d" % state.next_skill_bonus)
		_:
			return false
	return true


## The unit tools: HP, shield, Moxie and statuses on a resolved target set. Returns
## false when the command is not one of them.
func _apply_unit_command(command: String, args: Dictionary, state: GameState, ui: GameUI) -> bool:
	match command:
		"step_dice":
			_step_dice(state, ui, args)
		"fill_moxie":
			_set_moxie(ui, _targets(state, args), true)
		"drain_moxie":
			_set_moxie(ui, _targets(state, args), false)
		"heal_full":
			_heal(ui, _targets(state, args))
		"damage":
			_damage(ui, _targets(state, args), _to_int(args.get("amount", 1), 1), false)
		"true_damage":
			_damage(ui, _targets(state, args), _to_int(args.get("amount", 1), 1), true)
		"add_shield":
			_shield(ui, _targets(state, args), _to_int(args.get("amount", 1), 1))
		"clear_shield":
			_clear_shield(ui, _targets(state, args))
		"kill":
			_kill(ui, _targets(state, args))
		"apply_status":
			_apply_status(
				ui, _targets(state, args),
				str(args.get("status_id", "")),
				_to_int(args.get("amount", 1), 1)
			)
		"clear_statuses":
			_clear_statuses(ui, _targets(state, args))
		"clear_wave":
			# Let the turn loop's own all-enemies-dead check advance the wave or
			# declare victory, so this needs no wave code of its own.
			_kill(ui, state.get_living_enemies())
		_:
			return false
	return true


## The tools that act on the turn machine rather than on a unit: the intents, the wave,
## the result screen and the flag registry. Returns false when the command is not one
## of them.
func _apply_loop_command(command: String, args: Dictionary, state: GameState, ui: GameUI) -> bool:
	match command:
		"reroll_intents":
			intents_reroll_requested.emit()
			log_line(ui, "Rerolled the enemy intents.")
		"respawn_wave":
			wave_respawn_requested.emit()
			log_line(ui, "Respawned wave %d." % (state.current_wave + 1))
		"show_victory":
			result_request = RESULT_VICTORY
			log_line(ui, "Previewing the Victory cutscene.")
		"show_defeat":
			result_request = RESULT_DEFEAT
			log_line(ui, "Previewing the Defeat cutscene.")
		"set_flag":
			log_line(ui, state.debug_set_flag(args))
		_:
			return false
	return true
#endregion


## Writes one-line confirmation into the message log, so a tester can see what a tool
## did. (Named `log_line` because `log()` is Godot's built-in logarithm.)
func log_line(ui: GameUI, message: String) -> void:
	ui.show_message(ColorUtils.colorize("[debug] ", ColorUtils.COLOR_HEADER) + message)
#endregion


#region Private Methods
## Coerces a debug-command argument into an int: the tester tools receive their values
## from UI controls and dictionaries, either of which can hold a float.
func _to_int(value: Variant, fallback: int) -> int:
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


## Coerces a Variant into a Dictionary (payloads cross the UI boundary as Variant).
func _to_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dict: Dictionary = value
		return dict
	return {}


## Resolves a { "scope": int, "slot": int } payload into the affected units.
## slot >= 0 always means one specific slot of its own row; slot -1 means the whole
## scope. A payload with no target selects the ally row only, so a malformed command
## can never sweep the whole board.
func _targets(state: GameState, args: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	var scope: int = _to_int(args.get("scope", SCOPE_ALLIES), SCOPE_ALLIES)
	var slot: int = _to_int(args.get("slot", -1), -1)

	if slot >= 0:
		var row: Array[Unit] = state.allies if scope == SCOPE_ALLIES else state.enemies
		if slot < row.size():
			result.append(row[slot])
		return result

	if scope == SCOPE_ALLIES or scope == SCOPE_ALL:
		result.append_array(state.allies)
	if scope == SCOPE_ENEMIES or scope == SCOPE_ALL:
		result.append_array(state.enemies)
	return result


## Steps the dice size and re-rolls straight away, so the tester sees the new size now
## instead of having to wait for the next turn.
func _step_dice(state: GameState, ui: GameUI, args: Dictionary) -> void:
	state.dice_size_modifier += _to_int(args.get("delta", 1), 1)
	log_line(ui, "Dice size modifier: %+d (next rolls use d%d)." % [
		state.dice_size_modifier, state.get_dice_size(state.turn_number)
	])
	intents_reroll_requested.emit()


## "Striker 12/12, Healer 8/10" - the HP line every unit tool reports.
func _hp_summary(units: Array[Unit]) -> String:
	var parts := PackedStringArray()
	for unit: Unit in units:
		parts.append("%s %d/%d" % [unit.data.display_name, unit.current_hp, unit.max_hp])
	return ", ".join(parts)


func _spawn_random(state: GameState, ui: GameUI, count: int) -> void:
	var spawned: int = 0
	for _i: int in maxi(0, count):
		state.hand.append(state.spawn_debug_card(state.rng.randi_range(1, 6)))
		spawned += 1
	if spawned == 0:
		return
	log_line(ui, "Spawned %d random card(s). Hand %d / %d." % [
		spawned, state.hand.size(), state.max_hand_size
	])


func _spawn_custom(state: GameState, ui: GameUI, value: int, tier: int) -> void:
	# tier: 0 = base V, 1 = merged MV, 2 = double-merged DMV
	var card: Card = state.spawn_debug_card(value, tier >= 1, tier >= 2)
	state.hand.append(card)
	log_line(ui, "Spawned %s%s. Hand %d / %d." % [
		str(card.get_effective_value()),
		card.get_suffix(),
		state.hand.size(),
		state.max_hand_size,
	])


func _draw(state: GameState, ui: GameUI, drawn: Array[Card]) -> void:
	if drawn.is_empty():
		log_line(ui, "Nothing left to draw (deck and discard are both empty).")
		return
	log_line(ui, "Drew %d card(s). Hand %d / %d." % [
		drawn.size(), state.hand.size(), state.max_hand_size
	])


func _buff_hand(state: GameState, ui: GameUI, amount: int) -> void:
	if state.hand.is_empty():
		log_line(ui, "Hand is empty, nothing to buff.")
		return
	for card: Card in state.hand:
		var before: int = card.get_effective_value()
		card.value_buff += amount
		# CardUI re-renders the number on this signal.
		EventBus.card_value_changed.emit(card, before, card.get_effective_value())
	log_line(ui, "Buffed %d card(s) by +%d." % [state.hand.size(), amount])


func _discard_random(state: GameState, ui: GameUI) -> void:
	if state.hand.is_empty():
		log_line(ui, "Hand is empty, nothing to discard.")
		return
	var index: int = state.rng.randi_range(0, state.hand.size() - 1)
	var card: Card = state.hand[index]
	state.discard_card(card)
	log_line(ui, "Discarded %s from hand." % ColorUtils.colorize(
		str(card.get_effective_value()) + card.get_suffix(), ColorUtils.COLOR_CARD
	))


func _clear_hand(state: GameState, ui: GameUI) -> void:
	if state.hand.is_empty():
		log_line(ui, "Hand is already empty.")
		return
	var cleared: int = state.hand.size()
	for card: Card in state.hand.duplicate():
		state.discard_card(card)
	log_line(ui, "Discarded %d card(s) from hand." % cleared)


func _set_moxie(ui: GameUI, units: Array[Unit], fill: bool) -> void:
	for unit: Unit in units:
		unit.set_moxie(unit.max_moxie if fill else 0)
		EventBus.moxie_changed.emit(unit, unit.moxie, unit.max_moxie)
	log_line(ui,
		("Filled Moxie (Ultimates ready) on %d unit(s)." if fill else "Zeroed Moxie on %d unit(s).")
		% units.size()
	)


func _heal(ui: GameUI, units: Array[Unit]) -> void:
	for unit: Unit in units:
		var restored: int = unit.heal(unit.max_hp)
		if restored > 0:
			EventBus.unit_healed.emit(unit, restored)
	log_line(ui, "Full heal -> %s" % _hp_summary(units))


func _damage(ui: GameUI, units: Array[Unit], amount: int, true_damage: bool) -> void:
	for unit: Unit in units:
		var lost: int = unit.deal_true_damage(amount) if true_damage else unit.take_damage(amount)
		if lost > 0:
			EventBus.damage_dealt.emit(unit, unit, amount, lost)
		if unit.is_dead:
			EventBus.unit_died.emit(unit)
	log_line(ui, "%s %d -> %s" % [
		"True damage" if true_damage else "Damage", amount, _hp_summary(units)
	])


func _shield(ui: GameUI, units: Array[Unit], amount: int) -> void:
	for unit: Unit in units:
		var gained: int = unit.gain_shield(amount)
		if gained > 0:
			EventBus.shield_gained.emit(unit, gained)
	log_line(ui, "Shield +%d -> %s" % [amount, _hp_summary(units)])


func _clear_shield(ui: GameUI, units: Array[Unit]) -> void:
	for unit: Unit in units:
		var removed: int = unit.reduce_shield(unit.shield)
		if removed > 0:
			EventBus.shield_reduced.emit(unit, removed)
	log_line(ui, "Cleared shield on %d unit(s)." % units.size())


func _kill(ui: GameUI, units: Array[Unit]) -> void:
	var killed: int = 0
	for unit: Unit in units:
		if unit.is_dead:
			continue
		unit.deal_true_damage(unit.current_hp)
		unit.reset_shield()
		EventBus.unit_died.emit(unit)
		killed += 1
	if killed == 0:
		log_line(ui, "Nothing to defeat: the target is already down.")
		return
	log_line(ui, "Defeated %d unit(s)." % killed)


func _apply_status(ui: GameUI, units: Array[Unit], status_id: String, amount: int) -> void:
	var applied: int = 0
	for unit: Unit in units:
		if unit.apply_status(status_id, amount) > 0:
			EventBus.unit_statuses_changed.emit(unit)
			applied += 1
	if applied == 0:
		log_line(ui, "No %s applied (defeated units reject statuses)." % status_id)
		return
	log_line(ui, "%s +%d on %d unit(s)." % [status_id.capitalize(), amount, applied])


func _clear_statuses(ui: GameUI, units: Array[Unit]) -> void:
	for unit: Unit in units:
		unit.clear_statuses()
		EventBus.unit_statuses_changed.emit(unit)
	log_line(ui, "Cleared statuses on %d unit(s)." % units.size())
#endregion
