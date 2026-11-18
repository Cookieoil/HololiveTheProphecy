class_name GameUI
extends Node
## Abstract UI interface the GameManager talks to.
## Subclass for TextGameUI (now) or a full GraphicalGameUI (later).
## Every input methods are async, not synchronously. Callers must use `await`.
## Synchronously: Run line by line, blocking the code path until a line is finishes
## Asynchronous: Starts a task that takes time and pauses itself until that task is complete)
##
## @author TheGreatJellyfish
## @version 7/1/2026


#region Display (fire-and-forget)
## Print a single message line to the player.
func show_message(_msg: String) -> void:
	push_warning("GameUI.show_message() not overridden.")
	
## Display enemy intent previews for the coming turn.
func show_enemy_intents(_intents: Array[EnemyIntent]) -> void:
	push_warning("GameUI.show_enemy_intents() not overridden.")
	
## Refresh the full board / hand / resource display.
func show_game_state(_state: GameState) -> void:
	push_warning("GameUI.show_game_state() not overridden.")
	
func focus_input() -> void:
	pass
	
func play_unit_skill(_unit: Unit, _skill_index: int, _rank: int = 0) -> void:
	push_warning("GameUI.play_unit_skill() not overridden.")
	
func play_unit_ultimate(_unit: Unit) -> void:
	push_warning("GameUI.play_unit_ultimate() not overridden.")
	
## Presentation cue: an enemy is about to act (or is skipped because it's dead),
## so its intent preview should disappear. 
func clear_unit_intent(_unit: Unit) -> void:
	pass
	
## Presentation cue: a card was accepted and left the hand.
func on_card_played(_card: Card, _state: GameState) -> void:
	pass

## Presentation cue: two cards in hand were fused into `result` by a merge.
## `source_a` is the card that was dragged and `source_b` the card it was
## dropped on; `result` takes the target's slot. Implementations that animate
## should play the merge here, because the hand refresh that follows reuses the
## forged card rather than rebuilding it.
func on_cards_merged(
	_source_a: Card,
	_source_b: Card,
	_result: Card,
	_state: GameState
) -> void:
	pass

## Presentation cue: the game picked these cards out of the hand on its own
## (auto_top_n / auto_highest), so no prompt was shown. Briefly highlight them
## so the player can still see which cards were affected.
## `hostile` marks enemy-caused changes; implementations should flash red
## instead of the friendly highlight colour.
## Callers may `await` this; implementations that animate should be coroutines.
func flash_auto_selected_cards(_cards: Array[Card], _hostile: bool = false) -> void:
	pass
#endregion

#region Player Input (async)
## Ask the player for their next action.
## Returns a Dictionary with at minimum a key "type":
## "play"		-> { type, card: Card, target_ally: Unit }
## "merge"		-> { type, card_a: Card, card_b: Card }
## "convert"	-> { type }
## "end_turn"	-> { type }
func get_player_action(_state: GameState) -> Dictionary:
		push_warning("GameUI.get_player_action() not overridden.")
		return {"type": "end_turn"}
		
		
## Ask the player to pick 'count' unit from 'units'.
## returns the chosen units (fewer if not enough).
func ask_pick_targets(_units: Array[Unit], _count: int) -> Array[Unit]:
	push_warning("GameUI.ask_pick_targets() not overridden.")
	return []
	
## Ask the player to pick 'count' cards from 'cards'.
## Returns the chosen cards.
func ask_pick_cards(_cards: Array[Card], _count: int) -> Array[Card]:
	push_warning("GameUI.ask_pick_cards() not overridden.")
	return []
	
## Refresh hand and resource counters (Actions, Merges, Deck, Discard).
func show_hand_and_resources(_state: GameState) -> void:
	push_warning("GameUI.show_hand_and_resources() not overridden.")
#endregion
