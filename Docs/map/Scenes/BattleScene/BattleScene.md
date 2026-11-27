<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.gd` — `class_name BattleScene` extends `GameUI`

`659` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends GameUI, 2 signal(s), 10 export(s), 46 function(s)

Sections: GameUI Overrides · Helpers & Interaction Handlers · Debug Menu · Battle Result · Telemetry Consent

Signals:
- L66 `action_decided(action_dict: Dictionary)`
- L67 `unit_selected_for_target(unit: Unit)`

Constants:
- L70 `INTENT_STAGGER: float = 0.08` — seconds between each enemy's intent appearing
- L74 `ICON_BUTTON_HOVER_TINT: Color = Color(1.25, 1.25, 1.25)` — The two top-bar action buttons draw no button chrome (see BattleScene.tscn), so hovering brightens their icon a little instead, the same cue the ultimate orbs g…

Exports:
- L5 `icon_catalog: CardIconCatalog`
- L6 `status_icon_catalog: StatusIconCatalog`
- L7 `tooltip_icon_catalog: TooltipIconCatalog`
- L8 `unit_ui_scene: PackedScene`
- L9 `turn_dice_progression: Array[int] = []`
- L12 `debug_menu_enabled: bool = true` — Tester tools (the Debug button + F1). Turn off for a build that must not show them. A release export hides them regardless of this flag — see `_debug_tools_allo…
- L15 `victory_icon: Texture2D` — Emblems for the end-of-battle cutscene. Placeholder art until the hand-drawn icons land; the overlay shows them framed above the VICTORY / DEFEAT banner.
- L16 `defeat_icon: Texture2D`
- L19 `fixed_seed_override: int = 0` — Pins the run seed for replay tooling: the dealt hand, the rolls and the enemy intents become identical on every machine. 0 keeps the normal random seed.
- L23 `consent_path_override: String = ""` — Points the telemetry disclosure at a throwaway file instead of the player's real `user://` answer. Set by the UI snapshot runner so a capture never overwrites t…

Onready:
- L25 `hand_bar: HandBar`
- L26 `allies_container: HBoxContainer`
- L27 `enemies_container: HBoxContainer`
- L29 `battle_overlay: BattleOverlayController`
- L31 `wave_value_label: Label`
- L32 `dice_value_label: Label`
- L33 `actions_value_label: Label`
- L34 `merges_value_label: Label`
- L35 `deck_value_label: Label`
- L36 `discard_value_label: Label`
- L37 `convert_button: Button`
- L38 `end_turn_button: Button`
- L39 `log_label: Label`
- L41 `debug_layer: CanvasLayer`
- L42 `debug_button: Button`

State:
- L44 `game_manager: GameManager`
- L46 `debug_menu: DebugMenuPopup` — Tester overlay, built in code and mounted on `debug_layer`.
- L48 `result_overlay: BattleResultOverlay` — End-of-battle cutscene, built in code and mounted on its own top layer.
- L49 `result_layer: CanvasLayer`
- L53 `result_back_buffer: BackBufferCopy` — Copies the rendered battle into the back buffer, so the cutscene's backdrop shader can grade what is behind it (a CanvasItem screen texture needs a BackBufferCo…
- L56 `consent_popup: TelemetryConsentPopup` — First-launch telemetry disclosure, built in code and mounted on its own top layer so it owns the screen until the player answers.
- L57 `consent_layer: CanvasLayer`
- L60 `telemetry_uploader: TelemetryUploader` — Background uploader for the telemetry outbox (Stage 2). Does nothing until `telemetry/endpoint` is configured in project settings.
- L63 `_awaiting_player_action: bool = false` — True only while GameManager awaits a player action: the one window in which a debug tool may be applied, because the turn loop is sitting on the action queue.
- L64 `_intent_cache: Dictionary[Unit, Dictionary] = {}`

Public API:
- L123-125 `on_card_played(card: Card, state: GameState) -> void`
- L131-133 `on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void` — Two cards in hand were fused into `result`: the hand plays the merge (the two cards drift into each other from where they were dropped, fold closed, and the mer…
- L138-139 `flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void` — Cards the game selected without asking (auto_top_n / auto_highest) get a short highlight so the player can see what was picked for them. `hostile` is set when a…
- L144-156 `show_battle_result(victory: bool) -> void` — End of battle: the turn loop is parked, so every player control is locked and the Victory / Defeat cutscene takes over the screen. Awaited by GameManager, so th…
- L161-166 `play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — `lead` is the fraction of the skill animation to wait for: 1.0 for the player's own actions, lower for chained enemy turns that overlap their animations (see Ga…
- L169-172 `play_unit_ultimate(unit: Unit) -> void`
- L174-179 `show_message(msg: String) -> void`
- L182-189 `show_game_state(state: GameState) -> void`
- L192-196 `show_hand_and_resources(state: GameState) -> void`
- L219-231 `show_enemy_intents(intents: Array[EnemyIntent]) -> void`
- L234-238 `clear_unit_intent(unit: Unit) -> void`
- L265-284 `get_player_action(state: GameState) -> Dictionary`
- L287-310 `ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]`
- L313-341 `ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]`

Private:
- L76-118 `_ready`
- L199-209 `_update_top_bar`
- L214-216 `_setup_icon_button_hover`
- L241-245 `_apply_cached_intents`
- L248-260 `_apply_intent_to`
- L346-351 `_on_merge_requested`
- L354-359 `_on_card_dropped_on_unit`
- L362-363 `_on_unit_clicked`
- L369-370 `_on_ally_ultimate_requested`
- L374-383 `_sync_overlay_units`
- L386-390 `_highlight_target_candidates`
- L393-400 `_get_unit_ui`
- L403-434 `_sync_unit_row`
- L448-449 `_debug_tools_allowed`
- L452-461 `_unhandled_key_input`
- L466-477 `_setup_debug_menu`
- L480-485 `_on_debug_button_pressed`
- L489-492 `_sync_debug_toggle`
- L495-497 `_set_debug_interactive`
- L502-505 `_on_debug_command_requested`
- L508-514 `_refresh_debug_menu`
- L517-520 `_debug_state`
- L524-537 `_debug_snapshot`
- L543-552 `_build_debug_targets`
- L562-577 `_setup_result_overlay`
- L583-585 `_on_restart_requested`
- L589-594 `_debug_target_entry`
- L601-613 `_setup_consent_gate`
- L619-627 `_run_consent_gate`
- L632-638 `_setup_telemetry_uploader`
- L643-645 `_on_game_over_drain`
- L652-657 `_should_prompt_consent`

Uses: BattleOverlayController, BattleResultOverlay, Card, CardIconCatalog, DataLoader, DebugMenuPopup, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, HandBar, StatusIconCatalog, TelemetryConsent, TelemetryConsentPopup, TelemetryUploader, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: GDTest/BattleEndTest.gd, GDTest/CodeIndexTest.gd, GDTest/DebugMenuTest.gd, GDTest/HudTooltipTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TooltipIconCatalogTest.gd, GDTest/UiSnapshotTest.gd, Scenes/BattleUnit/SpinePortrait.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/BattleResultOverlay.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd, Tools/SnapshotRunner.gd, Tools/check_navigation.gd
Loads: res://Scenes/BattleUnit/UnitUI.tscn, res://Scenes/BattleScene/Assets/icon2.png, res://Scenes/BattleScene/Assets/icon.svg

