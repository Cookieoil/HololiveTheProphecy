<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/BattleEndTest.gd` — `class_name BattleEndTest` extends `GdUnitTestSuite`

`599` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the end of a battle: - a unit that dies never keeps Moxie (or a "ULT READY" glow) on the board - the skill that kills the final boss does not charge the c…

Sections: Helpers · Unit: a dead unit never keeps Moxie · Final wave detection · The winning skill does not charge Moxie · Post-action clear check · Player phase: an Ultimate that wins the battle · One exit for every ending · The loop ends the battle on the winning action · (+3 more)
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
- L397-408 `test_the_orb_releases_its_preview_when_the_unit_dies() -> void`
- L414-428 `test_the_orb_ring_dims_even_when_the_gauge_never_moved() -> void` — The reported bug: a unit that dies without its gauge moving (it was empty, or its fill never changed) used to keep a fully lit ring, because the ring only re-sy…
- L431-443 `test_the_orb_ring_follows_the_drained_gauge_to_empty() -> void`
- L469-480 `test_the_victory_banner_uses_its_placeholder_emblem_and_flat_colours() -> void`
- L483-491 `test_the_defeat_banner_swaps_to_its_own_emblem_and_text() -> void`
- L497-506 `test_the_cutscene_boxes_neither_the_title_nor_the_icon() -> void` — Removed on request: the small rectangle around the title (the slab) and the rectangle around the icon (the emblem tile). The backdrop stays, and so do the title…
- L511-517 `test_the_button_draws_no_outline() -> void` — Removed on request: the outlines. The button keeps its own surface but draws no border.
- L522-530 `test_the_title_laps_over_the_emblem() -> void` — The requested look: the title laps slightly over the emblem, and the title is the mark's last child, so it draws on top of it.
- L533-540 `test_the_result_screen_blocks_clicks_to_the_board_behind_it() -> void`
- L543-552 `test_play_again_asks_the_owner_to_restart() -> void`
- L568-584 `test_the_battle_scene_mounts_the_cutscene_above_every_other_layer() -> void` — The battle scene is where the cutscene layer, the overlay and the restart signal meet, so this loads the real scene and checks they are connected.
- L589-597 `test_the_scene_cutscene_raises_the_banner_and_locks_the_player_controls() -> void` — The scene's cutscene: banner up, player controls locked, placeholder emblem in place. The game loop is parked on the player action, so this never restarts.

Private:
- L57-63 `_make_unit_data`
- L67-81 `_make_nuke_skill`
- L84-91 `_make_manager`
- L94-95 `_recorder`
- L101-125 `_prepare_wave`
- L390-394 `_make_orb`
- L448-451 `_make_overlay`
- L456-457 `_is_flat_sdr`
- L461-466 `_has_no_border`
- L557-563 `_load_battle_scene`

Uses: BattleResultOverlay, BattleScene, Card, EffectBlock, EnemyIntent, GameManager, GameState, GameUI, MoxieOrbUI, SkillData, SkillEffect, Unit, UnitData
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn

