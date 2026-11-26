<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DebugMenuTest.gd` — `class_name DebugMenuTest` extends `GdUnitTestSuite`

`846` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager): - the panel is view-only: it reports readouts, gates its tools while the turn loop…

Sections: Panel (view-only) tests · Header drag (the panel can be moved out of the way) · Card tools (overflow, merge tiers, hand operations) · Resource tools · Unit tools · Wave tools · Build-type gate · Scene wiring
- L16 `class RecordingUI extends GameUI` (members are not indexed)

Public API:
- L138-146 `test_menu_starts_closed_and_toggles() -> void`
- L150-161 `test_panel_chrome_has_square_corners() -> void` — The panel and the hover tooltip slabs are one flat surface: square on all four edges.
- L164-177 `test_close_button_closes_the_menu_and_reports_it() -> void`
- L180-194 `test_gate_locks_every_tool_and_the_close_button_stays_live() -> void`
- L197-205 `test_refresh_flags_an_over_cap_hand() -> void`
- L208-219 `test_refresh_lists_targets_and_keeps_the_selection() -> void`
- L222-244 `test_unit_tool_carries_the_selected_target() -> void`
- L247-259 `test_unit_tool_without_a_target_does_nothing() -> void`
- L264-283 `test_result_preview_tools_emit_their_commands() -> void` — The result cutscene is otherwise only reachable by actually winning or losing, so the panel offers a preview tool for each outcome.
- L288-302 `test_result_previews_live_in_their_own_tab() -> void` — The result previews have their own Screen tab, so they are not buried under the unit tools.
- L323-345 `test_dragging_the_header_moves_the_panel() -> void`
- L348-356 `test_header_drag_ignores_other_mouse_buttons() -> void`
- L359-366 `test_header_is_a_wired_drag_handle() -> void`
- L369-389 `test_dragging_cannot_push_the_panel_off_screen() -> void`
- L395-403 `test_spawning_ignores_the_hand_cap() -> void`
- L406-423 `test_custom_spawn_builds_each_merge_tier() -> void`
- L426-434 `test_spawned_merged_card_evaporates_instead_of_poisoning_the_deck() -> void`
- L437-445 `test_clearing_the_hand_still_discards_real_deck_cards() -> void`
- L448-456 `test_discard_random_removes_exactly_one_card() -> void`
- L459-471 `test_draw_tools_pull_from_the_deck() -> void`
- L474-489 `test_buff_hand_raises_every_card_and_announces_it() -> void`
- L492-500 `test_hand_tools_on_an_empty_hand_do_not_crash() -> void`
- L506-515 `test_resource_tools_top_up_actions_and_merges() -> void`
- L518-527 `test_hand_cap_stepper_clamps_at_both_ends() -> void`
- L530-536 `test_next_skill_bonus_accumulates() -> void`
- L542-550 `test_fill_moxie_makes_the_ultimate_castable() -> void`
- L553-561 `test_zero_moxie_clears_the_gauge_and_the_used_lock() -> void`
- L564-574 `test_damage_tools_absorb_through_shield_then_hp() -> void`
- L577-587 `test_true_damage_bypasses_the_shield() -> void`
- L590-600 `test_heal_full_restores_the_target_only() -> void`
- L603-613 `test_shield_tools_add_and_clear() -> void`
- L616-623 `test_kill_defeats_only_the_targeted_slot() -> void`
- L626-633 `test_scope_all_hits_both_rows() -> void`
- L636-643 `test_untargeted_command_never_touches_the_enemy_row() -> void`
- L646-657 `test_status_tools_apply_and_clear() -> void`
- L663-669 `test_clear_wave_defeats_every_living_enemy() -> void`
- L672-684 `test_respawn_wave_rebuilds_the_enemy_row() -> void`
- L687-693 `test_reroll_intents_skips_defeated_enemies() -> void`
- L696-708 `test_dice_step_rerolls_with_the_new_dice() -> void`
- L711-717 `test_unknown_command_is_ignored() -> void`
- L725-726 `before_test() -> void` — The engine is in charge by default: the suite must never leave a forced answer behind for another test file to inherit.
- L729-730 `after_test() -> void`
- L735-736 `test_a_debug_build_keeps_the_tools_available() -> void` — The headless run uses the editor binary, so the tools stay available here. If this ever fails, the rest of the suite is running against a release binary.
- L741-753 `test_a_release_build_never_mounts_the_overlay() -> void` — A release export must never mount the overlay, even though the shipped scene file still carries `debug_menu_enabled = true`.
- L758-766 `test_a_release_build_refuses_a_debug_command() -> void` — And a debug action that somehow reaches the turn loop is refused there too: the manager is the authority, not the UI.
- L774-802 `test_battle_scene_mounts_and_toggles_the_debug_menu() -> void` — The battle scene is the only place the toggle button, the hotkey and the panel meet, so this loads the real scene and checks they are actually connected.
- L805-819 `test_battle_scene_locks_the_tools_until_the_player_turn_starts() -> void`
- L824-842 `test_battle_scene_applies_a_tool_through_the_turn_loop() -> void` — _ready() runs the loop up to its first player action, so a tool press goes straight onto the queue and the turn loop applies it for real.

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
- L309-313 `_press_header`
- L317-320 `_drag_header`

Uses: BattleScene, Card, DebugMenuPopup, EnemyIntent, GameManager, GameState, GameUI, SkillData, Unit, UnitData
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn

