# Codebase Map — Hololive: The Prophecy

<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd from the first-party sources. -->

Refresh after changing any first-party script, scene or data file:

```powershell
godot --headless --path . --script res://Tools/gen_code_index.gd
```

Staleness and correctness gate (run by Tools/preflight.ps1 and CI; it also checks coverage, ranges, links, scenes, signals and data, and prints the read-cost benchmark):

```powershell
godot --headless --path . --script res://Tools/check_navigation.gd
```

## How to use this map (overview here, details in their own page)

- **Overview:** section 1 lists every game script, section 2 every test, each with `class_name`, size and role.
- **One script's API with line numbers:** open its page under `Docs/map/` (linked from sections 1 and 2).
- **One scene's node tree:** open `Docs/map/<scene>.scene.md` (linked from section 4).
- **Find a symbol:** `rg -n '^get_effective_value\t' Docs/symbols.tsv` returns `path:start-end`; drop the `^name\t` anchor to search loosely.
- **Impact of a change:** the `Uses` / `Used by` lines on a script's page, and the emit/listen table in section 3.
- **Balancing:** section 5 lists each JSON file's shape, entry count and keys, so the file rarely has to be opened.
- **Measure it:** `godot --headless --path . --script res://Tools/check_navigation.gd -- --benchmark` prints what each recipe costs to read.

## 1. Game scripts at a glance (43)

