class_name TextGameUI
extends GameUI
## Console-style text interface for testing only.
## Outputs to a RichTextLabel, reads from a LineEdit.
##
## @author TheGreatJellyfish
## @version 7/13/2026

@onready var output: RichTextLabel = $Output
@onready var input: LineEdit = $Input

## Internal signal that bridges LineEdit.text_submitted -> await
signal _text_entered(text: String)

func _ready() -> void:
	if input:
		input.text_submitted.connect(_on_input_submitted)
		input.focus_exited.connect(_on_input_focus_exited)
		input.keep_editing_on_text_submit = true 
		# Settings for better UX
		input.caret_blink = true
		input.context_menu_enabled = false
		input.editable = true
	else: 
		push_warning("TextUI: No Input assigned. Input will not work.")
	if not output:
		push_warning("TextUI: No Output assigned. Output will not work.")
	
	# Focus on ready
	await get_tree().process_frame
	focus_input()
		
func _on_input_submitted(text: String) -> void:
	input.clear()
	_append_output(">" + text) # echo the player input
	_text_entered.emit(text)
	
func _on_input_focus_exited() -> void:
	call_deferred("focus_input")
	
#region Helpers
func focus_input() -> void:
	if input:
		input.grab_focus()
		
func _card_display(card: Card) -> String:
	var val = card.get_effective_value()
	var suffix = "V"
	if card.is_double_merged:
		suffix = "DMV"
	elif card.is_merged:
		suffix = "MV"
	return "%d %s" % [val, suffix]
	
## Await one line of player input.
func _await_input(prompt: String = "") -> String:
	if prompt != "":
		_append_output(prompt)
	call_deferred("focus_input")
	var text: String = await _text_entered
	return text.strip_escapes() # erase useless input words
	
func _append_output(line: String) -> void:
	print(line)
	if output:
		output.append_text(line + "\n")
		# automatically scroll to bottom
		output.scroll_to_line(output.get_line_count() - 1)
		
#endregion

#region Display overrides
func show_message(_msg: String) -> void:
	_append_output(_msg)
	
func show_enemy_intents(_intents: Array[EnemyIntent]) -> void:
	@warning_ignore("static_called_on_instance")
	_append_output(ColorUtils.colorize("── Enemy Intents ──", ColorUtils.COLOR_HEADER))
	for intent in _intents:
		@warning_ignore("static_called_on_instance")
		var name_str : String = ColorUtils.colorize(intent.enemy.data.display_name, ColorUtils.COLOR_ENEMY)
		@warning_ignore("static_called_on_instance")
		var val_str : String = ColorUtils.colorize(str(intent.effective_value), ColorUtils.COLOR_CARD)
		@warning_ignore("static_called_on_instance")
		_append_output("  [%d] %s Rolls %s → %s" % [
			intent.enemy.slot_index, name_str, val_str, intent.skill.skill_name
		])

		
func show_game_state(_state: GameState) -> void:
	_append_output("")
	_append_output(ColorUtils.colorize("── Board ──", ColorUtils.COLOR_HEADER))
	
	# Allies
	_append_output(ColorUtils.colorize("Allies:", ColorUtils.COLOR_HEADER))
	for i in _state.allies.size():
		var u := _state.allies[i]
		var name : String = ColorUtils.colorize(u.data.display_name, ColorUtils.COLOR_ALLY)
		var hp : String = ColorUtils.colorize(str(u.current_hp), ColorUtils.COLOR_HP)
		var max_hp : String = ColorUtils.colorize(str(u.max_hp), ColorUtils.COLOR_HP)
		var shield : String = ColorUtils.colorize(str(u.shield), ColorUtils.COLOR_SHIELD)
		var dead_tag : String = ColorUtils.colorize(" [DEFEATED]", ColorUtils.COLOR_DEAD) if u.is_dead else ""
		_append_output("  [%d] %s  HP: %s/%s  Shield: %s%s" % [
			i, name, hp, max_hp, shield, dead_tag
		])
		
	# Enemies
	_append_output(ColorUtils.colorize("Enemies:", ColorUtils.COLOR_HEADER))
	for i in _state.enemies.size():
		var u := _state.enemies[i]
		var name : String = ColorUtils.colorize(u.data.display_name, ColorUtils.COLOR_ENEMY)
		var hp : String = ColorUtils.colorize(str(u.current_hp), ColorUtils.COLOR_HP)
		var max_hp : String = ColorUtils.colorize(str(u.max_hp), ColorUtils.COLOR_HP)
		var shield : String = ColorUtils.colorize(str(u.shield), ColorUtils.COLOR_SHIELD)
		var dead_tag : String = ColorUtils.colorize(" [DEFEATED]", ColorUtils.COLOR_DEAD) if u.is_dead else ""
		_append_output("  [%d] %s  HP: %s/%s  Shield: %s%s" % [
			i, name, hp, max_hp, shield, dead_tag
		])

func show_hand_and_resources(_state: GameState) -> void:
	_append_output("")
	_append_output(ColorUtils.colorize("── Hand ──", ColorUtils.COLOR_HEADER))
	for i in _state.hand.size():
		var display = ColorUtils.colorize(_card_display(_state.hand[i]), ColorUtils.COLOR_CARD)
		_append_output("  [%d] %s" % [i, display])
	_append_output("Actions: %d  |  Merges: %d  |  Deck: %d  |  Discard: %d" % [
		_state.actions_left, _state.merges_left, _state.deck.size(), _state.discard.size()
	])
	
#region Player Input overrides
func get_player_action(_state: GameState) -> Dictionary:
	while true:
		_append_output(ColorUtils.colorize("Commands: play <card#> <ally#>  |  merge <card#> <card#>  |  convert  |  stats  |  hand  |  end", 
		ColorUtils.COLOR_HEADER))
		
		var raw := await _await_input(">> ")
		var parts := raw.split(" ", false) # Split string into substring
		if parts.is_empty():
			continue
			
		var cmd := parts[0].to_lower() # lowercase
		
		if cmd == "end":
			return {"type": "end_turn"}
			
		if cmd == "convert":
			return {"type": "convert"}
			
		if cmd == "hand":
			return {"type": "hand"}
			
		if cmd == "stats":
			return {"type": "stats"}
			
		if cmd == "play":
			if parts.size() < 3:
				show_message("Usage: play <card#> <ally#>")
				continue
			if not parts[1].is_valid_int() or not parts[2].is_valid_int():
				show_message("Indices must be numbers.")
				continue
			var ci := parts[1].to_int()
			var ai := parts[2].to_int()
			if ci < 0 or ci >= _state.hand.size():
				show_message("Card index out of range (0–%d)." % (_state.hand.size() - 1))
				continue
			if ai < 0 or ai >= _state.allies.size():
				show_message("Ally index out of range (0–%d)." % (_state.allies.size() - 1))
				continue
			return {
				"type": "play",
				"card": _state.hand[ci],
				"target_ally": _state.allies[ai],
			}
			
		if cmd == "merge":
			if parts.size() < 3:
				show_message("Usage: merge <card#> <card#>")
				continue
			if not parts[1].is_valid_int() or not parts[2].is_valid_int():
				show_message("Indices must be numbers.")
				continue
			var ia := parts[1].to_int()
			var ib := parts[2].to_int()
			if ia < 0 or ia >= _state.hand.size() or ib < 0 or ib >= _state.hand.size():
				show_message("Card index out of range (0–%d)." % (_state.hand.size() - 1))
				continue
			if ia == ib:
				show_message("Cannot merge a card with itself.")
				continue
			return {
				"type": "merge",
				"card_a": _state.hand[ia],
				"card_b": _state.hand[ib],
			}

		show_message("Unknown command '%s'." % cmd)

	# Unreachable, but satisfies return type
	return {"type": "end_turn"}
	
func ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]:
	var chosen: Array[Unit] = []
	var available: Array = []  # each element: {"unit": Unit, "idx": int}
	for i in units.size():
		available.append({"unit": units[i], "idx": i})

	for n in count:
		if available.is_empty():
			break
		_append_output(ColorUtils.colorize("Pick target %d of %d:" % [n+1, count], ColorUtils.COLOR_HEADER))
		for entry in available:
			var u: Unit = entry.unit          # get the Unit from the dict
			var idx: int = entry.idx          # original index
			var name: String = ColorUtils.colorize(u.data.display_name, ColorUtils.COLOR_ENEMY if not u.is_ally else ColorUtils.COLOR_ALLY)
			var hp: String = ColorUtils.colorize(str(u.current_hp), ColorUtils.COLOR_HP)
			var max_hp: String = ColorUtils.colorize(str(u.max_hp), ColorUtils.COLOR_HP)
			var shield: String = ColorUtils.colorize(str(u.shield), ColorUtils.COLOR_SHIELD)
			_append_output("  [%d] %s  HP: %s/%s  Shield: %s" % [idx, name, hp, max_hp, shield])
	
		while true:
			var raw := await _await_input("target>> ")
			if not raw.is_valid_int():
				show_message("Enter a number.")
				continue
			var idx := raw.to_int()
			var found_entry = null
			for entry in available:
				if entry.idx == idx:
					found_entry = entry
					break
			if found_entry == null:
				show_message("Index %d not available (already picked or out of range 0–%d)." % [idx, units.size()-1])
				continue
			chosen.append(found_entry.unit)
			available.erase(found_entry)
			break
	return chosen


func ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]:
	var chosen: Array[Card] = []
	var available: Array = []  # each element: {"unit": Unit, "idx": int}
	for i in cards.size():
		available.append({"card": cards[i], "idx": i})

	for n in count:
		if available.is_empty():
			break
		_append_output(ColorUtils.colorize("Pick %d out of %d card(s):" % [n+1, count], ColorUtils.COLOR_HEADER))
		for entry in available:
			var card: Card = entry.card
			var idx: int = entry.idx
			var display: String = ColorUtils.colorize(_card_display(card), ColorUtils.COLOR_CARD)
			_append_output("  [%d] %s" % [idx, display])
	
		while true:
			var raw := await _await_input("card>> ")
			if not raw.is_valid_int():
				show_message("Enter a number.")
				continue
			var idx := raw.to_int()
			var found_entry = null
			for entry in available:
				if entry.idx == idx:
					found_entry = entry
					break
			if found_entry == null:
				show_message("Index %d not available (already picked or out of range 0–%d)." % [idx, cards.size()-1])
				continue
			chosen.append(found_entry.card)
			available.erase(found_entry)
			break
	return chosen
#endregion
