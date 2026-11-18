# HandBar.gd
class_name HandBar
extends PanelContainer
## Bottom-edge hand of cards. View-only: it animates, GameManager validates.

signal merge_requested(card_a: Card, card_b: Card)
signal drag_started(card: Card)
signal drag_ended(card: Card)
signal card_clicked(card: Card)

const CARD_SCENE: PackedScene = preload("res://Scenes/Cards/CardUI.tscn")
const ENTER_TWEEN_TIME: float = 0.22
## How long a card takes to glide to its new slot when the hand changes.
const SLIDE_TIME: float = 0.22
const CARD_WIDTH: float = 100.0
const CARD_HEIGHT: float = 145.0
## How long auto-selected cards stay lit before the flash fades out.
const AUTO_FLASH_HOLD: float = 0.55

#region Deal choreography
## Seconds between two cards of the same deal, so a full opening hand fans out in
## well under a second instead of arriving as one block.
const DEAL_STAGGER: float = 0.068
## Deck origin as an offset from the card's own slot: beyond the right edge of
## the hand, so every drawn card is dealt in from off-screen straight to its
## place instead of drifting in through the middle of the screen.
const DECK_DROP: float = 42.0
## Alternating deck position, so a multi-card deal looks like it comes off a
## small pile rather than a single point.
const DECK_STACK_STEP: Vector2 = Vector2(16.0, 8.0)
#endregion

var game_state: GameState

# While _pick_active is true the game is waiting for the player to click cards
# in hand, so every candidate keeps its pick highlight on.
var _pick_active: bool = false
var _pick_candidates: Array[Card] = []

## Where the card the player was carrying was let go of, if the merge about to be
## played was driven by a real drag. Recorded by the card it was dropped on and
## consumed by `play_merge`, so a merge can start from the point of release
## rather than from the slot the card was dragged out of.
var _release_card: Card
var _release_centre: Vector2 = Vector2.ZERO
var _has_merge_release: bool = false

## Stagger slot handed to each card dealt within the same frame. Reset once the
## frame is over, so a later, separate draw always starts at zero again.
var _deal_slot: int = 0
var _deal_slot_queued: bool = false

## True once the row has been laid out at least once. Until then a card's
## position is meaningless, so nothing may be animated away from it.
var _row_laid_out: bool = false

@onready var cards_row: HBoxContainer = $MarginContainer/VBox/CardsRow


#region Lifecycle

func _ready() -> void:
	if EventBus.has_signal("card_played"):
		EventBus.card_played.connect(_on_event_card_played)
	# Skill-driven draws / discards happen mid-turn, while the hand UI is alive:
	# react to them right away instead of waiting for the next full refresh.
	if EventBus.has_signal("card_drawn"):
		EventBus.card_drawn.connect(_on_event_card_drawn)
	if EventBus.has_signal("card_discarded"):
		EventBus.card_discarded.connect(_on_event_card_discarded)

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


## Rebuilds the row from the model, reusing every CardUI that is still valid.
## A deal that is still in flight, a hover, or a pick highlight therefore all
## survive the refreshes BattleScene fires after every action.
## Cards that are new to the row are dealt in from the right; merged cards are
## forged in hand, so they simply fade into the gap that opens for them.
## Cards that left the hand slide the rest of the row into place instead of
## letting the layout snap them there.
func set_hand(cards: Array[Card]) -> void:
	var before: Dictionary[CardUI, Vector2] = _snapshot_slots()

	for ui: CardUI in _live_card_uis():
		if not cards.has(ui.card):
			_consume_card(ui.card)

	for card: Card in cards:
		if _find_card_ui(card) == null:
			_spawn_card(card, true)

	# The container is the layout authority, so the row still has to be put in
	# model order; the glide below hides the jump that reordering would cause.
	for index: int in cards.size():
		var ui: CardUI = _find_card_ui(cards[index])
		if ui != null and ui.get_index() != index:
			cards_row.move_child(ui, index)

	_glide_to_new_slots(before)
	_apply_pick_candidates()


