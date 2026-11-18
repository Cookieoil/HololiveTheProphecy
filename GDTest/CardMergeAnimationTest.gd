class_name CardMergeAnimationTest
extends GdUnitTestSuite
## Locks in the merge: the card the player was carrying is picked up from the
## exact point they released it, the two cards drift into each other and fold
## closed into one edge, and the merged card opens back out of that edge.
##   - the merge starts where the card was released, at the drag preview's size,
##     and not from the slot it was dragged out of
##   - the two cards are never taken off screen before the merged card is on it
##     (they are children of the node that used to be dimmed to hide it)
##   - the two cards fold edge on, which is what makes the hand over to the
##     merged card invisible, and the merged card starts folded the same way
##   - the merged card is drawn in front of both, flat again and back on the
##     layout grid once it is over
##   - the survivors of the merge glide into the gap it left
##   - the hand refresh BattleScene fires after every action reuses the merging
##     card instead of interrupting it
##   - grabbing the card mid-merge leaves it flat, visible and grabbable
##   - a double merge produces a free-play card, and every card in hand wears the
##     same frame whatever it has been through
##
## @author TheGreatJellyfish
## @version 11/18/2026

## Comfortably longer than CardUI's converge + reveal.
const MERGE_SETTLE_MILLIS: int = 900
## Just past the point the two cards have folded away and the merged card has
## taken over from the edge they left: CardUI.MERGE_CONVERGE_TIME plus a margin.
const FOLDED_MILLIS: int = 360
## Part way through CardUI.MERGE_CONVERGE_TIME, for looking at cards mid-drift.
const HALF_WAY_MILLIS: int = 150
## Long enough for the hand layout to settle, so slot positions are real.
const LAYOUT_SETTLE_MILLIS: int = 60


## Minimal HandBar: the real one lives inside BattleScene, which would start a
## whole game, so only the node path HandBar actually needs is built here.
func _make_hand_bar() -> HandBar:
	var bar: HandBar = HandBar.new()
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "MarginContainer"
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "VBox"
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "CardsRow"
	bar.add_child(margin)
	margin.add_child(column)
	column.add_child(row)
	add_child(bar)
	return bar


func _row(bar: HandBar) -> Array[CardUI]:
	var result: Array[CardUI] = []
	for child: Node in bar.cards_row.get_children():
		var ui: CardUI = child as CardUI
		if ui != null:
			result.append(ui)
	return result


func _card_ui(bar: HandBar, card: Card) -> CardUI:
	var ui: CardUI = bar._find_card_ui(card)
	assert_object(ui).is_not_null()
	return ui


## The two cards in the merge, the dragged one first, whatever order they happen
## to sit in for drawing.
func _plates(ui: CardUI) -> Array[ForgePlate]:
	var result: Array[ForgePlate] = []
	for child: Node in ui.bounds.get_children():
		var plate: ForgePlate = child as ForgePlate
		if plate != null:
			result.append(plate)
	result.sort_custom(
		func(a: ForgePlate, b: ForgePlate) -> bool:
			return String(a.name) < String(b.name)
	)
	return result


## Reads one of the fake-3D uniforms, so a test can assert on the card's pose.
func _tilt(ui: CardUI, param: StringName) -> float:
	var material: ShaderMaterial = ui._card_material
	assert_object(material).is_not_null()
	var raw: Variant = material.get_shader_parameter(param)
	assert_bool(raw is float).is_true()
	var value: float = raw
	return value


## Builds a hand of the given values in the row and on the model.
func _ready_hand(bar: HandBar, values: Array[int]) -> GameState:
	var state: GameState = GameState.new()
	var hand: Array[Card] = []
	for value: int in values:
		hand.append(Card.new(value))
	state.hand = hand
	bar.set_hand(state.hand)
	return state


## Merges the two cards at the given hand indices exactly like GameManager does:
## the model merge, then the presentation call that plays the merge.
func _merge_on_state(bar: HandBar, state: GameState, index_a: int, index_b: int) -> Card:
	var card_a: Card = state.hand[index_a]
	var card_b: Card = state.hand[index_b]
	var merged: Card = state.try_merge(card_a, card_b)
	assert_object(merged).is_not_null()
	bar.play_merge(card_a, card_b, merged, state.hand)
	return merged



