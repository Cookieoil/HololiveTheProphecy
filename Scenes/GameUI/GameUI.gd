class_name GameUI
extends Node
## Abstract interface for all game I/O. The GameManager talks to this.
## Subclass TextGameUI (now) or a full GraphicalGameUI (later).
## Every async method returns via signal/coroutine.
##
## @author TheGreatJellyfish
## @version 5/17/2026


## ── Display ──

func show_message(_text: String) -> void:
	pass

func show_game_state(_state: GameState) -> void:
	pass

func show_enemy_intents(_intents: Array[EnemyIntent]) -> void:
	pass

func show_hand(_hand: Array[Card]) -> void:
	pass


## ── Async Player Input ──
## Each returns the chosen value. GameManager always awaits these.

## Main action prompt. Returns a Dictionary:
##   { "type": "play"|"merge"|"convert"|"end_turn",
##     "card": Card, "card_a": Card, "card_b": Card, "target_ally": Unit }
func get_player_action(_state: GameState) -> Dictionary:
	return {}

## Ask the player to choose one unit from a filtered list.
func get_living_enemies(_state: GameState, _filter: Callable) -> Array[Unit]:
	return []

## Ask the player to choose N units (no repeats) from a filtered list.
func get_n_target(_state: GameState, _count: int, _filter: Callable) -> Array[Unit]:
	return []

## Ask the player to choose a card from hand.
func get_card_choice(_state: GameState, _count: int, _filter: Callable) -> Array[Unit]:
	return []
