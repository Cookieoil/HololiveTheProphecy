class_name CardTest
extends GdUnitTestSuite

## This is the GDUnit test for Card class
## @author TheGreatJellyfish
## @version 5/16/2026

# This function runs before each test to set up an instance
func test_card_values() -> void:
	# Create an instance of Card object
	var card = Card.new(4)
	
	# Assert that the values initialized correctly
	assert_int(card.base_value).is_equal(4)
	assert_int(card.current_value).is_equal(4)
	assert_bool(card.is_odd()).is_false()

func test_card_effective_value_with_buff() -> void:
	var card = Card.new(2)
	card.value_buff = 3
	
	# math: 2 + 3 = 5
	assert_int(card.get_effective_value()).is_equal(5)

func test_card_effective_value_with_debuff() -> void:
	var card = Card.new(2)
	card.value_debuff = 3
	
	# math: 2 - 3 = -1 (neg) = 1
	assert_int(card.get_effective_value()).is_equal(1)