func test_the_two_cards_are_mounted_where_they_were_and_the_layout_never_moves() -> void:
	var bar: HandBar = _make_hand_bar()
	var a: Card = Card.new(2)
	var b: Card = Card.new(3)
	var last: Card = Card.new(5)
	bar.set_hand([a, b, last])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# Where the two cards are on screen, and the slot the merge will produce.
	var a_centre: Vector2 = _card_ui(bar, a).centre()
	var b_centre: Vector2 = _card_ui(bar, b).centre()
	var merged_slot: Vector2 = _card_ui(bar, a).position

	var merged: Card = Card.new(5)
	merged.is_merged = true
	bar.play_merge(a, b, merged, [merged, last])

	var merged_ui: CardUI = _card_ui(bar, merged)
	assert_bool(merged_ui.is_merging()).is_true()
	# The merged card itself is hidden while the two cards travel...
	assert_bool(merged_ui._visual_root.visible).is_false()
	# ...but the node carrying them is never dimmed. Dimming it here would take
	# the two cards down with it, and the merge would read as two cards vanishing
	# into a third one that appeared out of nowhere.
	assert_float(merged_ui.modulate.a).is_equal_approx(1.0, 0.001)
	# The merged card takes the slot the merge produced.
	assert_int(merged_ui.get_index()).is_equal(0)

	# Both cards are up, each setting off from exactly where it was on screen, at
	# the size it was drawn at.
	var plates: Array[ForgePlate] = _plates(merged_ui)
	assert_int(plates.size()).is_equal(2)
	assert_float(plates[0].centre().distance_to(a_centre)).is_less(0.5)
	assert_float(plates[1].centre().distance_to(b_centre)).is_less(0.5)
	assert_float(plates[0].scale.x).is_equal_approx(1.0, 0.001)
	# And they are flat to start with: the fold only comes as they arrive.
	assert_float(absf(plates[0].tilt().x)).is_less(1.0)

	await await_millis(LAYOUT_SETTLE_MILLIS)
	# The merge plays around the fixed layout slot, so the hand never re-flowed:
	# the merged card is exactly on the slot the merge produced.
	assert_vector(merged_ui.position).is_equal(merged_slot)
	assert_int(bar.cards_row.get_child_count()).is_equal(2)
	assert_object(_card_ui(bar, last)).is_not_null()


## The point of the whole animation: the card the player was carrying is picked
## up where they let go of it, not where it was dragged out of.
func test_the_merge_starts_from_where_the_card_was_released() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	var dragged: Card = state.hand[1]
	var target: Card = state.hand[2]
	var slot_centre: Vector2 = _card_ui(bar, dragged).centre()
	var target_centre: Vector2 = _card_ui(bar, target).centre()
	# Somewhere well clear of the hand, as if the player had carried the card up
	# and let go of it a little early.
	var released: Vector2 = slot_centre + Vector2(-140.0, -90.0)

	bar.note_merge_release(dragged, released)
	var merged: Card = state.try_merge(dragged, target)
	assert_object(merged).is_not_null()
	bar.play_merge(dragged, target, merged, state.hand)

	var merged_ui: CardUI = _card_ui(bar, merged)
	var plates: Array[ForgePlate] = _plates(merged_ui)
	assert_int(plates.size()).is_equal(2)
	# The carried card starts at the point of release, nowhere near its old slot...
	assert_float(plates[0].centre().distance_to(released)).is_less(0.5)
	assert_float(plates[0].centre().distance_to(slot_centre)).is_greater(100.0)
	# ...at the size the drag preview was, so it does not shrink as it is taken
	# over, and the card it was dropped on is simply where it was sitting.
	assert_float(plates[0].scale.x).is_equal_approx(CardUI.DRAG_PREVIEW_SCALE, 0.001)
	assert_float(plates[1].centre().distance_to(target_centre)).is_less(0.5)

	# Half way in it is on its way from the release point to the merged card, and
	# it has snapped to neither.
	await await_millis(HALF_WAY_MILLIS)
	var live: Array[ForgePlate] = _plates(merged_ui)
	assert_int(live.size()).is_equal(2)
	var landing: Vector2 = merged_ui.centre()
	var travelled: float = live[0].centre().distance_to(released)
	assert_float(travelled).is_greater(5.0)
	assert_float(travelled).is_less(released.distance_to(landing) - 5.0)

	await await_millis(MERGE_SETTLE_MILLIS)
	# ...and it gets there: the merge is over, with the card resting in the row.
	assert_bool(merged_ui.is_merging()).is_false()
	assert_object(_card_ui(bar, merged)).is_same(merged_ui)


