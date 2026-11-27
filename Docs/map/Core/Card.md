<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Card.gd` — `class_name Card` extends `RefCounted`

`115` lines · [back to the map](../../CODEBASE_MAP.md)

> This class contains the data for the card Card instance is created/destroyed during merging. Rule: Merge consumes two cards and produces one. Total count is shr…

State:
- L11 `_next_id: int = 0`
- L13 `id: int = -1`
- L14 `base_value: int`
- L15 `current_value: int`
- L16 `is_merged: bool = false`
- L17 `is_double_merged: bool = false`
- L20 `constituents: Array[Card] = []`
- L23 `value_buff: int = 0`
- L24 `value_debuff: int = 0`

Public API:
- L27-28 `static reset_id_counter() -> void` — Reset the card id (e.g card#1 -> card#0)
- L32-38 `get_suffix() -> String` — Returns a human-readable suffix for this card's merge state.
- L40-41 `format_value(value: int) -> String` — Returns a colored string for a given numeric value using the card's suffix.
- L53-61 `decompose() -> Array[Card]` — Recursively breaks this card down into its original unmerged base cards. Returns an array of clean base cards ready for discard/draw.
- L65-71 `reset_to_base() -> void` — Restores this card to its pristine starting state (unmerged, original value).
- L74-75 `get_effective_value() -> int` — get the actual effective value (included buff/debuff)
- L80-81 `is_odd() -> bool` — check if the value is odd
- L86-87 `costs_action() -> bool` — check if playing this card costs an action
- L91-93 `clear_temp_buffs() -> void` — clear the temporary value buff/debuff

Private:
- L45-49 `_init`
- L98-114 `_to_string`

Uses: —
Used by: Core/GameState.gd, Core/GameUI.gd, Core/Telemetry/TelemetrySchema.gd, GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/CardDrawAnimationTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/CardTest.gd, GDTest/CardUITest.gd, GDTest/CodeIndexTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/GameStateMergeTest.gd, GDTest/TelemetryTest.gd, GDTest/TooltipIconCatalogTest.gd, GDTest/UiSnapshotTest.gd, Managers/EventBus.gd, Managers/GameManager.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardDrag.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/DebugMenuPopup.gd, Skills/EffectBlock.gd, Skills/SkillContext.gd, Skills/SkillPreviewFormatter.gd, Tools/check_navigation.gd
Loads: —

