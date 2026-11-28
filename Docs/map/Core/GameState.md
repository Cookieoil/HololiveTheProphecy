<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/GameState.gd` — `class_name GameState` extends `RefCounted`

`690` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L72 `_flag_definitions: Dictionary = {}` — The registry this run resolved from, and the overrides forced on it, kept so a tester tool can re-resolve mid-run instead of only at setup.
- L73 `_flag_overrides: Dictionary = {}`

Public API:
- L77-79 `set_run_seed(value: int) -> void` — Seeds the run's generator. Call before the deck is built.
- L83-88 `shuffle_cards(cards: Array[Card]) -> void` — Seeded Fisher-Yates so a shuffle is reproducible from `run_seed`.
- L92-97 `shuffle_units(units: Array[Unit]) -> void` — Seeded Fisher-Yates for units (enemy targeting), mirroring shuffle_cards.
- L103-107 `initialize_allies(ally_data: Array[UnitData]) -> void` — Clear all allies from previous round, then add the allies into the allies unit array
- L112-117 `initialize_enemies(enemy_data: Array[UnitData]) -> void` — Clear all enemies from previous round, then add the enemies into the enemies unit array
- L123-141 `build_deck(decklist: Array = CURRENT_DECKLIST) -> void` — Clear are current cards in game Create a new deck with new default cards Numbers are coerced with int() because JSON parses every number as float.
- L142-143 `set_dice_progression(prog: Array[int]) -> void`
- L154-171 `draw_n_cards(count: int) -> Array[Card]` — Draw cards in hand up to count. Returns the cards drawn. Reshuffle when the deck runs out, then clear the discard pile. Add the new drawn card into the draw lis…
- L175-181 `draw_cards_to_limit(hand_limit: int = -1) -> Array[Card]` — Draw until hand reaches hand_limit. Returns drawn cards.
- L212-215 `discard_card(card: Card) -> void` — Removes the card from the hand and discards its underlying base cards.
- L221-231 `play_card_on_ally(card: Card, _ally: Unit) -> bool` — Removes card from hand, deducts action if needed. Returns false if the play is illegal (not allowed).
- L234-237 `end_player_turn_cleanup() -> void` — Move played cards to discard pile, clearing temporary buffs and unpacking any merged cards back into their base components.
- L250-256 `spawn_debug_card(value: int, merged: bool = false, double_merged: bool = false) -> Card` — Tester/debug hook: builds a card that lives outside the deck's source set. The card is registered with *no* merge sources, so `_extract_base_cards()` makes it e…
- L269-273 `can_cross_merge(a: Card, b: Card) -> bool` — cross merge checker Check two chosen cards if they're qualified to cross merge: 1. a and b must be base cards 2. a and b must be in hand 3. a and b are two sepe…
- L282-289 `can_double_merge(merged_card: Card, other_card: Card) -> bool` — double merge checker Check two chosen cards if they're qualified to double merge: 1. merged_card must be a merged card 2. merged_card and other_card must be in…
- L296-300 `can_merge_pair(a: Card, b: Card) -> bool` — This wrapper returns true if the pair can merge in either direction. It doesn't matters which card is chosen first or second.
- L309-324 `cross_merge(a: Card, b: Card) -> Card` — cross merge logic Two unmerged (a,b) → one merged (c). Returns the new card. The new card set as a merged card The two cards used for merging are removed from h…
- L334-351 `double_merge(merged_card: Card, other_card: Card) -> Card` — double merge logic merged + same-value → double-merged (value + 1, free play). Returns the new card. The new card set as a merged card The two cards used for me…
- L364-382 `try_merge(a: Card, b: Card) -> Card` — This function is the router for merging mechanics. It uses merge checker funcs to see: 1. what kind of merge player is trying to do. 2. if that merge is valid,…
- L405-413 `get_highest_card_in_hand(exclude: Card = null) -> Card` — Returns the card with the highest effective value in hand, or null. If `exclude` is provided, that card is skipped (used during hover previews where the card be…
- L415-421 `get_lowest_card_in_hand() -> Card` — Returns the card with the lowest effective value in hand, or null.
- L423-431 `get_top_n_cards(n: int) -> Array[Card]` — Returns the N highest-value cards in hand (sorted descending).
- L457-459 `static scaled_value(value: int, divisor: int = 1) -> int` — Integer division, minimum 1
- L461-467 `get_living_allies() -> Array[Unit]`
- L468-474 `get_living_enemies() -> Array[Unit]`
- L476-478 `get_dice_size(turn_index: int) -> int` — Returns the dice size for a given turn (0-based index).
- L480-484 `all_enemies_dead() -> bool`
- L486-491 `all_allies_dead() -> bool`
- L493-527 `get_merge_error(a: Card, b: Card) -> String`
- L536-559 `apply_config(config: Dictionary) -> void` — Applies a config.json-shaped dictionary to this run. The caller passes the flag definitions and any tester overrides in the same dictionary (`flag_definitions`,…
- L564-569 `static seed_from_config(config: Dictionary) -> int` — The run seed: an explicit `seed` in the config (so a specific battle can be replayed), otherwise a fresh random value.
- L649-650 `refresh_flags() -> void` — Re-resolves `flags` from the stored registry and overrides. `apply_config` calls it, and so does the tester tool that flips a flag, so both paths agree by const…
- L655-660 `set_flag_override(flag_name: String, enabled: bool) -> bool` — Forces one staged flag on or off for this run. Returns false for a name the run does not know, so a stale panel cannot invent a flag.
- L665-676 `flag_report() -> Dictionary` — The flags this run knows about, with their current value and what they are trying to find out, for the tester panel.
- L684-689 `debug_set_flag(args: Dictionary) -> String` — Applies a tester tool's `set_flag` request and returns the line to log. The run is already flagged as debug-tainted by the debug action that carried this, so an…

Private:
- L186-194 `_extract_base_cards`
- L199-208 `_reset_and_discard`
- L390-398 `_merge_slot`
- L437-453 `_to_int`
- L574-575 `_config_int`
- L579-595 `_coerce_int`
- L599-616 `_config_decklist`
- L620-628 `_config_int_list`
- L631-636 `_definitions_from`
- L639-644 `_overrides_from`

Uses: Card, FeatureFlags, Unit, UnitData
Used by: Core/DataLoader.gd, Core/GameUI.gd, Core/Telemetry/TelemetryDecision.gd, Core/Telemetry/TelemetrySchema.gd, GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/DebugCommandRunnerTest.gd, GDTest/DebugMenuTest.gd, GDTest/EffectBlockMessageTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/FeatureFlagsTest.gd, GDTest/GameStateMergeTest.gd, GDTest/SkillContextFactoryTest.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryDecisionTest.gd, GDTest/TelemetryTest.gd, GDTest/TurnLoopTest.gd, Managers/DebugCommandRunner.gd, Managers/GameManager.gd, Managers/SkillContextFactory.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Skills/EffectBlock.gd, Skills/SkillContext.gd, Skills/SkillPreviewFormatter.gd, Tools/BattleSimulator.gd, Tools/GameDataValidator.gd
Loads: —

