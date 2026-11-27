<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.gd` — `class_name BattleScene` extends `GameUI`

`670` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends GameUI, 2 signal(s), 11 export(s), 46 function(s)

Sections: GameUI Overrides · Helpers & Interaction Handlers · Debug Menu · Battle Result · Telemetry Consent

Signals:
- L69 `action_decided(action_dict: Dictionary)`
- L70 `unit_selected_for_target(unit: Unit)`

Constants:
- L73 `INTENT_STAGGER: float = 0.08` — seconds between each enemy's intent appearing
- L77 `ICON_BUTTON_HOVER_TINT: Color = Color(1.25, 1.25, 1.25)` — The two top-bar action buttons draw no button chrome (see BattleScene.tscn), so hovering brightens their icon a little instead, the same cue the ultimate orbs g…

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
- L26 `flag_overrides: Dictionary = {}` — Tester/tooling seam: forces staged flags on or off for this battle, on top of the rollout in features.json (see Core/FeatureFlags.gd). Empty in a normal run.

Onready:
- L28 `hand_bar: HandBar`
- L29 `allies_container: HBoxContainer`
- L30 `enemies_container: HBoxContainer`
- L32 `battle_overlay: BattleOverlayController`
- L34 `wave_value_label: Label`
- L35 `dice_value_label: Label`
- L36 `actions_value_label: Label`
- L37 `merges_value_label: Label`
- L38 `deck_value_label: Label`
- L39 `discard_value_label: Label`
- L40 `convert_button: Button`
- L41 `end_turn_button: Button`
- L42 `log_label: RichTextLabel`
- L44 `debug_layer: CanvasLayer`
- L45 `debug_button: Button`

State:
- L47 `game_manager: GameManager`
- L49 `debug_menu: DebugMenuPopup` — Tester overlay, built in code and mounted on `debug_layer`.
- L51 `result_overlay: BattleResultOverlay` — End-of-battle cutscene, built in code and mounted on its own top layer.
- L52 `result_layer: CanvasLayer`
- L56 `result_back_buffer: BackBufferCopy` — Copies the rendered battle into the back buffer, so the cutscene's backdrop shader can grade what is behind it (a CanvasItem screen texture needs a BackBufferCo…
- L59 `consent_popup: TelemetryConsentPopup` — First-launch telemetry disclosure, built in code and mounted on its own top layer so it owns the screen until the player answers.
- L60 `consent_layer: CanvasLayer`
- L63 `telemetry_uploader: TelemetryUploader` — Background uploader for the telemetry outbox (Stage 2). Does nothing until `telemetry/endpoint` is configured in project settings.
- L66 `_awaiting_player_action: bool = false` — True only while GameManager awaits a player action: the one window in which a debug tool may be applied, because the turn loop is sitting on the action queue.
- L67 `_intent_cache: Dictionary[Unit, Dictionary] = {}`

Public API:
- L130-132 `on_card_played(card: Card, state: GameState) -> void`
- L138-140 `on_cards_merged(source_a: Card, source_b: Card, result: Card, state: GameState) -> void` — Two cards in hand were fused into `result`: the hand plays the merge (the two cards drift into each other from where they were dropped, fold closed, and the mer…
- L145-146 `flash_auto_selected_cards(cards: Array[Card], hostile: bool = false) -> void` — Cards the game selected without asking (auto_top_n / auto_highest) get a short highlight so the player can see what was picked for them. `hostile` is set when a…
- L151-163 `show_battle_result(victory: bool) -> void` — End of battle: the turn loop is parked, so every player control is locked and the Victory / Defeat cutscene takes over the screen. Awaited by GameManager, so th…
- L168-173 `play_unit_skill(unit: Unit, skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — `lead` is the fraction of the skill animation to wait for: 1.0 for the player's own actions, lower for chained enemy turns that overlap their animations (see Ga…
- L176-179 `play_unit_ultimate(unit: Unit) -> void`
- L181-189 `show_message(msg: String) -> void`
- L192-199 `show_game_state(state: GameState) -> void`
- L202-206 `show_hand_and_resources(state: GameState) -> void`
- L229-241 `show_enemy_intents(intents: Array[EnemyIntent]) -> void`
- L244-248 `clear_unit_intent(unit: Unit) -> void`
- L275-294 `get_player_action(state: GameState) -> Dictionary`
- L297-320 `ask_pick_targets(units: Array[Unit], count: int) -> Array[Unit]`
- L323-351 `ask_pick_cards(cards: Array[Card], count: int) -> Array[Card]`

Private:
- L79-125 `_ready`
- L209-219 `_update_top_bar`
- L224-226 `_setup_icon_button_hover`
- L251-255 `_apply_cached_intents`
- L258-270 `_apply_intent_to`
- L356-361 `_on_merge_requested`
- L364-369 `_on_card_dropped_on_unit`
- L372-373 `_on_unit_clicked`
- L379-380 `_on_ally_ultimate_requested`
- L384-393 `_sync_overlay_units`
- L396-400 `_highlight_target_candidates`
- L403-410 `_get_unit_ui`
- L413-444 `_sync_unit_row`
- L458-459 `_debug_tools_allowed`
- L462-471 `_unhandled_key_input`
- L476-487 `_setup_debug_menu`
- L490-495 `_on_debug_button_pressed`
- L499-502 `_sync_debug_toggle`
- L505-507 `_set_debug_interactive`
- L512-515 `_on_debug_command_requested`
- L518-524 `_refresh_debug_menu`
- L527-530 `_debug_state`
- L534-548 `_debug_snapshot`
- L554-563 `_build_debug_targets`
- L573-588 `_setup_result_overlay`
- L594-596 `_on_restart_requested`
- L600-605 `_debug_target_entry`
- L612-624 `_setup_consent_gate`
- L630-638 `_run_consent_gate`
- L643-649 `_setup_telemetry_uploader`
- L654-656 `_on_game_over_drain`
- L663-668 `_should_prompt_consent`

Uses: BattleOverlayController, BattleResultOverlay, Card, CardIconCatalog, DataLoader, DebugMenuPopup, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, HandBar, StatusIconCatalog, TelemetryConsent, TelemetryConsentPopup, TelemetryUploader, TooltipIconCatalog, Unit, UnitData, UnitUI
Used by: GDTest/BattleEndTest.gd, GDTest/DebugMenuTest.gd, GDTest/MessageLogTest.gd, GDTest/UiSnapshotTest.gd, Tools/SnapshotRunner.gd
Loads: res://Scenes/BattleUnit/UnitUI.tscn, res://Scenes/BattleScene/Assets/icon2.png, res://Scenes/BattleScene/Assets/icon.svg