## Appends one newly drawn card to the right end of the row, matching the model
## (which also appends), and deals it in from the deck. Safe to call twice for
## the same card: a refresh that already added it is a no-op.
func add_card(card: Card) -> void:
	if _find_card_ui(card) != null:
		return
	var before: Dictionary[CardUI, Vector2] = _snapshot_slots()
	_spawn_card(card, true)
	_glide_to_new_slots(before)
	# Keep any in-progress pick highlight correct for the rebuilt row.
	_apply_pick_candidates()


## Records where a card was let go of, so the merge it triggers can start that card
## from that exact point on screen instead of from the slot it was dragged out of.
## Called by the card the drop landed on, immediately before the merge is
## requested; consumed by `play_merge`.
func note_merge_release(card: Card, global_centre: Vector2) -> void:
	_release_card = card
	_release_centre = global_centre
	_has_merge_release = true


## Merges two cards in hand where the player left them: the card they were
## carrying drifts out of the point they released it at into the card they
## dropped it on, the two fold closed into a single edge, and the merged card
## opens back out of that edge.
##
## `card_a` is the card that was dragged and `card_b` the card it was dropped on;
## the merged card takes the target's slot, exactly like GameState.try_merge. The
## reconciliation happens here so the two cards are already mounted on the frame
## the row changes, and the hand refresh that follows reuses the merged card
## instead of tearing the merge down.
func play_merge(
	card_a: Card,
	card_b: Card,
	merged_card: Card,
	new_hand: Array[Card]
) -> void:
	# The release point is taken up front and cleared whatever happens next, so a
	# stale one can never be picked up by a later merge.
	var released_here: bool = _has_merge_release and _release_card == card_a
	var release_centre: Vector2 = _release_centre
	_release_card = null
	_has_merge_release = false

	if merged_card == null or not is_inside_tree():
		set_hand(new_hand)
		return

	var ui_a: CardUI = _find_card_ui(card_a)
	var ui_b: CardUI = _find_card_ui(card_b)
	if ui_a == null or ui_b == null:
		# The row does not hold the two source cards (e.g. a merge driven straight
		# on the model), so there is nothing to move together.
		set_hand(new_hand)
		return

	# Where the two cards are on screen as the player lets go: the one they were
	# carrying is wherever they released it, drawn at the size of the drag
	# preview, and the one it landed on is simply sitting in its slot.
	var start_centre_a: Vector2 = release_centre if released_here else ui_a.centre()
	var start_scale_a: float = CardUI.DRAG_PREVIEW_SCALE if released_here else 1.0
	var start_centre_b: Vector2 = ui_b.centre()

	# Snapshots have to be taken before the cards are consumed, and the plates have
	# to be built while their source cards are still alive.
	var before: Dictionary[CardUI, Vector2] = _snapshot_slots()
	var plate_a: ForgePlate = ui_a.make_merge_plate()
	var plate_b: ForgePlate = ui_b.make_merge_plate()

	# Both source cards left the model, so they leave the row at once and the
	# survivors glide into the gap they opened.
	_consume_card(card_a)
	_consume_card(card_b)

	var merged_ui: CardUI = _find_card_ui(merged_card)
	if merged_ui == null:
		merged_ui = _spawn_card(merged_card, false)

	for index: int in new_hand.size():
		var ui: CardUI = _find_card_ui(new_hand[index])
		if ui != null and ui.get_index() != index:
			cards_row.move_child(ui, index)

	_glide_to_new_slots(before)
	_apply_pick_candidates()

	merged_ui.play_merge_animation(
		plate_a, plate_b, start_centre_a, start_centre_b, start_scale_a
	)


## A card left the hand: it drops out of the row at once and the cards around it
## glide into the gap it left.
func remove_card(card: Card) -> void:
	var before: Dictionary[CardUI, Vector2] = _snapshot_slots()
	if _consume_card(card):
		_glide_to_new_slots(before)


## Locks a card against further interaction and takes it out of the row, so the
## layout closes the gap it left. Returns false when it was already gone.
func _consume_card(card: Card) -> bool:
	var ui: CardUI = _find_card_ui(card)
	if ui == null:
		return false

	ui.mark_consumed()
	# The card is invisible from here on, so it can leave the row immediately:
	# the cards around it then glide into the space it used to hold.
	cards_row.remove_child(ui)
	ui.queue_free()
	return true


