class_name CardMergeAnimationTest
extends GdUnitTestSuite
## Locks in the merge: the two cards slide onto the same spot and the card they
## become is simply there - the plain Reverse: 1999 read, no wind-up and no impact.
##   - the two source cards are never taken off screen before the merged card is
##     on it (they are children of the node that used to be dimmed to hide it)
##   - the merged card takes over their exact spot at full size, unmoved and
##     unwarped, so no part of the silhouette jumps when the two become one
##   - the two cards finish up stacked on that spot, behind it
##   - the survivors of the merge glide into the gap it left
##   - the hand refresh BattleScene fires after every action reuses the merging
##     card instead of interrupting it
##   - grabbing the card mid-merge leaves it flat, visible and grabbable
##   - a double merge (a free-play card) merges differently from a cross merge
##
## @author TheGreatJellyfish
## @version 11/18/2026

## Comfortably longer than CardUI's move + settle.
const FORGE_SETTLE_MILLIS: int = 900
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


## The two source cards mounted in the slot, the dragged card first, whatever
## order they happen to sit in for drawing.
func _ghosts(ui: CardUI) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in ui.bounds.get_children():
		if child.name.begins_with("ForgePlate"):
			var control: Control = child as Control
			if control != null:
				result.append(control)
	result.sort_custom(
		func(a: Control, b: Control) -> bool:
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
## the model merge, then the presentation call that plays the forge.
func _merge_on_state(bar: HandBar, state: GameState, index_a: int, index_b: int) -> Card:
	var card_a: Card = state.hand[index_a]
	var card_b: Card = state.hand[index_b]
	var merged: Card = state.try_merge(card_a, card_b)
	assert_object(merged).is_not_null()
	bar.play_merge(card_a, card_b, merged, state.hand)
	return merged


func test_the_two_plates_are_mounted_and_the_layout_never_moves() -> void:
	var bar: HandBar = _make_hand_bar()
	var a: Card = Card.new(2)
	var b: Card = Card.new(3)
	var last: Card = Card.new(5)
	bar.set_hand([a, b, last])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# The merge of the first two cards produces the slot the first one held.
	var anvil_slot: Vector2 = _card_ui(bar, a).position

	var merged: Card = Card.new(5)
	merged.is_merged = true
	bar.play_merge(a, b, merged, [merged, last])

	var forged_ui: CardUI = _card_ui(bar, merged)
	assert_bool(forged_ui.is_merging()).is_true()
	# The card itself is hidden while the two source cards fly in...
	assert_bool(forged_ui._visual_root.visible).is_false()
	# ...but the node carrying those two cards is never dimmed. Dimming it here
	# would take the two source cards down with it, and the merge would read as
	# two cards vanishing into a third one that appeared out of nowhere.
	assert_float(forged_ui.modulate.a).is_equal_approx(1.0, 0.001)
	# The forged card takes the slot the merge produced.
	assert_int(forged_ui.get_index()).is_equal(0)

	# Both source cards are mounted on that slot, starting exactly where they sat
	# in hand: plate A on the anvil, plate B one slot to its right.
	var ghosts: Array[Control] = _ghosts(forged_ui)
	assert_int(ghosts.size()).is_equal(2)
	assert_float(absf(ghosts[0].position.x)).is_less(1.0)
	assert_float(ghosts[1].position.x).is_greater(90.0)

	await await_millis(LAYOUT_SETTLE_MILLIS)
	# The forge plays inside the fixed layout slot, so the hand never re-flowed:
	# the forged card is exactly on the slot the merge produced.
	assert_vector(forged_ui.position).is_equal(anvil_slot)
	assert_int(bar.cards_row.get_child_count()).is_equal(2)
	assert_object(_card_ui(bar, last)).is_not_null()


func test_the_forged_card_settles_flat_and_the_weld_is_cleaned_up() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var forged_ui: CardUI = _card_ui(bar, merged)
	assert_bool(forged_ui.is_merging()).is_true()

	await await_millis(FORGE_SETTLE_MILLIS)

	assert_bool(forged_ui.is_merging()).is_false()
	# Nothing of the forge survives on a card that is simply sitting in hand.
	assert_int(_ghosts(forged_ui).size()).is_equal(0)
	assert_object(forged_ui._weld_overlay).is_null()
	# It is up, resting, and back on the same pixel grid it was drawn on.
	assert_bool(forged_ui._visual_root.visible).is_true()
	assert_float(forged_ui.modulate.a).is_equal_approx(1.0, 0.001)
	assert_float(forged_ui._visual_root.position.x).is_equal_approx(0.0, 0.01)
	assert_float(forged_ui._visual_root.position.y).is_equal_approx(0.0, 0.01)
	assert_float(forged_ui._visual_root.scale.x).is_equal_approx(1.0, 0.01)
	# It is warped back to dead flat by the fake-3D shader...
	assert_float(_tilt(forged_ui, "x_rot")).is_equal_approx(0.0, 0.01)
	assert_float(_tilt(forged_ui, "y_rot")).is_equal_approx(0.0, 0.01)
	# ...and back on the resting pixel grid, lined up with its slot.
	assert_vector(forged_ui._card_surface.canvas_transform.get_scale()).is_equal(Vector2.ONE)
	assert_vector(Vector2(forged_ui._card_surface.size)).is_equal(CardUI.QUAD_SIZE)


func test_the_forged_card_takes_the_slot_the_merge_produced() -> void:
	var bar: HandBar = _make_hand_bar()
	# 3 + 5 = 8, sitting where the target 5 was: [2, 8].
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)

	var row: Array[CardUI] = _row(bar)
	assert_int(row.size()).is_equal(2)
	assert_object(row[1].card).is_same(merged)
	assert_int(row[1].card.get_effective_value()).is_equal(8)

	await await_millis(FORGE_SETTLE_MILLIS)
	# The forged card never teleports to the far right once the weld is over.
	assert_object(_row(bar)[1].card).is_same(merged)
	assert_int(bar.cards_row.get_child_count()).is_equal(2)


