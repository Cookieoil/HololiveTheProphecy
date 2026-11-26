<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleOverlayController.gd` — `class_name BattleOverlayController` extends `Node`

`511` lines · [back to the map](../../../CODEBASE_MAP.md)

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
- L45-58 `setup(p_game_manager: Node, p_icon_catalog: CardIconCatalog, p_tooltip_icon_catalog: TooltipIconCatalog = null) -> void`
- L62-114 `rebuild_for_units(ally_uis: Array[UnitUI], enemy_uis: Array[UnitUI]) -> void` — Call whenever allies or a new enemy wave spawns, passing active UnitUI nodes.
- L118-125 `set_player_turn_interactive(enabled: bool) -> void` — Toggle whether ally Ultimate orbs can be clicked right now (true inside get_player_action).
- L129-141 `sync_enemy_intent_previews() -> void` — Updates enemy orb preview segments from GameManager.current_intents & refreshes Enemy Ult warnings.
- L144-155 `clear_enemy_intent_previews() -> void`

Private:
- L31-42 `_ready`
- L160-168 `_is_live_unit_ui`
- L171-178 `_get_valid_orb`
- L181-198 `_get_valid_unit_ui`
- L201-209 `_same_units_and_valid_orbs`
- L212-226 `_auto_bind_scene_rows`
- L229-230 `_on_row_children_changed`
- L233-234 `_on_wave_or_turn_changed`
- L237-241 `_queue_auto_sync`
- L244-257 `_run_auto_sync`
- L260-265 `_clear_container`
- L273-308 `_build_rails`
- L311-319 `_build_tooltip`
- L322-329 `_spawn_orb`
- L332-350 `_extract_unit_portrait`
- L353-390 `_find_character_texture_in_node`
- L393-404 `_bind_unit_ui`
- L407-413 `_get_state`
- L416-427 `_find_intent_for_enemy`
- L430-438 `_on_unit_card_hover_started`
- L441-445 `_on_unit_card_hover_ended`
- L448-455 `_on_unit_intent_hover_started`
- L458-459 `_on_unit_intent_hover_ended`
- L462-473 `_on_orb_hover_started`
- L476-480 `_on_orb_hover_ended`
- L483-486 `_on_orb_activated`
- L489-492 `_on_ultimate_cast`
- L498-508 `_on_game_over`

Uses: Card, CardIconCatalog, EnemyIntent, GameManager, GameState, MoxieOrbUI, SkillPreviewFormatter, SkillTooltipPopup, TooltipIconCatalog, Unit, UnitUI
Used by: Scenes/BattleScene/BattleScene.gd, Tools/check_navigation.gd
Loads: —

