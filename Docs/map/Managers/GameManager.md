<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`1177` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Helpers · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+4 more)

Constants:
- L17 `WAVE_MODE_MAP: Dictionary = {` — JSON/config string -> WaveTransition (config.json stores readable names).
- L27 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L505 `DEBUG_HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L508 `DEBUG_SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L509 `DEBUG_SCOPE_ENEMIES: int = 1`
- L510 `DEBUG_SCOPE_ALL: int = 2`
- L514 `DEBUG_RESULT_NONE: int = 0` — Result-screen preview requested by the Debug menu: 0 = none, 1 = Victory, 2 = Defeat. The panel only asks; the player-action loop applies it, so a preview leave…
- L515 `DEBUG_RESULT_VICTORY: int = 1`
- L516 `DEBUG_RESULT_DEFEAT: int = 2`
- L519 `DEBUG_BUILD_ENGINE: int = -1` — Values for `debug_build_override`: the engine decides, or the suite forces the release / debug answer so the gate below can be exercised without an export.
- L520 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L521 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L527 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…
- L531 `_debug_result_request: int = DEBUG_RESULT_NONE` — Result-screen preview the Debug menu asked for, applied by the player-action loop (see `_player_action_phase`). `DEBUG_RESULT_NONE` when there is none.

Public API:
- L58-76 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L539-542 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

Private:
- L31-33 `_color_unit`
- L35-37 `_color_value`
- L39-41 `_color_card_value`
- L78-96 `_apply_config`
- L101-102 `_config_int`
- L106-122 `_coerce_int`
- L126-143 `_config_decklist`
- L147-156 `_config_int_list`
- L157-165 `_spawn_wave`
- L170-259 `_run_game_loop`
- L260-261 `_show_instructions`
- L280-339 `_player_action_phase`
- L350-359 `_resolve_enemy_clear_after_action`
- L362-431 `_handle_play`
- L433-461 `_handle_ally_ultimate`
- L463-467 `_refresh_enemy_intents`
- L468-487 `_handle_merge`
- L490-498 `_handle_convert`
- L553-647 `_handle_debug_command`
- L651-655 `_coerce_dict`
- L662-677 `_debug_targets`
- L681-682 `_debug_log`
- L686-690 `_debug_hp_summary`
- L693-702 `_debug_spawn_random`
- L705-714 `_debug_spawn_custom`
- L717-723 `_debug_draw`
- L726-735 `_debug_buff_hand`
- L738-747 `_debug_discard_random`
- L750-757 `_debug_clear_hand`
- L760-767 `_debug_set_moxie`
- L770-775 `_debug_heal`
- L778-787 `_debug_damage`
- L790-795 `_debug_shield`
- L798-803 `_debug_clear_shield`
- L806-818 `_debug_kill`
- L821-830 `_debug_apply_status`
- L833-837 `_debug_clear_statuses`
- L842-884 `_build_ally_context`
- L887-926 `_build_enemy_context`
- L930-950 `_resolve_skill`
- L955-965 `_roll_enemy_intents`
- L968-1018 `_resolve_enemy_turns`
- L1019-1037 `_execute_enemy_ultimate`
- L1042-1064 `_try_advance_wave`
- L1073-1094 `_finish_battle`
- L1098-1102 `_clear_all_moxie`
- L1106-1107 `_has_remaining_waves`
- L1112-1113 `_is_final_wave_cleared`
- L1122-1138 `_end_of_turn_cleanup`
- L1142-1174 `_log_status_event`

Uses: Card, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, Unit, UnitData
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Tools/check_navigation.gd, Tools/validate_gameData.gd
Loads: —

