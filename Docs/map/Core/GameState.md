<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/GameState.gd` — `class_name GameState` extends `RefCounted`

`638` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure game state. No nodes, no signals, no rendering. All mutation happens through methods that return result The presentation layer can react to.

Sections: Initialisation · Card Operations · Merge Operations · Hand Queries · Helpers
- L42-45 `enum WaveTransition` = FULL_TURN, IMMEDIATE_SKIP

Constants:
- L10 `MAX_HAND_SIZE: int = 7`
- L11 `ACTIONS_PER_TURN: int = 3`
- L12 `MERGES_PER_TURN: int = 2`
- L15 `DEFAULT_DECKLIST: Array = [` — Deck composition: [[value, count], ...]
- L48 `WAVE_MODE_MAP: Dictionary = {` — JSON/config string -> WaveTransition (config.json stores readable names).

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
- L53 `wave_definitions: Array = []`
- L54 `wave_transition_mode: int = WaveTransition.FULL_TURN`
- L55 `actions_left: int = 0`
- L56 `merges_left: int = 0`
- L57 `next_skill_bonus: int = 0`
- L58 `current_wave: int = 0`
- L59 `turn_number: int = 0`
- L64 `run_seed: int = 0` — Deterministic run seed and the generator every shuffle and roll goes through, so a run can be replayed exactly from its seed (Array.shuffle() and the global RNG…
- L65 `rng: RandomNumberGenerator = RandomNumberGenerator.new()`
- L69 `flags: Dictionary = {}` — The staged feature flags that are ON for this run (name -> true), resolved by apply_config() from res://Data/json/features.json. Empty means no experiment is ac…

Public API:
- L73-75 `set_run_seed(value: int) -> void` — Seeds the run's generator. Call before the deck is built.
- L79-84 `shuffle_cards(cards: Array[Card]) -> void` — Seeded Fisher-Yates so a shuffle is reproducible from `run_seed`.
- L88-93 `shuffle_units(units: Array[Unit]) -> void` — Seeded Fisher-Yates for units (enemy targeting), mirroring shuffle_cards.
- L99-103 `initialize_allies(ally_data: Array[UnitData]) -> void` — Clear all allies from previous round, then add the allies into the allies unit array
- L108-113 `initialize_enemies(enemy_data: Array[UnitData]) -> void` — Clear all enemies from previous round, then add the enemies into the enemies unit array
- L119-137 `build_deck(decklist: Array = CURRENT_DECKLIST) -> void` — Clear are current cards in game Create a new deck with new default cards Numbers are coerced with int() because JSON parses every number as float.
- L138-139 `set_dice_progression(prog: Array[int]) -> void`
- L150-167 `draw_n_cards(count: int) -> Array[Card]` — Draw cards in hand up to count. Returns the cards drawn. Reshuffle when the deck runs out, then clear the discard pile. Add the new drawn card into the draw lis…
- L171-177 `draw_cards_to_limit(hand_limit: int = -1) -> Array[Card]` — Draw until hand reaches hand_limit. Returns drawn cards.
- L208-211 `discard_card(card: Card) -> void` — Removes the card from the hand and discards its underlying base cards.
- L217-227 `play_card_on_ally(card: Card, _ally: Unit) -> bool` — Removes card from hand, deducts action if needed. Returns false if the play is illegal (not allowed).
- L230-233 `end_player_turn_cleanup() -> void` — Move played cards to discard pile, clearing temporary buffs and unpacking any merged cards back into their base components.
- L246-252 `spawn_debug_card(value: int, merged: bool = false, double_merged: bool = false) -> Card` — Tester/debug hook: builds a card that lives outside the deck's source set. The card is registered with *no* merge sources, so `_extract_base_cards()` makes it e…
- L265-269 `can_cross_merge(a: Card, b: Card) -> bool` — cross merge checker Check two chosen cards if they're qualified to cross merge: 1. a and b must be base cards 2. a and b must be in hand 3. a and b are two sepe…
- L278-285 `can_double_merge(merged_card: Card, other_card: Card) -> bool` — double merge checker Check two chosen cards if they're qualified to double merge: 1. merged_card must be a merged card 2. merged_card and other_card must be in…
- L292-296 `can_merge_pair(a: Card, b: Card) -> bool` — This wrapper returns true if the pair can merge in either direction. It doesn't matters which card is chosen first or second.
- L305-320 `cross_merge(a: Card, b: Card) -> Card` — cross merge logic Two unmerged (a,b) → one merged (c). Returns the new card. The new card set as a merged card The two cards used for merging are removed from h…
- L330-347 `double_merge(merged_card: Card, other_card: Card) -> Card` — double merge logic merged + same-value → double-merged (value + 1, free play). Returns the new card. The new card set as a merged card The two cards used for me…
- L360-378 `try_merge(a: Card, b: Card) -> Card` — This function is the router for merging mechanics. It uses merge checker funcs to see: 1. what kind of merge player is trying to do. 2. if that merge is valid,…
- L401-409 `get_highest_card_in_hand(exclude: Card = null) -> Card` — Returns the card with the highest effective value in hand, or null. If `exclude` is provided, that card is skipped (used during hover previews where the card be…
- L411-417 `get_lowest_card_in_hand() -> Card` — Returns the card with the lowest effective value in hand, or null.
- L419-427 `get_top_n_cards(n: int) -> Array[Card]` — Returns the N highest-value cards in hand (sorted descending).
- L453-455 `static scaled_value(value: int, divisor: int = 1) -> int` — Integer division, minimum 1
- L457-463 `get_living_allies() -> Array[Unit]`
- L464-470 `get_living_enemies() -> Array[Unit]`
- L472-474 `get_dice_size(turn_index: int) -> int` — Returns the dice size for a given turn (0-based index).
- L476-480 `all_enemies_dead() -> bool`
- L482-487 `all_allies_dead() -> bool`
- L489-523 `get_merge_error(a: Card, b: Card) -> String`
- L532-551 `apply_config(config: Dictionary) -> void` — Applies a config.json-shaped dictionary to this run. The caller passes the flag definitions and any tester overrides in the same dictionary (`flag_definitions`,…
- L556-561 `static seed_from_config(config: Dictionary) -> int` — The run seed: an explicit `seed` in the config (so a specific battle can be replayed), otherwise a fresh random value.

Private:
- L182-190 `_extract_base_cards`
- L195-204 `_reset_and_discard`
- L386-394 `_merge_slot`
- L433-449 `_to_int`
- L566-567 `_config_int`
- L571-587 `_coerce_int`
- L591-608 `_config_decklist`
- L612-620 `_config_int_list`
- L623-628 `_flag_definitions`
- L631-636 `_flag_overrides`

Uses: Card, FeatureFlags, Unit, UnitData
Used by: Core/DataLoader.gd, Core/GameUI.gd, Core/Telemetry/TelemetrySchema.gd, GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/GameStateMergeTest.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Skills/EffectBlock.gd, Skills/SkillContext.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