func test_the_hand_refresh_reuses_the_forging_card() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var forged_ui: CardUI = _card_ui(bar, merged)

	# BattleScene refreshes the hand after every action, right after the merge
	# (show_hand_and_resources). That refresh must not tear the weld down.
	bar.set_hand(state.hand)

	assert_object(_card_ui(bar, merged)).is_same(forged_ui)
	assert_bool(forged_ui.is_merging()).is_true()
	assert_int(_ghosts(forged_ui).size()).is_equal(2)

	await await_millis(FORGE_SETTLE_MILLIS)
	assert_bool(forged_ui.is_merging()).is_false()
	assert_int(_ghosts(forged_ui).size()).is_equal(0)


func test_the_hand_refresh_never_slides_the_forging_card() -> void:
	var bar: HandBar = _make_hand_bar()
	var first: Card = Card.new(2)
	var second: Card = Card.new(3)
	var third: Card = Card.new(5)
	bar.set_hand([first, second, third])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# 3 + 5 = 8 lands in the slot the 3 held.
	var anvil_slot: Vector2 = _card_ui(bar, second).position
	var merged: Card = Card.new(8)
	merged.is_merged = true
	bar.play_merge(second, third, merged, [first, merged])
	var forged_ui: CardUI = _card_ui(bar, merged)

	# A refresh right after the forge would otherwise snapshot the forged card at
	# its not-yet-laid-out position and slide the weld out from under the strike.
	bar.set_hand([first, merged])
	await await_millis(120)

	# The forge is untouched: the weld is still mounted, both plates are still on
	# the anvil...
	assert_bool(forged_ui.is_merging()).is_true()
	assert_object(forged_ui._weld_overlay).is_not_null()
	assert_int(_ghosts(forged_ui).size()).is_equal(2)
	# ...and its slot was never slid away from the slot the merge produced.
	assert_vector(forged_ui.position).is_equal(anvil_slot)


func test_grabbing_a_forging_card_snaps_it_flat() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var forged_ui: CardUI = _card_ui(bar, merged)

	# What a fast player does by dragging the freshly merged card.
	forged_ui._finish_merge_immediate()

	assert_bool(forged_ui.is_merging()).is_false()
	assert_int(_ghosts(forged_ui).size()).is_equal(0)
	assert_object(forged_ui._weld_overlay).is_null()
	# The card is visible and grabbable instead of being left hidden mid-flight,
	# and it is flat instead of left part way through unfolding.
	assert_bool(forged_ui._visual_root.visible).is_true()
	assert_float(forged_ui._visual_root.position.x).is_equal_approx(0.0, 0.001)
	assert_float(forged_ui._visual_root.scale.x).is_equal_approx(1.0, 0.001)
	assert_float(_tilt(forged_ui, "x_rot")).is_equal_approx(0.0, 0.001)


