class_name TextGameUI
extends GameUI
## Text-based implementation of GameUI.
## Uses RichTextLabel + LineEdit for console-style interaction.
## Attach this as a child Node of your test scene.
##
## @author TheGreatJellyfish
## @version 5/17/2026

@onready var output: RichTextLabel = $Output
@onready var input: LineEdit = $Input

signal _input_submitted(text: String)


func _ready() -> void:
	input.text_submitted.connect(_on_input_text_submitted)


func _on_input_text_submitted(text: String) -> void:
	input.clear()
	_print("> %s" % text)
	_input_submitted.emit(text)


#region Display
func _print(text: String) -> void:
	if output:
		output.append_text(text + "\n")
	else:
		print(text)

func show_message(text: String) -> void:
	_print(text)

func show_game_state(state: GameState) -> void:
	_print("=== TURN %d | Actions: %d | Merges: %d ===" % [
		state.turn_number, state.actions_left, state.merges_left])
	_print("-- Allies --")
	for u in state.allies:
		_print("  [%d] %s" % [u.slot_index, u])
	_print("-- Enemies --")
	for u in state.enemies:
		_print("  [%d] %s" % [u.slot_index, u])
	show_hand(state.hand)

func show_hand(hand: Array[Card]) -> void:
	_print("-- Hand (%d cards) --" % hand.size())
	for i in hand.size():
		_print("  [%d] %s" % [i, hand[i]])

func show_enemy_intents(intents: Array[EnemyIntent]) -> void:
	_print("-- Enemy Intents --")
	for intent in intents:
		_print("  %s" % intent)
#endregion


#region Async Input Helpers
## Wait for player to type a line. Returns the trimmed string.
func _get_raw_input(prompt: String = "") -> String:
	if prompt != "":
		_print(prompt)
	var text: String = await _input_submitted
	return text.strip_edges()

## Prompt for an integer within [min_val, max_val].
func _get_int_input(prompt: String, min_val: int, max_val: int) -> int:
	while true:
		var text := await _get_raw_input(prompt)
		if text.is_valid_int():
			var num := text.to_int()
			if num >= min_val and num <= max_val:
				return num
		_print("  Enter a number between %d and %d." % [min_val, max_val])
	return min_val # unreachable, satisfies return type
#endregion


#region Async Player Actions
func get_player_action(state: GameState) -> Dictionary:
	_print("\nActions: [p]lay, [m]erge, [c]onvert, [e]nd turn")
	while true:
		var cmd := await _get_raw_input(">> ")
		match cmd.to_lower():

			"p", "play":
				if state.hand.is_empty():
					_print("  No cards in hand.")
					continue
				var ci := await _get_int_input(
					"  Card index (0-%d):" % (state.hand.size() - 1),
					0, state.hand.size() - 1)
				var card: Card = state.hand[ci]
				var living := state.get_living_allies()
				_print("  Allies:")
				for i in living.size():
					_print("    [%d] %s" % [i, living[i]])
				var ai := await _get_int_input(
					"  Ally index (0-%d):" % (living.size() - 1),
					0, living.size() - 1)
				return {
					"type": "play",
					"card": card,
					"target_ally": living[ai],
				}

			"m", "merge":
				if state.hand.size() < 2:
					_print("  Need at least 2 cards.")
					continue
				show_hand(state.hand)
				var ai2 := await _get_int_input(
					"  First card index:", 0, state.hand.size() - 1)
				var bi := await _get_int_input(
					"  Second card index:", 0, state.hand.size() - 1)
				if ai2 == bi:
					_print("  Can't merge a card with itself.")
					continue
				return {
					"type": "merge",
					"card_a": state.hand[ai2],
					"card_b": state.hand[bi],
				}

			"c", "convert":
				return { "type": "convert" }

			"e", "end":
				return { "type": "end_turn" }

			_:
				_print("  Unknown command.")


	return { "type": "end_turn" } # unreachable


func ask_target(state: GameState, filter: Callable) -> Unit:
	var valid: Array[Unit] = []
	for u in (state.enemies + state.allies):
		if not u.is_dead and filter.call(u):
			valid.append(u)
	if valid.is_empty():
		_print("  (No valid targets)")
		return null
	_print("  Choose target:")
	for i in valid.size():
		_print("    [%d] %s" % [i, valid[i]])
	var idx := await _get_int_input("  Target index:", 0, valid.size() - 1)
	return valid[idx]


func ask_multi_target(state: GameState, count: int, filter: Callable) -> Array[Unit]:
	var valid: Array[Unit] = []
	for u in (state.enemies + state.allies):
		if not u.is_dead and filter.call(u):
			valid.append(u)
	var chosen: Array[Unit] = []
	for n in count:
		if valid.is_empty():
			break
		_print("  Choose target %d of %d:" % [n + 1, count])
		for i in valid.size():
			_print("    [%d] %s" % [i, valid[i]])
		var idx := await _get_int_input("  Target index:", 0, valid.size() - 1)
		chosen.append(valid[idx])
		valid.remove_at(idx) # can't choose same target twice
	return chosen


func ask_card_choice(state: GameState, filter: Callable) -> Card:
	var valid: Array[Card] = []
	for c in state.hand:
		if filter.call(c):
			valid.append(c)
	if valid.is_empty():
		_print("  (No valid cards)")
		return null
	_print("  Choose a card:")
	for i in valid.size():
		_print("    [%d] %s" % [i, valid[i]])
	var idx := await _get_int_input("  Card index:", 0, valid.size() - 1)
	return valid[idx]
#endregion
