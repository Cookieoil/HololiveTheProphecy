<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleOverlayController.gd` — `class_name BattleOverlayController` extends `Node`

`529` lines · [back to the map](../../../CODEBASE_MAP.md)

> Builds E1–E3 on the left, A1–A3 on the right, manages the tooltip layer, and safely bridges UnitUI hover & wave transitions without freed-instance errors.

Sections: Safe Instance Lookup & Auto Row Sync · Internal Builders & Signal Handlers

Signals:
- L7 `ally_ultimate_requested(ally: Unit)`

Constants:
- L10 `RAIL_RETREAT_TIME: float = 0.22` — How long the rails take to step off stage when the battle ends.

State:
- L12 `icon_catalog: CardIconCatalog`
- L13 `tooltip_icon_catalog: TooltipIconCatalog`
- L14 `game_manager: Node # GameManager`
- L16 `_rail_layer: CanvasLayer`
- L17 `_enemy_rail: VBoxContainer`
- L18 `_ally_rail: VBoxContainer`
- L20 `_tooltip_layer: CanvasLayer`
- L21 `_tooltip: SkillTooltipPopup`
- L23 `_orbs_by_unit: Dictionary[Unit, MoxieOrbUI] = {} # Unit -> MoxieOrbUI`
- L24 `_units_to_ui: Dictionary[Unit, UnitUI] = {}      # Unit -> UnitUI`
- L25 `_current_ally_units: Array[Unit] = []`
- L26 `_current_enemy_units: Array[Unit] = []`
- L28 `_allies_row: Control`
- L29 `_enemies_row: Control`
- L30 `_player_input_enabled: bool = false`
- L31 `_auto_sync_queued: bool = false`

Public API:
- L48-61 `setup(p_game_manager: Node, p_icon_catalog: CardIconCatalog, p_tooltip_icon_catalog: TooltipIconCatalog = null) -> void`
- L65-117 `rebuild_for_units(ally_uis: Array[UnitUI], enemy_uis: Array[UnitUI]) -> void` — Call whenever allies or a new enemy wave spawns, passing active UnitUI nodes.
- L121-128 `set_player_turn_interactive(enabled: bool) -> void` — Toggle whether ally Ultimate orbs can be clicked right now (true inside get_player_action).
- L132-144 `sync_enemy_intent_previews() -> void` — Updates enemy orb preview segments from GameManager.current_intents & refreshes Enemy Ult warnings.
- L147-158 `clear_enemy_intent_previews() -> void`
- L164-173 `retreat_for_result() -> void` — The battle is over: the rails are combat chrome, so they step off stage and leave the battlefield - and the result cutscene - alone on screen. Awaited by the ca…

Private:
- L34-45 `_ready`
- L178-186 `_is_live_unit_ui`
- L189-196 `_get_valid_orb`
- L199-216 `_get_valid_unit_ui`
- L219-227 `_same_units_and_valid_orbs`
- L230-244 `_auto_bind_scene_rows`
- L247-248 `_on_row_children_changed`
- L251-252 `_on_wave_or_turn_changed`
- L255-259 `_queue_auto_sync`
- L262-275 `_run_auto_sync`
- L278-283 `_clear_container`
- L291-326 `_build_rails`
- L329-337 `_build_tooltip`
- L340-347 `_spawn_orb`
- L350-368 `_extract_unit_portrait`
- L371-408 `_find_character_texture_in_node`
- L411-422 `_bind_unit_ui`
- L425-431 `_get_state`
- L434-445 `_find_intent_for_enemy`
- L448-456 `_on_unit_card_hover_started`
- L459-463 `_on_unit_card_hover_ended`
- L466-473 `_on_unit_intent_hover_started`
- L476-477 `_on_unit_intent_hover_ended`
- L480-491 `_on_orb_hover_started`
- L494-498 `_on_orb_hover_ended`
- L501-504 `_on_orb_activated`
- L507-510 `_on_ultimate_cast`
- L516-526 `_on_game_over`

Uses: Card, CardIconCatalog, EnemyIntent, GameManager, GameState, MoxieOrbUI, SkillPreviewFormatter, SkillTooltipPopup, TooltipIconCatalog, Unit, UnitUI
Used by: Scenes/BattleScene/BattleScene.gd, Tools/check_navigation.gd
Loads: —

