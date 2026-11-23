<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.gd` — `class_name BattleScene` extends `GameUI`

`511` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends GameUI, 2 signal(s), 6 export(s), 38 function(s)

Sections: GameUI Overrides · Helpers & Interaction Handlers · Debug Menu

Signals:
- L41 `action_decided(action_dict: Dictionary)`
- L42 `unit_selected_for_target(unit: Unit)`

Constants:
- L45 `INTENT_STAGGER: float = 0.08` — seconds between each enemy's intent appearing
- L49 `ICON_BUTTON_HOVER_TINT: Color = Color(1.25, 1.25, 1.25)` — The two top-bar action buttons draw no button chrome (see BattleScene.tscn), so hovering brightens their icon a little instead, the same cue the ultimate orbs g…

Exports:
- L5 `icon_catalog: CardIconCatalog`
- L6 `status_icon_catalog: StatusIconCatalog`
- L7 `tooltip_icon_catalog: TooltipIconCatalog`
- L8 `unit_ui_scene: PackedScene`
- L9 `turn_dice_progression: Array[int] = []`
- L12 `debug_menu_enabled: bool = true` — Tester tools (the Debug button + F1). Turn off for a build that must not show them. A release export hides them regardless of this flag — see `_debug_tools_allo…

Onready:
- L14 `hand_bar: HandBar`
- L15 `allies_container: HBoxContainer`
- L16 `enemies_container: HBoxContainer`
- L18 `battle_overlay: BattleOverlayController`
- L20 `wave_value_label: Label`
- L21 `dice_value_label: Label`
- L22 `actions_value_label: Label`
- L23 `merges_value_label: Label`
- L24 `deck_value_label: Label`
- L25 `discard_value_label: Label`
- L26 `convert_button: Button`
- L27 `end_turn_button: Button`
- L28 `log_label: Label`
- L30 `debug_layer: CanvasLayer`
- L31 `debug_button: Button`

State:
- L33 `game_manager: GameManager`
- L35 `debug_menu: DebugMenuPopup` — Tester overlay, built in code and mounted on `debug_layer`.
- L38 `_awaiting_player_action: bool = false` — True only while GameManager awaits a player action: the one window in which a debug tool may be applied, because the turn loop is sitting on the action queue.
- L39 `_intent_cache: Dictionary[Unit, Dictionary] = {}`

Public API:
- L89-91 `on_card_played(card: Card, state: GameState) -> void`
- L97-99 `on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void` — Two cards in hand were fused into `result`: the hand plays the merge (the two cards drift into each other from where they were dropped, fold closed, and the mer…
- L104-105 `flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void` — Cards the game selected without asking (auto_top_n / auto_highest) get a short highlight so the player can see what was picked for them. `hostile` is set when a…
- L110-115 `play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — `lead` is the fraction of the skill animation to wait for: 1.0 for the player's own actions, lower for chained enemy turns that overlap their animations (see Ga…
- L118-121 `play_unit_ultimate(unit: Unit) -> void`
- L123-128 `show_message(msg: String) -> void`
- L131-138 `show_game_state(state: GameState) -> void`
- L141-145 `show_hand_and_resources(state: GameState) -> void`
- L168-180 `show_enemy_intents(intents: Array[EnemyIntent]) -> void`
- L183-187 `clear_unit_intent(unit: Unit) -> void`
- L214-233 `get_player_action(state: GameState) -> Dictionary`
- L236-259 `ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]`
- L262-290 `ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]`

Private:
- L51-84 `_ready`
- L148-158 `_update_top_bar`
- L163-165 `_setup_icon_button_hover`
- L190-194 `_apply_cached_intents`
- L197-209 `_apply_intent_to`
- L295-300 `_on_merge_requested`
- L303-308 `_on_card_dropped_on_unit`
- L311-312 `_on_unit_clicked`
- L318-319 `_on_ally_ultimate_requested`
- L323-332 `_sync_overlay_units`
- L335-339 `_highlight_target_candidates`
- L342-349 `_get_unit_ui`
- L352-383 `_sync_unit_row`
- L397-398 `_debug_tools_allowed`
- L401-410 `_unhandled_key_input`
- L415-426 `_setup_debug_menu`
- L429-434 `_on_debug_button_pressed`
- L438-441 `_sync_debug_toggle`
- L444-446 `_set_debug_interactive`
- L451-454 `_on_debug_command_requested`
- L457-463 `_refresh_debug_menu`
- L466-469 `_debug_state`
- L473-486 `_debug_snapshot`
- L492-501 `_build_debug_targets`
- L504-509 `_debug_target_entry`

Uses: BattleOverlayController, Card, CardIconCatalog, DataLoader, DebugMenuPopup, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, HandBar, StatusIconCatalog, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: GDTest/CodeIndexTest.gd, GDTest/DebugMenuTest.gd, GDTest/HudTooltipTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, Scenes/BattleUnit/SpinePortrait.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd, Tools/check_navigation.gd
Loads: res://Scenes/BattleUnit/UnitUI.tscn

