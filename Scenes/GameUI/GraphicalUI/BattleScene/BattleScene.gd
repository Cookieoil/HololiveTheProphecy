# BattleScene.gd
class_name BattleScene
extends GameUI

@export var icon_catalog: IconCatalog
@export var status_icon_catalog: StatusIconCatalog
@export var unit_ui_scene: PackedScene = preload("res://Scenes/GameUI/GraphicalUI/BattleUnit/UnitUI.tscn")
@export var turn_dice_progression: Array[int] = []

@onready var hand_bar: HandBar = $HUD/HandBar
@onready var allies_container: HBoxContainer = $EntityOverlay/AlliesRow
@onready var enemies_container: HBoxContainer = $EntityOverlay/EnemiesRow

@onready var wave_value_label: Label = $HUD/TopBar/Margin/HBox/LeftGroup/WaveStat/Value
@onready var dice_value_label: Label = $HUD/TopBar/Margin/HBox/LeftGroup/DiceStat/Value
@onready var actions_value_label: Label = $HUD/TopBar/Margin/HBox/CenterGroup/ActionsStat/Value
@onready var merges_value_label: Label = $HUD/TopBar/Margin/HBox/CenterGroup/MergesStat/Value
@onready var resource_label: Label = $HUD/TopBar/Margin/HBox/RightGroup/ResourceLabel
@onready var convert_button: Button = $HUD/TopBar/Margin/HBox/RightGroup/ConvertButton
@onready var end_turn_button: Button = $HUD/TopBar/Margin/HBox/RightGroup/EndTurnButton
@onready var log_label: Label = $HUD/MessageLog

var game_manager: GameManager
var _intent_cache: Dictionary = {}

signal action_decided(action_dict: Dictionary)
signal unit_selected_for_target(unit: Unit)

## seconds between each enemy's intent appearing
const INTENT_STAGGER: float = 0.08

func _ready() -> void:
	if status_icon_catalog == null:
		status_icon_catalog = StatusIconCatalog.new()

	end_turn_button.pressed.connect(func(): action_decided.emit({"type": "end_turn"}))
	convert_button.pressed.connect(func(): action_decided.emit({"type": "convert"}))
	hand_bar.merge_requested.connect(_on_merge_requested)

	game_manager = GameManager.new()
	add_child(game_manager)

	var db = DataLoader.db()
	var ally_ids: Array = db.config.get("allies", ["striker", "healer", "buff"])
	var ally_data: Array[UnitData] = []
	for id in ally_ids:
		if db.units.has(id):
			ally_data.append(db.units[id])

	var config: Dictionary = db.config.duplicate()
	if not turn_dice_progression.is_empty():
		config["dice_progression"] = turn_dice_progression

	game_manager.setup_game(ally_data, db.waves, self, config)


#region GameUI Overrides

func on_card_played(card: Card, state: GameState) -> void:
	hand_bar.remove_card(card)   # animated collapse
	_update_top_bar(state)       # Actions counter updates immediately too
	
func play_unit_skill(unit: Unit, skill_index: int, rank: int = 0) -> void:
	var unit_ui := _get_unit_ui(unit)
	if unit_ui == null:
		push_warning("BattleScene.play_unit_skill(): no UnitUI found for %s" % unit)
		return
	await unit_ui.play_skill_animation(skill_index, rank)
	
func show_message(msg: String) -> void:
	print(msg)
	log_label.text = msg
	var t := create_tween()
	t.tween_property(log_label, "modulate:a", 1.0, 0.1)
	t.tween_interval(1.8)
	t.tween_property(log_label, "modulate:a", 0.0, 0.4)


func show_game_state(state: GameState) -> void:
	hand_bar.game_state = state
	hand_bar.set_hand(state.hand)
	_update_top_bar(state)
	_sync_unit_row(enemies_container, state.enemies, false)
	_sync_unit_row(allies_container, state.allies, true)


func show_hand_and_resources(state: GameState) -> void:
	_update_top_bar(state)
	hand_bar.game_state = state
	hand_bar.set_hand(state.hand)


func _update_top_bar(state: GameState) -> void:
	if state == null:
		return
	var wave_num: int = 1
	if "current_wave" in state:
		wave_num = int(state.get("current_wave")) + 1
	elif "wave_index" in state:
		wave_num = int(state.get("wave_index")) + 1
	elif "turn_number" in state:
		wave_num = state.turn_number

	wave_value_label.text = str(wave_num)
	dice_value_label.text = str(state.get_dice_size(state.turn_number))
	actions_value_label.text = str(state.actions_left)
	merges_value_label.text = str(state.merges_left)
	resource_label.text = "Deck: %d | Discard: %d" % [state.deck.size(), state.discard.size()]


func show_enemy_intents(intents: Array[EnemyIntent]) -> void:
	_intent_cache.clear()
	for i in intents.size():
		var intent := intents[i]
		_intent_cache[intent.enemy] = {
			"text": "Roll %d: %s" % [intent.effective_value, intent.skill.skill_name],
			"categories": intent.skill.get_active_categories(intent.condition_met),
			"order": i,
		}
	_apply_cached_intents()

func clear_unit_intent(unit: Unit) -> void:
	_intent_cache.erase(unit)  # so a later row rebuild can't bring it back
	var u_ui := _get_unit_ui(unit)
	if u_ui:
		u_ui.clear_intent(true)


func _apply_cached_intents() -> void:
	for child in enemies_container.get_children():
		var u_ui := child as UnitUI
		if u_ui and not u_ui.is_queued_for_deletion():
			_apply_intent_to(u_ui)


func _apply_intent_to(u_ui: UnitUI) -> void:
	var entry: Dictionary = _intent_cache.get(u_ui.unit, {})
	if entry.is_empty() or u_ui.unit.is_dead:
		u_ui.clear_intent()
	else:
		u_ui.show_intent(
			entry["text"],
			entry["categories"],
			int(entry["order"]) * INTENT_STAGGER
		)

func get_player_action(_state: GameState) -> Dictionary:
	end_turn_button.disabled = false
	convert_button.disabled = false

	var action: Dictionary = await action_decided

	end_turn_button.disabled = true
	convert_button.disabled = true
	return action


func ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]:
	if units.is_empty():
		return []

	if units.size() <= count:
		return units.duplicate()

	show_message("Click %d target(s) to attack!" % count)
	_highlight_target_candidates(units, true)

	var chosen: Array[Unit] = []
	var available: Array[Unit] = units.duplicate()

	while chosen.size() < count and not available.is_empty():
		var picked: Unit = await unit_selected_for_target
		if available.has(picked):
			chosen.append(picked)
			available.erase(picked)
			var u_ui := _get_unit_ui(picked)
			if u_ui:
				u_ui.set_target_highlight(false)

	_highlight_target_candidates(units, false)
	return chosen


func ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]:
	var chosen: Array[Card] = []
	for i in mini(count, cards.size()):
		chosen.append(cards[i])
	return chosen


# --- Helpers & Interaction Handlers -------------------------------------------

func _on_merge_requested(card_a: Card, card_b: Card) -> void:
	action_decided.emit({
		"type": "merge",
		"card_a": card_a,
		"card_b": card_b
	})


func _on_card_dropped_on_unit(card: Card, unit: Unit) -> void:
	action_decided.emit({
		"type": "play",
		"card": card,
		"target_ally": unit
	})


func _on_unit_clicked(unit: Unit) -> void:
	unit_selected_for_target.emit(unit)


func _highlight_target_candidates(units: Array[Unit], active: bool) -> void:
	for u in units:
		var u_ui := _get_unit_ui(u)
		if u_ui:
			u_ui.set_target_highlight(active)


func _get_unit_ui(target_unit: Unit) -> UnitUI:
	for container in [enemies_container, allies_container]:
		for child in container.get_children():
			var u_ui := child as UnitUI
			if u_ui and not u_ui.is_queued_for_deletion() and u_ui.unit == target_unit:
				return u_ui
	return null


func _sync_unit_row(container: HBoxContainer, units: Array, is_ally: bool) -> void:
	var total: int = units.size()

	# Reuse existing UnitUI nodes if they already match the current units
	if container.get_child_count() == total:
		var same_units := true
		for idx in total:
			var data_idx: int = idx if is_ally else (total - 1 - idx)
			var u_ui := container.get_child(idx) as UnitUI
			if u_ui == null or u_ui.unit != units[data_idx]:
				same_units = false
				break
		if same_units:
			return

	for child in container.get_children():
		child.queue_free()

	for idx in total:
		var data_idx: int = idx if is_ally else (total - 1 - idx)
		var unit := units[data_idx] as Unit
		var card_ui: UnitUI = unit_ui_scene.instantiate()
		container.add_child(card_ui)
		card_ui.setup(unit, icon_catalog, status_icon_catalog)
		card_ui.play_intro(idx * 0.1)
		card_ui.set_staggered(data_idx == 1)

		if is_ally:
			card_ui.card_dropped_on_unit.connect(_on_card_dropped_on_unit)
		else:
			_apply_intent_to(card_ui)
		card_ui.unit_clicked.connect(_on_unit_clicked)
		
#endregion
