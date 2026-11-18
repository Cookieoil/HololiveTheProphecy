class_name GameStateMergeTest
extends GdUnitTestSuite
## Locks in where a merged card lands in hand: it takes the slot of the card the
## player merged *into*, so a merge never teleports the result to the far right.
##
## @author TheGreatJellyfish
## @version 11/17/2026


## Builds a state whose hand is exactly the given values, in that order.
func _make_state(values: Array[int]) -> GameState:
	var state: GameState = GameState.new()
	var hand: Array[Card] = []
	for value: int in values:
		hand.append(Card.new(value))
	state.hand = hand
	return state


## Effective value of the card at `index`, so a test can assert on placement.
func _value_at(state: GameState, index: int) -> int:
	var card: Card = state.hand[index]
	return card.get_effective_value()


func test_cross_merge_takes_the_slot_of_the_target() -> void:
	var state: GameState = _make_state([2, 3, 5, 3])
	var dragged: Card = state.hand[1] # value 3
	var target: Card = state.hand[2]  # value 5

	var merged: Card = state.try_merge(dragged, target)

	assert_object(merged).is_not_null()
	# 3 + 5 = 8, sitting where the 5 was: [2, 8, 3].
	assert_int(state.hand.size()).is_equal(3)
	assert_int(_value_at(state, 0)).is_equal(2)
	assert_object(state.hand[1]).is_same(merged)
	assert_int(_value_at(state, 1)).is_equal(8)
	assert_int(_value_at(state, 2)).is_equal(3)


func test_cross_merge_onto_an_earlier_card_keeps_that_slot() -> void:
	var state: GameState = _make_state([2, 3, 5, 3])
	var dragged: Card = state.hand[2] # value 5
	var target: Card = state.hand[0]  # value 2

	var merged: Card = state.try_merge(dragged, target)

	assert_object(merged).is_not_null()
	# 5 + 2 = 7, back where the 2 was: [7, 3, 3].
	assert_int(state.hand.size()).is_equal(3)
	assert_object(state.hand[0]).is_same(merged)
	assert_int(_value_at(state, 0)).is_equal(7)
	assert_int(_value_at(state, 1)).is_equal(3)
	assert_int(_value_at(state, 2)).is_equal(3)


func test_cross_merge_onto_the_last_card_stays_last() -> void:
	var state: GameState = _make_state([2, 3, 4])
	var dragged: Card = state.hand[0]
	var target: Card = state.hand[2]

	var merged: Card = state.try_merge(dragged, target)

	assert_object(merged).is_not_null()
	# 2 + 4 = 6, still the last slot: [3, 6].
	assert_int(state.hand.size()).is_equal(2)
	assert_int(_value_at(state, 0)).is_equal(3)
	assert_object(state.hand[1]).is_same(merged)


func test_double_merge_takes_the_slot_of_the_target() -> void:
	var state: GameState = _make_state([4, 2, 2, 6])
	var merged_pair: Card = state.try_merge(state.hand[0], state.hand[1])
	assert_object(merged_pair).is_not_null()
	assert_int(merged_pair.get_effective_value()).is_equal(6)

	# Hand is now [merged(6), 2, 6]: double merge the merged card into the 6.
	var target: Card = state.hand[2]
	var doubled: Card = state.try_merge(merged_pair, target)

	assert_object(doubled).is_not_null()
	assert_bool(doubled.is_double_merged).is_true()
	# 6 + 6 + 1 = 13, back where the target 6 was: [2, 13].
	assert_int(state.hand.size()).is_equal(2)
	assert_int(_value_at(state, 0)).is_equal(2)
	assert_object(state.hand[1]).is_same(doubled)
	assert_int(_value_at(state, 1)).is_equal(13)