| Script | class_name | lines | role |
| --- | --- | --- | --- |
| [`Core/Card.gd`](map/Core/Card.md) | `Card` | 115 | This class contains the data for the card Card instance is created/destroyed during merging. Rule: Merge consumes two cards and produces one. Total count is shr… |
| [`Core/DataLoader.gd`](map/Core/DataLoader.md) | `DataLoader` | 515 | Runtime loader for the game data JSON files in res://Data/json/. Those JSON files are the single source of truth; the workbook (res://Data/xlsx/game_data.xlsx)… |
| [`Core/DiceRoller.gd`](map/Core/DiceRoller.md) | `DiceRoller` | 23 | Static utility for dice rolls. Separated for easy mocking/seeding in tests. |
| [`Core/EnemyIntent.gd`](map/Core/EnemyIntent.md) | `EnemyIntent` | 38 | Pre-rolled intent for one enemy this turn. Created at step 1 of the turn loop, resolved at step 7. |
| [`Core/GameState.gd`](map/Core/GameState.md) | `GameState` | 481 | Pure game state. No nodes, no signals, no rendering. All mutation happens through methods that return result The presentation layer can react to. |
| [`Core/GameUI.gd`](map/Core/GameUI.md) | `GameUI` | 100 | Abstract UI interface the GameManager talks to. Implemented by the graphical BattleScene; GameManager only talks to this interface. Every input methods are asyn… |
| [`Core/Unit.gd`](map/Core/Unit.md) | `Unit` | 373 | Runtime instance of a unit on the board. Mutable HP/Shield state. This is all just data |
| [`Core/UnitData.gd`](map/Core/UnitData.md) | `UnitData` | 16 | Template definition for a unit type. |
| [`Data/gameDatabase.gd`](map/Data/gameDatabase.md) | `GameDatabase` | 27 | Skill definitions keyed by skill_id (effects embedded). |
| [`Managers/ColorUtils.gd`](map/Managers/ColorUtils.md) | — | 17 | Color definitions for BBCode |
| [`Managers/EventBus.gd`](map/Managers/EventBus.md) | — | 43 | This is used as a global signal bus. Add as an Autoload. Used for UI logging and passive hooks, not game logic. depend on these signals — they are fire-and-forg… |
| [`Managers/GameManager.gd`](map/Managers/GameManager.md) | `GameManager` | 1057 | Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext. |
| [`Scenes/BattleScene/BattleScene.gd`](map/Scenes/BattleScene/BattleScene.md) | `BattleScene` | 502 | extends GameUI, 2 signal(s), 6 export(s), 37 function(s) |
| [`Scenes/BattleUnit/SpinePortrait.gd`](map/Scenes/BattleUnit/SpinePortrait.md) | `SpinePortrait` | 632 | extends Control, 3 signal(s), 28 export(s), 36 function(s) |
| [`Scenes/BattleUnit/StatusIconCatalog.gd`](map/Scenes/BattleUnit/StatusIconCatalog.md) | `StatusIconCatalog` | 331 | Catalog for character buff/debuff status icons (separate from CardIconCatalog). Provides lookup and automatic inspection of Unit buff/debuff state. Two dictiona… |
| [`Scenes/BattleUnit/UnitUI.gd`](map/Scenes/BattleUnit/UnitUI.md) | `UnitUI` | 1341 | extends PanelContainer, 6 signal(s), 12 export(s), 58 function(s) |
| [`Scenes/Cards/CardDrag.gd`](map/Scenes/Cards/CardDrag.md) | `CardDrag` | 13 | Payload for all card drag operations. Consumed by: CardUI (merge), UnitDropZone (skill activation). |
| [`Scenes/Cards/CardIconCatalog.gd`](map/Scenes/Cards/CardIconCatalog.md) | `CardIconCatalog` | 15 | Central skill-type icon registry for cards / skill previews. One instance, set as project autoload or exported on UI roots. No res://Trash paths live in class c… |
| [`Scenes/Cards/CardUI.gd`](map/Scenes/Cards/CardUI.md) | `CardUI` | 1381 | Visual representation of one Card in hand. Drag source (play / merge) and drop target (merge only). The card is rendered into an offscreen SubViewport and that… |
| [`Scenes/Cards/ForgePlate.gd`](map/Scenes/Cards/ForgePlate.md) | `ForgePlate` | 140 | One of the two cards in a merge, drawn as a real fake-3D quad. A merge has to show two cards banking and folding into each other, so a flat copy of a card face… |
| [`Scenes/Cards/HandBar.gd`](map/Scenes/Cards/HandBar.md) | `HandBar` | 430 | Bottom-edge hand of cards. View-only: it animates, GameManager validates. |
| [`Scenes/HUD/BattleOverlayController.gd`](map/Scenes/HUD/BattleOverlayController.md) | `BattleOverlayController` | 494 | Builds E1–E3 on the left, A1–A3 on the right, manages the tooltip layer, and safely bridges UnitUI hover & wave transitions without freed-instance errors. |
| [`Scenes/HUD/DebugMenuPopup.gd`](map/Scenes/HUD/DebugMenuPopup.md) | `DebugMenuPopup` | 563 | Tester-only tool palette for the battle scene. Every button here is a *request*: it emits `debug_command_requested` upward and the turn loop performs the mutati… |
| [`Scenes/HUD/HudTooltip.gd`](map/Scenes/HUD/HudTooltip.md) | `HudTooltip` | 91 | Content of the hover tooltip for one top-bar widget. Every icon in the top bar is the same placeholder logo, so the icon alone cannot say what the number beside… |
| [`Scenes/HUD/MoxieOrbUI.gd`](map/Scenes/HUD/MoxieOrbUI.md) | `MoxieOrbUI` | 594 | extends Control, 3 signal(s), 1 export(s), 22 function(s) |
| [`Scenes/HUD/OutlineGlow.gd`](map/Scenes/HUD/OutlineGlow.md) | `OutlineGlow` | 233 | outer light border with scrolling sub-surface energy texture. |
| [`Scenes/HUD/SkillTooltipPopup.gd`](map/Scenes/HUD/SkillTooltipPopup.md) | `SkillTooltipPopup` | 272 | extends Control, 8 function(s) |
| [`Scenes/HUD/TooltipIconCatalog.gd`](map/Scenes/HUD/TooltipIconCatalog.md) | `TooltipIconCatalog` | 334 | Inline icon registry for tooltip descriptions (SkillTooltipPopup bodies). Two authoring styles are supported, mirroring Legend of Runeterra (icon + colored keyw… |
| [`Scenes/HUD/TooltipIconEntry.gd`](map/Scenes/HUD/TooltipIconEntry.md) | `TooltipIconEntry` | 133 | One tooltip keyword/icon rule, consumed by TooltipIconCatalog. DisplayMode decides how the keyword is drawn inside a RichTextLabel: ICON_AND_KEYWORD -> [icon] K… |
| [`Skills/EffectBlock.gd`](map/Skills/EffectBlock.md) | `EffectBlock` | 660 | The universal data skill effect component Use configureble resource for all effect scripts Execution pipeline: Phase 1: Resolve Targets Phase 2: Check Condition… |
| [`Skills/SkillContext.gd`](map/Skills/SkillContext.md) | `SkillContext` | 48 | Runtime context passed to every EffectBlock.execute(). Three inter-block communication channels: card_value     – mutable skill value (bonus damage adds here) t… |
| [`Skills/SkillData.gd`](map/Skills/SkillData.md) | `SkillData` | 51 | Defines one skill slot (Skill 1 or Skill 2) on a unit Holds arrays of effects for unmerged and merged resolution |
| [`Skills/SkillEffect.gd`](map/Skills/SkillEffect.md) | `SkillEffect` | 20 | Abstract base for all skill effect components. Subclasses override execute(). The GameManager always calls: await effect.execute(ctx). Note: This base shouldn't… |
| [`Skills/SkillPreviewFormatter.gd`](map/Skills/SkillPreviewFormatter.md) | `SkillPreviewFormatter` | 330 | extends RefCounted, 8 function(s) |
| [`Tools/CodeIndexParser.gd`](map/Tools/CodeIndexParser.md) | `CodeIndexParser` | 746 | Pure parsing layer behind Tools/gen_code_index.gd. Every function here takes text in and returns plain Dictionaries: no file system access, no rendering, no CLI… |
| [`Tools/check_navigation.gd`](map/Tools/check_navigation.md) | — | 763 | Test harness for the generated navigation set in Docs/. Two jobs: 1. Verify the committed artifacts against the sources with independent scans (coverage, ranges… |
| [`Tools/check_scripts.gd`](map/Tools/check_scripts.md) | — | 79 | Headless compile gate: loads every project GDScript outside the excluded folders, so a type error, a stale `class_name` or a bad annotation fails CI instead of… |
| [`Tools/check_spine_runtime.gd`](map/Tools/check_spine_runtime.md) | — | 142 | Headless link and compatibility gate for the spine-godot GDExtension. Proves three things: 1. the runtime in `bin/` loaded and exposes the Spine classes the gam… |
| [`Tools/dataBuilder.gd`](map/Tools/dataBuilder.md) | `DataBuilder` | 779 | Converts the bulk-entry workbook (res://Data/xlsx/game_data.xlsx) into the JSON files stored in res://Data/json/. Those JSON files are the single source of trut… |
| [`Tools/export_xlsx_to_json.gd`](map/Tools/export_xlsx_to_json.md) | — | 34 | Headless Excel -> JSON exporter for the game data pipeline. Usage: godot --headless --path . --script res://Tools/export_xlsx_to_json.gd The workbook (res://Dat… |
| [`Tools/gen_code_index.gd`](map/Tools/gen_code_index.md) | — | 809 | Headless symbol-index generator for this repository. Parses every first-party GDScript source and writes the navigation set that replaces reading the sources: D… |
| [`Tools/validate_gameData.gd`](map/Tools/validate_gameData.md) | — | 1263 | Headless, offline validator for the whole game-data pipeline. res://Data/json/ is the single source of truth the game reads at runtime, while res://Data/xlsx/ga… |
| [`Tools/xlsx_reader.gd`](map/Tools/xlsx_reader.md) | `XlsxReader` | 181 | Reads an .xlsx workbook (a zip of XML parts) into { sheet_name: Array[Array[String]] }. Every cell is returned as a String; DataBuilder performs the typed conve… |

## 2. Tests at a glance (13)

| Script | class_name | lines | role |
| --- | --- | --- | --- |
| [`GDTest/CardDrawAnimationTest.gd`](map/GDTest/CardDrawAnimationTest.md) | `CardDrawAnimationTest` | 303 | Locks in the fake-3D card draw: - every CardUI owns its own warp material, so tilting one card can never tilt the rest of the hand - a dealt card leaves the dec… |
| [`GDTest/CardFlashPolicyTest.gd`](map/GDTest/CardFlashPolicyTest.md) | `CardFlashPolicyTest` | 109 | Locks in *who caused it* when the game reveals hand cards it picked on its own: - an enemy acting on the player's hand flashes hostile (crimson) - the player's… |
| [`GDTest/CardMergeAnimationTest.gd`](map/GDTest/CardMergeAnimationTest.md) | `CardMergeAnimationTest` | 564 | Locks in the merge: the card the player was carrying is picked up from the exact point they released it, the two cards drift into each other and fold closed int… |
| [`GDTest/CardTest.gd`](map/GDTest/CardTest.md) | `CardTest` | 31 | This is the GDUnit test for Card class |
| [`GDTest/CardUITest.gd`](map/GDTest/CardUITest.md) | `CardUITest` | 99 | Tests for CardUI's runtime card feedback: the delayed value-label refresh after a skill buff/debuff and the hostile (enemy-caused) red glow preset. |
| [`GDTest/CodeIndexTest.gd`](map/GDTest/CodeIndexTest.md) | `CodeIndexTest` | 292 | Fixture tests for Tools/CodeIndexParser.gd, the pure parsing layer behind the generated navigation set (Docs/). Each fixture is an inline script so the test nev… |
| [`GDTest/DebugMenuTest.gd`](map/GDTest/DebugMenuTest.md) | `DebugMenuTest` | 742 | Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager): - the panel is view-only: it reports readouts, gates its tools while the turn loop… |
| [`GDTest/EnemyTurnOverlapTest.gd`](map/GDTest/EnemyTurnOverlapTest.md) | `EnemyTurnOverlapTest` | 232 | Locks the enemy-turn overlap ("fast mode" pacing): - consecutive enemies hand control to the next one at the impact beat of their skill animation, so wind-downs… |
| [`GDTest/EnemyUltAuraTest.gd`](map/GDTest/EnemyUltAuraTest.md) | `EnemyUltAuraTest` | 139 | Locks in the enemy Ultimate warning lifecycle. The crimson character aura and the Moxie orb preview both describe one *pending* roll, so neither may outlive the… |
| [`GDTest/GameStateMergeTest.gd`](map/GDTest/GameStateMergeTest.md) | `GameStateMergeTest` | 89 | Locks in where a merged card lands in hand: it takes the slot of the card the player merged *into*, so a merge never teleports the result to the far right. |
| [`GDTest/HudTooltipTest.gd`](map/GDTest/HudTooltipTest.md) | `HudTooltipTest` | 286 | Locks the top-bar hover tooltips (HudTooltip) and the slab they are drawn on (the tooltip theme in HudTooltipTheme.tres). Every icon in the bar is the same plac… |
| [`GDTest/StatusCatalogTest.gd`](map/GDTest/StatusCatalogTest.md) | `StatusCatalogTest` | 91 | Tests for the buff/debuff status system: Unit.statuses + StatusIconCatalog. |
| [`GDTest/TooltipIconCatalogTest.gd`](map/GDTest/TooltipIconCatalogTest.md) | `TooltipIconCatalogTest` | 171 | Tests for the inline tooltip icon system (TooltipIconCatalog + TooltipIconEntry). Covers: left-of-keyword icons (LoR style), pure glyphs (Riftbound style), expl… |

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

Node trees live on each scene's page.

| scene | root | nodes | script |
| --- | --- | --- | --- |
| [`Scenes/BattleScene/BattleScene.tscn`](map/Scenes/BattleScene/BattleScene.scene.md) | Main `Node` | 46 | `Scenes/BattleScene/BattleScene.gd` |
| [`Scenes/BattleUnit/UnitUI.tscn`](map/Scenes/BattleUnit/UnitUI.scene.md) | UnitUI `PanelContainer` | 19 | `Scenes/BattleUnit/UnitUI.gd` |
| [`Scenes/Cards/CardUI.tscn`](map/Scenes/Cards/CardUI.scene.md) | CardUI `PanelContainer` | 9 | `Scenes/Cards/CardUI.gd` |
| [`Tools/validator.tscn`](map/Tools/validator.scene.md) | Validator `Node` | 1 | `Tools/validate_gameData.gd` |

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

Indexed 56 script(s) (43 game, 13 test), 4 scene(s), 5 data file(s).
