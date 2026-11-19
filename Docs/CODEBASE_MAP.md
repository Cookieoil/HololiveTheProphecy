# Codebase Map — Hololive: The Prophecy

<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd from the first-party sources. -->

Refresh it after changing any first-party script, scene or data file:

```powershell
godot --headless --path . --script res://Tools/gen_code_index.gd
```

Staleness gate (the same check Tools/preflight.ps1 and CI run; exits 1 when stale):

```powershell
godot --headless --path . --script res://Tools/gen_code_index.gd -- --check
```

## How to use this map (read this, not the whole repo)

- **One-screen overview:** section 1 lists every first-party script with its `class_name`, size and role.
- **Find a symbol:** `rg -n '"my_symbol"' Docs/code_index.json` gives every `path:line` definition.
- **Impact of a change:** section 2 carries `Uses` / `Used by` per script; section 3 shows who emits and who listens to each `EventBus` signal.
- **Balancing:** section 5 lists each JSON file's shape, entry count and per-entry keys, so the file rarely has to be opened.
- Open a source file only for the specific line range the index points at.

## 1. Scripts at a glance (51)

| Script | class_name | lines | role |
| --- | --- | --- | --- |
| `Core/Card.gd` | `Card` | 115 | This class contains the data for the card Card instance is created/destroyed during merging. Rule: Merge consumes two cards and produces one. Total count is shr… |
| `Core/DataLoader.gd` | `DataLoader` | 515 | Runtime loader for the game data JSON files in res://Data/json/. Those JSON files are the single source of truth; the workbook (res://Data/xlsx/game_data.xlsx)… |
| `Core/DiceRoller.gd` | `DiceRoller` | 23 | Static utility for dice rolls. Separated for easy mocking/seeding in tests. |
| `Core/EnemyIntent.gd` | `EnemyIntent` | 38 | Pre-rolled intent for one enemy this turn. Created at step 1 of the turn loop, resolved at step 7. |
| `Core/GameState.gd` | `GameState` | 481 | Pure game state. No nodes, no signals, no rendering. All mutation happens through methods that return result The presentation layer can react to. |
| `Core/GameUI.gd` | `GameUI` | 100 | Abstract UI interface the GameManager talks to. Implemented by the graphical BattleScene; GameManager only talks to this interface. Every input methods are asyn… |
| `Core/Unit.gd` | `Unit` | 373 | Runtime instance of a unit on the board. Mutable HP/Shield state. This is all just data |
| `Core/UnitData.gd` | `UnitData` | 16 | Template definition for a unit type. |
| `Data/gameDatabase.gd` | `GameDatabase` | 27 | Skill definitions keyed by skill_id (effects embedded). |
| `GDTest/CardDrawAnimationTest.gd` | `CardDrawAnimationTest` | 303 | Locks in the fake-3D card draw: - every CardUI owns its own warp material, so tilting one card can never tilt the rest of the hand - a dealt card leaves the dec… |
| `GDTest/CardFlashPolicyTest.gd` | `CardFlashPolicyTest` | 109 | Locks in *who caused it* when the game reveals hand cards it picked on its own: - an enemy acting on the player's hand flashes hostile (crimson) - the player's… |
| `GDTest/CardMergeAnimationTest.gd` | `CardMergeAnimationTest` | 564 | Locks in the merge: the card the player was carrying is picked up from the exact point they released it, the two cards drift into each other and fold closed int… |
| `GDTest/CardTest.gd` | `CardTest` | 31 | This is the GDUnit test for Card class |
| `GDTest/CardUITest.gd` | `CardUITest` | 99 | Tests for CardUI's runtime card feedback: the delayed value-label refresh after a skill buff/debuff and the hostile (enemy-caused) red glow preset. |
| `GDTest/DebugMenuTest.gd` | `DebugMenuTest` | 727 | Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager): - the panel is view-only: it reports readouts, gates its tools while the turn loop… |
| `GDTest/EnemyTurnOverlapTest.gd` | `EnemyTurnOverlapTest` | 232 | Locks the enemy-turn overlap ("fast mode" pacing): - consecutive enemies hand control to the next one at the impact beat of their skill animation, so wind-downs… |
| `GDTest/EnemyUltAuraTest.gd` | `EnemyUltAuraTest` | 139 | Locks in the enemy Ultimate warning lifecycle. The crimson character aura and the Moxie orb preview both describe one *pending* roll, so neither may outlive the… |
| `GDTest/GameStateMergeTest.gd` | `GameStateMergeTest` | 89 | Locks in where a merged card lands in hand: it takes the slot of the card the player merged *into*, so a merge never teleports the result to the far right. |
| `GDTest/StatusCatalogTest.gd` | `StatusCatalogTest` | 91 | Tests for the buff/debuff status system: Unit.statuses + StatusIconCatalog. |
| `GDTest/TooltipIconCatalogTest.gd` | `TooltipIconCatalogTest` | 171 | Tests for the inline tooltip icon system (TooltipIconCatalog + TooltipIconEntry). Covers: left-of-keyword icons (LoR style), pure glyphs (Riftbound style), expl… |
| `Managers/ColorUtils.gd` | — | 17 | Color definitions for BBCode |
| `Managers/EventBus.gd` | — | 43 | This is used as a global signal bus. Add as an Autoload. Used for UI logging and passive hooks, not game logic. depend on these signals — they are fire-and-forg… |
| `Managers/GameManager.gd` | `GameManager` | 1057 | Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext. |
| `Scenes/BattleScene/BattleScene.gd` | `BattleScene` | 487 | Tester tools (the Debug button + F1). Turn off for a build that must not show them. |
| `Scenes/BattleUnit/SpinePortrait.gd` | `SpinePortrait` | 625 | Emitted once per lead-armed action when the caller may hand control to the next actor, i.e. the action played far enough to overlap with it. It also fires when… |
| `Scenes/BattleUnit/StatusIconCatalog.gd` | `StatusIconCatalog` | 331 | Catalog for character buff/debuff status icons (separate from CardIconCatalog). Provides lookup and automatic inspection of Unit buff/debuff state. Two dictiona… |
| `Scenes/BattleUnit/UnitUI.gd` | `UnitUI` | 1341 | Toggle this on to manually assign a .tres file below. |
| `Scenes/Cards/CardDrag.gd` | `CardDrag` | 13 | Payload for all card drag operations. Consumed by: CardUI (merge), UnitDropZone (skill activation). |
| `Scenes/Cards/CardIconCatalog.gd` | `CardIconCatalog` | 15 | Central skill-type icon registry for cards / skill previews. One instance, set as project autoload or exported on UI roots. No res://Trash paths live in class c… |
| `Scenes/Cards/CardUI.gd` | `CardUI` | 1381 | Visual representation of one Card in hand. Drag source (play / merge) and drop target (merge only). The card is rendered into an offscreen SubViewport and that… |
| `Scenes/Cards/ForgePlate.gd` | `ForgePlate` | 140 | One of the two cards in a merge, drawn as a real fake-3D quad. A merge has to show two cards banking and folding into each other, so a flat copy of a card face… |
| `Scenes/Cards/HandBar.gd` | `HandBar` | 430 | Bottom-edge hand of cards. View-only: it animates, GameManager validates. |
| `Scenes/HUD/BattleOverlayController.gd` | `BattleOverlayController` | 494 | Builds E1–E3 on the left, A1–A3 on the right, manages the tooltip layer, and safely bridges UnitUI hover & wave transitions without freed-instance errors. |
| `Scenes/HUD/DebugMenuPopup.gd` | `DebugMenuPopup` | 558 | Tester-only tool palette for the battle scene. Every button here is a *request*: it emits `debug_command_requested` upward and the turn loop performs the mutati… |
| `Scenes/HUD/MoxieOrbUI.gd` | `MoxieOrbUI` | 594 |  |
| `Scenes/HUD/OutlineGlow.gd` | `OutlineGlow` | 233 | outer light border with scrolling sub-surface energy texture. |
| `Scenes/HUD/SkillTooltipPopup.gd` | `SkillTooltipPopup` | 272 | Temporary toggle: category icon row in the tooltip header. |
| `Scenes/HUD/TooltipIconCatalog.gd` | `TooltipIconCatalog` | 334 | Inline icon registry for tooltip descriptions (SkillTooltipPopup bodies). Two authoring styles are supported, mirroring Legend of Runeterra (icon + colored keyw… |
| `Scenes/HUD/TooltipIconEntry.gd` | `TooltipIconEntry` | 133 | One tooltip keyword/icon rule, consumed by TooltipIconCatalog. DisplayMode decides how the keyword is drawn inside a RichTextLabel: ICON_AND_KEYWORD -> [icon] K… |
| `Skills/EffectBlock.gd` | `EffectBlock` | 660 | The universal data skill effect component Use configureble resource for all effect scripts Execution pipeline: Phase 1: Resolve Targets Phase 2: Check Condition… |
| `Skills/SkillContext.gd` | `SkillContext` | 48 | Runtime context passed to every EffectBlock.execute(). Three inter-block communication channels: card_value     – mutable skill value (bonus damage adds here) t… |
| `Skills/SkillData.gd` | `SkillData` | 51 | Defines one skill slot (Skill 1 or Skill 2) on a unit Holds arrays of effects for unmerged and merged resolution |
| `Skills/SkillEffect.gd` | `SkillEffect` | 20 | Abstract base for all skill effect components. Subclasses override execute(). The GameManager always calls: await effect.execute(ctx). Note: This base shouldn't… |
| `Skills/SkillPreviewFormatter.gd` | `SkillPreviewFormatter` | 330 | Slightly smaller inline icons for the dimmed "Merged" reminder line (font_size=12). |
| `Tools/check_scripts.gd` | — | 79 | Headless compile gate: loads every project GDScript outside the excluded folders, so a type error, a stale `class_name` or a bad annotation fails CI instead of… |
| `Tools/dataBuilder.gd` | `DataBuilder` | 779 | Converts the bulk-entry workbook (res://Data/xlsx/game_data.xlsx) into the JSON files stored in res://Data/json/. Those JSON files are the single source of trut… |
| `Tools/diagnose_spine_atlas.gd` | — | 49 |  |
| `Tools/export_xlsx_to_json.gd` | — | 34 | Headless Excel -> JSON exporter for the game data pipeline. Usage: godot --headless --path . --script res://Tools/export_xlsx_to_json.gd The workbook (res://Dat… |
| `Tools/gen_code_index.gd` | — | 1164 | Headless symbol-index generator for this repository. Parses every first-party GDScript source and writes two artifacts that make the codebase navigable without… |
| `Tools/validate_gameData.gd` | — | 1263 | Headless, offline validator for the whole game-data pipeline. res://Data/json/ is the single source of truth the game reads at runtime, while res://Data/xlsx/ga… |
| `Tools/xlsx_reader.gd` | `XlsxReader` | 181 | Reads an .xlsx workbook (a zip of XML parts) into { sheet_name: Array[Array[String]] }. Every cell is returned as a String; DataBuilder performs the typed conve… |

## 2. Script details

### `Core/Card.gd` — `class_name Card` extends `RefCounted` · 115 lines

> This class contains the data for the card Card instance is created/destroyed during merging. Rule: Merge consumes two cards and produces one. Total count is shr…

State:
- L11 `_next_id: int` = `0`
- L13 `id: int` = `-1`
- L14 `base_value: int`
- L15 `current_value: int`
- L16 `is_merged: bool` = `false`
- L17 `is_double_merged: bool` = `false`
- L20 `constituents: Array[Card]` = `[]`
- L23 `value_buff: int` = `0`
- L24 `value_debuff: int` = `0`

Public API:
- L27 `static reset_id_counter() -> void` — Reset the card id (e.g card#1 -> card#0)
- L32 `get_suffix() -> String` — Returns a human-readable suffix for this card's merge state.
- L40 `format_value(value: int) -> String` — Returns a colored string for a given numeric value using the card's suffix.
- L53 `decompose() -> Array[Card]` — Recursively breaks this card down into its original unmerged base cards. Returns an array of clean base cards ready for discard/draw.
- L65 `reset_to_base() -> void` — Restores this card to its pristine starting state (unmerged, original value).
- L74 `get_effective_value() -> int` — get the actual effective value (included buff/debuff)
- L80 `is_odd() -> bool` — check if the value is odd
- L86 `costs_action() -> bool` — check if playing this card costs an action
- L91 `clear_temp_buffs() -> void` — clear the temporary value buff/debuff

Private:
- L45 `_init`
- L98 `_to_string`

Uses: —
Used by: Core/GameState.gd, Core/GameUI.gd, GDTest/CardDrawAnimationTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/CardTest.gd, GDTest/CardUITest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/GameStateMergeTest.gd, GDTest/TooltipIconCatalogTest.gd, Managers/EventBus.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardDrag.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/DebugMenuPopup.gd, Scenes/HUD/TooltipIconCatalog.gd, Skills/EffectBlock.gd, Skills/SkillContext.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

### `Core/DataLoader.gd` — `class_name DataLoader` extends `RefCounted` · 515 lines

> Runtime loader for the game data JSON files in res://Data/json/. Those JSON files are the single source of truth; the workbook (res://Data/xlsx/game_data.xlsx)…

Sections: Constants · Private Variables · Public Methods · Private Methods

Constants:
- L17 `JSON_DIR: String` = `"res://Data/json"`
- L18 `SKILLS_PATH: String` = `"res://Data/json/skills.json"`
- L19 `ALLIES_PATH: String` = `"res://Data/json/allies.json"`
- L20 `ENEMIES_PATH: String` = `"res://Data/json/enemies.json"`
- L21 `WAVES_PATH: String` = `"res://Data/json/waves.json"`
- L22 `CONFIG_PATH: String` = `"res://Data/json/config.json"`
- L24 `DEFAULT_MAX_MOXIE: int` = `20`
- L25 `DEFAULT_MAX_HP: int` = `10`
- L28 `ACTION_MAP: Dictionary` = `{` — JSON enum strings -> runtime enums (mirrors the Enums sheet).
- L43 `TARGET_MODE_MAP: Dictionary` = `{`
- L53 `VALUE_SOURCE_MAP: Dictionary` = `{`
- L63 `MERGED_MODE_MAP: Dictionary` = `{`
- L68 `CONDITION_MAP: Dictionary` = `{`
- L72 `CARD_SELECT_MAP: Dictionary` = `{`
- L77 `CARD_MOD_MAP: Dictionary` = `{`

State:
- L84 `_db: GameDatabase` = `null`
- L85 `_errors: PackedStringArray` = `PackedStringArray()`

Public API:
- L89 `static db() -> GameDatabase` — Returns the cached database, loading the JSON files on first use.
- L110 `static load_database() -> GameDatabase` — Reads every JSON file and rebuilds a fresh GameDatabase. Problems are collected in get_errors() instead of aborting immediately so tooling can report them all a…
- L131 `static get_errors() -> PackedStringArray` — Problems collected by the most recent db() or load_database() call.
- L136 `static reload() -> void` — Drops the cached database so the next db() call re-reads the JSON files.
- L142 `static quit_code(code: int) -> void` — Quits the running game with the given exit code (no-op inside the editor).

Private:
- L154 `_read_json_object`
- L174 `_get_int`
- L180 `_to_int`
- L200 `_get_bool`
- L222 `_get_string`
- L233 `_get_string_array`
- L247 `_get_array`
- L254 `_build_skills`
- L281 `_add_effects`
- L300 `_sorted_effects`
- L326 `_build_effect_block`
- L368 `_resolve_enum`
- L375 `_build_units`
- L396 `_resolve_skill`
- L408 `_build_waves`
- L445 `_clone_unit`
- L458 `_build_config`

Uses: EffectBlock, GameDatabase, GameState, SkillData, UnitData
Used by: Scenes/BattleScene/BattleScene.gd, Tools/dataBuilder.gd, Tools/validate_gameData.gd
Loads: res

### `Core/DiceRoller.gd` — `class_name DiceRoller` extends `RefCounted` · 23 lines

> Static utility for dice rolls. Separated for easy mocking/seeding in tests.

Public API:
- L10 `static roll(sides: int) -> int` — Roll a single die with the given number of sides.
- L15 `static roll_target(units: Array[Unit]) -> Unit` — Roll a targeting die among living allies. Returns a random living ally. Returns null if no allies are alive.

Uses: Unit
Used by: Managers/GameManager.gd
Loads: —

### `Core/EnemyIntent.gd` — `class_name EnemyIntent` extends `RefCounted` · 38 lines

> Pre-rolled intent for one enemy this turn. Created at step 1 of the turn loop, resolved at step 7.

State:
- L9 `enemy: Unit`
- L10 `raw_dice_value: int          ## The unmodified roll`
- L11 `effective_value: int         ## After value_modifier applied`
- L12 `skill: SkillData             ## skill_1 or skill_2 based on odd/even`
- L13 `condition_met: bool          ## effective_value >` = `skill.condition_threshold`

Public API:
- L20 `recalculate() -> void`
- L25 `will_trigger_ultimate() -> bool`

Private:
- L15 `_init`
- L31 `_to_string`

Uses: SkillData, Unit
Used by: Core/GameUI.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

### `Core/GameState.gd` — `class_name GameState` extends `RefCounted` · 481 lines

> Pure game state. No nodes, no signals, no rendering. All mutation happens through methods that return result The presentation layer can react to.

Sections: Initialisation · Card Operations · Merge Operations · Hand Queries · Helpers
- L42 `enum WaveTransition` = FULL_TURN, IMMEDIATE_SKIP

Constants:
- L10 `MAX_HAND_SIZE: int` = `7`
- L11 `ACTIONS_PER_TURN: int` = `3`
- L12 `MERGES_PER_TURN: int` = `2`
- L15 `DEFAULT_DECKLIST: Array` = `[` — Deck composition: [[value, count], ...]

State:
- L22 `CURRENT_DECKLIST: Array` = `DEFAULT_DECKLIST.duplicate(true)` — Active deck composition; replaced from config.json by GameManager.
- L24 `turn_dice_progression: Array[int]` = `[6, 10, 14, 18]`
- L25 `dice_size_modifier: int` = `0`
- L28 `allies: Array[Unit]` = `[]` — Runtime State
- L29 `enemies: Array[Unit]` = `[]`
- L30 `deck: Array[Card]` = `[]`
- L31 `hand: Array[Card]` = `[]`
- L32 `discard: Array[Card]` = `[]`
- L33 `played_this_turn: Array[Card]` = `[]`
- L35 `_merged_sources: Dictionary[Card, Array]` = `{}` — Maps a temporary merged/double-merged Card -> Array[Card] of original base deck cards.
- L38 `max_hand_size: int` = `MAX_HAND_SIZE` — Draw cards
- L39 `actions_per_turn: int` = `ACTIONS_PER_TURN`
- L40 `merges_per_turn: int` = `MERGES_PER_TURN`
- L47 `wave_definitions: Array` = `[]`
- L48 `wave_transition_mode: int` = `WaveTransition.FULL_TURN`
- L49 `actions_left: int` = `0`
- L50 `merges_left: int` = `0`
- L51 `next_skill_bonus: int` = `0`
- L52 `current_wave: int` = `0`
- L53 `turn_number: int` = `0`

Public API:
- L59 `initialize_allies(ally_data: Array[UnitData]) -> void` — Clear all allies from previous round, then add the allies into the allies unit array
- L68 `initialize_enemies(enemy_data: Array[UnitData]) -> void` — Clear all enemies from previous round, then add the enemies into the enemies unit array
- L79 `build_deck(decklist: Array = CURRENT_DECKLIST) -> void` — Clear are current cards in game Create a new deck with new default cards Numbers are coerced with int() because JSON parses every number as float.
- L98 `set_dice_progression(prog: Array[int]) -> void`
- L110 `draw_n_cards(count: int) -> Array[Card]` — Draw cards in hand up to count. Returns the cards drawn. Reshuffle when the deck runs out, then clear the discard pile. Add the new drawn card into the draw lis…
- L131 `draw_cards_to_limit(hand_limit: int = -1) -> Array[Card]` — Draw until hand reaches hand_limit. Returns drawn cards.
- L168 `discard_card(card: Card) -> void` — Removes the card from the hand and discards its underlying base cards.
- L177 `play_card_on_ally(card: Card, _ally: Unit) -> bool` — Removes card from hand, deducts action if needed. Returns false if the play is illegal (not allowed).
- L190 `end_player_turn_cleanup() -> void` — Move played cards to discard pile, clearing temporary buffs and unpacking any merged cards back into their base components.
- L206 `spawn_debug_card(value: int, merged: bool = false, double_merged: bool = false) -> Card` — Tester/debug hook: builds a card that lives outside the deck's source set. The card is registered with *no* merge sources, so `_extract_base_cards()` makes it e…
- L225 `can_cross_merge(a: Card, b: Card) -> bool` — cross merge checker Check two chosen cards if they're qualified to cross merge: 1. a and b must be base cards 2. a and b must be in hand 3. a and b are two sepe…
- L238 `can_double_merge(merged_card: Card, other_card: Card) -> bool` — double merge checker Check two chosen cards if they're qualified to double merge: 1. merged_card must be a merged card 2. merged_card and other_card must be in…
- L252 `can_merge_pair(a: Card, b: Card) -> bool` — This wrapper returns true if the pair can merge in either direction. It doesn't matters which card is chosen first or second.
- L265 `cross_merge(a: Card, b: Card) -> Card` — cross merge logic Two unmerged (a,b) → one merged (c). Returns the new card. The new card set as a merged card The two cards used for merging are removed from h…
- L290 `double_merge(merged_card: Card, other_card: Card) -> Card` — double merge logic merged + same-value → double-merged (value + 1, free play). Returns the new card. The new card set as a merged card The two cards used for me…
- L320 `try_merge(a: Card, b: Card) -> Card` — This function is the router for merging mechanics. It uses merge checker funcs to see: 1. what kind of merge player is trying to do. 2. if that merge is valid,…
- L359 `get_highest_card_in_hand() -> Card` — Returns the card with the highest effective value in hand, or null.
- L367 `get_lowest_card_in_hand() -> Card` — Returns the card with the lowest effective value in hand, or null.
- L375 `get_top_n_cards(n: int) -> Array[Card]` — Returns the N highest-value cards in hand (sorted descending).
- L409 `static scaled_value(value: int, divisor: int = 1) -> int` — Integer division, minimum 1
- L413 `get_living_allies() -> Array[Unit]`
- L420 `get_living_enemies() -> Array[Unit]`
- L428 `get_dice_size(turn_index: int) -> int` — Returns the dice size for a given turn (0-based index).
- L432 `all_enemies_dead() -> bool`
- L438 `all_allies_dead() -> bool`
- L445 `get_merge_error(a: Card, b: Card) -> String`

Private:
- L142 `_extract_base_cards`
- L155 `_reset_and_discard`
- L346 `_merge_slot`
- L389 `_to_int`

Uses: Card, GameManager, Unit, UnitData
Used by: Core/DataLoader.gd, Core/GameUI.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/GameStateMergeTest.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/DebugMenuPopup.gd, Skills/EffectBlock.gd, Skills/SkillContext.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

### `Core/GameUI.gd` — `class_name GameUI` extends `Node` · 100 lines

> Abstract UI interface the GameManager talks to. Implemented by the graphical BattleScene; GameManager only talks to this interface. Every input methods are asyn…

Sections: Display (fire-and-forget) · Player Input (async)

Public API:
- L15 `show_message(_msg: String) -> void` — Print a single message line to the player.
- L19 `show_enemy_intents(_intents: Array[EnemyIntent]) -> void` — Display enemy intent previews for the coming turn.
- L23 `show_game_state(_state: GameState) -> void` — Refresh the full board / hand / resource display.
- L26 `focus_input() -> void`
- L34 `play_unit_skill(_unit: Unit, _skill_index: int, _rank: int = 0, _lead: float = 1.0) -> void` — Plays the unit's skill animation and waits for the caller's turn to continue. `lead` is the fraction of the animation the caller waits for: 1.0 (default) waits…
- L37 `play_unit_ultimate(_unit: Unit) -> void`
- L42 `clear_unit_intent(_unit: Unit) -> void` — Presentation cue: an enemy is about to act (or is skipped because it's dead), so its intent preview should disappear.
- L46 `on_card_played(_card: Card, _state: GameState) -> void` — Presentation cue: a card was accepted and left the hand.
- L54 `on_cards_merged(_source_a: Card, _source_b: Card, _result: Card, _state: GameState) -> void` — Presentation cue: two cards in hand were fused into `result` by a merge. `source_a` is the card that was dragged and `source_b` the card it was dropped on; `res…
- L68 `flash_auto_selected_cards(_cards: Array[Card], _hostile: bool = false) -> void` — Presentation cue: the game picked these cards out of the hand on its own (auto_top_n / auto_highest), so no prompt was shown. Briefly highlight them so the play…
- L79 `get_player_action(_state: GameState) -> Dictionary` — Ask the player for their next action. Returns a Dictionary with at minimum a key "type": "play"		-> { type, card: Card, target_ally: Unit } "merge"		-> { type,…
- L86 `ask_pick_targets(_units: Array[Unit], _count: int) -> Array[Unit]` — Ask the player to pick 'count' unit from 'units'. returns the chosen units (fewer if not enough).
- L92 `ask_pick_cards(_cards: Array[Card], _count: int) -> Array[Card]` — Ask the player to pick 'count' cards from 'cards'. Returns the chosen cards.
- L97 `show_hand_and_resources(_state: GameState) -> void` — Refresh hand and resource counters (Actions, Merges, Deck, Discard).

Uses: BattleScene, Card, EnemyIntent, GameManager, GameState, Unit
Used by: GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

### `Core/Unit.gd` — `class_name Unit` extends `RefCounted` · 373 lines

> Runtime instance of a unit on the board. Mutable HP/Shield state. This is all just data

Sections: Signals · Constants · Public Variables · Lifecycle Methods · Public Methods · Private Methods

Signals:
- L10 `damaged(hp_lost: int, shield_lost: int)`
- L11 `moxie_changed(current: int, maximum: int)`
- L13 `statuses_changed` — Fired whenever the status dictionary changes (applied / stacked / ticked / cleared).

Constants:
- L22 `COUNT_MODE_DURATION: String` = `"duration"` — Known buff/debuff definitions keyed by the status id used in skills.json ("apply_status" effects). "count_mode" decides what the icon counter means: duration ->…
- L23 `COUNT_MODE_STACKS: String` = `"stacks"`
- L24 `DEFAULT_COUNT_MODE: String` = `COUNT_MODE_STACKS`
- L25 `STATUS_REGENERATION: String` = `"regeneration"`
- L26 `STATUS_GLOOM: String` = `"gloom"`
- L27 `REGENERATION_HEAL_PER_TICK: int` = `3`
- L28 `GLOOM_DAMAGE_PER_STACK: int` = `1`
- L29 `STATUS_DEFS: Dictionary` = `{`

State:
- L44 `data: UnitData`
- L45 `current_hp: int`
- L46 `max_hp: int`
- L47 `shield: int` = `0`
- L48 `moxie: int` = `0`
- L49 `max_moxie: int` = `20`
- L50 `ult_used_this_turn: bool` = `false`
- L51 `value_modifier: int`
- L52 `slot_index: int` = `-1 ## Board position (0,1,2)`
- L53 `is_ally: bool` = `true`
- L58 `statuses: Dictionary` = `{}` — Active statuses: status_id (String) -> { "count": int, "count_mode": String, "is_debuff": bool }
- L60 `can_cast_ultimate: bool:`
- L67 `is_dead: bool: #true if hp <` = `0, false otherwise`
- L71 `missing_hp: int: #return the unit missing HP from max HP`

Public API:
- L93 `gain_moxie(amount: int) -> int`
- L103 `consume_moxie() -> void`
- L113 `set_moxie(value: int) -> void` — Tester/debug hook: forces the Moxie gauge to `value` and clears the once-per-turn Ultimate lock, so a tester can fire an Ultimate on demand instead of waiting f…
- L124 `take_damage(amount: int, ignore_shield: bool = false) -> int` — Absorbs via shield, then applies the remainder to HP. Emits `damaged` after both values have been updated so UnitUI can react (flinch + bar drop). Also fires wh…
- L146 `heal(amount: int) -> int` — Capped at max_hp. Returns actual HP restored.
- L151 `gain_shield(amount: int) -> int`
- L160 `reset_shield() -> void`
- L166 `reduce_shield(amount: int) -> int` — Directly reduce shield (e.g. Buff merged skill 1). Can't go below 0.
- L175 `deal_true_damage(amount: int) -> int` — Deal damage to HP directly, bypassing shields. Can't go below 0.
- L180 `apply_value_modifier(amount: int) -> void` — Modify the value based on the amount
- L184 `clear_value_modifier() -> void` — Reset the value modifer to 0
- L189 `raise_max_hp(new_max: int) -> void` — raise the unit max HP based on the new max HP
- L198 `apply_status(status_id: String, amount: int = 1) -> int` — Applies (or stacks) a status. Duration statuses add to their remaining rounds, stack statuses add to their stack count.
- L216 `get_status_count(status_id: String) -> int`
- L223 `has_status(status_id: String) -> bool`
- L228 `clear_statuses() -> void` — Removes every status (used when a unit dies so no badge lingers).
- L240 `tick_round_end_statuses() -> Array[Dictionary]` — Runs every active status once, at the end of a round. "duration" statuses fire their effect then lose 1 round (expiring at 0), "stacks" statuses fire their effe…

Private:
- L81 `_init`
- L301 `_to_string`
- L309 `_normalize_status_id`
- L314 `_status_def`
- L324 `_def_int`
- L330 `_def_bool`
- L340 `_def_string`
- L347 `_entry_count`
- L355 `_coerce_int`

Uses: UnitData, UnitUI
Used by: Core/DiceRoller.gd, Core/EnemyIntent.gd, Core/GameState.gd, Core/GameUI.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/EnemyUltAuraTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, Managers/EventBus.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/DebugMenuPopup.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd, Skills/EffectBlock.gd, Skills/SkillContext.gd, Skills/SkillPreviewFormatter.gd, Tools/gen_code_index.gd, Tools/validate_gameData.gd
Loads: —

### `Core/UnitData.gd` — `class_name UnitData` extends `Resource` · 16 lines

> Template definition for a unit type.

Exports:
- L8 `display_name: String` = `""`
- L9 `max_hp: int` = `10`
- L10 `portrait: Texture2D` = `null`
- L11 `skill_1: SkillData` = `null`
- L12 `skill_2: SkillData` = `null`
- L13 `ultimate: SkillData` = `null`
- L14 `max_moxie: int` = `20`
- L15 `is_enemy: bool` = `false`

Uses: SkillData
Used by: Core/DataLoader.gd, Core/GameState.gd, Core/Unit.gd, Data/gameDatabase.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/EnemyUltAuraTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Tools/validate_gameData.gd
Loads: —

### `Data/gameDatabase.gd` — `class_name GameDatabase` extends `Resource` · 27 lines

> Skill definitions keyed by skill_id (effects embedded).

Exports:
- L5 `skills: Dictionary` = `{}`
- L7 `allies: Dictionary` = `{}` — Ally unit templates keyed by unit_id (from allies.json).
- L9 `enemies: Dictionary` = `{}` — Enemy unit templates keyed by unit_id (from enemies.json).
- L11 `units: Dictionary` = `{}` — Union of allies and enemies, kept for unit lookups by id.
- L12 `waves: Array` = `[]`
- L13 `config: Dictionary` = `{}`

Public API:
- L15 `get_unit(id: String) -> UnitData` — Returns the unit template for an id, or null when unknown.
- L22 `get_skill(id: String) -> SkillData` — Returns the skill definition for an id, or null when unknown.

Uses: SkillData, UnitData
Used by: Core/DataLoader.gd, Scenes/BattleScene/BattleScene.gd, Tools/validate_gameData.gd
Loads: —

### `GDTest/CardDrawAnimationTest.gd` — `class_name CardDrawAnimationTest` extends `GdUnitTestSuite` · 303 lines

> Locks in the fake-3D card draw: - every CardUI owns its own warp material, so tilting one card can never tilt the rest of the hand - a dealt card leaves the dec…

Constants:
- L15 `CARD_UI_SCENE_PATH: String` = `"res://Scenes/Cards/CardUI.tscn"`
- L17 `FLIGHT_SETTLE_MILLIS: int` = `900` — Comfortably longer than CardUI.DRAW_FLIGHT_TIME plus the largest deal stagger.

Public API:
- L66 `test_every_card_owns_its_fake_3d_material() -> void`
- L79 `test_dealt_card_starts_face_down_and_lands_flat() -> void`
- L98 `test_card_back_wears_the_emblem_image() -> void`
- L125 `test_grabbing_a_card_mid_flight_snaps_it_flat() -> void`
- L137 `test_set_hand_reuses_the_cards_already_in_the_row() -> void`
- L156 `test_set_hand_only_deals_the_new_cards() -> void`
- L173 `test_merged_card_appears_in_place_instead_of_flying_in() -> void`
- L190 `test_a_resting_card_renders_on_the_pixel_grid_of_its_slot() -> void`
- L208 `test_removed_card_leaves_the_row_at_once() -> void`
- L225 `test_merged_card_is_placed_at_its_model_slot() -> void`
- L245 `test_survivors_glide_instead_of_snapping_into_place() -> void`
- L271 `test_the_card_footprint_matches_its_layout_slot() -> void`
- L281 `test_hover_scales_the_card_without_warping_it() -> void`

Private:
- L21 `_make_card_ui`
- L32 `_make_hand_bar`
- L47 `_row`
- L57 `_tilt`

Uses: BattleScene, Card, CardUI, HandBar
Used by: —
Loads: res

### `GDTest/CardFlashPolicyTest.gd` — `class_name CardFlashPolicyTest` extends `GdUnitTestSuite` · 109 lines

> Locks in *who caused it* when the game reveals hand cards it picked on its own: - an enemy acting on the player's hand flashes hostile (crimson) - the player's…
- L15 `class RecordingUI extends GameUI` (members not indexed)

Public API:
- L58 `test_enemy_auto_pick_flashes_hostile() -> void`
- L72 `test_enemy_auto_pick_with_empty_hand_does_not_flash() -> void`
- L83 `test_enemy_effect_flash_is_hostile() -> void`
- L97 `test_player_effect_flash_is_friendly() -> void`

Private:
- L27 `_make_manager`
- L44 `_recorder`
- L48 `_make_enemy`
- L54 `_accept_all`

Uses: BattleScene, Card, EnemyIntent, GameManager, GameState, GameUI, SkillContext, Unit, UnitData
Used by: —
Loads: —

### `GDTest/CardMergeAnimationTest.gd` — `class_name CardMergeAnimationTest` extends `GdUnitTestSuite` · 564 lines

> Locks in the merge: the card the player was carrying is picked up from the exact point they released it, the two cards drift into each other and fold closed int…

Constants:
- L27 `MERGE_SETTLE_MILLIS: int` = `900` — Comfortably longer than CardUI's converge + reveal.
- L30 `FOLDED_MILLIS: int` = `360` — Just past the point the two cards have folded away and the merged card has taken over from the edge they left: CardUI.MERGE_CONVERGE_TIME plus a margin.
- L32 `HALF_WAY_MILLIS: int` = `150` — Part way through CardUI.MERGE_CONVERGE_TIME, for looking at cards mid-drift.
- L34 `LAYOUT_SETTLE_MILLIS: int` = `60` — Long enough for the hand layout to settle, so slot positions are real.

Public API:
- L117 `test_the_two_cards_are_mounted_where_they_were_and_the_layout_never_moves() -> void`
- L165 `test_the_merge_starts_from_where_the_card_was_released() -> void` — The point of the whole animation: the card the player was carrying is picked up where they let go of it, not where it was dragged out of.
- L212 `test_a_merge_with_no_release_starts_from_the_cards_own_slot() -> void` — A merge driven on the model rather than by a drag has no release point to pick up from, so the carried card starts from its own slot instead.
- L232 `test_the_cards_fold_over_and_the_merged_card_unfolds_out_of_the_same_pose() -> void` — The two cards fold over as they arrive, and the merged card takes over from that exact pose - the same angle and the same faintness - and unfolds out of it. The…
- L294 `test_a_card_at_the_fold_angle_is_not_drawn_at_all() -> void` — A card at the fold angle must not be drawn at all. This curve is the whole reason the fold can run all the way to edge on without ending in a thin bright line,…
- L307 `test_the_merged_card_settles_flat_and_the_merge_is_cleaned_up() -> void`
- L333 `test_the_merged_card_takes_the_slot_the_merge_produced() -> void`
- L351 `test_the_hand_refresh_reuses_the_merging_card() -> void`
- L371 `test_the_hand_refresh_never_slides_the_merging_card() -> void`
- L398 `test_grabbing_a_merging_card_snaps_it_flat() -> void`
- L419 `test_the_survivors_glide_into_the_gap_the_merge_left() -> void`
- L446 `test_a_double_merge_merges_a_free_play_card() -> void`
- L477 `test_every_card_wears_the_same_frame() -> void` — Every card wears the same frame, whatever it has been through. Merging used to repaint the frame, which made a merged card look like a different object rather t…
- L499 `test_the_two_cards_are_never_hidden_before_the_merged_card() -> void` — The user-visible contract: the two cards must never be taken off screen before the merged card is on it. They are children of the very node that used to be dimm…
- L542 `test_the_merged_card_is_drawn_in_front_of_the_two_cards_that_made_it() -> void` — The card that comes out of the merge has to be the thing the player watches, so both cards that made it are parked behind it in the draw order.
- L557 `test_the_two_cards_are_drawn_detached_from_the_hand_layout() -> void` — The two cards are drawn in viewport space, detached from the hand's layout, so the merge can glide between the point of release and the slot it lands in without…

Private:
- L39 `_make_hand_bar`
- L54 `_row`
- L63 `_card_ui`
- L71 `_plates`
- L85 `_tilt`
- L95 `_ready_hand`
- L107 `_merge_on_state`

Uses: BattleScene, Card, CardUI, ForgePlate, GameManager, GameState, HandBar
Used by: —
Loads: —

### `GDTest/CardTest.gd` — `class_name CardTest` extends `GdUnitTestSuite` · 31 lines

> This is the GDUnit test for Card class

Public API:
- L9 `test_card_values() -> void`
- L18 `test_card_effective_value_with_buff() -> void`
- L25 `test_card_effective_value_with_debuff() -> void`

Uses: Card
Used by: —
Loads: —

### `GDTest/CardUITest.gd` — `class_name CardUITest` extends `GdUnitTestSuite` · 99 lines

> Tests for CardUI's runtime card feedback: the delayed value-label refresh after a skill buff/debuff and the hostile (enemy-caused) red glow preset.

Constants:
- L10 `CARD_UI_SCENE_PATH: String` = `"res://Scenes/Cards/CardUI.tscn"`
- L13 `CRIMSON_MID: Color` — Mid colours of the OutlineGlow presets a hand card picks between.
- L14 `RUNETERRA_BLUE_MID: Color` = `Color(0.18, 0.70, 1.00) # RUNETERRA_BLUE`

Public API:
- L47 `test_value_label_refreshes_after_runtime_value_change() -> void`
- L63 `test_unrelated_card_change_is_ignored() -> void`
- L76 `test_hostile_flash_uses_the_crimson_preset() -> void`

Private:
- L19 `_make_card_ui`
- L30 `_glow_param`
- L40 `_glow_is_active`

Uses: Card, CardUI, OutlineGlow
Used by: —
Loads: res

### `GDTest/DebugMenuTest.gd` — `class_name DebugMenuTest` extends `GdUnitTestSuite` · 727 lines

> Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager): - the panel is view-only: it reports readouts, gates its tools while the turn loop…

Sections: Panel (view-only) tests · Header drag (the panel can be moved out of the way) · Card tools (overflow, merge tiers, hand operations) · Resource tools · Unit tools · Wave tools · Scene wiring
- L16 `class RecordingUI extends GameUI` (members not indexed)

Public API:
- L126 `test_menu_starts_closed_and_toggles() -> void`
- L137 `test_close_button_closes_the_menu_and_reports_it() -> void`
- L153 `test_gate_locks_every_tool_and_the_close_button_stays_live() -> void`
- L170 `test_refresh_flags_an_over_cap_hand() -> void`
- L181 `test_refresh_lists_targets_and_keeps_the_selection() -> void`
- L195 `test_unit_tool_carries_the_selected_target() -> void`
- L220 `test_unit_tool_without_a_target_does_nothing() -> void`
- L253 `test_dragging_the_header_moves_the_panel() -> void`
- L278 `test_header_drag_ignores_other_mouse_buttons() -> void`
- L289 `test_header_is_a_wired_drag_handle() -> void`
- L299 `test_dragging_cannot_push_the_panel_off_screen() -> void`
- L325 `test_spawning_ignores_the_hand_cap() -> void`
- L336 `test_custom_spawn_builds_each_merge_tier() -> void`
- L356 `test_spawned_merged_card_evaporates_instead_of_poisoning_the_deck() -> void`
- L367 `test_clearing_the_hand_still_discards_real_deck_cards() -> void`
- L378 `test_discard_random_removes_exactly_one_card() -> void`
- L389 `test_draw_tools_pull_from_the_deck() -> void`
- L404 `test_buff_hand_raises_every_card_and_announces_it() -> void`
- L422 `test_hand_tools_on_an_empty_hand_do_not_crash() -> void`
- L436 `test_resource_tools_top_up_actions_and_merges() -> void`
- L448 `test_hand_cap_stepper_clamps_at_both_ends() -> void`
- L460 `test_next_skill_bonus_accumulates() -> void`
- L472 `test_fill_moxie_makes_the_ultimate_castable() -> void`
- L483 `test_zero_moxie_clears_the_gauge_and_the_used_lock() -> void`
- L494 `test_damage_tools_absorb_through_shield_then_hp() -> void`
- L507 `test_true_damage_bypasses_the_shield() -> void`
- L520 `test_heal_full_restores_the_target_only() -> void`
- L533 `test_shield_tools_add_and_clear() -> void`
- L546 `test_kill_defeats_only_the_targeted_slot() -> void`
- L556 `test_scope_all_hits_both_rows() -> void`
- L566 `test_untargeted_command_never_touches_the_enemy_row() -> void`
- L576 `test_status_tools_apply_and_clear() -> void`
- L593 `test_clear_wave_defeats_every_living_enemy() -> void`
- L602 `test_respawn_wave_rebuilds_the_enemy_row() -> void`
- L617 `test_reroll_intents_skips_defeated_enemies() -> void`
- L626 `test_dice_step_rerolls_with_the_new_dice() -> void`
- L641 `test_unknown_command_is_ignored() -> void`
- L655 `test_battle_scene_mounts_and_toggles_the_debug_menu() -> void` — The battle scene is the only place the toggle button, the hotkey and the panel meet, so this loads the real scene and checks they are actually connected.
- L686 `test_battle_scene_locks_the_tools_until_the_player_turn_starts() -> void`
- L705 `test_battle_scene_applies_a_tool_through_the_turn_loop() -> void` — _ready() runs the loop up to its first player action, so a tool press goes straight onto the queue and the turn loop applies it for real.

Private:
- L36 `_make_skill`
- L40 `_make_ally_data`
- L51 `_make_enemy_data`
- L58 `_make_enemy`
- L64 `_make_manager`
- L81 `_run`
- L85 `_snapshot`
- L101 `_targets`
- L113 `_find_button`
- L239 `_press_header`
- L247 `_drag_header`

Uses: BattleScene, Card, DebugMenuPopup, EnemyIntent, GameManager, GameState, GameUI, SkillData, Unit, UnitData
Used by: —
Loads: res

### `GDTest/EnemyTurnOverlapTest.gd` — `class_name EnemyTurnOverlapTest` extends `GdUnitTestSuite` · 232 lines

> Locks the enemy-turn overlap ("fast mode" pacing): - consecutive enemies hand control to the next one at the impact beat of their skill animation, so wind-downs…
- L14 `class RecordingUI extends GameUI` (members not indexed)

Public API:
- L89 `test_consecutive_enemy_skills_overlap_at_the_impact_beat() -> void`
- L101 `test_overlap_lead_keeps_an_actual_overlap_window() -> void`
- L107 `test_enemy_ultimate_still_plays_in_full_after_the_skill() -> void`
- L123 `test_player_skill_still_waits_for_the_full_animation() -> void`
- L139 `test_lead_wait_is_a_slice_of_the_animation_duration() -> void`
- L146 `test_full_lead_means_wait_for_the_whole_animation() -> void`
- L152 `test_lead_wait_never_goes_negative() -> void`
- L169 `test_lead_beat_fires_once_once_the_animation_slice_elapsed() -> void`
- L190 `test_lead_beat_is_flushed_when_the_action_ends_early() -> void`
- L204 `test_lead_beat_is_flushed_while_the_portrait_is_dying() -> void`
- L220 `test_clearing_the_queue_releases_overlap_waiters() -> void`

Private:
- L34 `_make_skill`
- L38 `_make_enemy`
- L50 `_make_ally`
- L61 `_make_manager`
- L76 `_recorder`
- L81 `_play_enemy_turn`
- L159 `_make_bare_portrait`

Uses: Card, EnemyIntent, GameManager, GameState, GameUI, SkillData, SpinePortrait, Unit, UnitData
Used by: —
Loads: —

### `GDTest/EnemyUltAuraTest.gd` — `class_name EnemyUltAuraTest` extends `GdUnitTestSuite` · 139 lines

> Locks in the enemy Ultimate warning lifecycle. The crimson character aura and the Moxie orb preview both describe one *pending* roll, so neither may outlive the…

Constants:
- L12 `UNIT_UI_SCENE_PATH: String` = `"res://Scenes/BattleUnit/UnitUI.tscn"`
- L15 `CRIMSON_MID: Color` — Mid colours of the OutlineGlow presets (see OutlineGlow.apply_preset).
- L16 `RUNETERRA_BLUE_MID: Color` = `Color(0.18, 0.70, 1.00) # RUNETERRA_BLUE`

Public API:
- L56 `test_orb_preview_is_spent_when_the_roll_lands_short() -> void`
- L69 `test_orb_preview_never_double_counts_into_a_false_ready_glow() -> void`
- L87 `test_aura_warns_before_the_roll_then_releases_on_the_cast() -> void`
- L108 `test_aura_drops_when_the_roll_lands_short() -> void`
- L122 `test_ally_highlights_are_never_rewritten_as_the_enemy_warning() -> void`

Private:
- L20 `_make_enemy`
- L29 `_make_orb`
- L38 `_make_unit_ui`
- L49 `_glow_param`

Uses: MoxieOrbUI, OutlineGlow, SkillData, Unit, UnitData, UnitUI
Used by: —
Loads: res

### `GDTest/GameStateMergeTest.gd` — `class_name GameStateMergeTest` extends `GdUnitTestSuite` · 89 lines

> Locks in where a merged card lands in hand: it takes the slot of the card the player merged *into*, so a merge never teleports the result to the far right.

Public API:
- L26 `test_cross_merge_takes_the_slot_of_the_target() -> void`
- L42 `test_cross_merge_onto_an_earlier_card_keeps_that_slot() -> void`
- L58 `test_cross_merge_onto_the_last_card_stays_last() -> void`
- L72 `test_double_merge_takes_the_slot_of_the_target() -> void`

Private:
- L11 `_make_state`
- L21 `_value_at`

Uses: Card, GameState
Used by: —
Loads: —

### `GDTest/StatusCatalogTest.gd` — `class_name StatusCatalogTest` extends `GdUnitTestSuite` · 91 lines

> Tests for the buff/debuff status system: Unit.statuses + StatusIconCatalog.

Constants:
- L8 `CATALOG_PATH: String`

Public API:
- L18 `test_catalog_resolves_sample_icons() -> void`
- L30 `test_regeneration_counts_down_and_heals() -> void`
- L44 `test_gloom_stacks_and_damages() -> void`
- L57 `test_statuses_clear_when_a_unit_dies() -> void`
- L67 `test_catalog_extracts_buff_and_debuff() -> void`

Private:
- L11 `_make_unit`

Uses: BattleScene, StatusIconCatalog, Unit, UnitData
Used by: —
Loads: res

### `GDTest/TooltipIconCatalogTest.gd` — `class_name TooltipIconCatalogTest` extends `GdUnitTestSuite` · 171 lines

> Tests for the inline tooltip icon system (TooltipIconCatalog + TooltipIconEntry). Covers: left-of-keyword icons (LoR style), pure glyphs (Riftbound style), expl…

Constants:
- L10 `CATALOG_PATH: String`

Public API:
- L22 `test_authored_catalog_resolves_both_sample_statuses() -> void`
- L43 `test_gloom_icon_is_placed_left_of_the_keyword() -> void`
- L54 `test_regeneration_icon_is_placed_left_of_the_keyword() -> void`
- L65 `test_keyword_matching_ignores_case_but_not_partial_words() -> void`
- L76 `test_icon_only_mode_replaces_the_keyword_with_a_pure_glyph() -> void`
- L89 `test_explicit_tokens_honor_the_requested_mode() -> void`
- L101 `test_unknown_token_is_stripped_instead_of_leaking_raw_text() -> void`
- L108 `test_card_category_token_falls_back_to_a_pure_glyph() -> void`
- L122 `test_existing_bbcode_and_image_paths_are_never_rewritten() -> void`
- L133 `test_output_is_consumed_by_a_rich_text_label() -> void`
- L148 `test_formatter_threads_the_catalog_into_the_tooltip_body() -> void`

Private:
- L13 `_fresh_catalog`
- L18 `_authored_catalog`

Uses: BattleScene, Card, CardIconCatalog, SkillData, SkillPreviewFormatter, TooltipIconCatalog, TooltipIconEntry, Unit, UnitData
Used by: —
Loads: res

### `Managers/ColorUtils.gd` extends `Node` · 17 lines

> Color definitions for BBCode

Constants:
- L5 `COLOR_ALLY` = `"#00FF00"`
- L6 `COLOR_ENEMY` = `"#FF4444"`
- L7 `COLOR_HP` = `"#FFA500"`
- L8 `COLOR_SHIELD` = `"#00BFFF"`
- L9 `COLOR_CARD` = `"#FFFF00"`
- L10 `COLOR_DEAD` = `"#7A7A7A"`
- L11 `COLOR_HEADER` = `"#FFFFFF"`

Public API:
- L14 `static colorize(text: String, color: String) -> String` — Wrap text in a BBCode color tag.

Uses: —
Used by: —
Loads: —

### `Managers/EventBus.gd` extends `Node` · 43 lines

> This is used as a global signal bus. Add as an Autoload. Used for UI logging and passive hooks, not game logic. depend on these signals — they are fire-and-forg…

Sections: Turn / Wave · Card Events · Combat Events · Skill Events · Moxie · Status Events

Signals:
- L10 `turn_started(turn_number: int)`
- L11 `wave_started(wave_index: int)`
- L12 `game_over(victory: bool)`
- L16 `card_played(card: Card, ally: Unit)`
- L17 `card_drawn(card: Card)`
- L18 `card_discarded(card: Card)`
- L19 `card_value_changed(card: Card, old_value: int, new_value: int)`
- L23 `damage_dealt(source: Unit, target: Unit, amount: int, hp_lost: int)`
- L24 `shield_gained(target: Unit, amount: int)`
- L25 `shield_reduced(target: Unit, amount: int)`
- L26 `unit_healed(target: Unit, amount: int)`
- L27 `unit_died(target: Unit)`
- L31 `skill_resolved(caster: Unit, skill_name: String)`
- L35 `moxie_changed(unit: Unit, current: int, maximum: int)`
- L36 `ultimate_cast(caster: Unit, skill_name: String)`
- L41 `unit_statuses_changed(unit: Unit)` — A unit's buff/debuff list changed (applied, stacked, ticked or expired).

Uses: Card, Unit
Used by: —
Loads: —

### `Managers/GameManager.gd` — `class_name GameManager` extends `Node` · 1057 lines

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Helpers · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+3 more)

Constants:
- L17 `WAVE_MODE_MAP: Dictionary` = `{` — JSON/config string -> WaveTransition (config.json stores readable names).
- L27 `ENEMY_SKILL_OVERLAP_LEAD: float` = `0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L478 `DEBUG_HAND_CAP_LIMIT: int` = `20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L481 `DEBUG_SCOPE_ALLIES: int` = `0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L482 `DEBUG_SCOPE_ENEMIES: int` = `1`
- L483 `DEBUG_SCOPE_ALL: int` = `2`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent]` = `[]`
- L12 `game_running: bool` = `false`
- L13 `instructions_shown: bool` = `false`

Public API:
- L58 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…

Private:
- L31 `_color_unit`
- L35 `_color_value`
- L39 `_color_card_value`
- L78 `_apply_config`
- L101 `_config_int`
- L106 `_coerce_int`
- L126 `_config_decklist`
- L147 `_config_int_list`
- L157 `_spawn_wave`
- L170 `_run_game_loop`
- L259 `_show_instructions`
- L279 `_player_action_phase`
- L341 `_handle_play`
- L406 `_handle_ally_ultimate`
- L436 `_refresh_enemy_intents`
- L441 `_handle_merge`
- L463 `_handle_convert`
- L494 `_handle_debug_command`
- L581 `_coerce_dict`
- L592 `_debug_targets`
- L611 `_debug_log`
- L616 `_debug_hp_summary`
- L623 `_debug_spawn_random`
- L635 `_debug_spawn_custom`
- L647 `_debug_draw`
- L656 `_debug_buff_hand`
- L668 `_debug_discard_random`
- L680 `_debug_clear_hand`
- L690 `_debug_set_moxie`
- L700 `_debug_heal`
- L708 `_debug_damage`
- L720 `_debug_shield`
- L728 `_debug_clear_shield`
- L736 `_debug_kill`
- L751 `_debug_apply_status`
- L763 `_debug_clear_statuses`
- L772 `_build_ally_context`
- L817 `_build_enemy_context`
- L860 `_resolve_skill`
- L885 `_roll_enemy_intents`
- L898 `_resolve_enemy_turns`
- L949 `_execute_enemy_ultimate`
- L972 `_try_advance_wave`
- L1002 `_end_of_turn_cleanup`
- L1022 `_log_status_event`

Uses: Card, CardUI, DebugMenuPopup, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, Unit, UnitData
Used by: Core/GameState.gd, Core/GameUI.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/DebugMenuPopup.gd, Skills/SkillEffect.gd, Tools/validate_gameData.gd
Loads: —

### `Scenes/BattleScene/BattleScene.gd` — `class_name BattleScene` extends `GameUI` · 487 lines

> Tester tools (the Debug button + F1). Turn off for a build that must not show them.

Sections: GameUI Overrides · Helpers & Interaction Handlers · Debug Menu

Signals:
- L39 `action_decided(action_dict: Dictionary)`
- L40 `unit_selected_for_target(unit: Unit)`

Constants:
- L43 `INTENT_STAGGER: float` = `0.08` — seconds between each enemy's intent appearing

Exports:
- L5 `icon_catalog: CardIconCatalog`
- L6 `status_icon_catalog: StatusIconCatalog`
- L7 `tooltip_icon_catalog: TooltipIconCatalog`
- L8 `unit_ui_scene: PackedScene`
- L9 `turn_dice_progression: Array[int]` = `[]`
- L11 `debug_menu_enabled: bool` = `true`

Onready:
- L13 `hand_bar: HandBar`
- L14 `allies_container: HBoxContainer`
- L15 `enemies_container: HBoxContainer`
- L17 `battle_overlay: BattleOverlayController`
- L19 `wave_value_label: Label`
- L20 `dice_value_label: Label`
- L21 `actions_value_label: Label`
- L22 `merges_value_label: Label`
- L23 `resource_label: Label`
- L24 `convert_button: Button`
- L25 `end_turn_button: Button`
- L26 `log_label: Label`
- L28 `debug_layer: CanvasLayer`
- L29 `debug_button: Button`

State:
- L31 `game_manager: GameManager`
- L33 `debug_menu: DebugMenuPopup` — Tester overlay, built in code and mounted on `debug_layer`.
- L36 `_awaiting_player_action: bool` = `false` — True only while GameManager awaits a player action: the one window in which a debug tool may be applied, because the turn loop is sitting on the action queue.
- L37 `_intent_cache: Dictionary[Unit, Dictionary]` = `{}`

Public API:
- L81 `on_card_played(card: Card, state: GameState) -> void`
- L89 `on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void` — Two cards in hand were fused into `result`: the hand plays the merge (the two cards drift into each other from where they were dropped, fold closed, and the mer…
- L96 `flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void` — Cards the game selected without asking (auto_top_n / auto_highest) get a short highlight so the player can see what was picked for them. `hostile` is set when a…
- L102 `play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — `lead` is the fraction of the skill animation to wait for: 1.0 for the player's own actions, lower for chained enemy turns that overlap their animations (see Ga…
- L110 `play_unit_ultimate(unit: Unit) -> void`
- L115 `show_message(msg: String) -> void`
- L123 `show_game_state(state: GameState) -> void`
- L133 `show_hand_and_resources(state: GameState) -> void`
- L152 `show_enemy_intents(intents: Array[EnemyIntent]) -> void`
- L167 `clear_unit_intent(unit: Unit) -> void`
- L198 `get_player_action(state: GameState) -> Dictionary`
- L220 `ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]`
- L246 `ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]`

Private:
- L45 `_ready`
- L140 `_update_top_bar`
- L174 `_apply_cached_intents`
- L181 `_apply_intent_to`
- L279 `_on_merge_requested`
- L287 `_on_card_dropped_on_unit`
- L295 `_on_unit_clicked`
- L302 `_on_ally_ultimate_requested`
- L307 `_sync_overlay_units`
- L319 `_highlight_target_candidates`
- L326 `_get_unit_ui`
- L336 `_sync_unit_row`
- L377 `_unhandled_key_input`
- L391 `_setup_debug_menu`
- L405 `_on_debug_button_pressed`
- L414 `_sync_debug_toggle`
- L420 `_set_debug_interactive`
- L427 `_on_debug_command_requested`
- L433 `_refresh_debug_menu`
- L442 `_debug_state`
- L449 `_debug_snapshot`
- L468 `_build_debug_targets`
- L480 `_debug_target_entry`

Uses: BattleOverlayController, Card, CardIconCatalog, DataLoader, DebugMenuPopup, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, HandBar, StatusIconCatalog, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: Core/GameUI.gd, GDTest/CardDrawAnimationTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/DebugMenuTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, Scenes/BattleUnit/SpinePortrait.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd
Loads: res

### `Scenes/BattleUnit/SpinePortrait.gd` — `class_name SpinePortrait` extends `Control` · 625 lines

> Emitted once per lead-armed action when the caller may hand control to the next actor, i.e. the action played far enough to overlap with it. It also fires when…

Sections: Helper methods
- L81 `enum ActionBeat` = REACTION, transformation, buff preparation, etc. ATTACK

Signals:
- L4 `action_finished(anim_name: StringName)`
- L5 `action_started(anim_name: StringName)`
- L10 `action_lead_reached(anim_name: StringName)`

Constants:
- L12 `FALLBACK_ICON: Texture2D`
- L13 `PORTRAIT_SHADER: Shader`
- L14 `BASE_TRACK: int` = `0`
- L15 `ACTION_COMPLETION_GRACE: float` = `0.25`
- L16 `FALLBACK_ACTION_DURATION: float` = `2.0`

Exports:
- L18 `skeleton_data: Resource`
- L20 `anim_idle: StringName` = `&"idle"`
- L21 `anim_sleep: StringName` = `&"sleep"`
- L22 `anim_born: StringName` = `&"born"`
- L23 `anim_change: StringName` = `&"change"`
- L24 `anim_die: StringName` = `&"die"`
- L25 `anim_freeze: StringName` = `&"freeze"`
- L26 `anim_giddy: StringName` = `&"giddy"`
- L27 `anim_hit: StringName` = `&"hit"`
- L28 `anim_idle_special: StringName` = `&"idle_special1"`
- L29 `anim_posture: StringName` = `&"posture"`
- L30 `anim_skill1: StringName` = `&"skill1"`
- L31 `anim_skill1_1: StringName` = `&"skill1_1"`
- L32 `anim_skill1_2: StringName` = `&"skill1_2"`
- L33 `anim_skill2_1: StringName` = `&"skill2_1"`
- L34 `anim_unique: StringName` = `&"unique"`
- L35 `anim_unique_1: StringName` = `&"unique_1"`
- L38 `source_art_bounds: Vector2` = `Vector2(220.0, 420.0)`
- L39 `viewport_fill: float` = `0.96`
- L40 `bottom_padding: float` = `2.0`
- L41 `horizontal_offset: float` = `0.0`
- L44 `bloom_intensity: float` = `1.0`
- L45 `bloom_threshold: float` = `0.35`
- L46 `bloom_tint: float` = `0.0`
- L48 `hdr_bloom: bool` = `false` — Enable only if a WorldEnvironment glow + HDR 2D is set up (see below).
- L50 `bloom_debug_view: int` = `0` — 0 normal, 1 R, 2 G, 3 B, 4 mask
- L53 `hit_reaction_delay: float` = `0.35`
- L54 `death_animation_delay: float` = `0.35`

State:
- L56 `_canvas_group: CanvasGroup`
- L57 `_spine: Node2D`
- L58 `_animation_state: Object`
- L59 `_material: ShaderMaterial`
- L60 `_fallback: TextureRect`
- L61 `_facing_left: bool` = `false`
- L62 `_dead: bool` = `false`
- L64 `_action_queue: Array[Dictionary]` = `[]`
- L65 `_action_running: bool` = `false`
- L66 `_action_pump_scheduled: bool` = `false`
- L67 `_active_action: StringName` = `&""`
- L68 `_next_action_order: int` = `0`
- L69 `_action_watchdog: float` = `0.0`
- L72 `_action_lead: float` = `0.0` — Seconds left until the running action reaches its overlap beat.
- L76 `_action_lead_armed: bool` = `false` — True while an overlap wait is armed for the running action. Kept separate from the counter so "already elapsed" (negative time) can never be confused with "no l…
- L79 `_hit_cancel_token: int` = `0` — Cancels pending hit reactions when the queue is cleared (death/reload).

Public API:
- L117 `set_skeleton_data(new_data: Resource) -> void` — Dynamically update the skeleton data (e.g., if assigned at runtime)
- L131 `configure_from_unit(_display_name: String, is_enemy: bool) -> void`
- L135 `set_hit_flash(strength: float) -> void`
- L144 `request_action(anim_name: StringName, beat: ActionBeat = ActionBeat.ATTACK, lead_seconds: float = -1.0) -> bool` — Requests an animation without immediately interrupting another action. Lower beat values play first. Requests with the same beat remain FIFO. fires. -1 (default…
- L180 `play_hit(delay: float = -1.0) -> void`
- L214 `play_skill(skill_index: int, rank: int = 0) -> void`
- L223 `play_skill_and_wait(skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — Plays a skill action and waits for the caller's turn to continue. waits for the whole animation plus its blend back to idle, which is what the player's own turn…
- L244 `static lead_wait_seconds(duration: float, lead_fraction: float) -> float` — Seconds the caller waits before the next actor may start, for an action that lasts `duration` and an overlap request of `lead_fraction`. -1.0 means "wait for th…
- L255 `play_ultimate_and_wait() -> void`
- L350 `has_animation(anim_name: StringName) -> bool` — Check if the current skeleton actually has the animation
- L364 `play_animation(anim_name: StringName, loop: bool = false) -> void` — Plays a one-shot by default, then automatically returns to idle. Pass loop = true for persistent states such as sleep, freeze, or giddy.
- L426 `set_dead(value: bool) -> void`
- L599 `is_skill_animation(anim_name: StringName) -> bool` — True for animations where the character leaves its idle spot.
- L606 `get_intro_duration() -> float` — How long the spawn animation lasts. UnitUI fades its HUD in after this.
- L612 `get_canvas_group() -> CanvasGroup`

Private:
- L87 `_ready`
- L93 `_process`
- L122 `_reload_spine`
- L187 `_schedule_delayed_hit`
- L202 `_get_skill_anim`
- L249 `_get_ultimate_anim`
- L262 `_schedule_action_pump`
- L270 `_pump_action_queue`
- L305 `_on_spine_animation_completed`
- L330 `_clear_action_queue`
- L376 `_play_base_animation`
- L412 `_play_death_animation`
- L446 `_schedule_delayed_death`
- L457 `_create_spine_sprite`
- L503 `_create_material`
- L521 `_fit_sprite`
- L536 `_show_fallback`
- L550 `_get_animation_duration`
- L573 `_finish_active_action`
- L591 `_emit_action_lead`
- L616 `_ensure_canvas_group`

Uses: BattleScene, UnitUI
Used by: GDTest/EnemyTurnOverlapTest.gd, Scenes/BattleUnit/UnitUI.gd
Loads: res

### `Scenes/BattleUnit/StatusIconCatalog.gd` — `class_name StatusIconCatalog` extends `Resource` · 331 lines

> Catalog for character buff/debuff status icons (separate from CardIconCatalog). Provides lookup and automatic inspection of Unit buff/debuff state. Two dictiona…

Sections: Constants · Exports · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L17 `PLACEHOLDER_ICON: Texture2D`
- L21 `SAMPLE_ICON_SVG: Texture2D` — Sample icons shipped with the project. icon.svg is 128x128 and icon2.png is 1000x1000; the UI badge scales both into the same square, so mismatched dimensions (…
- L22 `SAMPLE_ICON_PNG: Texture2D`
- L26 `DEBUFF_KEYWORDS: PackedStringArray` = `[` — Keyword heuristics: a status id containing one of these counts as a debuff even before it is registered in `debuff_icons`.

Exports:
- L33 `default_icon: Texture2D` = `PLACEHOLDER_ICON`
- L34 `buff_icons: Dictionary[String, Texture2D]` = `{}   # status_id (String) -> Texture2D`
- L35 `debuff_icons: Dictionary[String, Texture2D]` = `{} # status_id (String) -> Texture2D`

Public API:
- L48 `register_default_icons() -> void` — Adds the sample status mappings without overwriting authored entries.
- L56 `get_status_icon(status_id: String) -> Texture2D` — Never returns null: unknown ids (and empty slots) fall back to the default.
- L68 `is_debuff_id(status_id: String) -> bool` — Registered buff ids win over the keyword heuristics.
- L82 `extract_unit_statuses(unit: Object) -> Array[Dictionary]` — Extracts active buffs/debuffs from a Unit instance. Returns Array[Dictionary] with keys: { "id": String, "count": int, "is_debuff": bool, "icon": Texture2D }

Private:
- L42 `_init`
- L220 `_entry_is_debuff`
- L231 `_object_bool`
- L241 `_extract_count`
- L270 `_extract_scalar_int`
- L283 `_parse_status_object`

Uses: BattleScene, CardIconCatalog, Unit
Used by: GDTest/StatusCatalogTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/HUD/TooltipIconCatalog.gd
Loads: res

### `Scenes/BattleUnit/UnitUI.gd` — `class_name UnitUI` extends `PanelContainer` · 1341 lines

> Toggle this on to manually assign a .tres file below.

Sections: Health Bar State · Lifecycle · Setup & Binding · Intent Label · Outline Glow & Highlights · Drag & Drop · Character Animation · Skill HUD fade · (+4 more)

Signals:
- L4 `card_dropped_on_unit(card: Card, unit: Unit)`
- L5 `unit_clicked(unit: Unit)`
- L6 `card_hover_started(unit: Unit, card: Card, anchor_rect: Rect2)`
- L7 `card_hover_ended(unit: Unit)`
- L8 `intent_hover_started(unit: Unit, anchor_rect: Rect2)`
- L9 `intent_hover_ended(unit: Unit)`

Constants:
- L11 `PLACEHOLDER_ICON: Texture2D`
- L12 `STAGGER_OFFSET_Y: float` = `65.0`
- L13 `SPINE_BASE_DIR` = `"res://Scenes/BattleUnit/Spine/"`
- L89 `HIT_FLASH_TIME: float` = `0.4`
- L90 `CHIP_HOLD_TIME: float`
- L91 `CHIP_DRAIN_SPEED: float` = `9.0`
- L92 `HEAL_FILL_SPEED: float` = `10.0`
- L93 `SHIELD_GAIN_SPEED: float` = `14.0`
- L94 `SHIELD_DECAY_SPEED: float` = `9.0  ## Expiry shrink (not a hit)`
- L95 `SHIELD_FLASH_TIME: float` = `0.28`
- L96 `CAP_EXPAND_SPEED: float` = `18.0`
- L97 `CAP_SHRINK_SPEED: float` = `6.0`
- L99 `SHATTER_DURATION: float` = `0.28`
- L100 `SHATTER_WAVE_TIME: float` = `0.14`
- L101 `SHATTER_SHARD_LIFE: float` = `0.16`
- L708 `SHOW_STATUS_ICONS: bool` = `true` — Status badge strip above the portrait (buff/debuff icons + counter).
- L710 `SHOW_SKILL_PREVIEW_STRIP: bool` = `false` — Legacy skill-category preview rows in the same section (kept off).
- L714 `BADGE_SIZE: float` = `24.0` — Square size of one status badge. The grid has 4 columns, so four badges fit inside the 114px strip without resizing the UnitUI.
- L716 `ICON_INSET: float` = `3.0` — Inset that keeps the icon art away from the badge frame.
- L718 `COUNT_FONT_SIZE: int` = `11` — Counter label styling (bottom-right corner, outlined white).
- L719 `COUNT_OUTLINE_SIZE: int` = `4`
- L721 `COUNT_OVERHANG: float` = `3.0` — How far the counter overhangs the badge corner (matches the reference art).
- L723 `COUNT_DISPLAY_MAX: int` = `99` — Counts above this are shown as "99+".
- L725 `BUFF_TILE_COLOR: Color` = `Color(0.10, 0.26, 0.42, 0.95)` — Badge tile tint: buffs are royal blue, debuffs crimson (LoR/R1999 style).
- L726 `BUFF_FRAME_COLOR: Color` = `Color(0.36, 0.78, 1.0, 0.95)`
- L727 `DEBUFF_TILE_COLOR: Color` = `Color(0.34, 0.09, 0.12, 0.95)`
- L728 `DEBUFF_FRAME_COLOR: Color` = `Color(1.0, 0.34, 0.32, 0.95)`

Exports:
- L15 `icon_catalog: CardIconCatalog`
- L16 `status_icon_catalog: StatusIconCatalog`
- L20 `use_override_spine: bool` = `false`
- L21 `override_spine_data: Resource`
- L24 `hit_flash_delay: float` = `0.0`
- L31 `status_apply_delay: float` = `-1.0` — How long the badge strip waits before showing a new/stacked status, so it lands together with the hit reaction. -1 = reuse the damage delay above (hit_flash_del…
- L34 `hud_fade_out_time: float` = `0.12`
- L35 `hud_fade_in_time: float` = `0.25`
- L41 `intent_fade_in_time: float` = `0.25`
- L42 `intent_fade_out_time: float` = `0.2`
- L50 `intro_extra_delay: float` = `0.0` — Extra wait after the born animation ends. Negative = start fading before born ends.
- L51 `intro_fade_in_time: float` = `0.35`

Onready:
- L60 `intent_label: Label`
- L61 `status_section: VBoxContainer`
- L62 `status_icons_grid: GridContainer`
- L63 `skill_preview_box: VBoxContainer`
- L64 `skill_1_row: HBoxContainer`
- L65 `skill_1_icons: HBoxContainer`
- L66 `skill_2_row: HBoxContainer`
- L67 `skill_2_icons: HBoxContainer`
- L69 `health_bar_canvas: Control`
- L70 `health_shield_container: Control`
- L71 `hp_bar: ProgressBar`
- L72 `shield_bar: ProgressBar`
- L74 `oval_body: PanelContainer`
- L75 `sprite: Control`
- L76 `name_label: Label`
- L77 `hover_glow: Panel`

State:
- L37 `_hud_tween: Tween`
- L38 `_hud_hidden: bool` = `false`
- L44 `_intent_tween: Tween`
- L46 `_intent_visible: bool` = `false` — Whether the label should end up shown, even mid-fade
- L53 `_intro_active: bool` = `false`
- L54 `_intro_tween: Tween`
- L55 `_pending_intent: Dictionary` = `{}`
- L56 `_skill_hud_active: bool` = `false`
- L58 `unit: Unit`
- L79 `_stagger_style: StyleBoxEmpty`
- L80 `_is_target_highlighted: bool` = `false`
- L81 `_is_drag_hovering: bool` = `false`
- L82 `_is_orb_linked_highlighted: bool` = `false`
- L83 `_hovered_drag_card: Card` = `null`
- L84 `_intent_style: StyleBoxEmpty`
- L85 `_glow: OutlineGlow`
- L86 `_ult_warning_active: bool` = `false`
- L104 `_display_hp: float` = `0.0` — What the bar currently shows (lags behind the Unit on purpose).
- L105 `_display_shield: float` = `0.0`
- L107 `_target_hp: float` = `0.0` — Where the bar is heading: real values + damage that hasn't landed yet.
- L108 `_target_shield: float` = `0.0`
- L109 `_prev_target_shield: float` = `0.0`
- L112 `_chip_total: float` = `0.0` — Right edge of the "recently lost" chip, in HP units (HP + shield).
- L113 `_chip_hold_timer: float` = `0.0`
- L114 `_display_max_cap: float` = `1.0`
- L116 `_hit_flash_timer: float` = `0.0`
- L117 `_shield_flash_timer: float` = `0.0`
- L120 `_pending_hits: Array[Dictionary]` = `[]` — Hits that already happened in the model but haven't landed visually.
- L122 `_withheld_hp: float` = `0.0` — Sum of pending losses. Added back so the bar keeps showing pre-hit values.
- L123 `_withheld_shield: float` = `0.0`
- L125 `_was_dead: bool` = `false`
- L126 `_pending_death_timer: float` = `-1.0`
- L127 `_shatter_timer: float` = `0.0`
- L128 `_shatter_shards: Array[Dictionary]` = `[]`
- L130 `_last_status_signature: String` = `""`
- L131 `_manual_statuses: Array[Dictionary]` = `[]`
- L133 `_statuses_dirty: bool` = `true` — Set whenever the unit's status list changes, so the strip only rebuilds then.
- L135 `_pending_status_timer: float` = `-1.0` — Counts down to the moment a pending status change becomes visible (-1 = none).

Public API:
- L208 `setup(p_unit: Unit, p_card_catalog: CardIconCatalog, p_status_catalog: StatusIconCatalog = null) -> void`
- L260 `set_staggered(is_lower: bool) -> void`
- L289 `set_intent_ult_warning(warn: bool) -> void`
- L306 `show_intent(text: String, _categories: PackedStringArray, delay: float = 0.0) -> void` — delay: seconds to wait before fading in (used to stagger enemies).
- L339 `clear_intent(animated: bool = false) -> void` — animated = true fades out; false hides instantly.
- L385 `set_target_highlight(highlight: bool) -> void`
- L390 `set_orb_linked_highlight(highlight: bool) -> void`
- L528 `play_skill_animation(skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — skill_index: 1 for odd, 2 for even. rank: 0 normal, 1 merged/condition met, 2 double merged. lead: fraction of the skill animation to wait for before returning.…
- L541 `play_ultimate_animation() -> void`
- L567 `play_character_animation(anim_name: StringName) -> void`
- L645 `play_intro(extra_delay: float = 0.0) -> void` — Hides HUD + intent, then fades them in once the born animation ends. Called automatically by setup(). Call again with extra_delay to stagger units.
- L730 `set_manual_statuses(statuses: Array[Dictionary]) -> void`

Private:
- L141 `_ready`
- L185 `_process`
- L240 `_bind_unit`
- L276 `_setup_intent_badge_style`
- L295 `_on_intent_mouse_entered`
- L300 `_on_intent_mouse_exited`
- L360 `_kill_intent_tween`
- L370 `_setup_glow_style`
- L395 `_refresh_outline_glow`
- L412 `_enemy_holds_full_gauge`
- L419 `_on_unit_moxie_changed`
- L426 `_update_glow_visibility`
- L451 `_gui_input`
- L457 `_can_drop_data`
- L489 `_drop_data`
- L498 `_notification`
- L503 `_reset_preview`
- L553 `_play_skill_animation_for_card`
- L576 `_is_skill_anim`
- L583 `_on_sprite_action_started`
- L589 `_on_sprite_action_finished`
- L595 `_get_hud_nodes`
- L605 `_update_hud_visibility`
- L611 `_set_hud_hidden`
- L668 `_finish_intro`
- L685 `_cancel_intro`
- L691 `_kill_intro_tween`
- L697 `_get_intro_duration`
- L740 `_on_unit_statuses_changed`
- L750 `_refresh_status_icons`
- L781 `_status_signature`
- L792 `_create_e7_status_badge`
- L855 `_refresh_display`
- L995 `_trigger_death_shatter`
- L1035 `_draw_health_bar`
- L1163 `_bar_rect`
- L1169 `_get_tick_step`
- L1176 `_reset_bar_state`
- L1190 `_clear_pending_hits`
- L1198 `_on_unit_damaged`
- L1217 `_get_effective_hit_flash_delay`
- L1233 `_get_effective_status_delay`
- L1239 `_get_effective_death_delay`
- L1255 `_render_skill_preview_icons`
- L1275 `_load_unit_texture`
- L1334 `_ignore_mouse_recursively`

Uses: BattleScene, Card, CardDrag, CardIconCatalog, OutlineGlow, SkillData, SpinePortrait, StatusIconCatalog, Unit
Used by: Core/Unit.gd, GDTest/EnemyUltAuraTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/SpinePortrait.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/BattleOverlayController.gd, Tools/gen_code_index.gd
Loads: res

### `Scenes/Cards/CardDrag.gd` — `class_name CardDrag` extends `RefCounted` · 13 lines

> Payload for all card drag operations. Consumed by: CardUI (merge), UnitDropZone (skill activation).

State:
- L7 `card: Card`
- L8 `source: HandBar`

Private:
- L10 `_init`

Uses: Card, CardUI, HandBar
Used by: Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd
Loads: —

### `Scenes/Cards/CardIconCatalog.gd` — `class_name CardIconCatalog` extends `Resource` · 15 lines

> Central skill-type icon registry for cards / skill previews. One instance, set as project autoload or exported on UI roots. No res://Trash paths live in class c…

Exports:
- L11 `icons: Dictionary` = `{}    # StringName -> Texture2D`

Public API:
- L13 `get_icon(category: StringName) -> Texture2D`

Uses: —
Used by: GDTest/TooltipIconCatalogTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/SkillTooltipPopup.gd, Scenes/HUD/TooltipIconCatalog.gd, Tools/validate_gameData.gd
Loads: res

### `Scenes/Cards/CardUI.gd` — `class_name CardUI` extends `PanelContainer` · 1381 lines

> Visual representation of one Card in hand. Drag source (play / merge) and drop target (merge only). The card is rendered into an offscreen SubViewport and that…

Sections: Fake-3D rig · Draw animation · Merge animation · Card frame · Card back · Consumed guard · Hover Animation · Fake-3D rig · (+9 more)

Signals:
- L13 `play_requested(card: Card)`

Constants:
- L15 `DRAG_PREVIEW_SIZE: Vector2` = `Vector2(100, 145)`
- L16 `DRAG_PREVIEW_SCALE: float` = `1.04`
- L17 `DRAG_SOURCE_ALPHA: float` = `0.0 # Hide the source card`
- L18 `RETURN_TWEEN_TIME: float` = `0.18`
- L19 `RETURN_CANVAS_LAYER: int` = `100`
- L20 `PLACEHOLDER_ICON: Texture2D`
- L22 `HOVER_SCALE: float` = `1.12`
- L23 `HOVER_LIFT: float` = `18.0`
- L24 `HOVER_TWEEN_TIME: float` = `0.12`
- L25 `HOVER_Z_INDEX: int` = `20`
- L28 `CARD_SIZE: Vector2` = `Vector2(100, 145)`
- L29 `CARD_CORNER_RADIUS: float` = `6.0`
- L32 `CARD_PADDING: Vector2` = `Vector2(20, 20)` — Transparent padding around the card body, so a strongly tilted card has room to stretch its near corners inside the quad instead of being clipped.
- L34 `QUAD_SIZE: Vector2` = `Vector2(140, 185)` — Padded quad (and matching SubViewport logical size) in logical pixels.
- L37 `RENDER_SUPERSAMPLE: float` = `2.0` — Offscreen supersampling used only while the deal is in flight, so the text and borders stay crisp under the perspective warp. A resting card renders 1:1.
- L38 `FAKE_3D_SHADER: Shader`
- L45 `DRAW_FLIGHT_TIME: float` = `0.42` — A drawn card is dealt in from beyond the right edge of the hand and flips from back to front in mid-air, landing straight in its slot: it never stops in the mid…
- L47 `DRAW_ROTATION_DELAY: float` = `0.22` — Fraction of the flight spent face down before the flip begins.
- L48 `DRAW_START_YAW: float` = `168.0`
- L49 `DRAW_START_PITCH: float` = `20.0`
- L50 `DRAW_MID_PITCH: float` = `-7.0`
- L51 `DRAW_START_BANK: float` = `15.0`
- L52 `DRAW_START_SCALE: float` = `0.74`
- L53 `DRAW_POP_SCALE: float` = `0.035`
- L54 `DRAW_FADE_IN: float` = `0.12`
- L55 `DRAW_ARC_BASE: float` = `78.0`
- L56 `DRAW_ARC_STEP: float` = `10.0`
- L58 `DRAW_ARC_SWING: float` = `0.34` — How far along the straight line the Bezier control point is pulled.
- L59 `DRAW_Z_BASE: int` = `30`
- L62 `SETTLE_FREQUENCY: float` = `7.0` — Critically damped settle, so the flip arrives with a small natural overshoot instead of a dead stop.
- L63 `SETTLE_DAMPING: float` = `6.5`
- L79 `FORGE_PLATE_A: String` = `"ForgePlateA"` — Two cards are merged where the player let go of them. The card they were carrying picks up from the exact point it was released at, the card it was dropped on p…
- L80 `FORGE_PLATE_B: String` = `"ForgePlateB"`
- L84 `MERGE_CONVERGE_TIME: float` = `0.30` — How long the two cards take to drift into each other. Deliberately unhurried: the merge is meant to read as the two cards becoming one, not as an impact.
- L86 `MERGE_REVEAL_TIME: float` = `0.26` — How long the card they became takes to swing open out of that fold.
- L89 `MERGE_FOLD_YAW: float` = `88.0` — How far each card folds over as it arrives. All the way to edge on, because that is what makes the fold read as the two cards closing.
- L92 `MERGE_FOLD_PITCH: float` = `12.0` — A lean into the fold, so it reads as a card rolling over rather than a page being closed. It is back to flat by the time the cards reach the fold.
- L95 `MERGE_UNFOLD_PITCH: float` = `10.0` — A lean through the unfold, on top of the yaw. Zero at both ends, so the card starts from the pose the two cards finished in and lands dead flat.
- L101 `MERGE_FADE_FROM_YAW: float` = `70.0` — The angle past which a folded card stops being drawn and is faded out instead. A card near edge on has nothing left facing the viewer but its own pale border an…
- L103 `MERGE_POP_SCALE: float` = `0.10` — How far past full size the card swells as it settles flat.
- L104 `MERGE_BRAND_SCALE: float` = `1.32`
- L105 `MERGE_BRAND_DELAY: float` = `0.06`
- L106 `MERGE_BRAND_TIME: float` = `0.16`
- L107 `MERGE_Z_INDEX: int` = `45`
- L114 `CARD_BG_COLOR: Color` = `Color(0.16, 0.18, 0.22, 0.96)` — Every card wears the same frame, whatever it has been through. Merging used to repaint the frame (gilded for a merge, cyan for a free-play card), which made a m…
- L115 `CARD_BORDER_COLOR: Color` = `Color(0.75, 0.78, 0.85, 1.0)`
- L116 `CARD_BORDER_WIDTH: int` = `2`
- L117 `CARD_BOX_RADIUS: int` = `6`
- L126 `CARD_BACK_LOGO: Texture2D` = `preload(` — Emblem painted in the middle of the card back - the side a card shows while it flips over on its way out of the deck. The back itself is drawn by res://Shaders/…
- L130 `CARD_BACK_LOGO_SIZE: float` = `34.0` — Side of the square, in card pixels, the emblem is fitted into.

Exports:
- L135 `icon_catalog: CardIconCatalog`
- L141 `value_change_delay: float` = `0.35` — How long the value label waits before it re-renders after a runtime value change (e.g. an enemy card debuff), mirroring the unit hit-reaction delay so the numbe…

Onready:
- L191 `hover_visual: PanelContainer`
- L192 `icon_row: HBoxContainer`
- L193 `art: TextureRect`
- L194 `value_label: Label`
- L195 `merge_glow: Panel`
- L196 `bounds: Control`

State:
- L132 `_back_logo_texture: Texture2D` = `null` — Built once and shared by every card: the emblem is the same picture for all.
- L143 `card: Card`
- L144 `hand_bar: HandBar`
- L146 `_hover_tween: Tween`
- L147 `_slide_tween: Tween`
- L148 `_draw_tween: Tween`
- L149 `_is_hovered: bool` = `false`
- L152 `_hover_wanted: bool` = `false` — True while the cursor sits inside the slot, even if the card is still flying in from the deck. The hover is applied the moment it lands.
- L154 `_is_drawing: bool` = `false` — True while the fake-3D deal animation owns the card transform.
- L155 `_pick_selectable: bool` = `false`
- L156 `_flash_active: bool` = `false`
- L158 `_flash_hostile: bool` = `false` — True when the flash was caused by an enemy, so the glow turns red.
- L160 `_drag_in_progress: bool` = `false`
- L161 `_is_consumed: bool` = `false`
- L162 `_return_tween: Tween`
- L163 `_return_layer: CanvasLayer`
- L164 `_glow: OutlineGlow`
- L166 `_value_tween: Tween` — Pending delayed re-render of the value label after a runtime value change.
- L170 `_is_merging: bool` = `false` — Merge state. The merge owns the card transform while it plays, the same way `_is_drawing` owns it during a deal.
- L171 `_merge_tween: Tween`
- L172 `_brand_tween: Tween`
- L176 `_merge_plate_a: ForgePlate` — The two cards in the merge, each a fake-3D copy of one card's face. They are children of this card only so that they are drawn along with it; they are posed in…
- L177 `_merge_plate_b: ForgePlate`
- L181 `_merge_start_a: Vector2` = `Vector2.ZERO` — Where each of the two cards set off from, and how big it was, in viewport coordinates. The card the player was carrying starts at the point it was released at,…
- L182 `_merge_start_b: Vector2` = `Vector2.ZERO`
- L183 `_merge_start_scale_a: float` = `1.0`
- L186 `_visual_root: Control` — Fake-3D rig, built in _ready() so CardUI.tscn stays a plain flat layout.
- L187 `_card_quad: TextureRect`
- L188 `_card_surface: SubViewport`
- L189 `_card_material: ShaderMaterial`

Public API:
- L267 `set_pick_selectable(active: bool) -> void` — Highlights this card while the game is asking the player to choose cards in hand. HandBar calls this for every candidate; candidates that have already been pick…
- L280 `set_flash_active(active: bool, hostile: bool = false) -> void` — Highlights this card while the game shows which cards it picked on its own (auto_top_n / auto_highest). HandBar times the flash and clears it again. `hostile` i…
- L291 `mark_consumed() -> void` — Permanently locks this card against further interaction. Called by HandBar immediately before the removal tween starts, so nothing (drag start, drop target, hov…
- L313 `is_consumed() -> bool`
- L363 `frame_style() -> StyleBoxFlat` — The frame this card is drawn with. The same one for every card: a merge is something a card has been through, not something that makes it a new object.
- L581 `slide_to(target: Vector2, duration: float) -> void` — Glides this card's layout slot to `target` (row-local), so the hand closes up or opens smoothly when another card leaves or arrives instead of snapping.
- L633 `is_drawing() -> bool` — True while the fake-3D deal animation owns the card transform.
- L641 `play_draw_animation(start_offset: Vector2, delay: float = 0.0, stagger_index: int = 0) -> void` — Deals this card in from the deck: one fast swoop from `start_offset` (CardUI-local pixels) straight into the slot, flipping from the card back to the printed fa…
- L771 `is_merging() -> bool` — True while the merge owns the card transform.
- L777 `centre() -> Vector2` — Where this card's own body sits on screen. A merge aims the two cards at this, so it is the one position the merge and the hand layout have to agree on.
- L785 `make_merge_plate() -> ForgePlate` — A fake-3D copy of this card's face, for use as one of the two cards in a merge. The caller owns the returned plate until `play_merge_animation` takes it over. O…
- L811 `play_merge_animation(plate_a: ForgePlate, plate_b: ForgePlate, start_centre_a: Vector2, start_centre_b: Vector2, start_scale_a: float) -> void` — Merges this card out of the two cards it was made from: the card the player was carrying at the point they released it, and the card it was dropped on. The two…
- L1059 `setup(p_card: Card, p_hand_bar: HandBar = null) -> void`

Private:
- L199 `_ready`
- L234 `_process`
- L249 `_refresh_glow`
- L317 `_gui_input`
- L326 `_exit_tree`
- L342 `_style_card_panel`
- L367 `_style_merge_glow`
- L387 `_update_hover_pivot`
- L414 `_build_fake_3d_rig`
- L485 `_card_back_logo_texture`
- L505 `_on_card_mouse_entered`
- L517 `_on_card_mouse_exited`
- L525 `_animate_hover`
- L561 `_reset_hover_immediate`
- L599 `_stop_slide`
- L609 `_set_tilt`
- L618 `_set_surface_scale`
- L669 `_finish_draw_immediate`
- L680 `_stop_pose_tweens`
- L690 `_apply_draw_pose`
- L712 `_finish_draw`
- L721 `_apply_flat_pose`
- L737 `_settle`
- L745 `_ease_out_cubic`
- L751 `_ease_in_out_cubic`
- L758 `_ease_out_quart`
- L763 `_quadratic_bezier`
- L864 `_finish_merge_immediate`
- L873 `_finish_merge`
- L885 `_discard_merge_plate`
- L894 `_mount_merge_plate`
- L906 `_pose_converge`
- L921 `_pose_merge_plate`
- L949 `_fold_visibility`
- L962 `_on_merge_folded`
- L986 `_pose_reveal`
- L1001 `_put_forge_plates_behind_card`
- L1010 `_start_brand_pop`
- L1034 `_end_forge_state`
- L1050 `_clear_merge_plates`
- L1065 `_refresh`
- L1077 `_build_stars_and_indicators`
- L1107 `_get_drag_data`
- L1143 `_make_drag_preview`
- L1162 `_make_visual_copy`
- L1184 `_set_mouse_filter_recursive`
- L1194 `_notification`
- L1219 `_restore_if_unconsumed`
- L1228 `_cancel_return_animation`
- L1241 `_animate_return_to_hand`
- L1286 `_on_return_finished`
- L1302 `_can_drop_data`
- L1324 `_drop_data`
- L1348 `_find_hand_bar`
- L1368 `_on_card_value_changed`

Uses: BattleScene, Card, CardDrag, CardIconCatalog, ForgePlate, GameState, HandBar, OutlineGlow, UnitUI
Used by: GDTest/CardDrawAnimationTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/CardUITest.gd, Managers/GameManager.gd, Scenes/Cards/CardDrag.gd, Scenes/Cards/HandBar.gd
Loads: res

### `Scenes/Cards/ForgePlate.gd` — `class_name ForgePlate` extends `Control` · 140 lines

> One of the two cards in a merge, drawn as a real fake-3D quad. A merge has to show two cards banking and folding into each other, so a flat copy of a card face…

Sections: Constants · Private Variables · Lifecycle Methods · Public Methods

Constants:
- L20 `CARD_SIZE: Vector2` = `Vector2(100, 145)`
- L21 `CARD_PADDING: Vector2` = `Vector2(20, 20)`
- L22 `QUAD_SIZE: Vector2` = `Vector2(140, 185)`
- L23 `CARD_CORNER_RADIUS: float` = `6.0`
- L24 `FAKE_3D_SHADER: Shader`

State:
- L28 `_material: ShaderMaterial`
- L29 `_surface: SubViewport`
- L30 `_quad: TextureRect`

Public API:
- L61 `setup(face: Control) -> void` — Builds the warp around a flat copy of one card's face. The face is reparented into the offscreen surface, so the caller must not keep using the node it passes i…
- L112 `set_centre(centre: Vector2) -> void` — Puts this card's centre at `centre` in viewport coordinates, whatever size the card is currently drawn at.
- L119 `centre() -> Vector2` — Where this card's centre is on screen, whatever size it is drawn at. With no pivot the card is scaled about its drawn corner, so the centre sits half a card awa…
- L124 `set_tilt(yaw: float, pitch: float) -> void` — Banks and folds the card in fake 3D, the same way a card being dealt does.
- L131 `tilt() -> Vector2` — How far the card is banked and folded right now, in degrees.

Private:
- L34 `_init`
- L46 `_ready`
- L52 `_exit_tree`

Uses: —
Used by: GDTest/CardMergeAnimationTest.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd
Loads: res

### `Scenes/Cards/HandBar.gd` — `class_name HandBar` extends `PanelContainer` · 430 lines

> Bottom-edge hand of cards. View-only: it animates, GameManager validates.

Sections: Deal choreography · Lifecycle · Public API (called by GraphicalGameUI) · EventBus handlers

Signals:
- L6 `merge_requested(card_a: Card, card_b: Card)`
- L7 `drag_started(card: Card)`
- L8 `drag_ended(card: Card)`
- L9 `card_clicked(card: Card)`

Constants:
- L11 `CARD_SCENE: PackedScene`
- L12 `ENTER_TWEEN_TIME: float` = `0.22`
- L14 `SLIDE_TIME: float` = `0.22` — How long a card takes to glide to its new slot when the hand changes.
- L15 `CARD_WIDTH: float` = `100.0`
- L16 `CARD_HEIGHT: float` = `145.0`
- L18 `AUTO_FLASH_HOLD: float` = `0.55` — How long auto-selected cards stay lit before the flash fades out.
- L23 `DEAL_STAGGER: float` = `0.068` — Seconds between two cards of the same deal, so a full opening hand fans out in well under a second instead of arriving as one block.
- L27 `DECK_DROP: float` = `42.0` — Deck origin as an offset from the card's own slot: beyond the right edge of the hand, so every drawn card is dealt in from off-screen straight to its place inst…
- L30 `DECK_STACK_STEP: Vector2` = `Vector2(16.0, 8.0)` — Alternating deck position, so a multi-card deal looks like it comes off a small pile rather than a single point.

Onready:
- L57 `cards_row: HBoxContainer`

State:
- L33 `game_state: GameState`
- L37 `_pick_active: bool` = `false`
- L38 `_pick_candidates: Array[Card]` = `[]`
- L44 `_release_card: Card` — Where the card the player was carrying was let go of, if the merge about to be played was driven by a real drag. Recorded by the card it was dropped on and cons…
- L45 `_release_centre: Vector2` = `Vector2.ZERO`
- L46 `_has_merge_release: bool` = `false`
- L50 `_deal_slot: int` = `0` — Stagger slot handed to each card dealt within the same frame. Reset once the frame is over, so a later, separate draw always starts at zero again.
- L51 `_deal_slot_queued: bool` = `false`
- L55 `_row_laid_out: bool` = `false` — True once the row has been laid out at least once. Until then a card's position is meaningless, so nothing may be animated away from it.

Public API:
- L76 `set_pick_candidates(candidates: Array[Card], active: bool) -> void`
- L90 `flash_auto_selected(cards: Array[Card], hostile: bool = false) -> void` — Briefly highlights cards the game picked on its own (auto_top_n / auto_highest) so the player can see which cards were affected even though no prompt was shown.…
- L133 `set_hand(cards: Array[Card]) -> void` — Rebuilds the row from the model, reusing every CardUI that is still valid. A deal that is still in flight, a hover, or a pick highlight therefore all survive th…
- L158 `add_card(card: Card) -> void` — Appends one newly drawn card to the right end of the row, matching the model (which also appends), and deals it in from the deck. Safe to call twice for the sam…
- L172 `note_merge_release(card: Card, global_centre: Vector2) -> void` — Records where a card was let go of, so the merge it triggers can start that card from that exact point on screen instead of from the slot it was dragged out of.…
- L188 `play_merge(card_a: Card, card_b: Card, merged_card: Card, new_hand: Array[Card]) -> void` — Merges two cards in hand where the player left them: the card they were carrying drifts out of the point they released it at into the card they dropped it on, t…
- L250 `remove_card(card: Card) -> void` — A card left the hand: it drops out of the row at once and the cards around it glide into the gap it left.
- L365 `can_merge(card_a: Card, card_b: Card) -> bool`

Private:
- L62 `_ready`
- L118 `_apply_pick_candidates`
- L258 `_consume_card`
- L272 `_snapshot_slots`
- L282 `_glide_to_new_slots`
- L290 `_apply_glide`
- L306 `_spawn_card`
- L332 `_next_deal_slot`
- L341 `_reset_deal_slots`
- L349 `_deck_offset`
- L356 `_live_card_uis`
- L376 `_get_game_state`
- L401 `_find_card_ui`
- L414 `_on_event_card_played`
- L420 `_on_event_card_drawn`
- L426 `_on_event_card_discarded`

Uses: BattleScene, Card, CardUI, ForgePlate, GameManager, GameState, Unit
Used by: GDTest/CardDrawAnimationTest.gd, GDTest/CardMergeAnimationTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/Cards/CardDrag.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/DebugMenuPopup.gd
Loads: res

### `Scenes/HUD/BattleOverlayController.gd` — `class_name BattleOverlayController` extends `Node` · 494 lines

> Builds E1–E3 on the left, A1–A3 on the right, manages the tooltip layer, and safely bridges UnitUI hover & wave transitions without freed-instance errors.

Sections: Safe Instance Lookup & Auto Row Sync · Internal Builders & Signal Handlers

Signals:
- L7 `ally_ultimate_requested(ally: Unit)`

State:
- L9 `icon_catalog: CardIconCatalog`
- L10 `tooltip_icon_catalog: TooltipIconCatalog`
- L11 `game_manager: Node # GameManager`
- L13 `_rail_layer: CanvasLayer`
- L14 `_enemy_rail: VBoxContainer`
- L15 `_ally_rail: VBoxContainer`
- L17 `_tooltip_layer: CanvasLayer`
- L18 `_tooltip: SkillTooltipPopup`
- L20 `_orbs_by_unit: Dictionary[Unit, MoxieOrbUI]` = `{} # Unit -> MoxieOrbUI`
- L21 `_units_to_ui: Dictionary[Unit, UnitUI]` = `{}      # Unit -> UnitUI`
- L22 `_current_ally_units: Array[Unit]` = `[]`
- L23 `_current_enemy_units: Array[Unit]` = `[]`
- L25 `_allies_row: Control`
- L26 `_enemies_row: Control`
- L27 `_player_input_enabled: bool` = `false`
- L28 `_auto_sync_queued: bool` = `false`

Public API:
- L44 `setup(p_game_manager: Node, p_icon_catalog: CardIconCatalog, p_tooltip_icon_catalog: TooltipIconCatalog = null) -> void`
- L61 `rebuild_for_units(ally_uis: Array[UnitUI], enemy_uis: Array[UnitUI]) -> void` — Call whenever allies or a new enemy wave spawns, passing active UnitUI nodes.
- L117 `set_player_turn_interactive(enabled: bool) -> void` — Toggle whether ally Ultimate orbs can be clicked right now (true inside get_player_action).
- L128 `sync_enemy_intent_previews() -> void` — Updates enemy orb preview segments from GameManager.current_intents & refreshes Enemy Ult warnings.
- L143 `clear_enemy_intent_previews() -> void`

Private:
- L31 `_ready`
- L159 `_is_live_unit_ui`
- L170 `_get_valid_orb`
- L180 `_get_valid_unit_ui`
- L200 `_same_units_and_valid_orbs`
- L211 `_auto_bind_scene_rows`
- L228 `_on_row_children_changed`
- L232 `_on_wave_or_turn_changed`
- L236 `_queue_auto_sync`
- L243 `_run_auto_sync`
- L259 `_clear_container`
- L272 `_build_rails`
- L310 `_build_tooltip`
- L321 `_spawn_orb`
- L331 `_extract_unit_portrait`
- L352 `_find_character_texture_in_node`
- L392 `_bind_unit_ui`
- L406 `_get_state`
- L415 `_find_intent_for_enemy`
- L429 `_on_unit_card_hover_started`
- L440 `_on_unit_card_hover_ended`
- L447 `_on_unit_intent_hover_started`
- L457 `_on_unit_intent_hover_ended`
- L461 `_on_orb_hover_started`
- L475 `_on_orb_hover_ended`
- L482 `_on_orb_activated`
- L488 `_on_ultimate_cast`

Uses: BattleScene, Card, CardIconCatalog, EnemyIntent, GameManager, GameState, MoxieOrbUI, SkillPreviewFormatter, SkillTooltipPopup, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: Scenes/BattleScene/BattleScene.gd
Loads: res

### `Scenes/HUD/DebugMenuPopup.gd` — `class_name DebugMenuPopup` extends `PanelContainer` · 558 lines

> Tester-only tool palette for the battle scene. Every button here is a *request*: it emits `debug_command_requested` upward and the turn loop performs the mutati…

Sections: Signals · Enums · Constants · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers
- L28 `enum Scope` = ALLIES, ENEMIES, ALL
- L30 `enum CardTier` = BASE, MERGED, DOUBLE_MERGED

Signals:
- L20 `debug_command_requested(command: String, args: Dictionary)` — A tester pressed a tool. `command` is one of the CMD_* ids below and `args` is that tool's payload, documented next to its CMD_* constant.
- L23 `menu_closed` — The panel closed itself (its own close button), so the owner can re-label the button that toggles it.

Constants:
- L36 `CMD_SPAWN_RANDOM: String`
- L37 `CMD_SPAWN_CUSTOM: String`
- L38 `CMD_DRAW: String`
- L39 `CMD_DRAW_TO_MAX: String` = `"draw_to_max"             # {}`
- L40 `CMD_BUFF_HAND: String`
- L41 `CMD_DISCARD_RANDOM: String` = `"discard_random"       # {}`
- L42 `CMD_CLEAR_HAND: String` = `"clear_hand"               # {}`
- L43 `CMD_GRANT_ACTIONS: String`
- L44 `CMD_GRANT_MERGES: String`
- L45 `CMD_STEP_MAX_HAND: String` = `"step_max_hand"         # { delta: int }`
- L46 `CMD_GRANT_NEXT_BONUS: String` = `"grant_next_bonus"   # { amount: int }`
- L47 `CMD_STEP_DICE: String`
- L48 `CMD_FILL_MOXIE: String`
- L49 `CMD_DRAIN_MOXIE: String`
- L50 `CMD_HEAL_FULL: String`
- L51 `CMD_DAMAGE: String`
- L52 `CMD_TRUE_DAMAGE: String`
- L53 `CMD_ADD_SHIELD: String`
- L54 `CMD_CLEAR_SHIELD: String`
- L55 `CMD_KILL: String`
- L56 `CMD_APPLY_STATUS: String`
- L57 `CMD_CLEAR_STATUSES: String`
- L58 `CMD_REROLL_INTENTS: String` = `"reroll_intents"       # {}`
- L59 `CMD_RESPAWN_WAVE: String` = `"respawn_wave"           # {}`
- L60 `CMD_CLEAR_WAVE: String` = `"clear_wave"               # {}`
- L63 `DAMAGE_STEP: int` = `5` — Amounts the quick action buttons apply.
- L64 `SHIELD_STEP: int` = `10`
- L65 `REGEN_STEP: int` = `2`
- L66 `GLOOM_STEP: int` = `3`
- L69 `PANEL_WIDTH: float` = `336.0` — Where the panel sits: bottom-left, directly above the button that opens it.
- L70 `PANEL_HEIGHT: float` = `404.0`
- L71 `SEAT_LEFT: float` = `18.0`
- L72 `SEAT_BOTTOM: float` = `50.0`
- L73 `PADDING: int` = `10`
- L74 `ROW_SEPARATION: int` = `5`
- L75 `BUTTON_MIN_SIZE: Vector2` = `Vector2(0.0, 26.0)`
- L78 `PANEL_BG: Color` = `Color(0.07, 0.08, 0.11, 0.97)` — Palette lifted from SkillTooltipPopup so the tools read as part of the HUD.
- L79 `PANEL_BORDER: Color` = `Color(0.45, 0.78, 0.95, 0.5)`
- L80 `TITLE_COLOR: Color` = `Color(0.55, 0.86, 1.0)`
- L81 `SECTION_COLOR: Color` = `Color(0.62, 0.72, 0.85)`
- L82 `READOUT_COLOR: Color` = `Color(0.80, 0.85, 0.93)`
- L83 `OVERFLOW_COLOR: Color` = `Color(1.0, 0.55, 0.45)`
- L84 `READY_COLOR: Color` = `Color(0.55, 1.0, 0.68)`
- L85 `LOCKED_COLOR: Color` = `Color(1.0, 0.72, 0.35)`

State:
- L89 `_status_label: Label`
- L90 `_hand_label: Label`
- L91 `_deck_label: Label`
- L92 `_turn_label: Label`
- L93 `_hand_cap_label: Label`
- L94 `_target_selector: OptionButton`
- L95 `_tier_selector: OptionButton`
- L96 `_value_spin: SpinBox`
- L97 `_close_button: Button`
- L99 `_header: HBoxContainer` — Header row: the drag handle for the whole panel.
- L101 `_dragging: bool` = `false` — True while the header is held down and dragging the panel.
- L104 `_gated_buttons: Array[Button]` = `[]` — Buttons that mutate battle state. They stay disabled while the turn loop is not waiting for a player action, because that is the only moment it can accept one.
- L106 `_target_entries: Array[Dictionary]` = `[]` — Payload (scope/slot) of each entry in `_target_selector`, in the same order.
- L108 `_target_labels: PackedStringArray` = `PackedStringArray()` — Labels currently in `_target_selector`, so an unchanged unit list is not rebuilt.

Public API:
- L133 `refresh(snapshot: Dictionary, targets: Array[Dictionary]) -> void` — Pushes live readouts and the unit list down from the scene. Called whenever the state changes (every action, every turn), never by this panel itself. turn/wave/…
- L159 `set_gameplay_enabled(enabled: bool) -> void` — Enables or greys out every state-mutating tool. The scene locks the panel while the game is animating and unlocks it as soon as it waits for a player action.
- L171 `is_open() -> bool`
- L175 `open_menu() -> void`
- L179 `close_menu() -> void`
- L184 `toggle_menu() -> void`

Private:
- L113 `_init`
- L194 `_seat_above_bottom_left`
- L208 `_move_by`
- L222 `_apply_chrome`
- L235 `_build_layout`
- L277 `_build_cards_tab`
- L327 `_build_resources_tab`
- L365 `_build_units_tab`
- L419 `_make_tab`
- L427 `_make_label`
- L436 `_make_section`
- L440 `_make_row`
- L449 `_make_gated_button`
- L461 `_make_button`
- L466 `_make_unit_button`
- L471 `_current_target_args`
- L480 `_rebuild_targets`
- L499 `_snap_int`
- L521 `_on_header_gui_input`
- L531 `_on_close_pressed`
- L535 `_on_action_pressed`
- L541 `_on_unit_action_pressed`
- L550 `_on_spawn_custom_pressed`

Uses: Card, GameManager, GameState, HandBar, SkillTooltipPopup, Unit
Used by: GDTest/DebugMenuTest.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd
Loads: res

### `Scenes/HUD/MoxieOrbUI.gd` — `class_name MoxieOrbUI` extends `Control` · 594 lines

Sections: Helper Methods

Signals:
- L5 `orb_activated(unit: Unit)`
- L6 `orb_hover_started(orb: MoxieOrbUI, unit: Unit)`
- L7 `orb_hover_ended(orb: MoxieOrbUI, unit: Unit)`

Constants:
- L9 `ORB_SCALE: float` = `1.3`
- L11 `MEDALLION_SIZE` = `Vector2(64.0, 64.0) * ORB_SCALE`
- L12 `ORB_RADIUS: float` = `25.5 * ORB_SCALE`
- L13 `INNER_RADIUS: float` = `18.0 * ORB_SCALE`
- L14 `ORB_GLOW_BLEED: float` = `13.0 * ORB_SCALE`
- L15 `SEGMENT_DIVIDERS: int`
- L17 `PORTRAIT_SHADER: Shader` = `preload(`
- L20 `RING_SHADER: Shader` = `preload(`
- L23 `PLACEHOLDER_PORTRAIT: Texture2D` = `preload(`
- L28 `ENEMY_GLOW_CORE` = `Color(0.976, 0.408, 0.0, 1.0)`
- L29 `ENEMY_GLOW_MID` = `Color(0.96, 0.26, 0.18, 1.0)`
- L30 `ENEMY_GLOW_DEEP` = `Color(0.52, 0.05, 0.08, 1.0)`
- L33 `SOCKET_GROOVE_COLOR`
- L34 `ALLY_SOCKET_FLOOR_COLOR`
- L35 `ENEMY_SOCKET_FLOOR_COLOR`
- L38 `ALLY_CRYSTAL_CHARGING_DEEP` = `Color("#0A2463") # Midnight sapphire rim`
- L39 `ALLY_CRYSTAL_CHARGING_MID` = `Color("#1D70E8") # Royal Hextech cobalt`
- L40 `ALLY_CRYSTAL_CHARGING_CORE`
- L42 `ALLY_CRYSTAL_READY_DEEP`
- L43 `ALLY_CRYSTAL_READY_MID` = `Color("#2ED4FF") # Blazing electric cyan`
- L44 `ALLY_CRYSTAL_READY_CORE`
- L47 `ENEMY_CRYSTAL_NORMAL_DEEP` = `Color("#420711") # Dark blood-garnet rim`
- L48 `ENEMY_CRYSTAL_NORMAL_MID` = `Color("#BD1928") # Rich crimson-ruby`
- L49 `ENEMY_CRYSTAL_NORMAL_CORE`
- L51 `ENEMY_CRYSTAL_WARN_DEEP` = `Color("#6E0F14") # Molten ruby rim`
- L52 `ENEMY_CRYSTAL_WARN_MID` = `Color("#FA3D22") # Blazing vermilion`
- L53 `ENEMY_CRYSTAL_WARN_CORE` = `Color("#FFE6B8") # White-hot ember core`
- L56 `ALLY_PREVIEW_DEEP` = `Color("#1F4B85")`
- L57 `ALLY_PREVIEW_COLOR` = `Color("#8EC5F5")`
- L58 `ALLY_PREVIEW_CORE` = `Color("#EEFAFF")`
- L60 `ENEMY_PREVIEW_DEEP` = `Color("#6B222C")`
- L61 `ENEMY_PREVIEW_COLOR` = `Color("#E89BA0")`
- L62 `ENEMY_PREVIEW_CORE` = `Color("#FFF0F2")`
- L65 `ALLY_BEZEL_DEFAULT`
- L66 `ALLY_BEZEL_HOVER`
- L67 `ALLY_BEZEL_READY`
- L68 `ENEMY_BEZEL_DEFAULT`
- L69 `ENEMY_BEZEL_HOVER`
- L70 `ENEMY_BEZEL_WARNING`
- L72 `BEZEL_DEFAULT_ALPHA` = `0.94`
- L75 `ALLY_SPARK_HALO`
- L76 `ALLY_SPARK_MID` = `Color(0.68, 0.95, 1.00)   # cyan body`
- L77 `ALLY_SPARK_CORE`
- L79 `ENEMY_SPARK_HALO`
- L80 `ENEMY_SPARK_MID` = `Color(1.00, 0.68, 0.44)   # orange body`
- L81 `ENEMY_SPARK_CORE`
- L84 `PREVIEW_SPARK_HALO_DARKEN` = `0.18`
- L85 `PREVIEW_SPARK_MID_LIGHTEN` = `0.28`
- L86 `PREVIEW_SPARK_CORE` = `Color(0.97, 0.99, 1.00)`
- L89 `SPARK_HALO_ALPHA` = `0.45`
- L90 `SPARK_MID_ALPHA` = `0.88`
- L91 `SPARK_HALO_RADIUS` = `5.6 * ORB_SCALE`
- L92 `SPARK_MID_RADIUS` = `3.1 * ORB_SCALE`
- L93 `SPARK_CORE_RADIUS` = `1.5 * ORB_SCALE`
- L94 `SPARK_PULSE_BASE` = `0.85`
- L95 `SPARK_PULSE_AMP` = `0.15`
- L96 `SPARK_PULSE_SPEED` = `5.0`

Exports:
- L98 `ready_glow_preset: OutlineGlow.Preset` = `OutlineGlow.Preset.RUNETERRA_BLUE`

State:
- L100 `unit: Unit`
- L101 `badge_code: String` = `"A1"`
- L102 `interactable: bool` = `true`
- L104 `_orb_bounds: Control`
- L105 `_glow: OutlineGlow`
- L106 `_glow_active: bool` = `false`
- L107 `_glow_is_ally: bool` = `true`
- L108 `_has_cached_ally_colors: bool` = `false`
- L109 `_enemy_colors_applied: bool` = `false`
- L110 `_ally_glow_core: Color`
- L111 `_ally_glow_mid: Color`
- L112 `_ally_glow_deep: Color`
- L114 `_portrait_rect: ColorRect`
- L115 `_portrait_mat: ShaderMaterial`
- L116 `_has_portrait: bool` = `false`
- L118 `_ring_rect: ColorRect`
- L119 `_ring_mat: ShaderMaterial`
- L121 `_display_moxie: float` = `0.0`
- L122 `_ready_blend: float` = `0.0`
- L123 `_hover_blend: float` = `0.0`
- L124 `_preview_gain: int` = `0`
- L125 `_is_hovered: bool` = `false`
- L126 `_is_pressed: bool` = `false`
- L127 `_burst_timer: float` = `0.0`
- L128 `_anim_time: float` = `0.0`

Public API:
- L221 `bind_unit(p_unit: Unit, p_badge_code: String, p_portrait: Texture2D = null) -> void`
- L246 `set_portrait(tex: Texture2D = null) -> void`
- L276 `set_preview_gain(amount: int) -> void`
- L285 `set_interactable(enabled: bool) -> void`
- L292 `play_cast_burst() -> void`

Private:
- L131 `_init`
- L143 `_ready`
- L150 `_build_glow_node`
- L158 `_build_portrait_node`
- L172 `_build_ring_node`
- L188 `_notification`
- L205 `_layout_subrects`
- L297 `_on_unit_moxie_changed`
- L311 `_can_click_cast`
- L315 `_should_show_glow`
- L324 `_sync_ring_shader`
- L378 `_sync_glow`
- L415 `_update_cursor`
- L419 `_gui_input`
- L437 `_process`
- L487 `_draw`
- L591 `_tint`

Uses: BattleScene, OutlineGlow, Unit
Used by: GDTest/EnemyUltAuraTest.gd, Scenes/HUD/BattleOverlayController.gd
Loads: res

### `Scenes/HUD/OutlineGlow.gd` — `class_name OutlineGlow` extends `ColorRect` · 233 lines

> outer light border with scrolling sub-surface energy texture.
- L6 `enum Preset` = RUNETERRA_BLUE

Constants:
- L12 `GLOW_SHADER: Shader` = `preload(`
- L15 `GROUP_GLOW_SHADER: Shader` = `preload(`

State:
- L19 `_shared_flow_tex: NoiseTexture2D`
- L20 `_silhouette_mipmap_cache: Dictionary[Variant, Texture2D]` = `{}`
- L22 `glow_bleed: float` = `15.0`
- L23 `frame_corner_radius: float` = `8.0`
- L25 `_mat: ShaderMaterial`
- L26 `_canvas_group: CanvasGroup`
- L27 `_fade_tween: Tween`
- L28 `_active: bool` = `false`

Public API:
- L31 `static attach_to(target_control: Control, p_corner_radius: float = 8.0, p_bleed: float = 15.0) -> OutlineGlow`
- L58 `bind_canvas_group(group: CanvasGroup) -> void`
- L121 `set_active(enabled: bool, preset: Preset = Preset.RUNETERRA_BLUE) -> void`
- L146 `apply_preset(preset: Preset) -> void`
- L162 `set_custom_flow_texture(tex: Texture2D) -> void`
- L221 `set_silhouette(tex: Texture2D) -> void`

Private:
- L44 `_init`
- L73 `_ready`
- L92 `_exit_tree`
- L98 `_apply_group_active_margins`
- L106 `_on_fade_out_finished`
- L116 `_sync_size`
- L167 `_set_intensity`
- L172 `_get_intensity`
- L180 `_ensure_shared_resources`
- L199 `_ensure_mipmapped_silhouette`

Uses: —
Used by: GDTest/CardUITest.gd, GDTest/EnemyUltAuraTest.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/MoxieOrbUI.gd
Loads: res

### `Scenes/HUD/SkillTooltipPopup.gd` — `class_name SkillTooltipPopup` extends `Control` · 272 lines

> Temporary toggle: category icon row in the tooltip header.

Constants:
- L5 `CARD_WIDTH: float` = `310.0`
- L6 `MIN_CARD_HEIGHT: float` = `88.0`
- L7 `ARROW_SIZE: float` = `11.0`
- L8 `PAD_X: int` = `14`
- L9 `PAD_Y: int` = `11`
- L10 `SCREEN_MARGIN: float` = `12.0`
- L12 `SHOW_CATEGORY_ICONS: bool` = `false`

State:
- L14 `icon_catalog: CardIconCatalog`
- L16 `_accent_color: Color` = `Color(0.49, 0.83, 0.99)`
- L17 `_arrow_on_left: bool` = `true`
- L18 `_arrow_local_y: float` = `40.0`
- L19 `_open_tween: Tween`
- L21 `_margin: MarginContainer`
- L22 `_vbox: VBoxContainer`
- L23 `_header_label: Label`
- L24 `_icons_box: HBoxContainer`
- L25 `_subtitle_label: Label`
- L26 `_body_rtl: RichTextLabel`
- L27 `_footer_sep: ColorRect`
- L28 `_footer_rtl: RichTextLabel`

Public API:
- L144 `show_callout(data: Dictionary, anchor_rect: Rect2) -> void`
- L209 `hide_callout() -> void`

Private:
- L31 `_init`
- L39 `_build_ui`
- L124 `_apply_side_margins`
- L135 `_sync_wrap_widths`
- L215 `_rebuild_category_icons`
- L236 `_draw`

Uses: CardIconCatalog
Used by: Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/DebugMenuPopup.gd, Scenes/HUD/TooltipIconCatalog.gd
Loads: res

### `Scenes/HUD/TooltipIconCatalog.gd` — `class_name TooltipIconCatalog` extends `Resource` · 334 lines

> Inline icon registry for tooltip descriptions (SkillTooltipPopup bodies). Two authoring styles are supported, mirroring Legend of Runeterra (icon + colored keyw…

Sections: Constants · Exports · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L23 `DEFAULT_ICON_SIZE: int` = `16` — Inline icon size tuned for the 13px body / 14px bold tooltip font.
- L25 `COLOR_BUFF: Color` = `Color("#6EE7B7")` — Buff (emerald) / debuff (amethyst) keyword highlight defaults.
- L26 `COLOR_DEBUFF: Color` = `Color("#C084FC")`
- L28 `SAMPLE_BUFF_ICON: Texture2D` — Sample art shipped with the project (same textures StatusIcons.tres uses).
- L29 `SAMPLE_DEBUFF_ICON: Texture2D`
- L32 `BBC_TAG_NAMES: PackedStringArray` = `[` — Tags the tooltip actually emits. Anything else inside brackets is treated as plain text, so a stray "[Value]" can never swallow a keyword behind it.
- L38 `TOKEN_PATTERN: String` — Explicit token palette: {icon:id} / {kw:id} / {icon_only:id}.
- L39 `TAG_OPEN: String` = `"img"`
- L40 `TAG_CLOSE: String` = `"[/img]"`

Exports:
- L44 `default_icon_size: int` = `DEFAULT_ICON_SIZE`
- L45 `entries: Array[TooltipIconEntry]` = `[]`
- L49 `fallback_category_catalog: CardIconCatalog` = `null` — Optional bridge: card categories ("damage", "shield", ...) missing from `entries` reuse this catalog's textures as ICON_ONLY glyphs, so art is authored once.
- L52 `fallback_status_catalog: StatusIconCatalog` = `null` — Optional bridge: statuses added to StatusIcons.tres but not here still get a left icon (ICON_AND_KEYWORD) with a buff/debuff default color.

Public API:
- L64 `register_default_entries() -> void` — Adds the sample status rules without overwriting authored entries.
- L71 `find_entry(id_key: String) -> TooltipIconEntry` — Lookup by id, display name or alias, then by the optional fallback catalogs. Returns null when nothing can render the keyword.
- L85 `has_entry(id_key: String) -> bool` — true when `id_key` can be rendered (authored entry or fallback).
- L91 `format_description(text: String, icon_size: int = 0) -> String` — Converts a skill description into tooltip-ready BBCode. `icon_size` <= 0 falls back to `default_icon_size`.

Private:
- L58 `_init`
- L100 `_add_default_entry`
- L115 `_find_authored_entry`
- L123 `_build_status_fallback_entry`
- L144 `_build_category_fallback_entry`
- L160 `_resolve_explicit_tokens`
- L194 `_apply_keyword_links`
- L242 `_link_plain_run`
- L263 `_lookup_index`
- L272 `_build_keyword_index`
- L283 `_build_keyword_pattern`
- L294 `_is_longer_key`
- L298 `_escape_regex`
- L306 `_bbcode_tag_name`
- L328 `_collapse_repeated_spaces`

Uses: BattleScene, Card, CardIconCatalog, SkillTooltipPopup, StatusIconCatalog, TooltipIconEntry, Unit
Used by: GDTest/TooltipIconCatalogTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/TooltipIconEntry.gd, Skills/SkillPreviewFormatter.gd
Loads: res

### `Scenes/HUD/TooltipIconEntry.gd` — `class_name TooltipIconEntry` extends `Resource` · 133 lines

> One tooltip keyword/icon rule, consumed by TooltipIconCatalog. DisplayMode decides how the keyword is drawn inside a RichTextLabel: ICON_AND_KEYWORD -> [icon] K…

Sections: Enums · Exports · Public Methods · Private Methods
- L18 `enum DisplayMode` = ICON_AND_KEYWORD, followed by the colored keyword. ICON_ONLY, the keyword word is dropped. KEYWORD_ONLY

Exports:
- L27 `id: String` = `""` — Canonical id ("gloom", "regeneration", "damage"). Case insensitive.
- L29 `display_name: String` = `""` — Keyword printed next to the icon. Empty = reuse the matched text.
- L31 `icon: Texture2D` = `null` — Texture shown inline. Null (or path-less) textures degrade to colored text.
- L32 `display_mode: DisplayMode` = `DisplayMode.ICON_AND_KEYWORD`
- L33 `use_custom_color: bool` = `true`
- L34 `keyword_color: Color` = `Color("#FBBF24")`
- L35 `bold_keyword: bool` = `false`
- L37 `match_plain_keyword: bool` = `true` — true = also auto-link plain whole-word mentions in prose (no {icon:...} tag).
- L39 `aliases: PackedStringArray` = `PackedStringArray()` — Extra word forms that resolve/link to this entry ("Shields", "glooms").
- L41 `icon_size_override: int` = `0` — 0 = use TooltipIconCatalog.default_icon_size.

Public API:
- L46 `matches_key(key: String) -> bool` — true when `key` (normalized by the caller) names this entry, its label or an alias.
- L61 `get_label() -> String` — Text used for the keyword slot of the rendered BBCode.
- L69 `get_keyword_keys() -> PackedStringArray` — Lowercase words this entry should auto-link in plain prose.
- L85 `build_inline(matched_text: String, icon_size: int = 0) -> String` — Renders `matched_text` using this entry's authored DisplayMode.
- L91 `build_inline_with_mode(matched_text: String, icon_size: int, mode: DisplayMode) -> String` — Renders `matched_text`, overriding the authored DisplayMode. Used by the explicit `{icon:id}` / `{kw:id}` / `{icon_only:id}` tokens.
- L110 `build_icon_tag(icon_size: int = 0) -> String` — `[img=WxH,valign=center]path[/img]`, or "" when no usable texture is set. Matching width/height keeps the 128x128 SVG and the 1000x1000 PNG at the exact same in…

Private:
- L123 `_style_keyword`

Uses: TooltipIconCatalog
Used by: GDTest/TooltipIconCatalogTest.gd, Scenes/HUD/TooltipIconCatalog.gd
Loads: res

### `Skills/EffectBlock.gd` — `class_name EffectBlock` extends `SkillEffect` · 660 lines

> The universal data skill effect component Use configureble resource for all effect scripts Execution pipeline: Phase 1: Resolve Targets Phase 2: Check Condition…

Sections: Shared Enums · Exports · Helpers · Phase 1: Resolve Targets · Phase 2: Check Conditions · Phase 3: Resolve Values · Phase 3: Resolve Values · Phase 4: Execute Action · (+1 more)
- L17 `enum TargetMode` = NONE
- L29 `enum Condition` = NONE
- L35 `enum Action` = DEAL_DAMAGE
- L52 `enum ValueSource` = CARD_VALUE
- L64 `enum CardSelectMode` = PICK_N_CARD
- L71 `enum CardModType` = BUFF

Exports:
- L82 `target_mode: TargetMode` = `TargetMode.NONE`
- L83 `target_count: int` = `1`
- L86 `condition: Condition` = `Condition.NONE`
- L87 `negate_condition: bool` = `false`
- L90 `action_type: Action` = `Action.DEAL_DAMAGE`
- L91 `card_select_mode: CardSelectMode` = `CardSelectMode.PICK_N_CARD`
- L92 `card_mod_type: CardModType` = `CardModType.BUFF`
- L93 `card_count: int` = `1 # For draw_card and auto_top_n`
- L96 `status_id: String`
- L99 `value_source: ValueSource` = `ValueSource.CARD_VALUE`
- L100 `fixed_amount: int` = `0`
- L101 `value_multiplier: int` = `1`
- L102 `value_divisor: int` = `1`
- L103 `value_offset: int` = `0`
- L104 `value_cap: int` = `-1 # -1 = no cap`
- L107 `store_resolved_value: bool` = `false`

Public API:
- L208 `compute_value_from_inputs(card_val: int, stored_val: int, state: GameState, sample_target: Unit = null) -> int`
- L258 `execute(ctx: SkillContext) -> void`
- L597 `get_description() -> String`

Private:
- L113 `_color_unit`
- L117 `_color_value`
- L121 `_color_card`
- L125 `_resolve_targets`
- L187 `_check_condition`
- L252 `_resolve_value`
- L311 `_deal_damage`
- L337 `_gain_shield`
- L358 `_reduce_shield`
- L379 `_heal`
- L401 `_deal_true_damage`
- L425 `_add_bonus`
- L432 `_apply_modifier`
- L447 `_flash_auto_selected`
- L453 `_modify_card`
- L486 `_apply_card_mod`
- L504 `_discard_card`
- L546 `_draw_card`
- L557 `_set_next_skill_bonus`
- L565 `_apply_status`
- L584 `_raise_max_hp`
- L641 `_describe_value`

Uses: Card, GameState, SkillContext, SkillEffect, Unit
Used by: Core/DataLoader.gd, Skills/SkillContext.gd, Skills/SkillEffect.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

### `Skills/SkillContext.gd` — `class_name SkillContext` extends `RefCounted` · 48 lines

> Runtime context passed to every EffectBlock.execute(). Three inter-block communication channels: card_value     – mutable skill value (bonus damage adds here) t…

State:
- L13 `caster: Unit`
- L14 `targets: Array[Unit]` = `[]`
- L16 `card: Card ## Null for enemy skills (they use dices)`
- L17 `is_merged: bool` = `false`
- L18 `game_state: GameState`
- L20 `card_value: int` = `0`
- L21 `stored_value: int` = `0`
- L24 `pick_n_target: Callable` = `Callable()`
- L26 `pick_n_card: Callable` = `Callable()`
- L29 `flash_cards: Callable` = `Callable()`
- L31 `log_message: Callable` = `Callable()`

Public API:
- L45 `log(msg: String) -> void`

Private:
- L33 `_init`

Uses: Card, EffectBlock, GameState, Unit
Used by: GDTest/CardFlashPolicyTest.gd, Managers/GameManager.gd, Skills/EffectBlock.gd, Skills/SkillEffect.gd, Tools/validate_gameData.gd
Loads: —

### `Skills/SkillData.gd` — `class_name SkillData` extends `Resource` · 51 lines

> Defines one skill slot (Skill 1 or Skill 2) on a unit Holds arrays of effects for unmerged and merged resolution
- L9 `enum MergedMode` = AND_MERGED_FIRST, then base effects AND_BASE_FIRST, then merged effects (for "that target" follow-ups) OR

Exports:
- L15 `skill_name: String` = `""`
- L16 `description: String` = `""`
- L17 `merged_description: String` = `""`
- L18 `merged_mode: MergedMode` = `MergedMode.AND_MERGED_FIRST`
- L19 `base_effects: Array[SkillEffect]` = `[]`
- L20 `merged_effects: Array[SkillEffect]` = `[]`
- L24 `condition_threshold: int` = `0` — For enemy skills: merged_effects trigger when dice value >= this. Leave at 0 for ally skills (uses card merge state instead).

State:
- L26 `base_categories: PackedStringArray` = `[]`
- L27 `merged_categories: PackedStringArray` = `[]`

Public API:
- L37 `get_active_categories(is_merged: bool) -> PackedStringArray` — Helper: Returns the active categories based on current merge status. Handles whether 'or' replaces base categories or if 'and' combines them.

Private:
- L31 `_init`

Uses: SkillEffect
Used by: Core/DataLoader.gd, Core/EnemyIntent.gd, Core/UnitData.gd, Data/gameDatabase.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/EnemyUltAuraTest.gd, GDTest/TooltipIconCatalogTest.gd, Managers/GameManager.gd, Scenes/BattleUnit/UnitUI.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

### `Skills/SkillEffect.gd` — `class_name SkillEffect` extends `Resource` · 20 lines

> Abstract base for all skill effect components. Subclasses override execute(). The GameManager always calls: await effect.execute(ctx). Note: This base shouldn't…

Public API:
- L13 `execute(_ctx: SkillContext) -> void`
- L18 `get_description() -> String` — Auto-description for inspectat	ion/debug

Uses: EffectBlock, GameManager, SkillContext
Used by: Managers/GameManager.gd, Skills/EffectBlock.gd, Skills/SkillData.gd, Skills/SkillPreviewFormatter.gd
Loads: —

### `Skills/SkillPreviewFormatter.gd` — `class_name SkillPreviewFormatter` extends `RefCounted` · 330 lines

> Slightly smaller inline icons for the dimmed "Merged" reminder line (font_size=12).

Constants:
- L5 `COL_NUM` = `"#FFD966"`
- L6 `COL_MOXIE` = `"#C77DFF"`
- L7 `COL_ULT` = `"#FF6B6B"`
- L8 `COL_OK` = `"#6EE7B7"`
- L9 `COL_MUTED` = `"#9CA3AF"`
- L11 `MUTED_ICON_SIZE: int` = `14`

Public API:
- L14 `static build_card_on_ally_data(ally: Unit, card: Card, state: GameState, tooltip_catalog: TooltipIconCatalog = null) -> Dictionary` — Returns structured data for the Sketch-2 callout when dragging a Card onto an Ally.
- L79 `static build_enemy_intent_data(intent: EnemyIntent, state: GameState, tooltip_catalog: TooltipIconCatalog = null) -> Dictionary` — Returns structured data when hovering an Enemy's Dice IntentLabel.
- L133 `static build_orb_ultimate_data(unit: Unit, badge_code: String, state: GameState, intent: EnemyIntent = null, tooltip_catalog: TooltipIconCatalog = null) -> Dictionary` — Returns structured data when hovering an Ally or Enemy Moxie/Ultimate Orb (A1-A3 / E1-E3).

Private:
- L195 `_resolve_description_lines`
- L244 `_estimate_post_blocks_value`
- L257 `_substitute_tokens`
- L321 `_pick_sample_target`
- L328 `_num_bb`

Uses: Card, EffectBlock, EnemyIntent, GameState, SkillData, SkillEffect, TooltipIconCatalog, Unit
Used by: GDTest/TooltipIconCatalogTest.gd, Scenes/HUD/BattleOverlayController.gd
Loads: res

### `Tools/check_scripts.gd` extends `SceneTree` · 79 lines

> Headless compile gate: loads every project GDScript outside the excluded folders, so a type error, a stale `class_name` or a bad annotation fails CI instead of…

Sections: Constants · Lifecycle Methods · Private Methods

Constants:
- L16 `EXCLUDED_DIRS: PackedStringArray` = `[` — Folders that are not part of the shipped game code (vendor, scratch, output).
- L22 `ROOT_DIR: String` = `"res://"`
- L23 `ENV_GITHUB_ACTIONS: String` = `"GITHUB_ACTIONS"`

Private:
- L27 `_initialize`
- L49 `_collect_scripts`
- L67 `_is_excluded`
- L74 `_repo_path`

Uses: —
Used by: —
Loads: res

### `Tools/dataBuilder.gd` — `class_name DataBuilder` extends `RefCounted` · 779 lines

> Converts the bulk-entry workbook (res://Data/xlsx/game_data.xlsx) into the JSON files stored in res://Data/json/. Those JSON files are the single source of trut…

Sections: Constants · Public Variables · Public Methods · Private Methods

Constants:
- L25 `DEFAULT_XLSX_PATH: String` = `"res://Data/xlsx/game_data.xlsx"`
- L26 `DEFAULT_JSON_DIR: String` = `"res://Data/json"`
- L27 `JSON_INDENT: String` = `"\t"`
- L28 `HEADER_SCAN_ROWS: int` = `10`
- L29 `DEFAULT_MAX_MOXIE: int` = `20`
- L31 `SKILLS_FILE: String` = `"skills.json"`
- L32 `ALLIES_FILE: String` = `"allies.json"`
- L33 `ENEMIES_FILE: String` = `"enemies.json"`
- L34 `WAVES_FILE: String` = `"waves.json"`
- L35 `CONFIG_FILE: String` = `"config.json"`
- L37 `REQUIRED_SHEETS: PackedStringArray` = `[`
- L40 `VALID_TRIGGERS: PackedStringArray` = `["base", "merged"]`
- L41 `UNIT_SKILL_SLOTS: PackedStringArray` = `["skill_1", "skill_2", "ultimate"]`
- L44 `JSON_FILE_KEYS: Dictionary` = `{` — Emitted JSON file -> key inside the bundle returned by build_json_bundle().
- L54 `SKILL_DEFAULTS: Dictionary` = `{` — Field order and fallback value used when emitting each JSON object. Keeping the order stable keeps hand/AI edits readable.
- L64 `EFFECT_DEFAULTS: Dictionary` = `{`
- L86 `UNIT_DEFAULTS: Dictionary` = `{`

State:
- L99 `errors: PackedStringArray` = `[]` — Blocking problems found while reading the workbook. Export stops when set.
- L101 `warnings: PackedStringArray` = `[]` — Non-blocking notes (duplicate ids, skipped files, ...).

Public API:
- L107 `build_json_bundle(sheets: Dictionary) -> Dictionary` — Builds every JSON payload from already-read worksheet grids.
- L160 `export_xlsx_to_json(xlsx_path: String = DEFAULT_XLSX_PATH, out_dir: String = DEFAULT_JSON_DIR, overwrite_existing: bool = true) -> Error` — Reads the workbook, validates it and writes the five JSON files. fresh checkout bootstraps data without clobbering hand/AI edits

Private:
- L182 `_write_bundle`
- L211 `_empty_bundle`
- L222 `_grid`
- L230 `_read_enums`
- L255 `_find_first_dense_row`
- L268 `_find_header_row`
- L281 `_parse_spec`
- L301 `_row_at`
- L312 `_to_int`
- L332 `_to_bool`
- L352 `_parse_table`
- L405 `_coerce`
- L463 `_has_enum`
- L468 `_enum_contains`
- L480 `_ordered_record`
- L494 `_row_number`
- L497 `_read_skills`
- L513 `_read_effects`
- L551 `_attach_effects`
- L578 `_read_units`
- L604 `_read_waves`
- L644 `_read_config`
- L692 `_parse_config_value`
- L713 `_scalar`
- L730 `_format_json_value`
- L740 `_format_json_object`
- L752 `_format_json_array`
- L769 `_is_inline_array`

Uses: DataLoader, XlsxReader
Used by: Tools/export_xlsx_to_json.gd, Tools/validate_gameData.gd, Tools/xlsx_reader.gd
Loads: res

### `Tools/diagnose_spine_atlas.gd` extends `SceneTree` · 49 lines

Constants:
- L3 `ROOT`
- L4 `PNG_PATH` = `ROOT + "/300101_zhujue.png"`
- L5 `ATLAS_PATH` = `ROOT + "/300101_zhujue.atlas"`

Private:
- L7 `_initialize`

Uses: —
Used by: —
Loads: res

### `Tools/export_xlsx_to_json.gd` extends `SceneTree` · 34 lines

> Headless Excel -> JSON exporter for the game data pipeline. Usage: godot --headless --path . --script res://Tools/export_xlsx_to_json.gd The workbook (res://Dat…

Sections: Constants · Lifecycle Methods

Constants:
- L12 `DATA_BUILDER_PATH: String` = `"res://Tools/dataBuilder.gd"`

Private:
- L16 `_initialize`

Uses: DataBuilder
Used by: —
Loads: res

### `Tools/gen_code_index.gd` extends `SceneTree` · 1164 lines

> Headless symbol-index generator for this repository. Parses every first-party GDScript source and writes two artifacts that make the codebase navigable without…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L30 `SCHEMA_VERSION: int` = `1` — Bump when the shape of Docs/code_index.json changes.
- L31 `ROOT_DIR: String` = `"res://"`
- L32 `DOCS_DIR: String` = `"res://Docs"`
- L33 `INDEX_PATH: String` = `"res://Docs/code_index.json"`
- L34 `MAP_PATH: String` = `"res://Docs/CODEBASE_MAP.md"`
- L35 `EVENT_BUS_PATH: String` = `"res://Managers/EventBus.gd"`
- L36 `DATA_JSON_DIR: String` = `"res://Data/json"`
- L37 `GENERATOR_PATH: String` = `"res://Tools/gen_code_index.gd"`
- L38 `GENERATE_COMMAND: String`
- L39 `ARG_CHECK: String` = `"--check"`
- L40 `ENV_GITHUB_ACTIONS: String` = `"GITHUB_ACTIONS"`
- L43 `EXCLUDED_DIRS: PackedStringArray` = `[` — Folders that hold no first-party game code (vendor, scratch, generated output).
- L52 `MAX_ITEM_KEYS: int` = `24` — Caps that keep the generated map cheap to read.
- L53 `MAX_REGIONS_LISTED: int` = `8`
- L54 `MAX_DOC_CHARS: int` = `160`
- L55 `MAX_REFS_LISTED: int` = `20`
- L56 `HEADER_SCAN_LINES: int` = `40`
- L57 `KEY_COLLECT_DEPTH: int` = `3`

State:
- L61 `_script_paths: PackedStringArray` = `PackedStringArray()`
- L62 `_scene_paths: PackedStringArray` = `PackedStringArray()`
- L63 `_infos: Array[Dictionary]` = `[]`
- L64 `_texts: Dictionary` = `{}`
- L65 `_class_names: PackedStringArray` = `PackedStringArray()`
- L66 `_check_only: bool` = `false`

Private:
- L70 `_initialize`
- L98 `_collect`
- L120 `_is_excluded`
- L127 `_normalized_text`
- L132 `_repo_path`
- L138 `_write_text`
- L148 `_matches_artifact`
- L154 `_report_staleness`
- L172 `_write_artifacts`
- L193 `_parse_script`
- L338 `_header_end_index`
- L353 `_header_summary`
- L365 `_doc_text`
- L370 `_join_doc`
- L383 `_leading_identifier`
- L391 `_is_identifier_char`
- L402 `_extract_between`
- L415 `_attribute`
- L419 `_parse_signal`
- L435 `_parse_function`
- L465 `_parse_named_declaration`
- L493 `_parse_enum`
- L518 `_enum_values`
- L534 `_signature_complete`
- L548 `_is_resource_path_char`
- L553 `_contains_word`
- L570 `_find_info`
- L580 `_apply_dependencies`
- L595 `_scan_resource_refs`
- L613 `_build_symbol_table`
- L627 `_add_symbol_list`
- L635 `_add_symbol`
- L649 `_build_used_by`
- L664 `_dict_string`
- L672 `_dict_int`
- L683 `_dict_array`
- L691 `_dict_string_array`
- L706 `_cell`
- L710 `_join_paths`
- L716 `_compact_regions`
- L725 `_collect_global_signals`
- L758 `_collect_scenes`
- L802 `_collect_data_files`
- L836 `_collect_keys`
- L853 `_keys_of`
- L860 `_finalize_keys`
- L873 `_render_index`
- L892 `_render_map`
- L935 `_append_overview`
- L954 `_append_details`
- L962 `_append_script_detail`
- L1010 `_append_declarations`
- L1029 `_declaration_text`
- L1053 `_append_functions`
- L1092 `_dict_bool`
- L1101 `_append_signals`
- L1120 `_append_scenes`
- L1140 `_append_data`

Uses: Unit, UnitUI
Used by: —
Loads: res

### `Tools/validate_gameData.gd` extends `Node` · 1263 lines

> Headless, offline validator for the whole game-data pipeline. res://Data/json/ is the single source of truth the game reads at runtime, while res://Data/xlsx/ga…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L25 `JSON_DIR: String` = `"res://Data/json"`
- L26 `SKILLS_PATH: String` = `JSON_DIR + "/skills.json"`
- L27 `ALLIES_PATH: String` = `JSON_DIR + "/allies.json"`
- L28 `ENEMIES_PATH: String` = `JSON_DIR + "/enemies.json"`
- L29 `WAVES_PATH: String` = `JSON_DIR + "/waves.json"`
- L30 `CONFIG_PATH: String` = `JSON_DIR + "/config.json"`
- L32 `WORKBOOK_PATH: String` = `"res://Data/xlsx/game_data.xlsx"`
- L33 `DATA_BUILDER_PATH: String` = `"res://Tools/dataBuilder.gd"`
- L35 `ARG_JSON_ONLY: String` = `"--json-only"`
- L36 `ARG_STRICT: String` = `"--strict"`
- L37 `ARG_SUMMARY: String` = `"--summary"`
- L38 `ARG_HELP: String` = `"--help"`
- L41 `ENV_GITHUB_ACTIONS: String` = `"GITHUB_ACTIONS"` — GitHub Actions environment variables used for CI reporting.
- L42 `ENV_STEP_SUMMARY: String` = `"GITHUB_STEP_SUMMARY"`
- L46 `REQUIRED_EFFECT_KEYS: PackedStringArray` — Keys a typo would silently change: Core/DataLoader.gd falls back to a default for any missing key, so these four must always be present on an effect.
- L48 `UNIT_SKILL_SLOTS: PackedStringArray` = `["skill_1", "skill_2", "ultimate"]`
- L49 `WAVE_KEYS: PackedStringArray` = `["wave_index", "enemies"]`
- L50 `WAVE_ENEMY_KEYS: PackedStringArray`
- L53 `TARGETED_ACTIONS: PackedStringArray` = `[` — Actions that must resolve at least one unit target.
- L58 `VALUE_ACTIONS: PackedStringArray` = `[` — Actions that resolve a numeric amount (so a fixed_amount of 0 does nothing).
- L63 `CARD_ACTIONS: PackedStringArray` — Actions that consume card_count / card_select_mode / card_mod_type.
- L65 `N_TARGET_MODES: PackedStringArray` — Target modes that select N units and therefore need target_count >= 1.
- L67 `TARGET_CACHING_MODES: PackedStringArray` = `[` — Target modes that fill SkillContext.targets for later "cached" effects.
- L72 `CARD_CATEGORIES: PackedStringArray` — Card categories the UI has art for (see CardIconCatalog).
- L75 `SANITY_MAX_TARGET_COUNT: int` = `10` — Obvious-typo guards.
- L76 `SANITY_MAX_CARD_VALUE: int` = `99`
- L77 `SANITY_MAX_DICE_SIDES: int` = `100`
- L78 `SANITY_MIN_HP: int` = `1`

State:
- L82 `_errors: PackedStringArray` = `PackedStringArray()`
- L83 `_warnings: PackedStringArray` = `PackedStringArray()`
- L84 `_skip_workbook: bool` = `false`
- L85 `_strict: bool` = `false`
- L88 `_actions: PackedStringArray` = `PackedStringArray()` — Enum allowlists, sourced from the runtime so the two can never drift apart.
- L89 `_target_modes: PackedStringArray` = `PackedStringArray()`
- L90 `_value_sources: PackedStringArray` = `PackedStringArray()`
- L91 `_conditions: PackedStringArray` = `PackedStringArray()`
- L92 `_card_select_modes: PackedStringArray` = `PackedStringArray()`
- L93 `_card_mod_types: PackedStringArray` = `PackedStringArray()`
- L94 `_merged_modes: PackedStringArray` = `PackedStringArray()`
- L95 `_status_ids: PackedStringArray` = `PackedStringArray()`
- L96 `_wave_modes: PackedStringArray` = `PackedStringArray()`
- L99 `_effect_keys: PackedStringArray` = `PackedStringArray()` — Canonical key sets, sourced from the workbook exporter so unknowns are typos.
- L100 `_skill_keys: PackedStringArray` = `PackedStringArray()`
- L101 `_unit_keys: PackedStringArray` = `PackedStringArray()`
- L104 `_skill_ids: Dictionary` = `{}` — Cross-file registries filled while validating.
- L105 `_ally_ids: Dictionary` = `{}`
- L106 `_enemy_ids: Dictionary` = `{}`
- L107 `_used_skill_ids: Dictionary` = `{}`
- L108 `_enemy_skill_ids: Dictionary` = `{}`
- L109 `_ally_skill_ids: Dictionary` = `{}`
- L110 `_skill_meta: Dictionary` = `{}`
- L112 `_id_pattern: RegEx` = `null`
- L115 `_raw_text: Dictionary` = `{}` — Raw JSON text per res:// path, so diagnostics can be located in the source.
- L117 `_skills_json: Dictionary` = `{}` — Raw parsed JSON, kept so the loaded database can be cross-checked against it.
- L118 `_allies_json: Dictionary` = `{}`
- L119 `_enemies_json: Dictionary` = `{}`
- L120 `_waves_json: Dictionary` = `{}`
- L121 `_config_json: Dictionary` = `{}`
- L123 `_summary_path: String` = `""`
- L124 `_help_requested: bool` = `false`

Private:
- L128 `_ready`
- L147 `_parse_arguments`
- L168 `_report`
- L194 `_fail`
- L199 `_warn`
- L204 `_keys_of`
- L211 `_as_dictionary`
- L218 `_as_array`
- L225 `_dict_int`
- L236 `_dict_bool`
- L244 `_type_name`
- L262 `_is_snake_case_id`
- L270 `_collect_allowlists`
- L285 `_warn_unknown_keys`
- L296 `_int_value`
- L319 `_int_field`
- L329 `_string_field`
- L342 `_bool_field`
- L355 `_enum_field`
- L370 `_array_field`
- L383 `_require_effect_keys`
- L392 `_validate_workbook`
- L426 `_bundle_count`
- L432 `_validate_runtime_json`
- L450 `_read_json_object`
- L474 `_validate_skills`
- L493 `_validate_skill`
- L539 `_validate_categories`
- L560 `_validate_effects`
- L608 `_validate_effect`
- L700 `_validate_units`
- L763 `_validate_unit_collisions`
- L770 `_validate_skill_usage`
- L784 `_validate_waves`
- L815 `_validate_wave_enemy`
- L842 `_validate_config`
- L868 `_validate_decklist`
- L903 `_validate_dice_progression`
- L925 `_validate_config_allies`
- L958 `_check_loader_integration`
- L985 `_print_usage`
- L1002 `_emit_annotations`
- L1011 `_emit_annotation`
- L1024 `_diagnostic_file`
- L1040 `_repo_path`
- L1047 `_diagnostic_line`
- L1072 `_waves_line`
- L1085 `_config_line`
- L1099 `_line_of`
- L1116 `_first_quoted`
- L1127 `_bracket_index`
- L1143 `_write_step_summary`
- L1184 `_validate_loader_consistency`
- L1215 `_validate_loaded_units`
- L1244 `_database_fingerprint`

Uses: Card, CardIconCatalog, DataBuilder, DataLoader, EffectBlock, EnemyIntent, GameDatabase, GameManager, GameState, SkillContext, SkillData, Unit, UnitData, XlsxReader
Used by: —
Loads: res

### `Tools/xlsx_reader.gd` — `class_name XlsxReader` extends `RefCounted` · 181 lines

> Reads an .xlsx workbook (a zip of XML parts) into { sheet_name: Array[Array[String]] }. Every cell is returned as a String; DataBuilder performs the typed conve…

Sections: Constants · Public Methods · Private Methods

Constants:
- L14 `WORKBOOK_PATH: String` = `"xl/workbook.xml"`
- L15 `WORKBOOK_RELS_PATH: String` = `"xl/_rels/workbook.xml.rels"`
- L16 `SHARED_STRINGS_PATH: String` = `"xl/sharedStrings.xml"`
- L18 `LETTER_OFFSET: int` = `64` — ASCII code of 'A' minus one, so "A" resolves to column 1.
- L19 `ALPHABET_SIZE: int` = `26`

Public API:
- L27 `static read_sheets(path: String) -> Dictionary` — Reads every worksheet in the workbook. Array of Strings ordered from column A onwards

Private:
- L54 `_read_workbook_sheets`
- L72 `_read_workbook_rels`
- L88 `_read_shared_strings`
- L113 `_parse_sheet`
- L160 `_column_from_reference`
- L172 `_commit_row`

Uses: DataBuilder
Used by: Tools/dataBuilder.gd, Tools/validate_gameData.gd
Loads: res

## 3. Global signals (Managers/EventBus.gd)

| signal | args | emitted by | listened by |
| --- | --- | --- | --- |
| `turn_started` | turn_number: int | Managers/GameManager.gd | Scenes/HUD/BattleOverlayController.gd |
| `wave_started` | wave_index: int | Managers/GameManager.gd | Scenes/HUD/BattleOverlayController.gd |
| `game_over` | victory: bool | Managers/GameManager.gd | — |
| `card_played` | card: Card, ally: Unit | Managers/GameManager.gd | Scenes/Cards/HandBar.gd |
| `card_drawn` | card: Card | Skills/EffectBlock.gd | Scenes/Cards/HandBar.gd |
| `card_discarded` | card: Card | Skills/EffectBlock.gd | Scenes/Cards/HandBar.gd |
| `card_value_changed` | card: Card, old_value: int, new_value: int | GDTest/CardUITest.gd, Managers/GameManager.gd, Skills/EffectBlock.gd | GDTest/DebugMenuTest.gd, Scenes/Cards/CardUI.gd |
| `damage_dealt` | source: Unit, target: Unit, amount: int, hp_lost: int | Managers/GameManager.gd, Skills/EffectBlock.gd | — |
| `shield_gained` | target: Unit, amount: int | Managers/GameManager.gd, Skills/EffectBlock.gd | — |
| `shield_reduced` | target: Unit, amount: int | Managers/GameManager.gd, Skills/EffectBlock.gd | — |
| `unit_healed` | target: Unit, amount: int | Managers/GameManager.gd, Skills/EffectBlock.gd | — |
| `unit_died` | target: Unit | Managers/GameManager.gd, Skills/EffectBlock.gd | — |
| `skill_resolved` | caster: Unit, skill_name: String | Managers/GameManager.gd | — |
| `moxie_changed` | unit: Unit, current: int, maximum: int | Managers/GameManager.gd | — |
| `ultimate_cast` | caster: Unit, skill_name: String | Managers/GameManager.gd | Scenes/HUD/BattleOverlayController.gd |
| `unit_statuses_changed` | unit: Unit | Managers/GameManager.gd, Skills/EffectBlock.gd | — |

## 4. Scenes (4)

| scene | root | nodes | script |
| --- | --- | --- | --- |
| `Scenes/BattleScene/BattleScene.tscn` | Main `Node` | 41 | `Scenes/BattleScene/BattleScene.gd` |
| `Scenes/BattleUnit/UnitUI.tscn` | UnitUI `PanelContainer` | 19 | `Scenes/BattleUnit/UnitUI.gd` |
| `Scenes/Cards/CardUI.tscn` | CardUI `PanelContainer` | 9 | `Scenes/Cards/CardUI.gd` |
| `Tools/validator.tscn` | Validator `Node` | 1 | `Tools/validate_gameData.gd` |

## 5. Game data (Data/json)

| file | shape | entries | per-entry keys |
| --- | --- | --- | --- |
| `Data/json/allies.json` | object | 3 | display_name, is_enemy, max_hp, max_moxie, skill_1, skill_2, ultimate |
| `Data/json/config.json` | object | 7 | — |
| `Data/json/enemies.json` | object | 2 | display_name, is_enemy, max_hp, max_moxie, skill_1, skill_2, ultimate |
| `Data/json/skills.json` | object | 15 | action, base_categories, card_count, card_mod_type, card_select_mode, condition, condition_threshold, description, display_name, effect_id, effects, fixed_amount, merged_categories, merged_description, merged_mode, negate_condition, order, status_id, store_resolved_value, target_count, target_mode, trigger, value_cap, value_divisor, (+3 more) |
| `Data/json/waves.json` | object | 1 | display_name_override, enemies, max_hp_override, unit_id, wave_index |

Top-level keys:
- `Data/json/allies.json`: buff, healer, striker
- `Data/json/config.json`: actions_per_turn, allies, decklist, dice_progression, hand_size, merges_per_turn, wave_transition_mode
- `Data/json/enemies.json`: boss_enemy, normal_enemy
- `Data/json/skills.json`: boss_enemy_1, boss_enemy_2, boss_enemy_ult, buff_1, buff_2, buff_ult, healer_1, healer_2, healer_ult, normal_enemy_1, normal_enemy_2, normal_enemy_ult, striker_1, striker_2, striker_ult
- `Data/json/waves.json`: waves

---

Indexed 51 script(s), 4 scene(s), 5 data file(s); 1490 indexed symbol(s).
