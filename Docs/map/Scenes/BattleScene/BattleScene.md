<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.gd` — `class_name BattleScene` extends `GameUI`

`502` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends GameUI, 2 signal(s), 6 export(s), 37 function(s)

Sections: GameUI Overrides · Helpers & Interaction Handlers · Debug Menu

Signals:
- L40 `action_decided(action_dict: Dictionary)`
- L41 `unit_selected_for_target(unit: Unit)`

Constants:
- L44 `INTENT_STAGGER: float = 0.08` — seconds between each enemy's intent appearing
- L48 `ICON_BUTTON_HOVER_TINT: Color = Color(1.25, 1.25, 1.25)` — The two top-bar action buttons draw no button chrome (see BattleScene.tscn), so hovering brightens their icon a little instead, the same cue the ultimate orbs g…

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
- L23 `deck_value_label: Label`
- L24 `discard_value_label: Label`
- L25 `convert_button: Button`
- L26 `end_turn_button: Button`
- L27 `log_label: Label`
- L29 `debug_layer: CanvasLayer`
- L30 `debug_button: Button`

State:
- L32 `game_manager: GameManager`
- L34 `debug_menu: DebugMenuPopup` — Tester overlay, built in code and mounted on `debug_layer`.
- L37 `_awaiting_player_action: bool = false` — True only while GameManager awaits a player action: the one window in which a debug tool may be applied, because the turn loop is sitting on the action queue.
- L38 `_intent_cache: Dictionary[Unit, Dictionary] = {}`

Public API:
- L88-90 `on_card_played(card: Card, state: GameState) -> void`
- L96-98 `on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void` — Two cards in hand were fused into `result`: the hand plays the merge (the two cards drift into each other from where they were dropped, fold closed, and the mer…
- L103-104 `flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void` — Cards the game selected without asking (auto_top_n / auto_highest) get a short highlight so the player can see what was picked for them. `hostile` is set when a…
- L109-114 `play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — `lead` is the fraction of the skill animation to wait for: 1.0 for the player's own actions, lower for chained enemy turns that overlap their animations (see Ga…
- L117-120 `play_unit_ultimate(unit: Unit) -> void`
- L122-127 `show_message(msg: String) -> void`
- L130-137 `show_game_state(state: GameState) -> void`
- L140-144 `show_hand_and_resources(state: GameState) -> void`
- L167-179 `show_enemy_intents(intents: Array[EnemyIntent]) -> void`
- L182-186 `clear_unit_intent(unit: Unit) -> void`
- L213-232 `get_player_action(state: GameState) -> Dictionary`
- L235-258 `ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]`
- L261-289 `ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]`

Private:
- L50-83 `_ready`
- L147-157 `_update_top_bar`
- L162-164 `_setup_icon_button_hover`
- L189-193 `_apply_cached_intents`
- L196-208 `_apply_intent_to`
- L294-299 `_on_merge_requested`
- L302-307 `_on_card_dropped_on_unit`
- L310-311 `_on_unit_clicked`
- L317-318 `_on_ally_ultimate_requested`
- L322-331 `_sync_overlay_units`
- L334-338 `_highlight_target_candidates`
- L341-348 `_get_unit_ui`
- L351-382 `_sync_unit_row`
- L392-401 `_unhandled_key_input`
- L406-417 `_setup_debug_menu`
- L420-425 `_on_debug_button_pressed`
- L429-432 `_sync_debug_toggle`
- L435-437 `_set_debug_interactive`
- L442-445 `_on_debug_command_requested`
- L448-454 `_refresh_debug_menu`
- L457-460 `_debug_state`
- L464-477 `_debug_snapshot`
- L483-492 `_build_debug_targets`
- L495-500 `_debug_target_entry`

Uses: BattleOverlayController, Card, CardIconCatalog, DataLoader, DebugMenuPopup, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, HandBar, StatusIconCatalog, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: GDTest/CodeIndexTest.gd, GDTest/DebugMenuTest.gd, GDTest/HudTooltipTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, Scenes/BattleUnit/SpinePortrait.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd, Tools/check_navigation.gd
Loads: res://Scenes/BattleUnit/UnitUI.tscn

