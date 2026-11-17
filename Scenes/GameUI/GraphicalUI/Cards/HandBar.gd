# HandBar.gd
class_name HandBar
extends PanelContainer
## Bottom-edge hand of cards. View-only: it animates, GameManager validates.

signal merge_requested(card_a: Card, card_b: Card)
signal drag_started(card: Card)
signal drag_ended(card: Card)
signal card_clicked(card: Card)

const CARD_SCENE: PackedScene = preload("res://Scenes/GameUI/GraphicalUI/Cards/CardUI.tscn")
const REMOVE_TWEEN_TIME: float = 0.18
const ENTER_TWEEN_TIME: float = 0.22
const CARD_WIDTH: float = 100.0
const CARD_HEIGHT: float = 145.0
## How long auto-selected cards stay lit before the flash fades out.
const AUTO_FLASH_HOLD: float = 0.55

var game_state: GameState

# While _pick_active is true the game is waiting for the player to click cards
# in hand, so every candidate keeps its pick highlight on.
var _pick_active: bool = false
var _pick_candidates: Array[Card] = []

@onready var cards_row: HBoxContainer = $MarginContainer/VBox/CardsRow


#region Lifecycle

func _ready() -> void:
	if EventBus.has_signal("card_played"):
		EventBus.card_played.connect(_on_event_card_played)

#endregion

#region Public API (called by GraphicalGameUI)

func set_pick_candidates(candidates: Array[Card], active: bool) -> void:
	_pick_active = active
	if active:
		_pick_candidates = candidates.duplicate()
	else:
		_pick_candidates.clear()
	_apply_pick_candidates()


## Briefly highlights cards the game picked on its own (auto_top_n /
## auto_highest) so the player can see which cards were affected even though no
## prompt was shown. Awaited by the caller, so the cards stay lit before the
## hand is rebuilt or the cards are discarded.
## `hostile` is set when an enemy caused the change; those cards flash red.
func flash_auto_selected(cards: Array[Card], hostile: bool = false) -> void:
	if cards.is_empty() or not is_inside_tree():
		return

	var flashed: Array[CardUI] = []
	for card: Card in cards:
		var ui: CardUI = _find_card_ui(card)
		if ui != null:
			flashed.append(ui)
	if flashed.is_empty():
		return

	for ui: CardUI in flashed:
		ui.set_flash_active(true, hostile)

	var tween: Tween = create_tween()
	tween.tween_interval(AUTO_FLASH_HOLD)
	await tween.finished

	for ui: CardUI in flashed:
		if is_instance_valid(ui) and not ui.is_consumed():
			ui.set_flash_active(false)


## Re-applies the current pick highlight to every card in the row.
## Called after each pick (so already-chosen cards go dark while the remaining
## candidates keep glowing) and after the row is rebuilt (so a mid-pick refresh
## does not silently drop the highlight).
func _apply_pick_candidates() -> void:
	for child: Node in cards_row.get_children():
		var ui := child as CardUI
		if ui == null or ui.is_consumed():
			continue
		ui.set_pick_selectable(_pick_active and _pick_candidates.has(ui.card))


func set_hand(cards: Array[Card]) -> void:
	for child: Node in cards_row.get_children():
		cards_row.remove_child(child)
		child.queue_free()
	for c: Card in cards:
		_spawn_card(c, false)
	_apply_pick_candidates()


func add_card(card: Card) -> void:
	## New cards enter from the LEFT, sliding existing cards right.
	var ui: CardUI = _spawn_card(card, true)
	# Keep any in-progress pick highlight correct for the rebuilt row.
	_apply_pick_candidates()
	cards_row.move_child(ui, 0)


func remove_card(card: Card) -> void:
	var ui: CardUI = _find_card_ui(card)
	if ui == null:
		return
	ui.mark_consumed()
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
	var st := _get_game_state()
	if st != null:
		return st.merges_left > 0 and st.can_merge_pair(card_a, card_b)
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

	var candidates: Array[Node] = []
	if get_tree() != null and get_tree().current_scene != null:
		candidates.append(get_tree().current_scene)
	var curr: Node = get_parent()
	while curr != null:
		candidates.append(curr)
		curr = curr.get_parent()

	for node: Node in candidates:
		var gm: Variant = node.get("game_manager")
		if gm is Object and is_instance_valid(gm):
			var gm_obj: Object = gm
			var raw_state: Variant = gm_obj.get("state")
			if raw_state is GameState:
				var gs: GameState = raw_state
				game_state = gs
				return game_state

	return null


func _find_card_ui(card: Card) -> CardUI:
	for child: Node in cards_row.get_children():
		var ui: CardUI = child as CardUI
		if ui != null and not ui.is_queued_for_deletion() and not ui.is_consumed() and ui.card == card:
			return ui
	return null

#endregion

#region EventBus handlers

## Played cards collapse immediately on play — before play_unit_skill() even
## starts — so the hand doesn't visibly hold a "used" card during the animation.
func _on_event_card_played(card: Card, _ally: Unit) -> void:
	remove_card(card)

#endregion
