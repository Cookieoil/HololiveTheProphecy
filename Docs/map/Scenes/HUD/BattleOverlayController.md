<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleOverlayController.gd` — `class_name BattleOverlayController` extends `Node`

`555` lines · [back to the map](../../../CODEBASE_MAP.md)

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
- L18 `scene_root: Node` — The scene whose `EntityOverlay/AlliesRow` and `EnemiesRow` this controller binds to. Left unset it defaults to the scene root that owns this node; a test can in…
- L20 `_rail_layer: CanvasLayer`
- L21 `_enemy_rail: VBoxContainer`
- L22 `_ally_rail: VBoxContainer`
- L24 `_tooltip_layer: CanvasLayer`
- L25 `_tooltip: SkillTooltipPopup`
- L27 `_orbs_by_unit: Dictionary[Unit, MoxieOrbUI] = {} # Unit -> MoxieOrbUI`
- L28 `_units_to_ui: Dictionary[Unit, UnitUI] = {}      # Unit -> UnitUI`
- L29 `_current_ally_units: Array[Unit] = []`
- L30 `_current_enemy_units: Array[Unit] = []`
- L32 `_allies_row: Control`
- L33 `_enemies_row: Control`
- L34 `_player_input_enabled: bool = false`
- L35 `_auto_sync_queued: bool = false`

Public API:
- L52-65 `setup(p_game_manager: Node, p_icon_catalog: CardIconCatalog, p_tooltip_icon_catalog: TooltipIconCatalog = null) -> void`
- L69-121 `rebuild_for_units(ally_uis: Array[UnitUI], enemy_uis: Array[UnitUI]) -> void` — Call whenever allies or a new enemy wave spawns, passing active UnitUI nodes.
- L125-132 `set_player_turn_interactive(enabled: bool) -> void` — Toggle whether ally Ultimate orbs can be clicked right now (true inside get_player_action).
- L136-148 `sync_enemy_intent_previews() -> void` — Updates enemy orb preview segments from GameManager.current_intents & refreshes Enemy Ult warnings.
- L151-162 `clear_enemy_intent_previews() -> void`
- L168-177 `retreat_for_result() -> void` — The battle is over: the rails are combat chrome, so they step off stage and leave the battlefield - and the result cutscene - alone on screen. Awaited by the ca…
- L182-183 `get_skill_tooltip() -> SkillTooltipPopup` — Exposes the shared skill callout so tooling (the UI snapshot runner) can render a populated tooltip without synthesising mouse hover.
- L188-196 `show_ally_ultimate_callout(index: int) -> bool` — Shows the ally Ultimate callout for the unit at `index`, anchored on its orb, and returns true once it was shown. Tooling/test seam: the real path is a hover.

Private:
- L38-49 `_ready`
- L201-209 `_is_live_unit_ui`
- L212-219 `_get_valid_orb`
- L222-239 `_get_valid_unit_ui`
- L242-250 `_same_units_and_valid_orbs`
- L253-270 `_auto_bind_scene_rows`
- L273-274 `_on_row_children_changed`
- L277-278 `_on_wave_or_turn_changed`
- L281-285 `_queue_auto_sync`
- L288-301 `_run_auto_sync`
- L304-309 `_clear_container`
- L317-352 `_build_rails`
- L355-363 `_build_tooltip`
- L366-373 `_spawn_orb`
- L376-394 `_extract_unit_portrait`
- L397-434 `_find_character_texture_in_node`
- L437-448 `_bind_unit_ui`
- L451-457 `_get_state`
- L460-471 `_find_intent_for_enemy`
- L474-482 `_on_unit_card_hover_started`
- L485-489 `_on_unit_card_hover_ended`
- L492-499 `_on_unit_intent_hover_started`
- L502-503 `_on_unit_intent_hover_ended`
- L506-517 `_on_orb_hover_started`
- L520-524 `_on_orb_hover_ended`
- L527-530 `_on_orb_activated`
- L533-536 `_on_ultimate_cast`
- L542-552 `_on_game_over`

Uses: Card, CardIconCatalog, EnemyIntent, GameManager, GameState, MoxieOrbUI, SkillPreviewFormatter, SkillTooltipPopup, TooltipIconCatalog, Unit, UnitUI
Used by: Scenes/BattleScene/BattleScene.gd, Tools/check_navigation.gd
Loads: —