## A merge driven on the model rather than by a drag has no release point to pick
## up from, so the carried card starts from its own slot instead.
func test_a_merge_with_no_release_starts_from_the_cards_own_slot() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	var dragged: Card = state.hand[1]
	var slot_centre: Vector2 = _card_ui(bar, dragged).centre()

	var merged: Card = _merge_on_state(bar, state, 1, 2)

	var plates: Array[ForgePlate] = _plates(_card_ui(bar, merged))
	assert_int(plates.size()).is_equal(2)
	assert_float(plates[0].centre().distance_to(slot_centre)).is_less(0.5)
	assert_float(plates[0].scale.x).is_equal_approx(1.0, 0.001)


## The two cards fold edge on as they arrive, and the merged card opens back out
## of that same fold. At the angle they fold to, a card is a hair line, which is
## the whole reason the hand over between them can happen without being seen.
func test_the_two_cards_fold_edge_on_and_the_merged_card_opens_out_of_it() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var merged_ui: CardUI = _card_ui(bar, merged)

	# One pass over the whole merge: the two cards travel flat, fold over as they
	# arrive, and the card that takes over from them opens back out.
	var first_fold: float = -1.0
	var deepest_fold: float = 0.0
	var deepest_open: float = 0.0
	var seen_open: bool = false
	for _sample: int in 90:
		await await_millis(10)
		var plates: Array[ForgePlate] = _plates(merged_ui)
		if not plates.is_empty():
			var yaw: float = absf(plates[0].tilt().x)
			if first_fold < 0.0:
				first_fold = yaw
			deepest_fold = maxf(deepest_fold, yaw)
		if merged_ui._visual_root.visible:
			seen_open = true
			deepest_open = maxf(deepest_open, absf(_tilt(merged_ui, "y_rot")))
		if not merged_ui.is_merging():
			break

	# They travel flat and only fold over as they arrive...
	assert_float(first_fold).is_less(5.0)
	assert_float(deepest_fold).is_greater(60.0)
	# ...and the card they became is folded the same way when it takes over, so
	# the fold it opens out of is the fold they closed into.
	assert_bool(seen_open).is_true()
	assert_float(deepest_open).is_greater(60.0)

	await await_millis(MERGE_SETTLE_MILLIS)
	# Over: flat, resting, in front, and back on the layout grid.
	assert_float(_tilt(merged_ui, "y_rot")).is_equal_approx(0.0, 0.01)
	assert_float(_tilt(merged_ui, "x_rot")).is_equal_approx(0.0, 0.01)
	assert_bool(merged_ui._visual_root.visible).is_true()
	assert_float(merged_ui._visual_root.scale.x).is_equal_approx(1.0, 0.01)


func test_the_merged_card_settles_flat_and_the_merge_is_cleaned_up() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var merged_ui: CardUI = _card_ui(bar, merged)
	assert_bool(merged_ui.is_merging()).is_true()

	await await_millis(MERGE_SETTLE_MILLIS)

	assert_bool(merged_ui.is_merging()).is_false()
	# Nothing of the merge survives on a card that is simply sitting in hand.
	assert_int(_plates(merged_ui).size()).is_equal(0)
	# It is up, resting, and back on the same pixel grid it was drawn on.
	assert_bool(merged_ui._visual_root.visible).is_true()
	assert_float(merged_ui.modulate.a).is_equal_approx(1.0, 0.001)
	assert_float(merged_ui._visual_root.position.x).is_equal_approx(0.0, 0.01)
	assert_float(merged_ui._visual_root.position.y).is_equal_approx(0.0, 0.01)
	assert_float(merged_ui._visual_root.scale.x).is_equal_approx(1.0, 0.01)
	# It is warped back to dead flat by the fake-3D shader...
	assert_float(_tilt(merged_ui, "x_rot")).is_equal_approx(0.0, 0.01)
	assert_float(_tilt(merged_ui, "y_rot")).is_equal_approx(0.0, 0.01)
	# ...and back on the resting pixel grid, lined up with its slot.
	assert_vector(merged_ui._card_surface.canvas_transform.get_scale()).is_equal(Vector2.ONE)
	assert_vector(Vector2(merged_ui._card_surface.size)).is_equal(CardUI.QUAD_SIZE)


func test_the_merged_card_takes_the_slot_the_merge_produced() -> void:
	var bar: HandBar = _make_hand_bar()
	# 3 + 5 = 8, sitting where the target 5 was: [2, 8].
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)

	var row: Array[CardUI] = _row(bar)
	assert_int(row.size()).is_equal(2)
	assert_object(row[1].card).is_same(merged)
	assert_int(row[1].card.get_effective_value()).is_equal(8)

	await await_millis(MERGE_SETTLE_MILLIS)
	# The merged card never teleports to the far right once the merge is over.
	assert_object(_row(bar)[1].card).is_same(merged)
	assert_int(bar.cards_row.get_child_count()).is_equal(2)



func test_the_hand_refresh_reuses_the_merging_card() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var merged_ui: CardUI = _card_ui(bar, merged)

	# BattleScene refreshes the hand after every action, right after the merge
	# (show_hand_and_resources). That refresh must not tear the merge down.
	bar.set_hand(state.hand)

	assert_object(_card_ui(bar, merged)).is_same(merged_ui)
	assert_bool(merged_ui.is_merging()).is_true()
	assert_int(_plates(merged_ui).size()).is_equal(2)

	await await_millis(MERGE_SETTLE_MILLIS)
	assert_bool(merged_ui.is_merging()).is_false()
	assert_int(_plates(merged_ui).size()).is_equal(0)


func test_the_hand_refresh_never_slides_the_merging_card() -> void:
	var bar: HandBar = _make_hand_bar()
	var first: Card = Card.new(2)
	var second: Card = Card.new(3)
	var third: Card = Card.new(5)
	bar.set_hand([first, second, third])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# 3 + 5 = 8 lands in the slot the 3 held.
	var merged_slot: Vector2 = _card_ui(bar, second).position
	var merged: Card = Card.new(8)
	merged.is_merged = true
	bar.play_merge(second, third, merged, [first, merged])
	var merged_ui: CardUI = _card_ui(bar, merged)

	# A refresh right after the merge would otherwise snapshot the merged card at
	# its not-yet-laid-out position and slide the merge out from under the cards.
	bar.set_hand([first, merged])
	await await_millis(HALF_WAY_MILLIS)

	# The merge is untouched: both cards are still travelling, and its slot was
	# never slid away from the slot the merge produced.
	assert_bool(merged_ui.is_merging()).is_true()
	assert_int(_plates(merged_ui).size()).is_equal(2)
	assert_vector(merged_ui.position).is_equal(merged_slot)


func test_grabbing_a_merging_card_snaps_it_flat() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var merged_ui: CardUI = _card_ui(bar, merged)

	# What a fast player does by dragging the freshly merged card.
	merged_ui._finish_merge_immediate()

	assert_bool(merged_ui.is_merging()).is_false()
	assert_int(_plates(merged_ui).size()).is_equal(0)
	# The card is visible and grabbable instead of being left hidden mid-flight,
	# and it is flat instead of left part way through a fold.
	assert_bool(merged_ui._visual_root.visible).is_true()
	assert_float(merged_ui.modulate.a).is_equal_approx(1.0, 0.001)
	assert_float(merged_ui._visual_root.position.x).is_equal_approx(0.0, 0.001)
	assert_float(merged_ui._visual_root.scale.x).is_equal_approx(1.0, 0.001)
	assert_float(_tilt(merged_ui, "x_rot")).is_equal_approx(0.0, 0.001)
	assert_float(_tilt(merged_ui, "y_rot")).is_equal_approx(0.0, 0.001)


func test_the_survivors_glide_into_the_gap_the_merge_left() -> void:
	var bar: HandBar = _make_hand_bar()
	var first: Card = Card.new(2)
	var second: Card = Card.new(3)
	var third: Card = Card.new(5)
	bar.set_hand([first, second, third])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# 3 + 5 = 8 sits in the slot the 3 held; the 5's slot is the one that closes.
	var merged_slot_x: float = _card_ui(bar, second).position.x
	var third_start_x: float = _card_ui(bar, third).position.x

	var merged: Card = Card.new(8)
	merged.is_merged = true
	bar.play_merge(second, third, merged, [first, merged])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# Two cards became one, so the end of the hand really did move left...
	assert_float(_card_ui(bar, merged).position.x).is_less(third_start_x)
	# ...and the merged card sits exactly on the slot the merge produced, next to
	# the survivor that never moved.
	assert_float(_card_ui(bar, merged).position.x).is_equal_approx(merged_slot_x, 0.5)
	assert_float(_card_ui(bar, first).position.x).is_equal_approx(0.0, 0.5)
	assert_int(_row(bar).size()).is_equal(2)



