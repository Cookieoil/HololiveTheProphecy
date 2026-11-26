<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.gd` — `class_name BattleScene` extends `GameUI`

`631` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends GameUI, 2 signal(s), 8 export(s), 45 function(s)

Sections: GameUI Overrides · Helpers & Interaction Handlers · Debug Menu · Battle Result · Telemetry Consent

Signals:
- L59 `action_decided(action_dict: Dictionary)`
- L60 `unit_selected_for_target(unit: Unit)`

Constants:
- L63 `INTENT_STAGGER: float = 0.08` — seconds between each enemy's intent appearing
- L67 `ICON_BUTTON_HOVER_TINT: Color = Color(1.25, 1.25, 1.25)` — The two top-bar action buttons draw no button chrome (see BattleScene.tscn), so hovering brightens their icon a little instead, the same cue the ultimate orbs g…

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
- L49 `consent_popup: TelemetryConsentPopup` — First-launch telemetry disclosure, built in code and mounted on its own top layer so it owns the screen until the player answers.
- L50 `consent_layer: CanvasLayer`
- L53 `telemetry_uploader: TelemetryUploader` — Background uploader for the telemetry outbox (Stage 2). Does nothing until `telemetry/endpoint` is configured in project settings.
- L56 `_awaiting_player_action: bool = false` — True only while GameManager awaits a player action: the one window in which a debug tool may be applied, because the turn loop is sitting on the action queue.
- L57 `_intent_cache: Dictionary[Unit, Dictionary] = {}`

Public API:
- L113-115 `on_card_played(card: Card, state: GameState) -> void`
- L121-123 `on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void` — Two cards in hand were fused into `result`: the hand plays the merge (the two cards drift into each other from where they were dropped, fold closed, and the mer…
- L128-129 `flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void` — Cards the game selected without asking (auto_top_n / auto_highest) get a short highlight so the player can see what was picked for them. `hostile` is set when a…
- L134-146 `show_battle_result(victory: bool) -> void` — End of battle: the turn loop is parked, so every player control is locked and the Victory / Defeat cutscene takes over the screen. Awaited by GameManager, so th…
- L151-156 `play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — `lead` is the fraction of the skill animation to wait for: 1.0 for the player's own actions, lower for chained enemy turns that overlap their animations (see Ga…
- L159-162 `play_unit_ultimate(unit: Unit) -> void`
- L164-169 `show_message(msg: String) -> void`
- L172-179 `show_game_state(state: GameState) -> void`
- L182-186 `show_hand_and_resources(state: GameState) -> void`
- L209-221 `show_enemy_intents(intents: Array[EnemyIntent]) -> void`
- L224-228 `clear_unit_intent(unit: Unit) -> void`
- L255-274 `get_player_action(state: GameState) -> Dictionary`
- L277-300 `ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]`
- L303-331 `ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]`

Private:
- L69-108 `_ready`
- L189-199 `_update_top_bar`
- L204-206 `_setup_icon_button_hover`
- L231-235 `_apply_cached_intents`
- L238-250 `_apply_intent_to`
- L336-341 `_on_merge_requested`
- L344-349 `_on_card_dropped_on_unit`
- L352-353 `_on_unit_clicked`
- L359-360 `_on_ally_ultimate_requested`
- L364-373 `_sync_overlay_units`
- L376-380 `_highlight_target_candidates`
- L383-390 `_get_unit_ui`
- L393-424 `_sync_unit_row`
- L438-439 `_debug_tools_allowed`
- L442-451 `_unhandled_key_input`
- L456-467 `_setup_debug_menu`
- L470-475 `_on_debug_button_pressed`
- L479-482 `_sync_debug_toggle`
- L485-487 `_set_debug_interactive`
- L492-495 `_on_debug_command_requested`
- L498-504 `_refresh_debug_menu`
- L507-510 `_debug_state`
- L514-527 `_debug_snapshot`
- L533-542 `_build_debug_targets`
- L552-567 `_setup_result_overlay`
- L573-575 `_on_restart_requested`
- L579-584 `_debug_target_entry`
- L591-599 `_setup_consent_gate`
- L605-613 `_run_consent_gate`
- L618-621 `_setup_telemetry_uploader`
- L624-629 `_should_prompt_consent`

Uses: BattleOverlayController, BattleResultOverlay, Card, CardIconCatalog, DataLoader, DebugMenuPopup, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, HandBar, StatusIconCatalog, TelemetryConsentPopup, TelemetryUploader, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: GDTest/BattleEndTest.gd, GDTest/CodeIndexTest.gd, GDTest/DebugMenuTest.gd, GDTest/HudTooltipTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, Scenes/BattleUnit/SpinePortrait.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/BattleResultOverlay.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd, Tools/check_navigation.gd
Loads: res://Scenes/BattleUnit/UnitUI.tscn, res://Scenes/BattleScene/Assets/icon2.png, res://Scenes/BattleScene/Assets/icon.svg