func test_the_survivors_glide_into_the_gap_the_merge_left() -> void:
	var bar: HandBar = _make_hand_bar()
	var first: Card = Card.new(2)
	var second: Card = Card.new(3)
	var third: Card = Card.new(5)
	bar.set_hand([first, second, third])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# 3 + 5 = 8 sits in the slot the 3 held; the 5's slot is the one that closes.
	var anvil_slot_x: float = _card_ui(bar, second).position.x
	var third_start_x: float = _card_ui(bar, third).position.x

	var merged: Card = Card.new(8)
	merged.is_merged = true
	bar.play_merge(second, third, merged, [first, merged])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# Two cards became one, so the end of the hand really did move left...
	assert_float(_card_ui(bar, merged).position.x).is_less(third_start_x)
	# ...and the forged card sits exactly on the slot the merge produced, next to
	# the survivor that never moved.
	assert_float(_card_ui(bar, merged).position.x).is_equal_approx(anvil_slot_x, 0.5)
	assert_float(_card_ui(bar, first).position.x).is_equal_approx(0.0, 0.5)
	assert_int(_row(bar).size()).is_equal(2)


func test_a_double_merge_forges_a_free_play_card() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [4, 2, 2, 6])
	await await_millis(LAYOUT_SETTLE_MILLIS)

	# 4 + 2 = 6 (merged), then 6 + 6 + 1 = 13 and it plays for free.
	var first_merge: Card = _merge_on_state(bar, state, 0, 1)
	assert_bool(first_merge.is_merged).is_true()
	await await_millis(FORGE_SETTLE_MILLIS)

	var target: Card = state.hand[2]
	var doubled: Card = state.try_merge(first_merge, target)
	assert_object(doubled).is_not_null()
	assert_bool(doubled.is_double_merged).is_true()
	bar.play_merge(first_merge, target, doubled, state.hand)

	var forged_ui: CardUI = _card_ui(bar, doubled)
	assert_bool(forged_ui.is_merging()).is_true()
	# The weld shader is told this forge is a double merge, so it fractures the
	# face into crystal facets and turns the seam dual tone.
	assert_object(forged_ui._weld_material).is_not_null()
	assert_bool(forged_ui._weld_material.get_shader_parameter("is_double_merge")).is_true()

	await await_millis(FORGE_SETTLE_MILLIS)
	assert_bool(forged_ui.is_merging()).is_false()
	assert_int(forged_ui.card.get_effective_value()).is_equal(13)
	assert_bool(forged_ui.card.costs_action()).is_false()


func test_a_resting_card_frame_reads_its_forge_rank() -> void:
	var bar: HandBar = _make_hand_bar()
	var base: Card = Card.new(3)
	var merged: Card = Card.new(8)
	merged.is_merged = true
	var doubled: Card = Card.new(13)
	doubled.is_merged = true
	doubled.is_double_merged = true
	bar.set_hand([base, merged, doubled])

	# A cross merge is gilded like the kintsugi seam that made it...
	assert_bool(
		_card_ui(bar, merged)._panel_box.border_color.is_equal_approx(CardUI.MERGE_BORDER_COLOR)
	).is_true()
	# ...and a free-play card gets the prophecy cyan rim, so it can be spotted in
	# hand at a glance.
	assert_bool(
		_card_ui(bar, doubled)._panel_box.border_color.is_equal_approx(
			CardUI.DOUBLE_MERGE_BORDER_COLOR
		)
	).is_true()
	# A card that has never been merged keeps the plain steel frame.
	assert_bool(
		_card_ui(bar, base)._panel_box.border_color.is_equal_approx(CardUI.BASE_BORDER_COLOR)
	).is_true()


