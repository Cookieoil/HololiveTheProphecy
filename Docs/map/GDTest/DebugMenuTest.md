<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DebugMenuTest.gd` — `class_name DebugMenuTest` extends `GdUnitTestSuite`

`864` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager): - the panel is view-only: it reports readouts, gates its tools while the turn loop…

Sections: Panel (view-only) tests · Header drag (the panel can be moved out of the way) · Card tools (overflow, merge tiers, hand operations) · Resource tools · Unit tools · Wave tools · Build-type gate · Scene wiring
- L16 `class RecordingUI extends GameUI` (members are not indexed)

Public API:
- L147-155 `test_menu_starts_closed_and_toggles() -> void`
- L159-170 `test_panel_chrome_has_square_corners() -> void` — The panel and the hover tooltip slabs are one flat surface: square on all four edges.
- L173-186 `test_close_button_closes_the_menu_and_reports_it() -> void`
- L189-203 `test_gate_locks_every_tool_and_the_close_button_stays_live() -> void`
- L206-214 `test_refresh_flags_an_over_cap_hand() -> void`
- L217-228 `test_refresh_lists_targets_and_keeps_the_selection() -> void`
- L231-253 `test_unit_tool_carries_the_selected_target() -> void`
- L256-268 `test_unit_tool_without_a_target_does_nothing() -> void`
- L273-292 `test_result_preview_tools_emit_their_commands() -> void` — The result cutscene is otherwise only reachable by actually winning or losing, so the panel offers a preview tool for each outcome.
- L297-320 `test_result_previews_live_in_their_own_tab() -> void` — The result previews have their own Screen tab, so they are not buried under the unit tools.
- L341-363 `test_dragging_the_header_moves_the_panel() -> void`
- L366-374 `test_header_drag_ignores_other_mouse_buttons() -> void`
- L377-384 `test_header_is_a_wired_drag_handle() -> void`
- L387-407 `test_dragging_cannot_push_the_panel_off_screen() -> void`
- L413-421 `test_spawning_ignores_the_hand_cap() -> void`
- L424-441 `test_custom_spawn_builds_each_merge_tier() -> void`
- L444-452 `test_spawned_merged_card_evaporates_instead_of_poisoning_the_deck() -> void`
- L455-463 `test_clearing_the_hand_still_discards_real_deck_cards() -> void`
- L466-474 `test_discard_random_removes_exactly_one_card() -> void`
- L477-489 `test_draw_tools_pull_from_the_deck() -> void`
- L492-507 `test_buff_hand_raises_every_card_and_announces_it() -> void`
- L510-518 `test_hand_tools_on_an_empty_hand_do_not_crash() -> void`
- L524-533 `test_resource_tools_top_up_actions_and_merges() -> void`
- L536-545 `test_hand_cap_stepper_clamps_at_both_ends() -> void`
- L548-554 `test_next_skill_bonus_accumulates() -> void`
- L560-568 `test_fill_moxie_makes_the_ultimate_castable() -> void`
- L571-579 `test_zero_moxie_clears_the_gauge_and_the_used_lock() -> void`
- L582-592 `test_damage_tools_absorb_through_shield_then_hp() -> void`
- L595-605 `test_true_damage_bypasses_the_shield() -> void`
- L608-618 `test_heal_full_restores_the_target_only() -> void`
- L621-631 `test_shield_tools_add_and_clear() -> void`
- L634-641 `test_kill_defeats_only_the_targeted_slot() -> void`
- L644-651 `test_scope_all_hits_both_rows() -> void`
- L654-661 `test_untargeted_command_never_touches_the_enemy_row() -> void`
- L664-675 `test_status_tools_apply_and_clear() -> void`
- L681-687 `test_clear_wave_defeats_every_living_enemy() -> void`
- L690-702 `test_respawn_wave_rebuilds_the_enemy_row() -> void`
- L705-711 `test_reroll_intents_skips_defeated_enemies() -> void`
- L714-726 `test_dice_step_rerolls_with_the_new_dice() -> void`
- L729-735 `test_unknown_command_is_ignored() -> void`
- L743-744 `before_test() -> void` — The engine is in charge by default: the suite must never leave a forced answer behind for another test file to inherit.
- L747-748 `after_test() -> void`
- L753-754 `test_a_debug_build_keeps_the_tools_available() -> void` — The headless run uses the editor binary, so the tools stay available here. If this ever fails, the rest of the suite is running against a release binary.
- L759-771 `test_a_release_build_never_mounts_the_overlay() -> void` — A release export must never mount the overlay, even though the shipped scene file still carries `debug_menu_enabled = true`.
- L776-784 `test_a_release_build_refuses_a_debug_command() -> void` — And a debug action that somehow reaches the turn loop is refused there too: the manager is the authority, not the UI.
- L792-820 `test_battle_scene_mounts_and_toggles_the_debug_menu() -> void` — The battle scene is the only place the toggle button, the hotkey and the panel meet, so this loads the real scene and checks they are actually connected.
- L823-837 `test_battle_scene_locks_the_tools_until_the_player_turn_starts() -> void`
- L842-860 `test_battle_scene_applies_a_tool_through_the_turn_loop() -> void` — _ready() runs the loop up to its first player action, so a tool press goes straight onto the queue and the turn loop applies it for real.

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
- L125-133 `_find_tab_container`
- L138-142 `_tab_index`
- L327-331 `_press_header`
- L335-338 `_drag_header`

Uses: BattleScene, Card, DebugMenuPopup, EnemyIntent, GameManager, GameState, GameUI, SkillData, Unit, UnitData
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn

