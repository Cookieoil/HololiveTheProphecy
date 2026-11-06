# GraphicalGameUI.gd
class_name GraphicalGameUI
extends GameUI

@export var icon_catalog: IconCatalog
@export var unit_ui_scene: PackedScene

@onready var hand_bar: HandBar = $BottomBar/HandBar
@onready var allies_container: HBoxContainer = $Field/AlliesContainer
@onready var enemies_container: HBoxContainer = $Field/EnemiesContainer
@onready var intents_container: VBoxContainer = $TopBar/EnemyIntents
@onready var end_turn_button: Button = $BottomBar/EndTurnButton
@onready var convert_button: Button = $BottomBar/ConvertButton
@onready var log_label: Label = $MessageLog

# Internal signal to resume get_player_action()
signal action_decided(action_dict: Dictionary)

var _current_state: GameState
var _unit_views: Dictionary = {}

func _ready() -> void:
	end_turn_button.pressed.connect(func(): action_decided.emit({"type": "end_turn"}))
	convert_button.pressed.connect(func(): action_decided.emit({"type": "convert"}))
	hand_bar.merge_requested.connect(_on_merge_requested)


func _on_merge_requested(card_a: Card, card_b: Card) -> void:
	action_decided.emit({
		"type": "merge",
		"card_a": card_a,
		"card_b": card_b
	})


func _on_card_dropped(card: Card, target_ally: Unit) -> void:
	action_decided.emit({
		"type": "play",
		"card": card,
		"target_ally": target_ally
	})


# --- GameUI Overrides ---------------------------------------------------------

func show_message(msg: String) -> void:
	log_label.text = msg
	var t := create_tween()
	t.tween_property(log_label, "modulate:a", 1.0, 0.1)
	t.tween_interval(2.0)
	t.tween_property(log_label, "modulate:a", 0.0, 0.5)


func show_game_state(state: GameState) -> void:
	_current_state = state
	
	# 1. Update Hand
	hand_bar.set_hand(state.hand)
	
	# 2. Update Allies
	_sync_units(allies_container, state.allies)
	
	# 3. Update Enemies
	_sync_units(enemies_container, state.enemies)


func show_enemy_intents(intents: Array[EnemyIntent]) -> void:
	for child in intents_container.get_children():
		child.queue_free()

	for intent in intents:
		var row := HBoxContainer.new()
		
		# Intent description: [Enemy] Rolls X -> Skill Name
		var lbl := Label.new()
		lbl.text = "%s Rolls %d -> %s " % [
			intent.enemy.data.display_name, 
			intent.effective_value, 
			intent.skill.skill_name
		]
		row.add_child(lbl)
		
		# Show the enemy skill's category icons
		var is_merged: bool = intent.effective_value >= intent.skill.condition_threshold
		var categories := intent.skill.get_active_categories(is_merged)
		for cat in categories:
			var icon := TextureRect.new()
			icon.texture = icon_catalog.get_icon(cat)
			icon.custom_minimum_size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(icon)
			
		intents_container.add_child(row)


func get_player_action(_state: GameState) -> Dictionary:
	# Enables interaction buttons
	end_turn_button.disabled = false
	convert_button.disabled = false
	
	# Wait asynchronously for the player to drag a card, merge, or click a button
	var action: Dictionary = await action_decided
	
	end_turn_button.disabled = true
	convert_button.disabled = true
	return action


#region Helper methods

func _sync_units(container: HBoxContainer, units: Array) -> void:
	var keep: Dictionary = {}

	for unit: Unit in units:
		keep[unit] = true

	# Remove only views whose units actually disappeared.
	for child: Node in container.get_children():
		var old_view := child as UnitUI
		if old_view != null and not keep.has(old_view.unit):
			_unit_views.erase(old_view.unit)
			container.remove_child(old_view)
			old_view.queue_free()

	# Reuse existing views. Recreating them would restart born/idle and
	# discard queued animations, hit reactions, and health-bar trails.
	for i in units.size():
		var unit: Unit = units[i]
		var view := _unit_views.get(unit, null) as UnitUI

		if view == null or not is_instance_valid(view):
			view = unit_ui_scene.instantiate() as UnitUI
			_unit_views[unit] = view
			container.add_child(view)
			view.setup(unit, icon_catalog)
			view.card_dropped_on_unit.connect(_on_card_dropped)
		elif view.get_parent() != container:
			view.reparent(container)

		container.move_child(view, i)
		
		
func play_unit_skill(
	unit: Unit,
	skill_index: int,
	rank: int = 0
) -> void:
	for container: HBoxContainer in [allies_container, enemies_container]:
		for child: Node in container.get_children():
			var unit_ui := child as UnitUI
			if unit_ui != null and unit_ui.unit == unit:
				unit_ui.play_skill_animation(skill_index, rank)
				return
#endregion
