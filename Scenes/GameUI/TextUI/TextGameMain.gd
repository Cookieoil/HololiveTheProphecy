extends Node

#region Exports
@export var game_manager: GameManager
@export var text_ui: TextGameUI
@export var turn_dice_progression: Array[int] = []
#endregion

#region Lifecycle Methods
func _ready() -> void:
	# res://Data/json/ is the single source of truth for all game data.
	var db: GameDatabase = DataLoader.db()
	var config: Dictionary = db.config
	var library: Dictionary = db.units

	var ally_ids: Array = config.get("allies", ["striker", "healer", "buff"])
	var ally_data: Array[UnitData] = []
	for ally_id: String in ally_ids:
		if not library.has(ally_id):
			push_warning("TextGameMain: config.json allies references unknown unit '%s'" % ally_id)
			continue
		var unit_data: UnitData = library[ally_id]
		ally_data.append(unit_data)

	var wave_defs: Array = db.waves
	await game_manager.setup_game(ally_data, wave_defs, text_ui, config)

	if not turn_dice_progression.is_empty():
		game_manager.state.set_dice_progression(turn_dice_progression)
#endregion