## The slot every card currently occupies, so a layout change can glide from it.
func _snapshot_slots() -> Dictionary[CardUI, Vector2]:
	var snapshot: Dictionary[CardUI, Vector2] = {}
	for ui: CardUI in _live_card_uis():
		snapshot[ui] = ui.position
	return snapshot


## Lets the container re-sort the row, then glides every card that was already on
## screen from the slot it had to the slot it now belongs in. The sort and this
## callback both run before the frame is drawn, so the snap never shows.
func _glide_to_new_slots(before: Dictionary[CardUI, Vector2]) -> void:
	var glide: bool = _row_laid_out and not before.is_empty()
	_row_laid_out = true
	cards_row.queue_sort()
	if glide:
		_apply_glide.call_deferred(before)


func _apply_glide(before: Dictionary[CardUI, Vector2]) -> void:
	for ui: CardUI in before:
		if not is_instance_valid(ui) or ui.is_consumed():
			continue
		# A card that is being merged owns its own transform: sliding its layout
		# slot would drag the two cards out from under that.
		if ui.is_merging():
			continue
		var target: Vector2 = ui.position
		var from: Vector2 = before[ui]
		if from.is_equal_approx(target):
			continue
		ui.position = from
		ui.slide_to(target, SLIDE_TIME)


func _spawn_card(card: Card, animate: bool) -> CardUI:
	var ui: CardUI = CARD_SCENE.instantiate()
	cards_row.add_child(ui)
	ui.setup(card, self)

	ui.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	if not animate:
		ui.modulate.a = 1.0
		return ui

	if card.is_merged:
		# A merged card is forged in hand rather than dealt from the deck, so it
		# simply fades into the slot that opened up for it.
		ui.modulate.a = 0.0
		var fade: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		fade.tween_property(ui, "modulate:a", 1.0, ENTER_TWEEN_TIME)
		return ui

	var slot: int = _next_deal_slot()
	ui.play_draw_animation(_deck_offset(slot), DEAL_STAGGER * float(slot), slot)
	return ui


## Hands out the next stagger slot for cards dealt in the same frame. The counter
## resets once the frame is over, so a later, unrelated draw starts at zero again.
func _next_deal_slot() -> int:
	var slot: int = _deal_slot
	_deal_slot += 1
	if not _deal_slot_queued:
		_deal_slot_queued = true
		_reset_deal_slots.call_deferred()
	return slot


func _reset_deal_slots() -> void:
	_deal_slot_queued = false
	_deal_slot = 0


## Deck origin for a dealt card, in CardUI-local pixels. Drawn cards always land
## at the right end of the row, so half the hand bar plus one card width is
## always beyond the visible hand area, whatever the window size.
func _deck_offset(slot: int) -> Vector2:
	var bar_width: float = maxf(get_global_rect().size.x, CARD_WIDTH * 6.0)
	var origin := Vector2(bar_width * 0.5 + CARD_WIDTH, DECK_DROP)
	return origin + DECK_STACK_STEP * float(slot % 2)


## Every CardUI in the row that is still alive and not already collapsing.
func _live_card_uis() -> Array[CardUI]:
	var result: Array[CardUI] = []
	for child: Node in cards_row.get_children():
		var ui: CardUI = child as CardUI
		if ui != null and not ui.is_queued_for_deletion() and not ui.is_consumed():
			result.append(ui)
	return result


func can_merge(card_a: Card, card_b: Card) -> bool:
	if card_a == null or card_b == null or card_a == card_b:
		return false
	var st := _get_game_state()
	if st != null:
		return st.merges_left > 0 and st.can_merge_pair(card_a, card_b)
	return not card_a.is_double_merged and not card_b.is_double_merged


## Falls back to walking the scene for the live GameState when the scene has not
## pushed one down yet. Also used by CardUI to re-show a card it did not consume.
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


## A skill drew a card mid-turn. Deal it in right away, so the player can see it
## (and pick it, when the same skill asks for a card) before the action resolves.
func _on_event_card_drawn(card: Card) -> void:
	add_card(card)


## A skill discarded a card. Collapse it right away instead of waiting for the
## post-action refresh.
func _on_event_card_discarded(card: Card) -> void:
	remove_card(card)

#endregion
