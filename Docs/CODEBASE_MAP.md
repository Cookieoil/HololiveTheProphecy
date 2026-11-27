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

## 1. Game scripts at a glance (59)

| Script | class_name | lines | role |
| --- | --- | --- | --- |
| [`Core/Card.gd`](map/Core/Card.md) | `Card` | 115 | This class contains the data for the card Card instance is created/destroyed during merging. Rul… |
| [`Core/DataLoader.gd`](map/Core/DataLoader.md) | `DataLoader` | 563 | Runtime loader for the game data JSON files in res://Data/json/. Those JSON files are the single… |
| [`Core/DiceRoller.gd`](map/Core/DiceRoller.md) | `DiceRoller` | 28 | Static utility for dice rolls. Separated for easy mocking/seeding in tests. |
| [`Core/EnemyIntent.gd`](map/Core/EnemyIntent.md) | `EnemyIntent` | 38 | Pre-rolled intent for one enemy this turn. Created at step 1 of the turn loop, resolved at step… |
| [`Core/FeatureFlags.gd`](map/Core/FeatureFlags.md) | `FeatureFlags` | 261 | Registry and deterministic evaluator for staged feature flags. A flag lives in `res://Data/json/… |
| [`Core/GameState.gd`](map/Core/GameState.md) | `GameState` | 690 | Pure game state. No nodes, no signals, no rendering. All mutation happens through methods that r… |
| [`Core/GameUI.gd`](map/Core/GameUI.md) | `GameUI` | 106 | Abstract UI interface the GameManager talks to. Implemented by the graphical BattleScene; GameMa… |
| [`Core/Telemetry/HttpBatchSink.gd`](map/Core/Telemetry/HttpBatchSink.md) | `HttpBatchSink` | 54 | Stage 2 telemetry sink: the same crash-safe, per-event spooling as JsonlFileSink, but the finish… |
| [`Core/Telemetry/JsonlFileSink.gd`](map/Core/Telemetry/JsonlFileSink.md) | `JsonlFileSink` | 94 | Stage 1 telemetry sink: appends one JSON object per line to a per-run file under user://telemetr… |
| [`Core/Telemetry/TelemetryConsent.gd`](map/Core/Telemetry/TelemetryConsent.md) | `TelemetryConsent` | 201 | Explicit opt-in gate for gameplay telemetry. The player is asked on every launch, before the fir… |
| [`Core/Telemetry/TelemetrySchema.gd`](map/Core/Telemetry/TelemetrySchema.md) | `TelemetrySchema` | 313 | Pure serialisers that turn live game objects into the plain Dictionaries the telemetry spool sto… |
| [`Core/Telemetry/TelemetrySink.gd`](map/Core/Telemetry/TelemetrySink.md) | `TelemetrySink` | 33 | Abstract destination for telemetry events. The recorder never cares where an event goes: Stage 1… |
| [`Core/Unit.gd`](map/Core/Unit.md) | `Unit` | 387 | Runtime instance of a unit on the board. Mutable HP/Shield state. This is all just data |
| [`Core/UnitData.gd`](map/Core/UnitData.md) | `UnitData` | 20 | Template definition for a unit type. |
| [`Data/gameDatabase.gd`](map/Data/gameDatabase.md) | `GameDatabase` | 36 | Skill definitions keyed by skill_id (effects embedded). |
| [`Managers/ColorUtils.gd`](map/Managers/ColorUtils.md) | — | 31 | Color definitions for BBCode |
| [`Managers/EventBus.gd`](map/Managers/EventBus.md) | — | 43 | This is used as a global signal bus. Add as an Autoload. Used for UI logging and passive hooks,… |
| [`Managers/GameManager.gd`](map/Managers/GameManager.md) | `GameManager` | 1174 | Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flo… |
| [`Managers/TelemetryManager.gd`](map/Managers/TelemetryManager.md) | `TelemetryManager` | 1021 | Records every decision a player makes, for game design and balancing. It is a passive observer:… |
| [`Managers/TelemetryUploader.gd`](map/Managers/TelemetryUploader.md) | `TelemetryUploader` | 238 | Drains the telemetry outbox to the metric server, in the background. It picks up the per-run JSO… |
| [`Scenes/BattleScene/BattleScene.gd`](map/Scenes/BattleScene/BattleScene.md) | `BattleScene` | 670 | extends GameUI, 2 signal(s), 11 export(s), 46 function(s) |
| [`Scenes/BattleUnit/SpinePortrait.gd`](map/Scenes/BattleUnit/SpinePortrait.md) | `SpinePortrait` | 649 | extends Control, 3 signal(s), 28 export(s), 37 function(s) |
| [`Scenes/BattleUnit/StatusIconCatalog.gd`](map/Scenes/BattleUnit/StatusIconCatalog.md) | `StatusIconCatalog` | 363 | Catalog for character buff/debuff status icons (separate from CardIconCatalog). Provides lookup… |
| [`Scenes/BattleUnit/UnitUI.gd`](map/Scenes/BattleUnit/UnitUI.md) | `UnitUI` | 1341 | extends PanelContainer, 6 signal(s), 12 export(s), 58 function(s) |
| [`Scenes/Cards/CardDrag.gd`](map/Scenes/Cards/CardDrag.md) | `CardDrag` | 13 | Payload for all card drag operations. Consumed by: CardUI (merge), UnitDropZone (skill activatio… |
| [`Scenes/Cards/CardIconCatalog.gd`](map/Scenes/Cards/CardIconCatalog.md) | `CardIconCatalog` | 15 | Central skill-type icon registry for cards / skill previews. One instance, set as project autolo… |
| [`Scenes/Cards/CardUI.gd`](map/Scenes/Cards/CardUI.md) | `CardUI` | 1377 | Visual representation of one Card in hand. Drag source (play / merge) and drop target (merge onl… |
| [`Scenes/Cards/ForgePlate.gd`](map/Scenes/Cards/ForgePlate.md) | `ForgePlate` | 140 | One of the two cards in a merge, drawn as a real fake-3D quad. A merge has to show two cards ban… |
| [`Scenes/Cards/HandBar.gd`](map/Scenes/Cards/HandBar.md) | `HandBar` | 412 | Bottom-edge hand of cards. View-only: it animates, GameManager validates. |
| [`Scenes/HUD/BattleOverlayController.gd`](map/Scenes/HUD/BattleOverlayController.md) | `BattleOverlayController` | 555 | Builds E1–E3 on the left, A1–A3 on the right, manages the tooltip layer, and safely bridges Unit… |
| [`Scenes/HUD/BattleResultOverlay.gd`](map/Scenes/HUD/BattleResultOverlay.md) | `BattleResultOverlay` | 384 | End-of-battle cutscene, staged like a big-budget result screen. The battle scene is the only sce… |
| [`Scenes/HUD/BattleResultPrompt.gd`](map/Scenes/HUD/BattleResultPrompt.md) | `BattleResultPrompt` | 183 | The end screen's action prompt, drawn the way big-budget menus do it: no box, no border and no f… |
| [`Scenes/HUD/DebugMenuPopup.gd`](map/Scenes/HUD/DebugMenuPopup.md) | `DebugMenuPopup` | 704 | Tester-only tool palette for the battle scene. Every button here is a *request*: it emits `debug… |
| [`Scenes/HUD/HudTooltip.gd`](map/Scenes/HUD/HudTooltip.md) | `HudTooltip` | 91 | Content of the hover tooltip for one top-bar widget. Every icon in the top bar is the same place… |
| [`Scenes/HUD/MoxieOrbUI.gd`](map/Scenes/HUD/MoxieOrbUI.md) | `MoxieOrbUI` | 605 | extends Control, 3 signal(s), 1 export(s), 22 function(s) |
| [`Scenes/HUD/OutlineGlow.gd`](map/Scenes/HUD/OutlineGlow.md) | `OutlineGlow` | 236 | outer light border with scrolling sub-surface energy texture. |
| [`Scenes/HUD/SkillTooltipPopup.gd`](map/Scenes/HUD/SkillTooltipPopup.md) | `SkillTooltipPopup` | 272 | extends Control, 8 function(s) |
| [`Scenes/HUD/TelemetryConsentPopup.gd`](map/Scenes/HUD/TelemetryConsentPopup.md) | `TelemetryConsentPopup` | 339 | First-launch disclosure for gameplay telemetry: a full-screen modal that asks the player whether… |
| [`Scenes/HUD/TooltipIconCatalog.gd`](map/Scenes/HUD/TooltipIconCatalog.md) | `TooltipIconCatalog` | 334 | Inline icon registry for tooltip descriptions (SkillTooltipPopup bodies). Two authoring styles a… |
| [`Scenes/HUD/TooltipIconEntry.gd`](map/Scenes/HUD/TooltipIconEntry.md) | `TooltipIconEntry` | 133 | One tooltip keyword/icon rule, consumed by TooltipIconCatalog. DisplayMode decides how the keywo… |
| [`Skills/EffectBlock.gd`](map/Skills/EffectBlock.md) | `EffectBlock` | 669 | The universal data skill effect component Use configureble resource for all effect scripts Execu… |
| [`Skills/SkillContext.gd`](map/Skills/SkillContext.md) | `SkillContext` | 48 | Runtime context passed to every EffectBlock.execute(). Three inter-block communication channels:… |
| [`Skills/SkillData.gd`](map/Skills/SkillData.md) | `SkillData` | 54 | Defines one skill slot (Skill 1 or Skill 2) on a unit Holds arrays of effects for unmerged and m… |
| [`Skills/SkillEffect.gd`](map/Skills/SkillEffect.md) | `SkillEffect` | 20 | Abstract base for all skill effect components. Subclasses override execute(). The GameManager al… |
| [`Skills/SkillPreviewFormatter.gd`](map/Skills/SkillPreviewFormatter.md) | `SkillPreviewFormatter` | 445 | extends RefCounted, 16 function(s) |
| [`Tools/CodeIndexParser.gd`](map/Tools/CodeIndexParser.md) | `CodeIndexParser` | 759 | Pure parsing layer behind Tools/gen_code_index.gd. Every function here takes text in and returns… |
| [`Tools/DiffReviewParser.gd`](map/Tools/DiffReviewParser.md) | `DiffReviewParser` | 831 | Pure review layer behind Tools/review_diff.gd. Every function takes a unified diff as text and r… |
| [`Tools/SnapshotRunner.gd`](map/Tools/SnapshotRunner.md) | — | 250 | Renders the canonical battle screens to PNGs for the "align visually" loop. Every normal gate is… |
| [`Tools/TriageParser.gd`](map/Tools/TriageParser.md) | `TriageParser` | 490 | Pure task-intake layer behind Tools/triage.gd: "forward pressure". Turns evidence into agent-rea… |
| [`Tools/check_navigation.gd`](map/Tools/check_navigation.md) | — | 763 | Test harness for the generated navigation set in Docs/. Two jobs: 1. Verify the committed artifa… |
| [`Tools/check_scripts.gd`](map/Tools/check_scripts.md) | — | 85 | Headless compile gate: loads every project GDScript outside the excluded folders, so a type erro… |
| [`Tools/check_spine_runtime.gd`](map/Tools/check_spine_runtime.md) | — | 142 | Headless link and compatibility gate for the spine-godot GDExtension. Proves three things: 1. th… |
| [`Tools/dataBuilder.gd`](map/Tools/dataBuilder.md) | `DataBuilder` | 779 | Converts the bulk-entry workbook (res://Data/xlsx/game_data.xlsx) into the JSON files stored in… |
| [`Tools/export_xlsx_to_json.gd`](map/Tools/export_xlsx_to_json.md) | — | 34 | Headless Excel -> JSON exporter for the game data pipeline. Usage: godot --headless --path . --s… |
| [`Tools/gen_code_index.gd`](map/Tools/gen_code_index.md) | — | 809 | Headless symbol-index generator for this repository. Parses every first-party GDScript source an… |
| [`Tools/review_diff.gd`](map/Tools/review_diff.md) | — | 150 | Second-pass reviewer for a branch: summarises the diff and flags the things a reviewer (human or… |
| [`Tools/triage.gd`](map/Tools/triage.md) | — | 222 | Forward pressure: turns evidence into agent-ready task issues. An agent (or a human) should neve… |
| [`Tools/validate_gameData.gd`](map/Tools/validate_gameData.md) | — | 1263 | Headless, offline validator for the whole game-data pipeline. res://Data/json/ is the single sou… |
| [`Tools/xlsx_reader.gd`](map/Tools/xlsx_reader.md) | `XlsxReader` | 181 | Reads an .xlsx workbook (a zip of XML parts) into { sheet_name: Array[Array[String]] }. Every ce… |

## 2. Tests at a glance (27)

| Script | class_name | lines | role |
| --- | --- | --- | --- |
| [`GDTest/AllyKitTest.gd`](map/GDTest/AllyKitTest.md) | `AllyKitTest` | 288 | Tests for the MOBA-style pure-skill rework of all ally kits. Covers: shield-slam, hand-scaling,… |
| [`GDTest/BattleEndTest.gd`](map/GDTest/BattleEndTest.md) | `BattleEndTest` | 687 | Locks the end of a battle: - a unit that dies never keeps Moxie (or a "ULT READY" glow) on the b… |
| [`GDTest/BattleOverlayControllerTest.gd`](map/GDTest/BattleOverlayControllerTest.md) | `BattleOverlayControllerTest` | 62 | Locks how the overlay finds the scene it belongs to. `BattleOverlay` is a node in BattleScene.ts… |
| [`GDTest/CardDrawAnimationTest.gd`](map/GDTest/CardDrawAnimationTest.md) | `CardDrawAnimationTest` | 303 | Locks in the fake-3D card draw: - every CardUI owns its own warp material, so tilting one card c… |
| [`GDTest/CardFlashPolicyTest.gd`](map/GDTest/CardFlashPolicyTest.md) | `CardFlashPolicyTest` | 109 | Locks in *who caused it* when the game reveals hand cards it picked on its own: - an enemy actin… |
| [`GDTest/CardMergeAnimationTest.gd`](map/GDTest/CardMergeAnimationTest.md) | `CardMergeAnimationTest` | 612 | Locks in the merge: the card the player was carrying is picked up from the exact point they rele… |
| [`GDTest/CardTest.gd`](map/GDTest/CardTest.md) | `CardTest` | 31 | This is the GDUnit test for Card class |
| [`GDTest/CardUITest.gd`](map/GDTest/CardUITest.md) | `CardUITest` | 122 | Tests for CardUI's runtime card feedback: the delayed value-label refresh after a skill buff/deb… |
| [`GDTest/CodeIndexTest.gd`](map/GDTest/CodeIndexTest.md) | `CodeIndexTest` | 302 | Fixture tests for Tools/CodeIndexParser.gd, the pure parsing layer behind the generated navigati… |
| [`GDTest/DebugFlagsTest.gd`](map/GDTest/DebugFlagsTest.md) | `DebugFlagsTest` | 87 | Locks the debug palette's Flags tab (Scenes/HUD/DebugMenuPopup.gd): it renders one toggle per st… |
| [`GDTest/DebugMenuTest.gd`](map/GDTest/DebugMenuTest.md) | `DebugMenuTest` | 864 | Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager): - the panel is vie… |
| [`GDTest/DiffReviewTest.gd`](map/GDTest/DiffReviewTest.md) | `DiffReviewTest` | 469 | Fixture tests for Tools/DiffReviewParser.gd, the pure review layer behind Tools/review_diff.gd.… |
| [`GDTest/EffectBlockMessageTest.gd`](map/GDTest/EffectBlockMessageTest.md) | `EffectBlockMessageTest` | 121 | Locks the colours of the battle-log lines EffectBlock writes. Every number in a message wears th… |
| [`GDTest/EnemySkillBalanceTest.gd`](map/GDTest/EnemySkillBalanceTest.md) | `EnemySkillBalanceTest` | 269 | Locks the enemy-skill balance pass: - an enemy threshold matches the parity of the slot it sits… |
| [`GDTest/EnemyTurnOverlapTest.gd`](map/GDTest/EnemyTurnOverlapTest.md) | `EnemyTurnOverlapTest` | 232 | Locks the enemy-turn overlap ("fast mode" pacing): - consecutive enemies hand control to the nex… |
| [`GDTest/EnemyUltAuraTest.gd`](map/GDTest/EnemyUltAuraTest.md) | `EnemyUltAuraTest` | 139 | Locks in the enemy Ultimate warning lifecycle. The crimson character aura and the Moxie orb prev… |
| [`GDTest/FeatureFlagsTest.gd`](map/GDTest/FeatureFlagsTest.md) | `FeatureFlagsTest` | 260 | Locks the feature-flag registry (Core/FeatureFlags.gd): deterministic bucketing, the precedence… |
| [`GDTest/GameStateMergeTest.gd`](map/GDTest/GameStateMergeTest.md) | `GameStateMergeTest` | 89 | Locks in where a merged card lands in hand: it takes the slot of the card the player merged *int… |
| [`GDTest/HudTooltipTest.gd`](map/GDTest/HudTooltipTest.md) | `HudTooltipTest` | 286 | Locks the top-bar hover tooltips (HudTooltip) and the slab they are drawn on (the tooltip theme… |
| [`GDTest/MessageLogTest.gd`](map/GDTest/MessageLogTest.md) | `MessageLogTest` | 46 | Locks the battle message log: the game authors it in BBCode (`ColorUtils.colorize` and the HOW T… |
| [`GDTest/StatusCatalogTest.gd`](map/GDTest/StatusCatalogTest.md) | `StatusCatalogTest` | 141 | Tests for the buff/debuff status system: Unit.statuses + StatusIconCatalog. |
| [`GDTest/TelemetryConsentTest.gd`](map/GDTest/TelemetryConsentTest.md) | `TelemetryConsentTest` | 362 | Locks the telemetry opt-in gate: - an unanswered consent is UNDECIDED and needs the prompt - "Ag… |
| [`GDTest/TelemetryFoundationTest.gd`](map/GDTest/TelemetryFoundationTest.md) | `TelemetryFoundationTest` | 60 | Locks the data foundation the telemetry system keys on: every UnitData and SkillData carries its… |
| [`GDTest/TelemetryTest.gd`](map/GDTest/TelemetryTest.md) | `TelemetryTest` | 697 | Locks the gameplay recorder end to end: a real battle through GameManager must produce run / wav… |
| [`GDTest/TooltipIconCatalogTest.gd`](map/GDTest/TooltipIconCatalogTest.md) | `TooltipIconCatalogTest` | 171 | Tests for the inline tooltip icon system (TooltipIconCatalog + TooltipIconEntry). Covers: left-o… |
| [`GDTest/TriageParserTest.gd`](map/GDTest/TriageParserTest.md) | `TriageParserTest` | 198 | Locks the task-intake rules (Tools/TriageParser.gd): every threshold, the ordering, the per-kind… |
| [`GDTest/UiSnapshotTest.gd`](map/GDTest/UiSnapshotTest.md) | `UiSnapshotTest` | 82 | Locks the seams the UI snapshot pipeline (Tools/snapshot_runner.tscn) relies on: a fixed seed mu… |

## 3. Global signals (Managers/EventBus.gd)

| signal | args | emitted by | listened by |
| --- | --- | --- | --- |
| `turn_started` | turn_number: int | Managers/GameManager.gd | Scenes/HUD/BattleOverlayController.gd |
| `wave_started` | wave_index: int | Managers/GameManager.gd | Managers/TelemetryManager.gd, Scenes/HUD/BattleOverlayController.gd |
| `game_over` | victory: bool | Managers/GameManager.gd | Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd |
| `card_played` | card: Card, ally: Unit | Managers/GameManager.gd | Scenes/Cards/HandBar.gd |
| `card_drawn` | card: Card | Skills/EffectBlock.gd | Managers/TelemetryManager.gd, Scenes/Cards/HandBar.gd |
| `card_discarded` | card: Card | Skills/EffectBlock.gd | Managers/TelemetryManager.gd, Scenes/Cards/HandBar.gd |
| `card_value_changed` | card: Card, old_value: int, new_value: int | GDTest/CardUITest.gd, Managers/GameManager.gd, Skills/EffectBlock.gd | GDTest/DebugMenuTest.gd, Managers/TelemetryManager.gd, Scenes/Cards/CardUI.gd |
| `damage_dealt` | source: Unit, target: Unit, amount: int, hp_lost: int | Managers/GameManager.gd, Skills/EffectBlock.gd | Managers/TelemetryManager.gd |
| `shield_gained` | target: Unit, amount: int | Managers/GameManager.gd, Skills/EffectBlock.gd | Managers/TelemetryManager.gd |
| `shield_reduced` | target: Unit, amount: int | Managers/GameManager.gd, Skills/EffectBlock.gd | Managers/TelemetryManager.gd |
| `unit_healed` | target: Unit, amount: int | Managers/GameManager.gd, Skills/EffectBlock.gd | Managers/TelemetryManager.gd |
| `unit_died` | target: Unit | Managers/GameManager.gd, Skills/EffectBlock.gd | Managers/TelemetryManager.gd |
| `skill_resolved` | caster: Unit, skill_name: String | Managers/GameManager.gd | — |
| `moxie_changed` | unit: Unit, current: int, maximum: int | Managers/GameManager.gd | — |
| `ultimate_cast` | caster: Unit, skill_name: String | Managers/GameManager.gd | Scenes/HUD/BattleOverlayController.gd |
| `unit_statuses_changed` | unit: Unit | Managers/GameManager.gd, Skills/EffectBlock.gd | — |

## 4. Scenes (5)

Node trees live on each scene's page.

| scene | root | nodes | script |
| --- | --- | --- | --- |
| [`Scenes/BattleScene/BattleScene.tscn`](map/Scenes/BattleScene/BattleScene.scene.md) | Main `Node` | 46 | `Scenes/BattleScene/BattleScene.gd` |
| [`Scenes/BattleUnit/UnitUI.tscn`](map/Scenes/BattleUnit/UnitUI.scene.md) | UnitUI `PanelContainer` | 19 | `Scenes/BattleUnit/UnitUI.gd` |
| [`Scenes/Cards/CardUI.tscn`](map/Scenes/Cards/CardUI.scene.md) | CardUI `PanelContainer` | 9 | `Scenes/Cards/CardUI.gd` |
| [`Tools/snapshot_runner.tscn`](map/Tools/snapshot_runner.scene.md) | SnapshotRunner `Node` | 1 | `Tools/SnapshotRunner.gd` |
| [`Tools/validator.tscn`](map/Tools/validator.scene.md) | Validator `Node` | 1 | `Tools/validate_gameData.gd` |

## 5. Game data (Data/json)

| file | shape | entries | per-entry keys |
| --- | --- | --- | --- |
| `Data/json/allies.json` | object | 3 | display_name, is_enemy, max_hp, max_moxie, skill_1, skill_2, ultimate |
| `Data/json/config.json` | object | 7 | — |
| `Data/json/enemies.json` | object | 2 | display_name, is_enemy, max_hp, max_moxie, skill_1, skill_2, ultimate |
| `Data/json/features.json` | object | 1 | — |
| `Data/json/skills.json` | object | 15 | action, base_categories, card_count, card_mod_type, card_select_mode, condition, condition_threshold, description, display_name, effect_id, effects, fixed_amount, merged_categories, merged_description, merged_mode, negate_condition, order, status_id, store_resolved_value, target_count, target_mode, trigger, value_cap, value_divisor, (+3 more) |
| `Data/json/waves.json` | object | 1 | display_name_override, enemies, max_hp_override, unit_id, wave_index |

Top-level keys:
- `Data/json/allies.json`: buff, healer, striker
- `Data/json/config.json`: actions_per_turn, allies, decklist, dice_progression, hand_size, merges_per_turn, wave_transition_mode
- `Data/json/enemies.json`: boss_enemy, normal_enemy
- `Data/json/features.json`: flags
- `Data/json/skills.json`: boss_enemy_1, boss_enemy_2, boss_enemy_ult, buff_1, buff_2, buff_ult, healer_1, healer_2, healer_ult, normal_enemy_1, normal_enemy_2, normal_enemy_ult, striker_1, striker_2, striker_ult
- `Data/json/waves.json`: waves

---

Indexed 86 script(s) (59 game, 27 test), 5 scene(s), 6 data file(s).
