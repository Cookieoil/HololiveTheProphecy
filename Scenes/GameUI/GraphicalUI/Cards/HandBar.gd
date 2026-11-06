# HandBar.gd
class_name HandBar
extends PanelContainer
## Bottom-edge hand of cards. View-only: it animates, GameManager validates.

signal merge_requested(card_a: Card, card_b: Card)
signal drag_started(card: Card)
signal drag_ended(card: Card)

const CARD_SCENE: PackedScene = preload("res://Scenes/GameUI/GraphicalUI/Cards/CardUI.tscn")
const REMOVE_TWEEN_TIME: float = 0.18
const ENTER_TWEEN_TIME: float = 0.22
const CARD_WIDTH: float = 100.0
const CARD_HEIGHT: float = 145.0

var game_state: GameState

@onready var cards_row: HBoxContainer = $MarginContainer/VBox/CardsRow


# --- Public API (called by GraphicalGameUI) -----------------------------------

func set_hand(cards: Array[Card]) -> void:
	for child: Node in cards_row.get_children():
		cards_row.remove_child(child)
		child.queue_free()
	for c: Card in cards:
		_spawn_card(c, false)


func add_card(card: Card) -> void:
	## New cards enter from the LEFT, sliding existing cards right.
	var ui: CardUI = _spawn_card(card, true)
	cards_row.move_child(ui, 0)


func remove_card(card: Card) -> void:
	var ui: CardUI = _find_card_ui(card)
	if ui == null:
		return
	# can't hover/drag a dying card
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ui, "custom_minimum_size:x", 0.0, REMOVE_TWEEN_TIME)
	tween.parallel().tween_property(ui, "modulate:a", 0.0, REMOVE_TWEEN_TIME)
	tween.tween_callback(ui.queue_free)


func replace_card(old_card: Card, new_card: Card) -> void:
	## Merge result: the consumed card collapses away, the target refreshes.
	remove_card(old_card)
	var target: CardUI = _find_card_ui(new_card)
	if target != null:
		target._refresh()


func _spawn_card(card: Card, animate: bool) -> CardUI:
	var ui: CardUI = CARD_SCENE.instantiate()
	cards_row.add_child(ui)
	ui.setup(card, self)

	var target_width: float = CARD_WIDTH if CARD_WIDTH > 0.0 else ui.custom_minimum_size.x
	ui.custom_minimum_size.y = CARD_HEIGHT

	if animate:
		ui.custom_minimum_size.x = 0.0
		ui.modulate.a = 0.0
		var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(ui, "custom_minimum_size:x", target_width, ENTER_TWEEN_TIME)
		tween.parallel().tween_property(ui, "modulate:a", 1.0, ENTER_TWEEN_TIME)
	else:
		ui.custom_minimum_size.x = target_width
		ui.modulate.a = 1.0

	return ui


func can_merge(card_a: Card, card_b: Card) -> bool:
	if card_a == null or card_b == null or card_a == card_b:
		return false
	return not card_a.is_double_merged and not card_b.is_double_merged


## Zero-argument method for the DebugCardSpawn button in QueueUI
func spawn_debug_card() -> void:
	var random_val := randi_range(1, 6)
	var new_card := Card.new(random_val)

	var state := _get_game_state()
	if state != null:
		state.hand.append(new_card)
	else:
		push_warning("HandBar: Could not find GameState. Debug card is visual only!")

	add_card(new_card)


func _get_game_state() -> GameState:
	if game_state != null and is_instance_valid(game_state):
		return game_state

	var scene := get_tree().current_scene as BattleScene
	if scene != null and scene.game_manager != null and scene.game_manager.state != null:
		game_state = scene.game_manager.state
		return game_state

	var curr: Node = get_parent()
	while curr != null:
		if curr is BattleScene:
			var bs := curr as BattleScene
			if bs.game_manager != null and bs.game_manager.state != null:
				game_state = bs.game_manager.state
				return game_state
		curr = curr.get_parent()

	return null


func _find_card_ui(card: Card) -> CardUI:
	for child: Node in cards_row.get_children():
		var ui: CardUI = child as CardUI
		if ui != null and ui.card == card:
			return ui
	return null
