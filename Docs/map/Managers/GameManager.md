<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`1084` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Helpers · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+3 more)

Constants:
- L17 `WAVE_MODE_MAP: Dictionary = {` — JSON/config string -> WaveTransition (config.json stores readable names).
- L27 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L478 `DEBUG_HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L481 `DEBUG_SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L482 `DEBUG_SCOPE_ENEMIES: int = 1`
- L483 `DEBUG_SCOPE_ALL: int = 2`
- L486 `DEBUG_BUILD_ENGINE: int = -1` — Values for `debug_build_override`: the engine decides, or the suite forces the release / debug answer so the gate below can be exercised without an export.
- L487 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L488 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L494 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…

Public API:
- L58-76 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L502-505 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

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
- L170-258 `_run_game_loop`
- L259-260 `_show_instructions`
- L279-339 `_player_action_phase`
- L341-404 `_handle_play`
- L406-434 `_handle_ally_ultimate`
- L436-440 `_refresh_enemy_intents`
- L441-460 `_handle_merge`
- L463-471 `_handle_convert`
- L516-604 `_handle_debug_command`
- L608-612 `_coerce_dict`
- L619-634 `_debug_targets`
- L638-639 `_debug_log`
- L643-647 `_debug_hp_summary`
- L650-659 `_debug_spawn_random`
- L662-671 `_debug_spawn_custom`
- L674-680 `_debug_draw`
- L683-692 `_debug_buff_hand`
- L695-704 `_debug_discard_random`
- L707-714 `_debug_clear_hand`
- L717-724 `_debug_set_moxie`
- L727-732 `_debug_heal`
- L735-744 `_debug_damage`
- L747-752 `_debug_shield`
- L755-760 `_debug_clear_shield`
- L763-775 `_debug_kill`
- L778-787 `_debug_apply_status`
- L790-794 `_debug_clear_statuses`
- L799-841 `_build_ally_context`
- L844-883 `_build_enemy_context`
- L887-907 `_resolve_skill`
- L912-922 `_roll_enemy_intents`
- L925-975 `_resolve_enemy_turns`
- L976-994 `_execute_enemy_ultimate`
- L999-1021 `_try_advance_wave`
- L1029-1045 `_end_of_turn_cleanup`
- L1049-1081 `_log_status_event`

Uses: Card, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, Unit, UnitData
Used by: GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Tools/check_navigation.gd, Tools/validate_gameData.gd
Loads: —

