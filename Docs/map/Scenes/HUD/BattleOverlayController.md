<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleOverlayController.gd` — `class_name BattleOverlayController` extends `Node`

`494` lines · [back to the map](../../../CODEBASE_MAP.md)

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
- L20 `_orbs_by_unit: Dictionary[Unit, MoxieOrbUI] = {} # Unit -> MoxieOrbUI`
- L21 `_units_to_ui: Dictionary[Unit, UnitUI] = {}      # Unit -> UnitUI`
- L22 `_current_ally_units: Array[Unit] = []`
- L23 `_current_enemy_units: Array[Unit] = []`
- L25 `_allies_row: Control`
- L26 `_enemies_row: Control`
- L27 `_player_input_enabled: bool = false`
- L28 `_auto_sync_queued: bool = false`

Public API:
- L44-57 `setup(p_game_manager: Node, p_icon_catalog: CardIconCatalog, p_tooltip_icon_catalog: TooltipIconCatalog = null) -> void`
- L61-113 `rebuild_for_units(ally_uis: Array[UnitUI], enemy_uis: Array[UnitUI]) -> void` — Call whenever allies or a new enemy wave spawns, passing active UnitUI nodes.
- L117-124 `set_player_turn_interactive(enabled: bool) -> void` — Toggle whether ally Ultimate orbs can be clicked right now (true inside get_player_action).
- L128-140 `sync_enemy_intent_previews() -> void` — Updates enemy orb preview segments from GameManager.current_intents & refreshes Enemy Ult warnings.
- L143-154 `clear_enemy_intent_previews() -> void`

Private:
- L31-41 `_ready`
- L159-167 `_is_live_unit_ui`
- L170-177 `_get_valid_orb`
- L180-197 `_get_valid_unit_ui`
- L200-208 `_same_units_and_valid_orbs`
- L211-225 `_auto_bind_scene_rows`
- L228-229 `_on_row_children_changed`
- L232-233 `_on_wave_or_turn_changed`
- L236-240 `_queue_auto_sync`
- L243-256 `_run_auto_sync`
- L259-264 `_clear_container`
- L272-307 `_build_rails`
- L310-318 `_build_tooltip`
- L321-328 `_spawn_orb`
- L331-349 `_extract_unit_portrait`
- L352-389 `_find_character_texture_in_node`
- L392-403 `_bind_unit_ui`
- L406-412 `_get_state`
- L415-426 `_find_intent_for_enemy`
- L429-437 `_on_unit_card_hover_started`
- L440-444 `_on_unit_card_hover_ended`
- L447-454 `_on_unit_intent_hover_started`
- L457-458 `_on_unit_intent_hover_ended`
- L461-472 `_on_orb_hover_started`
- L475-479 `_on_orb_hover_ended`
- L482-485 `_on_orb_activated`
- L488-491 `_on_ultimate_cast`

Uses: BattleScene, Card, CardIconCatalog, EnemyIntent, GameManager, GameState, MoxieOrbUI, SkillPreviewFormatter, SkillTooltipPopup, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: Scenes/BattleScene/BattleScene.gd
Loads: res