func test_a_double_merge_merges_a_free_play_card() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [4, 2, 2, 6])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# 4 + 2 = 6 (merged), then 6 + 6 + 1 = 13 and it plays for free.
	var first_merge: Card = _merge_on_state(bar, state, 0, 1)
	assert_bool(first_merge.is_merged).is_true()
	await await_millis(MERGE_SETTLE_MILLIS)

	var target: Card = state.hand[2]
	var doubled: Card = state.try_merge(first_merge, target)
	assert_object(doubled).is_not_null()
	assert_bool(doubled.is_double_merged).is_true()
	bar.play_merge(first_merge, target, doubled, state.hand)

	var merged_ui: CardUI = _card_ui(bar, doubled)
	assert_bool(merged_ui.is_merging()).is_true()
	# A double merge is a free-play card, and the only thing that has to say so is
	# the card itself: 13 DMV, which costs no action.
	assert_int(_plates(merged_ui).size()).is_equal(2)

	await await_millis(MERGE_SETTLE_MILLIS)
	assert_bool(merged_ui.is_merging()).is_false()
	assert_int(merged_ui.card.get_effective_value()).is_equal(13)
	assert_bool(merged_ui.card.costs_action()).is_false()


## Every card wears the same frame, whatever it has been through. Merging used to
## repaint the frame, which made a merged card look like a different object
## rather than the card it came from.
func test_every_card_wears_the_same_frame() -> void:
	var bar: HandBar = _make_hand_bar()
	var base: Card = Card.new(3)
	var merged: Card = Card.new(8)
	merged.is_merged = true
	var doubled: Card = Card.new(13)
	doubled.is_merged = true
	doubled.is_double_merged = true
	bar.set_hand([base, merged, doubled])

	for card: Card in [base, merged, doubled]:
		var frame: StyleBoxFlat = _card_ui(bar, card).frame_style()
		assert_object(frame).is_not_null()
		assert_bool(frame.bg_color.is_equal_approx(CardUI.CARD_BG_COLOR)).is_true()
		assert_bool(frame.border_color.is_equal_approx(CardUI.CARD_BORDER_COLOR)).is_true()
		assert_int(frame.border_width_left).is_equal(CardUI.CARD_BORDER_WIDTH)


## The user-visible contract: the two cards must never be taken off screen before
## the merged card is on it. They are children of the very node that used to be
## dimmed to hide it, so this samples the whole merge and checks that neither the
## dimming nor an early hand over can come back.
func test_the_two_cards_are_never_hidden_before_the_merged_card() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var merged_ui: CardUI = _card_ui(bar, merged)

	var dimmed_frames: int = 0
	var blank_frames: int = 0
	var born: bool = false
	var born_with_both_cards: bool = false
	for _sample: int in 80:
		await await_millis(5)
		if merged_ui.modulate.a < 1.0:
			dimmed_frames += 1
		var plates: Array[ForgePlate] = _plates(merged_ui)
		if merged_ui._visual_root.visible:
			if not born:
				born = true
				# The first frame the merged card is up, both cards it was made
				# from are still on screen at full strength.
				born_with_both_cards = plates.size() == 2 \
					and plates[0].modulate.a > 0.99 and plates[1].modulate.a > 0.99
		elif plates.is_empty():
			# Card hidden and both cards already gone: the dead frame the merge
			# used to blink through.
			blank_frames += 1

	assert_bool(born).is_true()
	assert_bool(born_with_both_cards).is_true()
	assert_int(dimmed_frames).is_equal(0)
	assert_int(blank_frames).is_equal(0)


## The card that comes out of the merge has to be the thing the player watches,
## so both cards that made it are parked behind it in the draw order.
func test_the_merged_card_is_drawn_in_front_of_the_two_cards_that_made_it() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var merged_ui: CardUI = _card_ui(bar, merged)

	var plates: Array[ForgePlate] = _plates(merged_ui)
	assert_int(plates.size()).is_equal(2)
	for plate: ForgePlate in plates:
		assert_int(plate.get_index()).is_less(merged_ui._visual_root.get_index())


## The two cards are drawn in viewport space, detached from the hand's layout, so
## the merge can glide between the point of release and the slot it lands in
## without either having to be expressed in the card's own local pixels.
func test_the_two_cards_are_drawn_detached_from_the_hand_layout() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)

	for plate: ForgePlate in _plates(_card_ui(bar, merged)):
		assert_bool(plate.top_level).is_true()
