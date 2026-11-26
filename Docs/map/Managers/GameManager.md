<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`1256` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Helpers · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+4 more)

Constants:
- L21 `WAVE_MODE_MAP: Dictionary = {` — JSON/config string -> WaveTransition (config.json stores readable names).
- L31 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L560 `DEBUG_HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L563 `DEBUG_SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L564 `DEBUG_SCOPE_ENEMIES: int = 1`
- L565 `DEBUG_SCOPE_ALL: int = 2`
- L569 `DEBUG_RESULT_NONE: int = 0` — Result-screen preview requested by the Debug menu: 0 = none, 1 = Victory, 2 = Defeat. The panel only asks; the player-action loop applies it, so a preview leave…
- L570 `DEBUG_RESULT_VICTORY: int = 1`
- L571 `DEBUG_RESULT_DEFEAT: int = 2`
- L574 `DEBUG_BUILD_ENGINE: int = -1` — Values for `debug_build_override`: the engine decides, or the suite forces the release / debug answer so the gate below can be exercised without an export.
- L575 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L576 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L17 `telemetry: TelemetryManager = TelemetryManager.new()` — Passive gameplay recorder (see Managers/TelemetryManager.gd). It is a no-op until the player has agreed to telemetry, so every hook below is safe to call uncond…
- L582 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…
- L586 `_debug_result_request: int = DEBUG_RESULT_NONE` — Result-screen preview the Debug menu asked for, applied by the player-action loop (see `_player_action_phase`). `DEBUG_RESULT_NONE` when there is none.

Public API:
- L62-87 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L594-597 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

Private:
- L35-37 `_color_unit`
- L39-41 `_color_value`
- L43-45 `_color_card_value`
- L89-107 `_apply_config`
- L112-113 `_config_int`
- L118-123 `_config_seed`
- L127-143 `_coerce_int`
- L147-164 `_config_decklist`
- L168-177 `_config_int_list`
- L178-186 `_spawn_wave`
- L191-286 `_run_game_loop`
- L292-293 `_close_turn_record`
- L299-302 `_exit_tree`
- L303-304 `_show_instructions`
- L323-393 `_player_action_phase`
- L404-413 `_resolve_enemy_clear_after_action`
- L416-485 `_handle_play`
- L487-515 `_handle_ally_ultimate`
- L517-521 `_refresh_enemy_intents`
- L522-542 `_handle_merge`
- L545-553 `_handle_convert`
- L608-702 `_handle_debug_command`
- L706-710 `_coerce_dict`
- L717-732 `_debug_targets`
- L736-737 `_debug_log`
- L741-745 `_debug_hp_summary`
- L748-757 `_debug_spawn_random`
- L760-769 `_debug_spawn_custom`
- L772-778 `_debug_draw`
- L781-790 `_debug_buff_hand`
- L793-802 `_debug_discard_random`
- L805-812 `_debug_clear_hand`
- L815-822 `_debug_set_moxie`
- L825-830 `_debug_heal`
- L833-842 `_debug_damage`
- L845-850 `_debug_shield`
- L853-858 `_debug_clear_shield`
- L861-873 `_debug_kill`
- L876-885 `_debug_apply_status`
- L888-892 `_debug_clear_statuses`
- L897-945 `_build_ally_context`
- L948-988 `_build_enemy_context`
- L992-1012 `_resolve_skill`
- L1017-1027 `_roll_enemy_intents`
- L1030-1085 `_resolve_enemy_turns`
- L1087-1106 `_execute_enemy_ultimate`
- L1111-1133 `_try_advance_wave`
- L1142-1168 `_finish_battle`
- L1172-1176 `_clear_all_moxie`
- L1180-1181 `_has_remaining_waves`
- L1186-1187 `_is_final_wave_cleared`
- L1196-1212 `_end_of_turn_cleanup`
- L1216-1253 `_log_status_event`

Uses: Card, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, TelemetryManager, Unit, UnitData
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/TelemetryTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Tools/check_navigation.gd, Tools/validate_gameData.gd
Loads: —

