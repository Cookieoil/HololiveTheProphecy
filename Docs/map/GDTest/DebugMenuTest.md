<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DebugMenuTest.gd` — `class_name DebugMenuTest` extends `GdUnitTestSuite`

`727` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the tester debug tools (Debug button -> DebugMenuPopup -> GameManager): - the panel is view-only: it reports readouts, gates its tools while the turn loop…

Sections: Panel (view-only) tests · Header drag (the panel can be moved out of the way) · Card tools (overflow, merge tiers, hand operations) · Resource tools · Unit tools · Wave tools · Scene wiring
- L16 `class RecordingUI extends GameUI` (members are not indexed)

Public API:
- L126-134 `test_menu_starts_closed_and_toggles() -> void`
- L137-150 `test_close_button_closes_the_menu_and_reports_it() -> void`
- L153-167 `test_gate_locks_every_tool_and_the_close_button_stays_live() -> void`
- L170-178 `test_refresh_flags_an_over_cap_hand() -> void`
- L181-192 `test_refresh_lists_targets_and_keeps_the_selection() -> void`
- L195-217 `test_unit_tool_carries_the_selected_target() -> void`
- L220-232 `test_unit_tool_without_a_target_does_nothing() -> void`
- L253-275 `test_dragging_the_header_moves_the_panel() -> void`
- L278-286 `test_header_drag_ignores_other_mouse_buttons() -> void`
- L289-296 `test_header_is_a_wired_drag_handle() -> void`
- L299-319 `test_dragging_cannot_push_the_panel_off_screen() -> void`
- L325-333 `test_spawning_ignores_the_hand_cap() -> void`
- L336-353 `test_custom_spawn_builds_each_merge_tier() -> void`
- L356-364 `test_spawned_merged_card_evaporates_instead_of_poisoning_the_deck() -> void`
- L367-375 `test_clearing_the_hand_still_discards_real_deck_cards() -> void`
- L378-386 `test_discard_random_removes_exactly_one_card() -> void`
- L389-401 `test_draw_tools_pull_from_the_deck() -> void`
- L404-419 `test_buff_hand_raises_every_card_and_announces_it() -> void`
- L422-430 `test_hand_tools_on_an_empty_hand_do_not_crash() -> void`
- L436-445 `test_resource_tools_top_up_actions_and_merges() -> void`
- L448-457 `test_hand_cap_stepper_clamps_at_both_ends() -> void`
- L460-466 `test_next_skill_bonus_accumulates() -> void`
- L472-480 `test_fill_moxie_makes_the_ultimate_castable() -> void`
- L483-491 `test_zero_moxie_clears_the_gauge_and_the_used_lock() -> void`
- L494-504 `test_damage_tools_absorb_through_shield_then_hp() -> void`
- L507-517 `test_true_damage_bypasses_the_shield() -> void`
- L520-530 `test_heal_full_restores_the_target_only() -> void`
- L533-543 `test_shield_tools_add_and_clear() -> void`
- L546-553 `test_kill_defeats_only_the_targeted_slot() -> void`
- L556-563 `test_scope_all_hits_both_rows() -> void`
- L566-573 `test_untargeted_command_never_touches_the_enemy_row() -> void`
- L576-587 `test_status_tools_apply_and_clear() -> void`
- L593-599 `test_clear_wave_defeats_every_living_enemy() -> void`
- L602-614 `test_respawn_wave_rebuilds_the_enemy_row() -> void`
- L617-623 `test_reroll_intents_skips_defeated_enemies() -> void`
- L626-638 `test_dice_step_rerolls_with_the_new_dice() -> void`
- L641-647 `test_unknown_command_is_ignored() -> void`
- L655-683 `test_battle_scene_mounts_and_toggles_the_debug_menu() -> void` — The battle scene is the only place the toggle button, the hotkey and the panel meet, so this loads the real scene and checks they are actually connected.
- L686-700 `test_battle_scene_locks_the_tools_until_the_player_turn_starts() -> void`
- L705-723 `test_battle_scene_applies_a_tool_through_the_turn_loop() -> void` — _ready() runs the loop up to its first player action, so a tool press goes straight onto the queue and the turn loop applies it for real.

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
- L239-243 `_press_header`
- L247-250 `_drag_header`

Uses: BattleScene, Card, DebugMenuPopup, EnemyIntent, GameManager, GameState, GameUI, SkillData, Unit, UnitData
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn

