class_name GameState
extends RefCounted
## Pure game state. No nodes, no signals, no rendering.
## All mutation happens through methods that return result
## The presentation layer can react to.
##
## @author TheGreatJellyfish
## @version 5/13/2026

const MAX_HAND_SIZE: int = 7
const ACTIONS_PER_TURN: int = 3
const MERGES_PER_TURN: int = 2

## Deck composition: [[value, count],...]
@export var DEFAULT_DECKLIST: Array = [
	[2, 6],
	[3, 5],
	[5, 4],
]

var CURRENT_DECKLIST: Array = DEFAULT_DECKLIST
 ## Dice sides per turn index (0-based). Clamped at last entry.
@export var turn_dice_progression: Array[int] = [6, 10, 14, 18]
var dice_size_modifier: int = 0

## Runtime State
var allies: Array[Unit] = []
var enemies: Array[Unit] = []
var deck: Array[Card] = []
var hand: Array[Card] = []
var discard: Array[Card] = []
var played_this_turn: Array[Card] = []
var wave_definitions: Array = []

enum WaveTransition { 
	FULL_TURN, 
	IMMEDIATE_SKIP
}

var wave_transition_mode: int = WaveTransition.FULL_TURN
var actions_left: int = 0
var merges_left: int = 0
var current_wave: int = 0
var turn_number: int = 0

#region Initialisation
## Clear all allies from previous round, 
## then add the allies into the allies unit array
## @param Array[UnitData] - an array contains all unit data
func initialize_allies(ally_data: Array[UnitData]) -> void:
	allies.clear()
	for i in ally_data.size():
		var u := Unit.new(ally_data[i], i)
		allies.append(u)

## Clear all enemies from previous round, 
## then add the enemies into the enemies unit array
## @param Array[UnitData] - an array contains all unit data
func initialize_enemies(enemy_data: Array[UnitData]) -> void:
	enemies.clear()
	for i in enemy_data.size():
		var u := Unit.new(enemy_data[i], i)
		u.is_ally = false
		enemies.append(u)

## Clear are current cards in game
## Create a new deck with new default cards
## @param Array - an array contains all default cards (number count and value)
func build_deck(decklist: Array = CURRENT_DECKLIST) -> void:
	Card.reset_id_counter()
	deck.clear()
	hand.clear()
	discard.clear()
	played_this_turn.clear()
	for entry in decklist:
		var value: int = entry[0]
		var count: int = entry[1]
		for i in count:
			deck.append(Card.new(value))
#endregion

#region Card Operations
## Draw cards in hand up to count. 
## Returns the cards drawn.
## Reshuffle when the deck runs out, then clear the discard pile.
## Add the new drawn card into the draw list and hand.
## @param int - the amount of cards drawn
## @return Array[Card] - an array of drawn cards
func draw_n_cards(count: int) -> Array[Card]:
	var drawn: Array[Card] = []
	for i in count:
		if deck.is_empty():
			if discard.is_empty():
				# Breaks the loop, no cards left in the game
				break
			# Copies the discard pile into the deck
			deck = discard.duplicate()
			discard.clear()
			deck.shuffle()
		# pop_back is faster than pop_front
		# draw one card at the end of the array list
		var c: Card = deck.pop_back()
		hand.append(c)
		drawn.append(c)
	return drawn
	
## Draw until hand reaches hand_limit. Returns drawn cards.
## @param int - the hand limit
## @return Array[Card] - call draw_n_cards to returns an array of cards
func draw_cards_to_limit(hand_limit: int = MAX_HAND_SIZE) -> Array[Card]:
	var to_draw := hand_limit - hand.size()
	if to_draw <= 0:
		return []
	return draw_n_cards(to_draw)
	
## Removes the card from the hand
## Clears its buff/debuff, then it into the discard pile
## @param card - the card to discard
func discard_card(card: Card) -> void:
	hand.erase(card)
	card.clear_temp_buffs()
	discard.append(card)
	
## Removes card from hand, deducts action if needed.
## Returns false if the play is illegal (not allowed).
## @param card - the card played on an ally
## @param ally - the ally that got played
## @return bool - true if the card can be played, false otherwise
func play_card_on_ally(card: Card, _ally: Unit) -> bool:
	if not hand.has(card):
		return false
	if card.costs_action():
		if actions_left <= 0:
			return false
		actions_left -= 1
	hand.erase(card)
	played_this_turn.append(card)
	return true
	
## Move played cards to discard pile, clear temporary buffs.
func end_player_turn_cleanup() -> void:
	for card in played_this_turn:
		card.clear_temp_buffs()
		discard.append(card)
	played_this_turn.clear()
	
#endregion

#region Merge Operations
## cross merge checker
## Check two chosen cards if they're qualified to cross merge:
## 1. a and b must be base cards
## 2. a and b must be in hand
## 3. a and b are two seperate cards
## @param a - the first card to merged
## @param b - the second card to merged
## @return bool - true if can cross merged, false otherwise
func can_cross_merge(a: Card, b: Card) -> bool:
	# the backlash \ is the line continuation
	return not a.is_merged and not b.is_merged \
		and hand.has(a) and hand.has(b) and a != b
		
## double merge checker
## Check two chosen cards if they're qualified to double merge:
## 1. merged_card must be a merged card
## 2. merged_card and other_card must be in hand
## 3. merged_card and other_card are two seperate cards
## @param merged_card - the merged card
## @param other_card - the merged or unmerged card
## @return bool - true if can double merged, false otherwise
func can_double_merge(merged_card: Card, other_card: Card) -> bool:
	if not merged_card.is_merged:
		return false
	if not hand.has(merged_card) or not hand.has(other_card):
		return false
	if merged_card == other_card:
		return false
	return merged_card.get_effective_value() == other_card.get_effective_value()

## This wrapper returns true if the pair can merge in either direction.
## It doesn't matters which card is chosen first or second.
## @param a - the first card
## @param b - the second card
## @return bool - true if can cross merge or double merge, false otherwise
func can_merge_pair(a: Card, b: Card) -> bool:
	return can_cross_merge(a, b) \
		or can_double_merge(a, b) \
		or can_double_merge(b, a)
		
## cross merge logic
## Two unmerged (a,b) → one merged (c). Returns the new card.
## The new card set as a merged card
## The two cards used for merging are removed from hand.
## @param a - the first unmerged card
## @param b - the second unmerged card
## @return Card - the merged card from cross merging
func cross_merge(a: Card, b: Card) -> Card:
	var c := Card.new(0)
	c.current_value = a.get_effective_value() + b.get_effective_value()
	c.base_value = c.current_value
	c.is_merged = true
	hand.erase(a)
	hand.erase(b)
	hand.append(c)
	return c
	
## double merge logic
## merged + same-value → double-merged (value + 1, free play). 
## Returns the new card.
## The new card set as a merged card
## The two cards used for merging are removed from hand.
## @param merged_card - the first merged card
## @param other_card - the second same-value card (merged or unmerged)
## @return Card - the merged card from double merging (value + 1, free play).
func double_merge(merged_card: Card, other_card: Card) -> Card:
	var c:= Card.new(0)
	c.current_value = merged_card.get_effective_value() \
		+ other_card.get_effective_value() + 1
	c.base_value = c.current_value
	c.is_merged = true
	c.is_double_merged = true
	hand.erase(merged_card)
	hand.erase(other_card)
	hand.append(c)
	return c
	
## This function is the router for merging mechanics.
## It uses merge checker funcs to see:
## 1. what kind of merge player is trying to do.
## 2. if that merge is valid, merge the cards 
##    and returns the merged card.
## 3. don't merge if there's no valid merge.
## @param a - the first card to merge
## @param b - the second card to merge
## @return Card - the merged card
func try_merge(a: Card, b: Card) -> Card:
	if can_cross_merge(a, b):
		return cross_merge(a, b)
	if can_double_merge(a, b):
		return double_merge(a, b)
	if can_double_merge(b, a):
		return double_merge(b, a)
	return null
#endregion

#region Hand Queries
## Returns the card with the highest effective value in hand, or null.
func get_highest_card_in_hand() -> Card:
	var best: Card = null
	for c in hand:
		if best == null or c.get_effective_value() > best.get_effective_value():
			best = c
	return best
	
## Returns the card with the lowest effective value in hand, or null.
func get_lowest_card_in_hand() -> Card:
	var worst : Card = null
	for c in hand:
		if worst == null or c.get_effective_value() < worst.get_effective_value():
			worst = c
	return worst
	
## Returns the N highest-value cards in hand (sorted descending).
func get_top_n_cards(n: int) -> Array[Card]:
	var sorted_hand := hand.duplicate()
	sorted_hand.sort_custom(func(a: Card, b: Card) -> bool:
		return a.get_effective_value() > b.get_effective_value()
	)
	var result: Array[Card] = []
	for i in mini(n, sorted_hand.size()):
		result.append(sorted_hand[i])
	return result
#endregion

#region Helpers
## Integer division, minimum 1
static func scaled_value(value: int, divisor: int = 1) -> int:
	if divisor <= 0:
		divisor = 1
	@warning_ignore("integer_division")
	return maxi(1, value / divisor)

func get_living_allies() -> Array[Unit]:
	var result: Array[Unit] = []
	for u in allies:
		if not u.is_dead:
			result.append(u)
	return result
	
func get_living_enemies() -> Array[Unit]:
	var result: Array[Unit] = []
	for u in enemies:
		if not u.is_dead:
			result.append(u)
	return result
	
## Returns the dice size for a given turn (0-based index).
func get_dice_size(turn_index: int) -> int:
	var idx := mini(turn_index, turn_dice_progression.size() - 1)
	return turn_dice_progression[idx] + dice_size_modifier

func all_enemies_dead() -> bool:
	for u in enemies:
		if not u.is_dead:
			return false
	return true

func all_allies_dead() -> bool:
	for u in allies:
		if not u.is_dead:
			return false
	return true
	
#endregion
