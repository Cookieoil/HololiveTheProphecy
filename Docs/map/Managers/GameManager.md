<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`1183` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Helpers · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+4 more)

Constants:
- L25 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L466 `DEBUG_HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L469 `DEBUG_SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L470 `DEBUG_SCOPE_ENEMIES: int = 1`
- L471 `DEBUG_SCOPE_ALL: int = 2`
- L475 `DEBUG_RESULT_NONE: int = 0` — Result-screen preview requested by the Debug menu: 0 = none, 1 = Victory, 2 = Defeat. The panel only asks; the player-action loop applies it, so a preview leave…
- L476 `DEBUG_RESULT_VICTORY: int = 1`
- L477 `DEBUG_RESULT_DEFEAT: int = 2`
- L480 `DEBUG_BUILD_ENGINE: int = -1` — Values for `debug_build_override`: the engine decides, or the suite forces the release / debug answer so the gate below can be exercised without an export.
- L481 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L482 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L17 `telemetry: TelemetryManager = TelemetryManager.new()` — Passive gameplay recorder (see Managers/TelemetryManager.gd). It is a no-op until the player has agreed to telemetry, so every hook below is safe to call uncond…
- L488 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…
- L492 `_debug_result_request: int = DEBUG_RESULT_NONE` — Result-screen preview the Debug menu asked for, applied by the player-action loop (see `_player_action_phase`). `DEBUG_RESULT_NONE` when there is none.

Public API:
- L56-82 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L500-503 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

Private:
- L29-31 `_color_unit`
- L33-35 `_color_value`
- L37-39 `_color_card_value`
- L84-92 `_spawn_wave`
- L97-192 `_run_game_loop`
- L198-199 `_close_turn_record`
- L205-208 `_exit_tree`
- L209-210 `_show_instructions`
- L229-299 `_player_action_phase`
- L310-319 `_resolve_enemy_clear_after_action`
- L322-391 `_handle_play`
- L393-421 `_handle_ally_ultimate`
- L423-427 `_refresh_enemy_intents`
- L428-448 `_handle_merge`
- L451-459 `_handle_convert`
- L514-608 `_handle_debug_command`
- L614-630 `_coerce_int`
- L633-637 `_coerce_dict`
- L644-659 `_debug_targets`
- L663-664 `_debug_log`
- L668-672 `_debug_hp_summary`
- L675-684 `_debug_spawn_random`
- L687-696 `_debug_spawn_custom`
- L699-705 `_debug_draw`
- L708-717 `_debug_buff_hand`
- L720-729 `_debug_discard_random`
- L732-739 `_debug_clear_hand`
- L742-749 `_debug_set_moxie`
- L752-757 `_debug_heal`
- L760-769 `_debug_damage`
- L772-777 `_debug_shield`
- L780-785 `_debug_clear_shield`
- L788-800 `_debug_kill`
- L803-812 `_debug_apply_status`
- L815-819 `_debug_clear_statuses`
- L824-872 `_build_ally_context`
- L875-915 `_build_enemy_context`
- L919-939 `_resolve_skill`
- L944-954 `_roll_enemy_intents`
- L957-1012 `_resolve_enemy_turns`
- L1014-1033 `_execute_enemy_ultimate`
- L1038-1060 `_try_advance_wave`
- L1069-1095 `_finish_battle`
- L1099-1103 `_clear_all_moxie`
- L1107-1108 `_has_remaining_waves`
- L1113-1114 `_is_final_wave_cleared`
- L1123-1139 `_end_of_turn_cleanup`
- L1143-1180 `_log_status_event`

Uses: Card, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, TelemetryManager, Unit, UnitData
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/DiffReviewTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/TelemetryTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Tools/check_navigation.gd
Loads: —

