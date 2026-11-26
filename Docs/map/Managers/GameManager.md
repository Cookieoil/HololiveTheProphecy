<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`1211` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Helpers · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+4 more)

Constants:
- L21 `WAVE_MODE_MAP: Dictionary = {` — JSON/config string -> WaveTransition (config.json stores readable names).
- L31 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L528 `DEBUG_HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L531 `DEBUG_SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L532 `DEBUG_SCOPE_ENEMIES: int = 1`
- L533 `DEBUG_SCOPE_ALL: int = 2`
- L537 `DEBUG_RESULT_NONE: int = 0` — Result-screen preview requested by the Debug menu: 0 = none, 1 = Victory, 2 = Defeat. The panel only asks; the player-action loop applies it, so a preview leave…
- L538 `DEBUG_RESULT_VICTORY: int = 1`
- L539 `DEBUG_RESULT_DEFEAT: int = 2`
- L542 `DEBUG_BUILD_ENGINE: int = -1` — Values for `debug_build_override`: the engine decides, or the suite forces the release / debug answer so the gate below can be exercised without an export.
- L543 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L544 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L17 `telemetry: TelemetryManager = TelemetryManager.new()` — Passive gameplay recorder (see Managers/TelemetryManager.gd). It is a no-op until the player has agreed to telemetry, so every hook below is safe to call uncond…
- L550 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…
- L554 `_debug_result_request: int = DEBUG_RESULT_NONE` — Result-screen preview the Debug menu asked for, applied by the player-action loop (see `_player_action_phase`). `DEBUG_RESULT_NONE` when there is none.

Public API:
- L62-83 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L562-565 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

Private:
- L35-37 `_color_unit`
- L39-41 `_color_value`
- L43-45 `_color_card_value`
- L85-103 `_apply_config`
- L108-109 `_config_int`
- L113-129 `_coerce_int`
- L133-150 `_config_decklist`
- L154-163 `_config_int_list`
- L164-172 `_spawn_wave`
- L177-270 `_run_game_loop`
- L271-272 `_show_instructions`
- L291-361 `_player_action_phase`
- L372-381 `_resolve_enemy_clear_after_action`
- L384-453 `_handle_play`
- L455-483 `_handle_ally_ultimate`
- L485-489 `_refresh_enemy_intents`
- L490-510 `_handle_merge`
- L513-521 `_handle_convert`
- L576-670 `_handle_debug_command`
- L674-678 `_coerce_dict`
- L685-700 `_debug_targets`
- L704-705 `_debug_log`
- L709-713 `_debug_hp_summary`
- L716-725 `_debug_spawn_random`
- L728-737 `_debug_spawn_custom`
- L740-746 `_debug_draw`
- L749-758 `_debug_buff_hand`
- L761-770 `_debug_discard_random`
- L773-780 `_debug_clear_hand`
- L783-790 `_debug_set_moxie`
- L793-798 `_debug_heal`
- L801-810 `_debug_damage`
- L813-818 `_debug_shield`
- L821-826 `_debug_clear_shield`
- L829-841 `_debug_kill`
- L844-853 `_debug_apply_status`
- L856-860 `_debug_clear_statuses`
- L865-913 `_build_ally_context`
- L916-955 `_build_enemy_context`
- L959-979 `_resolve_skill`
- L984-994 `_roll_enemy_intents`
- L997-1047 `_resolve_enemy_turns`
- L1048-1066 `_execute_enemy_ultimate`
- L1071-1093 `_try_advance_wave`
- L1102-1128 `_finish_battle`
- L1132-1136 `_clear_all_moxie`
- L1140-1141 `_has_remaining_waves`
- L1146-1147 `_is_final_wave_cleared`
- L1156-1172 `_end_of_turn_cleanup`
- L1176-1208 `_log_status_event`

Uses: Card, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, TelemetryManager, Unit, UnitData
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/TelemetryTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Tools/check_navigation.gd, Tools/validate_gameData.gd
Loads: —

