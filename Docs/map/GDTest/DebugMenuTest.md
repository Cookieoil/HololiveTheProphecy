<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DebugMenuTest.gd` — `class_name DebugMenuTest` extends `GdUnitTestSuite`

`815` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager): - the panel is view-only: it reports readouts, gates its tools while the turn loop…

Sections: Panel (view-only) tests · Header drag (the panel can be moved out of the way) · Card tools (overflow, merge tiers, hand operations) · Resource tools · Unit tools · Wave tools · Build-type gate · Scene wiring
- L16 `class RecordingUI extends GameUI` (members are not indexed)

Public API:
- L126-134 `test_menu_starts_closed_and_toggles() -> void`
- L138-149 `test_panel_chrome_has_square_corners() -> void` — The panel and the hover tooltip slabs are one flat surface: square on all four edges.
- L152-165 `test_close_button_closes_the_menu_and_reports_it() -> void`
- L168-182 `test_gate_locks_every_tool_and_the_close_button_stays_live() -> void`
- L185-193 `test_refresh_flags_an_over_cap_hand() -> void`
- L196-207 `test_refresh_lists_targets_and_keeps_the_selection() -> void`
- L210-232 `test_unit_tool_carries_the_selected_target() -> void`
- L235-247 `test_unit_tool_without_a_target_does_nothing() -> void`
- L252-271 `test_result_preview_tools_emit_their_commands() -> void` — The result cutscene is otherwise only reachable by actually winning or losing, so the panel offers a preview tool for each outcome.
- L292-314 `test_dragging_the_header_moves_the_panel() -> void`
- L317-325 `test_header_drag_ignores_other_mouse_buttons() -> void`
- L328-335 `test_header_is_a_wired_drag_handle() -> void`
- L338-358 `test_dragging_cannot_push_the_panel_off_screen() -> void`
- L364-372 `test_spawning_ignores_the_hand_cap() -> void`
- L375-392 `test_custom_spawn_builds_each_merge_tier() -> void`
- L395-403 `test_spawned_merged_card_evaporates_instead_of_poisoning_the_deck() -> void`
- L406-414 `test_clearing_the_hand_still_discards_real_deck_cards() -> void`
- L417-425 `test_discard_random_removes_exactly_one_card() -> void`
- L428-440 `test_draw_tools_pull_from_the_deck() -> void`
- L443-458 `test_buff_hand_raises_every_card_and_announces_it() -> void`
- L461-469 `test_hand_tools_on_an_empty_hand_do_not_crash() -> void`
- L475-484 `test_resource_tools_top_up_actions_and_merges() -> void`
- L487-496 `test_hand_cap_stepper_clamps_at_both_ends() -> void`
- L499-505 `test_next_skill_bonus_accumulates() -> void`
- L511-519 `test_fill_moxie_makes_the_ultimate_castable() -> void`
- L522-530 `test_zero_moxie_clears_the_gauge_and_the_used_lock() -> void`
- L533-543 `test_damage_tools_absorb_through_shield_then_hp() -> void`
- L546-556 `test_true_damage_bypasses_the_shield() -> void`
- L559-569 `test_heal_full_restores_the_target_only() -> void`
- L572-582 `test_shield_tools_add_and_clear() -> void`
- L585-592 `test_kill_defeats_only_the_targeted_slot() -> void`
- L595-602 `test_scope_all_hits_both_rows() -> void`
- L605-612 `test_untargeted_command_never_touches_the_enemy_row() -> void`
- L615-626 `test_status_tools_apply_and_clear() -> void`
- L632-638 `test_clear_wave_defeats_every_living_enemy() -> void`
- L641-653 `test_respawn_wave_rebuilds_the_enemy_row() -> void`
- L656-662 `test_reroll_intents_skips_defeated_enemies() -> void`
- L665-677 `test_dice_step_rerolls_with_the_new_dice() -> void`
- L680-686 `test_unknown_command_is_ignored() -> void`
- L694-695 `before_test() -> void` — The engine is in charge by default: the suite must never leave a forced answer behind for another test file to inherit.
- L698-699 `after_test() -> void`
- L704-705 `test_a_debug_build_keeps_the_tools_available() -> void` — The headless run uses the editor binary, so the tools stay available here. If this ever fails, the rest of the suite is running against a release binary.
- L710-722 `test_a_release_build_never_mounts_the_overlay() -> void` — A release export must never mount the overlay, even though the shipped scene file still carries `debug_menu_enabled = true`.
- L727-735 `test_a_release_build_refuses_a_debug_command() -> void` — And a debug action that somehow reaches the turn loop is refused there too: the manager is the authority, not the UI.
- L743-771 `test_battle_scene_mounts_and_toggles_the_debug_menu() -> void` — The battle scene is the only place the toggle button, the hotkey and the panel meet, so this loads the real scene and checks they are actually connected.
- L774-788 `test_battle_scene_locks_the_tools_until_the_player_turn_starts() -> void`
- L793-811 `test_battle_scene_applies_a_tool_through_the_turn_loop() -> void` — _ready() runs the loop up to its first player action, so a tool press goes straight onto the queue and the turn loop applies it for real.

Private:
- L36-37 `_make_skill`
- L40-48 `_make_ally_data`
- L51-55 `_make_enemy_data`
- L58-59 `_make_enemy`
- L64-77 `_make_manager`
- L81-82 `_run`
- L85-98 `_snapshot`
- L101-108 `_targets`
- L113-121 `_find_button`
- L278-282 `_press_header`
- L286-289 `_drag_header`

Uses: BattleScene, Card, DebugMenuPopup, EnemyIntent, GameManager, GameState, GameUI, SkillData, Unit, UnitData
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn

