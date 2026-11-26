<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`1149` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Helpers · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+4 more)

Constants:
- L17 `WAVE_MODE_MAP: Dictionary = {` — JSON/config string -> WaveTransition (config.json stores readable names).
- L27 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L493 `DEBUG_HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L496 `DEBUG_SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L497 `DEBUG_SCOPE_ENEMIES: int = 1`
- L498 `DEBUG_SCOPE_ALL: int = 2`
- L501 `DEBUG_BUILD_ENGINE: int = -1` — Values for `debug_build_override`: the engine decides, or the suite forces the release / debug answer so the gate below can be exercised without an export.
- L502 `DEBUG_BUILD_FORCED_OFF: int = 0`
- L503 `DEBUG_BUILD_FORCED_ON: int = 1`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`
- L509 `debug_build_override: int = DEBUG_BUILD_ENGINE` — Test seam for `debug_tools_enabled()`. `DEBUG_BUILD_ENGINE` is the default and the only value game code ever leaves behind; GDTest/DebugMenuTest.gd sets it to `…

Public API:
- L58-76 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…
- L517-520 `static debug_tools_enabled() -> bool` — Build-type gate for every tester tool (the Debug menu, the F1 hotkey and the "debug" action). Editor runs and debug exports report `true`; a **release** export…

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
- L170-254 `_run_game_loop`
- L255-256 `_show_instructions`
- L275-327 `_player_action_phase`
- L338-347 `_resolve_enemy_clear_after_action`
- L350-419 `_handle_play`
- L421-449 `_handle_ally_ultimate`
- L451-455 `_refresh_enemy_intents`
- L456-475 `_handle_merge`
- L478-486 `_handle_convert`
- L531-619 `_handle_debug_command`
- L623-627 `_coerce_dict`
- L634-649 `_debug_targets`
- L653-654 `_debug_log`
- L658-662 `_debug_hp_summary`
- L665-674 `_debug_spawn_random`
- L677-686 `_debug_spawn_custom`
- L689-695 `_debug_draw`
- L698-707 `_debug_buff_hand`
- L710-719 `_debug_discard_random`
- L722-729 `_debug_clear_hand`
- L732-739 `_debug_set_moxie`
- L742-747 `_debug_heal`
- L750-759 `_debug_damage`
- L762-767 `_debug_shield`
- L770-775 `_debug_clear_shield`
- L778-790 `_debug_kill`
- L793-802 `_debug_apply_status`
- L805-809 `_debug_clear_statuses`
- L814-856 `_build_ally_context`
- L859-898 `_build_enemy_context`
- L902-922 `_resolve_skill`
- L927-937 `_roll_enemy_intents`
- L940-990 `_resolve_enemy_turns`
- L991-1009 `_execute_enemy_ultimate`
- L1014-1036 `_try_advance_wave`
- L1045-1066 `_finish_battle`
- L1070-1074 `_clear_all_moxie`
- L1078-1079 `_has_remaining_waves`
- L1084-1085 `_is_final_wave_cleared`
- L1094-1110 `_end_of_turn_cleanup`
- L1114-1146 `_log_status_event`

Uses: Card, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, Unit, UnitData
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd, Tools/check_navigation.gd, Tools/validate_gameData.gd
Loads: —

