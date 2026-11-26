<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.gd` — `class_name BattleScene` extends `GameUI`

`574` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends GameUI, 2 signal(s), 8 export(s), 41 function(s)

Sections: GameUI Overrides · Helpers & Interaction Handlers · Debug Menu · Battle Result

Signals:
- L52 `action_decided(action_dict: Dictionary)`
- L53 `unit_selected_for_target(unit: Unit)`

Constants:
- L56 `INTENT_STAGGER: float = 0.08` — seconds between each enemy's intent appearing
- L60 `ICON_BUTTON_HOVER_TINT: Color = Color(1.25, 1.25, 1.25)` — The two top-bar action buttons draw no button chrome (see BattleScene.tscn), so hovering brightens their icon a little instead, the same cue the ultimate orbs g…

Exports:
- L5 `icon_catalog: CardIconCatalog`
- L6 `status_icon_catalog: StatusIconCatalog`
- L7 `tooltip_icon_catalog: TooltipIconCatalog`
- L8 `unit_ui_scene: PackedScene`
- L9 `turn_dice_progression: Array[int] = []`
- L12 `debug_menu_enabled: bool = true` — Tester tools (the Debug button + F1). Turn off for a build that must not show them. A release export hides them regardless of this flag — see `_debug_tools_allo…
- L15 `victory_icon: Texture2D` — Emblems for the end-of-battle cutscene. Placeholder art until the hand-drawn icons land; the overlay shows them framed above the VICTORY / DEFEAT banner.
- L16 `defeat_icon: Texture2D`

Onready:
- L18 `hand_bar: HandBar`
- L19 `allies_container: HBoxContainer`
- L20 `enemies_container: HBoxContainer`
- L22 `battle_overlay: BattleOverlayController`
- L24 `wave_value_label: Label`
- L25 `dice_value_label: Label`
- L26 `actions_value_label: Label`
- L27 `merges_value_label: Label`
- L28 `deck_value_label: Label`
- L29 `discard_value_label: Label`
- L30 `convert_button: Button`
- L31 `end_turn_button: Button`
- L32 `log_label: Label`
- L34 `debug_layer: CanvasLayer`
- L35 `debug_button: Button`

State:
- L37 `game_manager: GameManager`
- L39 `debug_menu: DebugMenuPopup` — Tester overlay, built in code and mounted on `debug_layer`.
- L41 `result_overlay: BattleResultOverlay` — End-of-battle cutscene, built in code and mounted on its own top layer.
- L42 `result_layer: CanvasLayer`
- L46 `result_back_buffer: BackBufferCopy` — Copies the rendered battle into the back buffer, so the cutscene's backdrop shader can grade what is behind it (a CanvasItem screen texture needs a BackBufferCo…
- L49 `_awaiting_player_action: bool = false` — True only while GameManager awaits a player action: the one window in which a debug tool may be applied, because the turn loop is sitting on the action queue.
- L50 `_intent_cache: Dictionary[Unit, Dictionary] = {}`

Public API:
- L101-103 `on_card_played(card: Card, state: GameState) -> void`
- L109-111 `on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void` — Two cards in hand were fused into `result`: the hand plays the merge (the two cards drift into each other from where they were dropped, fold closed, and the mer…
- L116-117 `flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void` — Cards the game selected without asking (auto_top_n / auto_highest) get a short highlight so the player can see what was picked for them. `hostile` is set when a…
- L122-134 `show_battle_result(victory: bool) -> void` — End of battle: the turn loop is parked, so every player control is locked and the Victory / Defeat cutscene takes over the screen. Awaited by GameManager, so th…
- L139-144 `play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — `lead` is the fraction of the skill animation to wait for: 1.0 for the player's own actions, lower for chained enemy turns that overlap their animations (see Ga…
- L147-150 `play_unit_ultimate(unit: Unit) -> void`
- L152-157 `show_message(msg: String) -> void`
- L160-167 `show_game_state(state: GameState) -> void`
- L170-174 `show_hand_and_resources(state: GameState) -> void`
- L197-209 `show_enemy_intents(intents: Array[EnemyIntent]) -> void`
- L212-216 `clear_unit_intent(unit: Unit) -> void`
- L243-262 `get_player_action(state: GameState) -> Dictionary`
- L265-288 `ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]`
- L291-319 `ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]`

Private:
- L62-96 `_ready`
- L177-187 `_update_top_bar`
- L192-194 `_setup_icon_button_hover`
- L219-223 `_apply_cached_intents`
- L226-238 `_apply_intent_to`
- L324-329 `_on_merge_requested`
- L332-337 `_on_card_dropped_on_unit`
- L340-341 `_on_unit_clicked`
- L347-348 `_on_ally_ultimate_requested`
- L352-361 `_sync_overlay_units`
- L364-368 `_highlight_target_candidates`
- L371-378 `_get_unit_ui`
- L381-412 `_sync_unit_row`
- L426-427 `_debug_tools_allowed`
- L430-439 `_unhandled_key_input`
- L444-455 `_setup_debug_menu`
- L458-463 `_on_debug_button_pressed`
- L467-470 `_sync_debug_toggle`
- L473-475 `_set_debug_interactive`
- L480-483 `_on_debug_command_requested`
- L486-492 `_refresh_debug_menu`
- L495-498 `_debug_state`
- L502-515 `_debug_snapshot`
- L521-530 `_build_debug_targets`
- L540-555 `_setup_result_overlay`
- L561-563 `_on_restart_requested`
- L567-572 `_debug_target_entry`

Uses: BattleOverlayController, BattleResultOverlay, Card, CardIconCatalog, DataLoader, DebugMenuPopup, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, HandBar, StatusIconCatalog, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: GDTest/BattleEndTest.gd, GDTest/CodeIndexTest.gd, GDTest/DebugMenuTest.gd, GDTest/HudTooltipTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, Scenes/BattleUnit/SpinePortrait.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/BattleResultOverlay.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd, Tools/check_navigation.gd
Loads: res://Scenes/BattleUnit/UnitUI.tscn, res://Scenes/BattleScene/Assets/icon2.png, res://Scenes/BattleScene/Assets/icon.svg

