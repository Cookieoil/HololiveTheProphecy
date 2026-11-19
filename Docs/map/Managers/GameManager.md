<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/GameManager.gd` — `class_name GameManager` extends `Node`

`1057` lines · [back to the map](../../CODEBASE_MAP.md)

> Orchestrates the full game loop. Holds GameState + GameUI references. All player interaction flows through async callables injected into SkillContext.

Sections: Constants · Helpers · Setup · Main Game Loop · Player Action Phase · Debug Commands · Context Builders · Skill Resolution · (+3 more)

Constants:
- L17 `WAVE_MODE_MAP: Dictionary = {` — JSON/config string -> WaveTransition (config.json stores readable names).
- L27 `ENEMY_SKILL_OVERLAP_LEAD: float = 0.6` — Fraction of an enemy's skill animation that plays before the next enemy may start its own. Below 1.0 the previous enemy's wind-down overlaps the next one's wind…
- L478 `DEBUG_HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L481 `DEBUG_SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this manager having to reference a UI class.
- L482 `DEBUG_SCOPE_ENEMIES: int = 1`
- L483 `DEBUG_SCOPE_ALL: int = 2`

State:
- L9 `state: GameState`
- L10 `ui: GameUI`
- L11 `current_intents: Array[EnemyIntent] = []`
- L12 `game_running: bool = false`
- L13 `instructions_shown: bool = false`

Public API:
- L58-76 `setup_game(ally_data: Array[UnitData], wave_defs: Array, p_ui: GameUI, config: Dictionary = {}) -> void` — The game state initializer (kickoff): 1. It takes the starting data to configures the game state. 2. Initialize both allies and enemies to assign them unit data…

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
- L494-577 `_handle_debug_command`
- L581-585 `_coerce_dict`
- L592-607 `_debug_targets`
- L611-612 `_debug_log`
- L616-620 `_debug_hp_summary`
- L623-632 `_debug_spawn_random`
- L635-644 `_debug_spawn_custom`
- L647-653 `_debug_draw`
- L656-665 `_debug_buff_hand`
- L668-677 `_debug_discard_random`
- L680-687 `_debug_clear_hand`
- L690-697 `_debug_set_moxie`
- L700-705 `_debug_heal`
- L708-717 `_debug_damage`
- L720-725 `_debug_shield`
- L728-733 `_debug_clear_shield`
- L736-748 `_debug_kill`
- L751-760 `_debug_apply_status`
- L763-767 `_debug_clear_statuses`
- L772-814 `_build_ally_context`
- L817-856 `_build_enemy_context`
- L860-880 `_resolve_skill`
- L885-895 `_roll_enemy_intents`
- L898-948 `_resolve_enemy_turns`
- L949-967 `_execute_enemy_ultimate`
- L972-994 `_try_advance_wave`
- L1002-1018 `_end_of_turn_cleanup`
- L1022-1054 `_log_status_event`

Uses: Card, CardUI, DebugMenuPopup, DiceRoller, EnemyIntent, GameState, GameUI, SkillContext, SkillData, SkillEffect, Unit, UnitData
Used by: Core/GameState.gd, Core/GameUI.gd, GDTest/CardFlashPolicyTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/DebugMenuPopup.gd, Skills/SkillEffect.gd, Tools/validate_gameData.gd
Loads: —

