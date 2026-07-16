extends Node

@export var game_manager: GameManager
@export var text_ui: TextGameUI
@export var turn_dice_progression: Array[int] = []

func _ready() -> void:
	# ── Allies ──
	var ally_data: Array[UnitData] = [
		UnitCreator.create_Striker(),
		UnitCreator.create_Healer(),
		UnitCreator.create_Buff(),
	]

	# ── Enemy waves ──
	var wave_1: Array[UnitData] = [
		UnitCreator.create_NormalEnemy(),
		UnitCreator.create_NormalEnemy(),
		UnitCreator.create_NormalEnemy(),
	]
	
	var wave_2: Array[UnitData] = [
		UnitCreator.create_NormalEnemy(14),
		UnitCreator.create_NormalEnemy(14),
		UnitCreator.create_BossEnemy(),
	]
	var wave_defs: Array = [wave_1, wave_2]

	# ── Go ──
	game_manager.setup_game(ally_data, wave_defs, text_ui)
	
	# Apply custom dice progression from inspector
	if not turn_dice_progression.is_empty():
		game_manager.state.set_dice_progression(turn_dice_progression)
	
