extends Node

@export var game_manager: GameManager
@export var text_ui: TextGameUI
@export var turn_dice_progression: Array[int] = []

func _ready() -> void:
	var config: Dictionary = DataLoader.db().config
	var library: Dictionary = DataLoader.db().units

	var ally_ids: Array = config.get("allies", ["striker", "healer", "buff"])
	var ally_data: Array[UnitData] = []
	for id in ally_ids:
		ally_data.append(library[id])

	var wave_defs: Array = DataLoader.db().waves

	game_manager.setup_game(ally_data, wave_defs, text_ui)

	if not turn_dice_progression.is_empty():
		game_manager.state.set_dice_progression(turn_dice_progression)
