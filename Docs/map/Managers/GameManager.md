<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`861` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Enums · Constants · Lifecycle Methods · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · (+5 more)
- L27-31 `enum StepOutcome` = CONTINUE_ROUND

Constants:
- L41 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L532 `DEBUG_BUILD_ENGINE: int = -1` — The tester tools themselves live in Managers/DebugCommandRunner.gd, which also owns the constants naming their scopes and their result previews (`DebugCommandRu…
- L533 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L534 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L17 `telemetry: TelemetryManager = TelemetryManager.new()` — Passive gameplay recorder (see Managers/TelemetryManager.gd). It is a no-op until the player has agreed to telemetry, so every hook below is safe to call uncond…
- L22 `_debug: DebugCommandRunner = DebugCommandRunner.new()` — Tester tool table (see Managers/DebugCommandRunner.gd). It holds no board of its own - it is handed `state` and `ui` per command - and it *asks* for the two too…
- L540 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…

Public API:
- L70-96 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L549-552 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

Private:
- L50-52 `_ready`
- L98-106 `_spawn_wave`
- L114-140 `_run_game_loop`
- L145-148 `_show_intro_once`
- L153-175 `_begin_turn`
- L179-185 `_turn_header`
- L191-197 `_reset_turn_state`
- L204-212 `_settle_player_phase`
- L217-220 `_reset_enemy_shields`
- L227-236 `_settle_enemy_turn`
- L242-253 `_tick_round`
- L259-260 `_close_turn_record`
- L266-269 `_exit_tree`
- L270-271 `_show_instructions`
- L290-360 `_player_action_phase`
- L371-380 `_resolve_enemy_clear_after_action`
- L383-452 `_handle_play`
- L454-482 `_handle_ally_ultimate`
- L484-488 `_refresh_enemy_intents`
- L489-509 `_handle_merge`
- L512-520 `_handle_convert`
- L561-565 `_handle_debug_command`
- L570-572 `_reroll_and_show_intents`
- L577-580 `_respawn_wave_and_show`
- L589-590 `_build_ally_context`
- L593-594 `_build_enemy_context`
- L598-618 `_resolve_skill`
- L623-633 `_roll_enemy_intents`
- L636-691 `_resolve_enemy_turns`
- L693-712 `_execute_enemy_ultimate`
- L717-737 `_try_advance_wave`
- L746-772 `_finish_battle`
- L776-780 `_clear_all_moxie`
- L784-785 `_has_remaining_waves`
- L790-791 `_is_final_wave_cleared`
- L800-816 `_end_of_turn_cleanup`
- L821-858 `_log_status_event`

Uses: Card, DebugCommandRunner, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillContextFactory, SkillData, SkillEffect, TelemetryManager, TelemetrySchema, Unit, UnitData
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/TelemetryTest.gd, GDTest/TurnLoopTest.gd, Scenes/BattleScene/BattleScene.gd, Tools/BattleSimulator.gd
Loads: —

