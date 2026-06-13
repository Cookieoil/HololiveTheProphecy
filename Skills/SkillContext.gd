class_name SkillContext
extends RefCounted
## Runtime context passed to every EffectBlock.execute().
##   
## Three inter-block communication channels:
##   card_value     – mutable skill value (bonus damage adds here)
##   targets        – cached Unit targets shared across blocks
##   stored_value   – ephemeral int (e.g. discarded card value)
##
##@author TheGreatJellyfish
##@version 5/18/2026

var caster: Unit
var targets: Array[Unit] = []

var card: Card ## Null for enemy skills (they use dices)
var is_merged: bool = false 
var game_state: GameState

var card_value: int = 0
var stored_value: int = 0

# func(count: int, filter: Callable) -> Array[Unit]
var request_n_target: Callable = Callable()
# func(count: int, filter: Callable) -> Array[Unit]
var request_all_targets: Callable = Callable()
# func(filter: Callable) -> Card
var request_card_choice: Callable = Callable()
# func(message: String) -> void
var log_message: Callable = Callable()

func _init(p_caster: Unit, p_card: Card, p_state: GameState) -> void:
	caster = p_caster
	card = p_card
	game_state = p_state
	if p_card:
		card_value = p_card.get_effective_value()
		is_merged = p_card.is_merged
	else:
		card_value = 0
		is_merged = false

# Log if the callback is valid
func log(msg: String) -> void:
	if log_message.is_valid():
		log_message.call(msg)