## The user-visible contract: the two source cards must never be taken off screen
## before the merged card is on it. They are children of the very node that used
## to be dimmed to hide the forged card, so this samples the whole merge and
## checks that neither the dimming nor an early hand-off can come back.
func test_the_two_source_cards_are_never_hidden_before_the_merged_card() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var forged_ui: CardUI = _card_ui(bar, merged)

	var dimmed_frames: int = 0
	var blank_frames: int = 0
	var born: bool = false
	var born_with_both_plates: bool = false
	for _sample: int in 80:
		await await_millis(5)
		if forged_ui.modulate.a < 1.0:
			dimmed_frames += 1
		var plates: Array[Control] = _ghosts(forged_ui)
		if forged_ui._visual_root.visible:
			if not born:
				born = true
				# The first frame the merged card is up, both source cards are
				# still on screen at full strength.
				born_with_both_plates = plates.size() == 2 \
					and plates[0].modulate.a > 0.99 and plates[1].modulate.a > 0.99
		elif plates.is_empty():
			# Card hidden and both source cards already gone: the dead frame the
			# merge used to blink through.
			blank_frames += 1

	assert_bool(born).is_true()
	assert_bool(born_with_both_plates).is_true()
	assert_int(dimmed_frames).is_equal(0)
	assert_int(blank_frames).is_equal(0)


## The merged card takes over the exact spot of the two cards that made it, at
## full size and unmoved, so the silhouette never jumps: only the face changes,
## which is the whole point of the merge reading as two cards becoming one.
func test_the_merged_card_takes_over_the_spot_of_the_two_cards_it_replaced() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var forged_ui: CardUI = _card_ui(bar, merged)

	# Hidden while the two cards slide onto each other.
	assert_bool(forged_ui._visual_root.visible).is_false()

	# The first frame it is up, it is already at its resting size and position.
	var first_scale: float = -1.0
	for _sample: int in 80:
		await await_millis(4)
		if forged_ui._visual_root.visible:
			first_scale = forged_ui._visual_root.scale.x
			break
	assert_float(first_scale).is_greater_equal(0.99)
	assert_float(first_scale).is_less(1.2)
	assert_vector(forged_ui._visual_root.position).is_equal(Vector2.ZERO)
	# It is not warped either, so nothing about its silhouette moved.
	assert_float(_tilt(forged_ui, "x_rot")).is_equal_approx(0.0, 0.001)
	assert_float(_tilt(forged_ui, "y_rot")).is_equal_approx(0.0, 0.001)
	# And the two cards are still mounted behind it as it settles.
	assert_int(_ghosts(forged_ui).size()).is_equal(2)


## The card that comes out of the merge has to be the thing the player watches,
## so both cards that made it are parked behind it in the draw order.
func test_the_merged_card_is_drawn_in_front_of_the_two_cards_that_made_it() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var forged_ui: CardUI = _card_ui(bar, merged)

	var plates: Array[Control] = _ghosts(forged_ui)
	assert_int(plates.size()).is_equal(2)
	for plate: Control in plates:
		assert_int(plate.get_index()).is_less(forged_ui._visual_root.get_index())


## The whole animation is the two cards travelling onto the same spot, so by the
## end of the move both of them are sitting exactly where the merged card is.
func test_the_two_cards_slide_onto_the_same_spot() -> void:
	var bar: HandBar = _make_hand_bar()
	var state: GameState = _ready_hand(bar, [2, 3, 5])
	await await_millis(LAYOUT_SETTLE_MILLIS)
	var merged: Card = _merge_on_state(bar, state, 1, 2)
	var forged_ui: CardUI = _card_ui(bar, merged)

	var start_gap: float = absf(_ghosts(forged_ui)[0].position.x - _ghosts(forged_ui)[1].position.x)
	assert_float(start_gap).is_greater(0.0)

	# Watch the two cards come together: they are seen part way in (so neither
	# snapped) and then parked on exactly the same spot.
	var saw_partway: bool = false
	var saw_stacked: bool = false
	for _sample: int in 40:
		await await_millis(10)
		var plates: Array[Control] = _ghosts(forged_ui)
		if plates.size() != 2:
			break
		var gap: float = absf(plates[0].position.x - plates[1].position.x)
		if gap > 0.0 and gap < start_gap - 1.0:
			saw_partway = true
		if is_zero_approx(gap):
			saw_stacked = true
			break

	assert_bool(saw_partway).is_true()
	assert_bool(saw_stacked).is_true()
	# The card they became is on top of that same spot by now.
	await await_millis(40)
	assert_bool(forged_ui._visual_root.visible).is_true()

	await await_millis(FORGE_SETTLE_MILLIS)
	assert_int(_ghosts(forged_ui).size()).is_equal(0)
	assert_object(_card_ui(bar, merged)).is_same(forged_ui)
