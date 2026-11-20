<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.gd` — `class_name BattleScene` extends `GameUI`

`487` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends GameUI, 2 signal(s), 6 export(s), 36 function(s)

Sections: GameUI Overrides · Helpers & Interaction Handlers · Debug Menu

Signals:
- L39 `action_decided(action_dict: Dictionary)`
- L40 `unit_selected_for_target(unit: Unit)`

Constants:
- L43 `INTENT_STAGGER: float = 0.08` — seconds between each enemy's intent appearing

Exports:
- L5 `icon_catalog: CardIconCatalog`
- L6 `status_icon_catalog: StatusIconCatalog`
- L7 `tooltip_icon_catalog: TooltipIconCatalog`
- L8 `unit_ui_scene: PackedScene`
- L9 `turn_dice_progression: Array[int] = []`
- L11 `debug_menu_enabled: bool = true` — Tester tools (the Debug button + F1). Turn off for a build that must not show them.

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
- L36 `_awaiting_player_action: bool = false` — True only while GameManager awaits a player action: the one window in which a debug tool may be applied, because the turn loop is sitting on the action queue.
- L37 `_intent_cache: Dictionary[Unit, Dictionary] = {}`

Public API:
- L81-83 `on_card_played(card: Card, state: GameState) -> void`
- L89-91 `on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void` — Two cards in hand were fused into `result`: the hand plays the merge (the two cards drift into each other from where they were dropped, fold closed, and the mer…
- L96-97 `flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void` — Cards the game selected without asking (auto_top_n / auto_highest) get a short highlight so the player can see what was picked for them. `hostile` is set when a…
- L102-107 `play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — `lead` is the fraction of the skill animation to wait for: 1.0 for the player's own actions, lower for chained enemy turns that overlap their animations (see Ga…
- L110-113 `play_unit_ultimate(unit: Unit) -> void`
- L115-120 `show_message(msg: String) -> void`
- L123-130 `show_game_state(state: GameState) -> void`
- L133-137 `show_hand_and_resources(state: GameState) -> void`
- L152-164 `show_enemy_intents(intents: Array[EnemyIntent]) -> void`
- L167-171 `clear_unit_intent(unit: Unit) -> void`
- L198-217 `get_player_action(state: GameState) -> Dictionary`
- L220-243 `ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]`
- L246-274 `ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]`

Private:
- L45-76 `_ready`
- L140-149 `_update_top_bar`
- L174-178 `_apply_cached_intents`
- L181-193 `_apply_intent_to`
- L279-284 `_on_merge_requested`
- L287-292 `_on_card_dropped_on_unit`
- L295-296 `_on_unit_clicked`
- L302-303 `_on_ally_ultimate_requested`
- L307-316 `_sync_overlay_units`
- L319-323 `_highlight_target_candidates`
- L326-333 `_get_unit_ui`
- L336-367 `_sync_unit_row`
- L377-386 `_unhandled_key_input`
- L391-402 `_setup_debug_menu`
- L405-410 `_on_debug_button_pressed`
- L414-417 `_sync_debug_toggle`
- L420-422 `_set_debug_interactive`
- L427-430 `_on_debug_command_requested`
- L433-439 `_refresh_debug_menu`
- L442-445 `_debug_state`
- L449-462 `_debug_snapshot`
- L468-477 `_build_debug_targets`
- L480-485 `_debug_target_entry`

Uses: BattleOverlayController, Card, CardIconCatalog, DataLoader, DebugMenuPopup, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, HandBar, StatusIconCatalog, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: GDTest/CodeIndexTest.gd, GDTest/DebugMenuTest.gd, GDTest/HudTooltipTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, Scenes/BattleUnit/SpinePortrait.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd, Tools/check_navigation.gd
Loads: res://Scenes/BattleUnit/UnitUI.tscn

