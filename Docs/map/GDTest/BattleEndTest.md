<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/BattleEndTest.gd` — `class_name BattleEndTest` extends `GdUnitTestSuite`

`687` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the end of a battle: - a unit that dies never keeps Moxie (or a "ULT READY" glow) on the board - the skill that kills the final boss does not charge the c…

Sections: Helpers · Unit: a dead unit never keeps Moxie · Final wave detection · The winning skill does not charge Moxie · Post-action clear check · Player phase: an Ultimate that wins the battle · One exit for every ending · The loop ends the battle on the winning action · (+4 more)
- L17 `class RecordingUI extends GameUI` (members are not indexed)

Public API:
- L130-138 `test_a_dead_unit_empties_its_moxie_gauge() -> void`
- L141-150 `test_death_releases_a_full_ready_gauge() -> void`
- L153-168 `test_clear_moxie_emits_only_when_the_gauge_had_something() -> void`
- L171-180 `test_clear_moxie_releases_the_once_per_turn_ultimate_lock() -> void`
- L185-191 `test_a_run_with_a_later_wave_is_not_the_final_wave() -> void`
- L194-200 `test_the_last_wave_of_the_run_is_the_final_wave() -> void`
- L203-207 `test_a_living_boss_is_never_a_cleared_wave() -> void`
- L212-224 `test_the_winning_skill_does_not_charge_the_casters_moxie() -> void`
- L227-239 `test_clearing_a_wave_with_a_successor_still_charges_moxie() -> void`
- L244-249 `test_a_cleared_final_wave_ends_the_player_phase() -> void`
- L252-259 `test_a_full_turn_wave_clear_ends_the_player_phase_without_advancing() -> void`
- L262-270 `test_an_immediate_skip_wave_clear_spawns_the_next_wave_and_continues() -> void`
- L273-277 `test_a_living_board_never_ends_the_player_phase() -> void`
- L282-298 `test_an_ultimate_that_clears_the_final_wave_ends_the_player_phase() -> void`
- L303-329 `test_finish_battle_wipes_moxie_and_intents_then_reports_victory() -> void`
- L332-351 `test_finish_battle_on_defeat_also_wipes_moxie() -> void`
- L354-362 `test_finish_battle_refreshes_the_hand_and_resources() -> void`
- L367-385 `test_the_loop_ends_the_battle_as_soon_as_the_final_wave_dies() -> void`
- L392-393 `before_test() -> void` — The tools reset the shared build gate, so a leftover forced answer from another suite can never hide the debug commands here.
- L396-397 `after_test() -> void`
- L403-415 `test_the_debug_preview_raises_the_victory_cutscene() -> void` — The Debug menu's preview tools are the only way to see the cutscene without actually winning, so they run through the normal player-action queue and leave the b…
- L418-428 `test_the_debug_preview_raises_the_defeat_cutscene() -> void`
- L432-444 `test_the_loop_stops_after_a_debug_preview() -> void` — A preview taken inside the running loop stops the battle before the enemy turn.
- L456-467 `test_the_orb_releases_its_preview_when_the_unit_dies() -> void`
- L473-487 `test_the_orb_ring_dims_even_when_the_gauge_never_moved() -> void` — The reported bug: a unit that dies without its gauge moving (it was empty, or its fill never changed) used to keep a fully lit ring, because the ring only re-sy…
- L490-502 `test_the_orb_ring_follows_the_drained_gauge_to_empty() -> void`
- L538-552 `test_the_victory_banner_uses_its_placeholder_emblem_and_flat_colours() -> void`
- L555-564 `test_the_defeat_banner_swaps_to_its_own_emblem_and_text() -> void`
- L570-579 `test_the_cutscene_boxes_neither_the_title_nor_the_icon() -> void` — Removed on request: the small rectangle around the title (the slab) and the rectangle around the icon (the emblem tile). The backdrop stays, and so do the emble…
- L584-595 `test_the_title_laps_over_the_emblem() -> void` — The requested look: the title laps over the emblem, and the emblem is added before the title stack so it stays behind it.
- L600-615 `test_the_prompt_has_no_box_and_asks_the_owner_to_restart() -> void` — The prompt replaced the old filled button: no box, no border, and pressing it asks the scene to restart.
- L618-625 `test_the_result_screen_blocks_clicks_to_the_board_behind_it() -> void`
- L641-661 `test_the_battle_scene_mounts_the_cutscene_above_every_other_layer() -> void` — The battle scene is where the cutscene layer, the overlay and the restart signal meet, so this loads the real scene and checks they are connected.
- L666-672 `test_the_moxie_rails_retreat_for_the_result() -> void` — The Moxie rails are combat chrome, so they step off stage before the cutscene takes the screen and leave the battlefield alone behind it.
- L677-685 `test_the_scene_cutscene_raises_the_banner_and_locks_the_player_controls() -> void` — The scene's cutscene: banner up, player controls locked, placeholder emblem in place. The game loop is parked on the player action, so this never restarts.

Private:
- L57-63 `_make_unit_data`
- L67-81 `_make_nuke_skill`
- L84-91 `_make_manager`
- L94-95 `_recorder`
- L101-125 `_prepare_wave`
- L449-453 `_make_orb`
- L507-510 `_make_overlay`
- L515-516 `_is_flat_sdr`
- L520-525 `_has_no_border`
- L529-535 `_shader_color`
- L630-636 `_load_battle_scene`

Uses: BattleResultOverlay, BattleResultPrompt, BattleScene, Card, EffectBlock, EnemyIntent, GameManager, GameState, GameUI, MoxieOrbUI, SkillData, SkillEffect, Unit, UnitData
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn

