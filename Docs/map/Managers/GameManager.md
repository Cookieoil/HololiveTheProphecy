<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`885` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Lifecycle Methods · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+4 more)

Constants:
- L30 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L474 `DEBUG_BUILD_ENGINE: int = -1` — The tester tools themselves live in Managers/DebugCommandRunner.gd, which also owns the constants naming their scopes and their result previews (`DebugCommandRu…
- L475 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L476 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L17 `telemetry: TelemetryManager = TelemetryManager.new()` — Passive gameplay recorder (see Managers/TelemetryManager.gd). It is a no-op until the player has agreed to telemetry, so every hook below is safe to call uncond…
- L22 `_debug: DebugCommandRunner = DebugCommandRunner.new()` — Tester tool table (see Managers/DebugCommandRunner.gd). It holds no board of its own - it is handed `state` and `ui` per command - and it *asks* for the two too…
- L482 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…

Public API:
- L59-85 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L491-494 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

Private:
- L39-41 `_ready`
- L87-95 `_spawn_wave`
- L100-195 `_run_game_loop`
- L201-202 `_close_turn_record`
- L208-211 `_exit_tree`
- L212-213 `_show_instructions`
- L232-302 `_player_action_phase`
- L313-322 `_resolve_enemy_clear_after_action`
- L325-394 `_handle_play`
- L396-424 `_handle_ally_ultimate`
- L426-430 `_refresh_enemy_intents`
- L431-451 `_handle_merge`
- L454-462 `_handle_convert`
- L503-507 `_handle_debug_command`
- L512-514 `_reroll_and_show_intents`
- L519-522 `_respawn_wave_and_show`
- L527-575 `_build_ally_context`
- L578-618 `_build_enemy_context`
- L622-642 `_resolve_skill`
- L647-657 `_roll_enemy_intents`
- L660-715 `_resolve_enemy_turns`
- L717-736 `_execute_enemy_ultimate`
- L741-761 `_try_advance_wave`
- L770-796 `_finish_battle`
- L800-804 `_clear_all_moxie`
- L808-809 `_has_remaining_waves`
- L814-815 `_is_final_wave_cleared`
- L824-840 `_end_of_turn_cleanup`
- L845-882 `_log_status_event`

Uses: Card, DebugCommandRunner, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, TelemetryManager, TelemetrySchema, Unit, UnitData
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/TelemetryTest.gd, GDTest/TurnLoopTest.gd, Scenes/BattleScene/BattleScene.gd, Tools/BattleSimulator.gd
Loads: —

