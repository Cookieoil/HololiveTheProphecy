<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`1174` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · Enemy Turn · (+3 more)

Constants:
- L25 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L453 `DEBUG_HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L456 `DEBUG_SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L457 `DEBUG_SCOPE_ENEMIES: int = 1`
- L458 `DEBUG_SCOPE_ALL: int = 2`
- L462 `DEBUG_RESULT_NONE: int = 0` — Result-screen preview requested by the Debug menu: 0 = none, 1 = Victory, 2 = Defeat. The panel only asks; the player-action loop applies it, so a preview leave…
- L463 `DEBUG_RESULT_VICTORY: int = 1`
- L464 `DEBUG_RESULT_DEFEAT: int = 2`
- L467 `DEBUG_BUILD_ENGINE: int = -1` — Values for `debug_build_override`: the engine decides, or the suite forces the release / debug answer so the gate below can be exercised without an export.
- L468 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L469 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L17 `telemetry: TelemetryManager = TelemetryManager.new()` — Passive gameplay recorder (see Managers/TelemetryManager.gd). It is a no-op until the player has agreed to telemetry, so every hook below is safe to call uncond…
- L475 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…
- L479 `_debug_result_request: int = DEBUG_RESULT_NONE` — Result-screen preview the Debug menu asked for, applied by the player-action loop (see `_player_action_phase`). `DEBUG_RESULT_NONE` when there is none.

Public API:
- L43-69 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L487-490 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

Private:
- L71-79 `_spawn_wave`
- L84-179 `_run_game_loop`
- L185-186 `_close_turn_record`
- L192-195 `_exit_tree`
- L196-197 `_show_instructions`
- L216-286 `_player_action_phase`
- L297-306 `_resolve_enemy_clear_after_action`
- L309-378 `_handle_play`
- L380-408 `_handle_ally_ultimate`
- L410-414 `_refresh_enemy_intents`
- L415-435 `_handle_merge`
- L438-446 `_handle_convert`
- L501-590 `_handle_debug_command`
- L595-611 `_coerce_int`
- L615-619 `_coerce_dict`
- L626-641 `_debug_targets`
- L647-653 `_debug_step_dice`
- L656-657 `_debug_log`
- L661-665 `_debug_hp_summary`
- L668-677 `_debug_spawn_random`
- L680-689 `_debug_spawn_custom`
- L692-698 `_debug_draw`
- L701-710 `_debug_buff_hand`
- L713-722 `_debug_discard_random`
- L725-732 `_debug_clear_hand`
- L735-742 `_debug_set_moxie`
- L745-750 `_debug_heal`
- L753-762 `_debug_damage`
- L765-770 `_debug_shield`
- L773-778 `_debug_clear_shield`
- L781-793 `_debug_kill`
- L796-805 `_debug_apply_status`
- L808-812 `_debug_clear_statuses`
- L817-865 `_build_ally_context`
- L868-908 `_build_enemy_context`
- L912-932 `_resolve_skill`
- L937-947 `_roll_enemy_intents`
- L950-1005 `_resolve_enemy_turns`
- L1007-1026 `_execute_enemy_ultimate`
- L1031-1051 `_try_advance_wave`
- L1060-1086 `_finish_battle`
- L1090-1094 `_clear_all_moxie`
- L1098-1099 `_has_remaining_waves`
- L1104-1105 `_is_final_wave_cleared`
- L1114-1130 `_end_of_turn_cleanup`
- L1134-1171 `_log_status_event`

Uses: Card, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, TelemetryManager, Unit, UnitData
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/DiffReviewTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/TelemetryTest.gd, GDTest/TriageParserTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Tools/check_navigation.gd
Loads: —

