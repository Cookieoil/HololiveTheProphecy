<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/GameState.gd` — `class_name GameState` extends `RefCounted`

`485` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure game state. No nodes, no signals, no rendering. All mutation happens through methods that return result The presentation layer can react to.

Sections: Initialisation · Card Operations · Merge Operations · Hand Queries · Helpers
- L42-45 `enum WaveTransition` = FULL_TURN, IMMEDIATE_SKIP

Constants:
- L10 `MAX_HAND_SIZE: int = 7`
- L11 `ACTIONS_PER_TURN: int = 3`
- L12 `MERGES_PER_TURN: int = 2`
- L15 `DEFAULT_DECKLIST: Array = [` — Deck composition: [[value, count], ...]

State:
- L22 `CURRENT_DECKLIST: Array = DEFAULT_DECKLIST.duplicate(true)` — Active deck composition; replaced from config.json by GameManager.
- L24 `turn_dice_progression: Array[int] = [6, 10, 14, 18]`
- L25 `dice_size_modifier: int = 0`
- L28 `allies: Array[Unit] = []` — Runtime State
- L29 `enemies: Array[Unit] = []`
- L30 `deck: Array[Card] = []`
- L31 `hand: Array[Card] = []`
- L32 `discard: Array[Card] = []`
- L33 `played_this_turn: Array[Card] = []`
- L35 `_merged_sources: Dictionary[Card, Array] = {}` — Maps a temporary merged/double-merged Card -> Array[Card] of original base deck cards.
- L38 `max_hand_size: int = MAX_HAND_SIZE` — Draw cards
- L39 `actions_per_turn: int = ACTIONS_PER_TURN`
- L40 `merges_per_turn: int = MERGES_PER_TURN`
- L47 `wave_definitions: Array = []`
- L48 `wave_transition_mode: int = WaveTransition.FULL_TURN`
- L49 `actions_left: int = 0`
- L50 `merges_left: int = 0`
- L51 `next_skill_bonus: int = 0`
- L52 `current_wave: int = 0`
- L53 `turn_number: int = 0`

Public API:
- L59-63 `initialize_allies(ally_data: Array[UnitData]) -> void` — Clear all allies from previous round, then add the allies into the allies unit array
- L68-73 `initialize_enemies(enemy_data: Array[UnitData]) -> void` — Clear all enemies from previous round, then add the enemies into the enemies unit array
- L79-97 `build_deck(decklist: Array = CURRENT_DECKLIST) -> void` — Clear are current cards in game Create a new deck with new default cards Numbers are coerced with int() because JSON parses every number as float.
- L98-99 `set_dice_progression(prog: Array[int]) -> void`
- L110-127 `draw_n_cards(count: int) -> Array[Card]` — Draw cards in hand up to count. Returns the cards drawn. Reshuffle when the deck runs out, then clear the discard pile. Add the new drawn card into the draw lis…
- L131-137 `draw_cards_to_limit(hand_limit: int = -1) -> Array[Card]` — Draw until hand reaches hand_limit. Returns drawn cards.
- L168-171 `discard_card(card: Card) -> void` — Removes the card from the hand and discards its underlying base cards.
- L177-187 `play_card_on_ally(card: Card, _ally: Unit) -> bool` — Removes card from hand, deducts action if needed. Returns false if the play is illegal (not allowed).
- L190-193 `end_player_turn_cleanup() -> void` — Move played cards to discard pile, clearing temporary buffs and unpacking any merged cards back into their base components.
- L206-212 `spawn_debug_card(value: int, merged: bool = false, double_merged: bool = false) -> Card` — Tester/debug hook: builds a card that lives outside the deck's source set. The card is registered with *no* merge sources, so `_extract_base_cards()` makes it e…
- L225-229 `can_cross_merge(a: Card, b: Card) -> bool` — cross merge checker Check two chosen cards if they're qualified to cross merge: 1. a and b must be base cards 2. a and b must be in hand 3. a and b are two sepe…
- L238-245 `can_double_merge(merged_card: Card, other_card: Card) -> bool` — double merge checker Check two chosen cards if they're qualified to double merge: 1. merged_card must be a merged card 2. merged_card and other_card must be in…
- L252-256 `can_merge_pair(a: Card, b: Card) -> bool` — This wrapper returns true if the pair can merge in either direction. It doesn't matters which card is chosen first or second.
- L265-280 `cross_merge(a: Card, b: Card) -> Card` — cross merge logic Two unmerged (a,b) → one merged (c). Returns the new card. The new card set as a merged card The two cards used for merging are removed from h…
- L290-307 `double_merge(merged_card: Card, other_card: Card) -> Card` — double merge logic merged + same-value → double-merged (value + 1, free play). Returns the new card. The new card set as a merged card The two cards used for me…
- L320-338 `try_merge(a: Card, b: Card) -> Card` — This function is the router for merging mechanics. It uses merge checker funcs to see: 1. what kind of merge player is trying to do. 2. if that merge is valid,…
- L361-369 `get_highest_card_in_hand(exclude: Card = null) -> Card` — Returns the card with the highest effective value in hand, or null. If `exclude` is provided, that card is skipped (used during hover previews where the card be…
- L371-377 `get_lowest_card_in_hand() -> Card` — Returns the card with the lowest effective value in hand, or null.
- L379-387 `get_top_n_cards(n: int) -> Array[Card]` — Returns the N highest-value cards in hand (sorted descending).
- L413-415 `static scaled_value(value: int, divisor: int = 1) -> int` — Integer division, minimum 1
- L417-423 `get_living_allies() -> Array[Unit]`
- L424-430 `get_living_enemies() -> Array[Unit]`
- L432-434 `get_dice_size(turn_index: int) -> int` — Returns the dice size for a given turn (0-based index).
- L436-440 `all_enemies_dead() -> bool`
- L442-447 `all_allies_dead() -> bool`
- L449-483 `get_merge_error(a: Card, b: Card) -> String`

Private:
- L142-150 `_extract_base_cards`
- L155-164 `_reset_and_discard`
- L346-354 `_merge_slot`
- L393-409 `_to_int`

Uses: Card, Unit, UnitData
Used by: Core/DataLoader.gd, Core/GameUI.gd, GDTest/AllyKitTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/GameStateMergeTest.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Skills/EffectBlock.gd, Skills/SkillContext.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

