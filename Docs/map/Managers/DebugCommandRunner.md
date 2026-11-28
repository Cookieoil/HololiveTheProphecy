<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/DebugCommandRunner.gd` — `class_name DebugCommandRunner` extends `RefCounted`

`401` lines · [back to the map](../../CODEBASE_MAP.md)

> Tester-only mutations behind the in-game Debug menu (Scenes/HUD/DebugMenuPopup.gd). Extracted from Managers/GameManager.gd, which had grown a 360-line tester to…

Sections: Signals · Constants · Public Variables · Public Methods · Private Methods · Private Methods

Signals:
- L28 `intents_reroll_requested` — The command needs the enemy intents re-rolled (and the new ones shown).
- L30 `wave_respawn_requested` — The command needs the current wave re-spawned (and the board redrawn).

Constants:
- L36 `HAND_CAP_LIMIT: int = 20` — Highest hand cap the Debug menu's stepper allows, so a stray click cannot set a four-digit cap.
- L39 `SCOPE_ALLIES: int = 0` — Scope values of the Debug menu's target selector. Mirrors DebugMenuPopup.Scope without this runner having to reference a UI class.
- L40 `SCOPE_ENEMIES: int = 1`
- L41 `SCOPE_ALL: int = 2`
- L45 `RESULT_NONE: int = 0` — Result-screen preview requested by the Debug menu: 0 = none, 1 = Victory, 2 = Defeat. The panel only asks; the player-action loop applies it, so a preview leave…
- L46 `RESULT_VICTORY: int = 1`
- L47 `RESULT_DEFEAT: int = 2`

State:
- L53 `result_request: int = RESULT_NONE` — Result-screen preview this run asked for, read and cleared by the player-action loop (see GameManager._player_action_phase). `RESULT_NONE` when there is none.

Public API:
- L64-73 `apply(action: Dictionary, state: GameState, ui: GameUI) -> void` — Applies one tester tool. The caller has already decided the build is allowed to run tools (GameManager owns that gate), so this only mutates and reports. The ta…
- L180-181 `log_line(ui: GameUI, message: String) -> void` — Writes one-line confirmation into the message log, so a tester can see what a tool did. (Named `log_line` because `log()` is Godot's built-in logarithm.)

Private:
- L80-111 `_apply_hand_command`
- L116-150 `_apply_unit_command`
- L156-174 `_apply_loop_command`
- L188-204 `_to_int`
- L208-212 `_to_dict`
- L219-234 `_targets`
- L239-244 `_step_dice`
- L248-252 `_hp_summary`
- L255-264 `_spawn_random`
- L267-276 `_spawn_custom`
- L279-285 `_draw`
- L288-297 `_buff_hand`
- L300-309 `_discard_random`
- L312-319 `_clear_hand`
- L322-329 `_set_moxie`
- L332-337 `_heal`
- L340-349 `_damage`
- L352-357 `_shield`
- L360-365 `_clear_shield`
- L368-380 `_kill`
- L383-392 `_apply_status`
- L395-399 `_clear_statuses`

Uses: Card, GameState, GameUI, Unit
Used by: GDTest/DebugCommandRunnerTest.gd, GDTest/DebugMenuTest.gd, Managers/GameManager.gd
Loads: —

