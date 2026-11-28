<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/BattleOverlayController.gd` — `class_name BattleOverlayController` extends `Node`

`606` lines · [back to the map](../../../CODEBASE_MAP.md)

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
- L69-81 `rebuild_for_units(ally_uis: Array[UnitUI], enemy_uis: Array[UnitUI]) -> void` — Call whenever allies or a new enemy wave spawns, passing active UnitUI nodes.
- L137-144 `set_player_turn_interactive(enabled: bool) -> void` — Toggle whether ally Ultimate orbs can be clicked right now (true inside get_player_action).
- L148-160 `sync_enemy_intent_previews() -> void` — Updates enemy orb preview segments from GameManager.current_intents & refreshes Enemy Ult warnings.
- L163-174 `clear_enemy_intent_previews() -> void`
- L180-189 `retreat_for_result() -> void` — The battle is over: the rails are combat chrome, so they step off stage and leave the battlefield - and the result cutscene - alone on screen. Awaited by the ca…
- L194-195 `get_skill_tooltip() -> SkillTooltipPopup` — Exposes the shared skill callout so tooling (the UI snapshot runner) can render a populated tooltip without synthesising mouse hover.
- L200-208 `show_ally_ultimate_callout(index: int) -> bool` — Shows the ally Ultimate callout for the unit at `index`, anchored on its orb, and returns true once it was shown. Tooling/test seam: the real path is a hover.

Private:
- L38-49 `_ready`
- L86-91 `_live_uis`
- L96-101 `_rebind_uis`
- L104-108 `_units_of`
- L114-133 `_sync_rail`
- L213-221 `_is_live_unit_ui`
- L224-231 `_get_valid_orb`
- L234-251 `_get_valid_unit_ui`
- L254-262 `_same_units_and_valid_orbs`
- L265-282 `_auto_bind_scene_rows`
- L285-286 `_on_row_children_changed`
- L289-290 `_on_wave_or_turn_changed`
- L293-297 `_queue_auto_sync`
- L300-313 `_run_auto_sync`
- L316-321 `_clear_container`
- L329-364 `_build_rails`
- L367-375 `_build_tooltip`
- L378-385 `_spawn_orb`
- L388-406 `_extract_unit_portrait`
- L409-419 `_find_character_texture_in_node`
- L425-430 `_is_chrome_node`
- L434-441 `_texture_of`
- L446-459 `_animation_frame`
- L464-477 `_sprite_texture`
- L482-485 `_rect_texture`
- L488-499 `_bind_unit_ui`
- L502-508 `_get_state`
- L511-522 `_find_intent_for_enemy`
- L525-533 `_on_unit_card_hover_started`
- L536-540 `_on_unit_card_hover_ended`
- L543-550 `_on_unit_intent_hover_started`
- L553-554 `_on_unit_intent_hover_ended`
- L557-568 `_on_orb_hover_started`
- L571-575 `_on_orb_hover_ended`
- L578-581 `_on_orb_activated`
- L584-587 `_on_ultimate_cast`
- L593-603 `_on_game_over`

Uses: Card, CardIconCatalog, EnemyIntent, GameState, MoxieOrbUI, SkillPreviewFormatter, SkillTooltipPopup, TooltipIconCatalog, Unit, UnitUI
Used by: GDTest/BattleOverlayControllerTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

