<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/EnemyTurnOverlapTest.gd` — `class_name EnemyTurnOverlapTest` extends `GdUnitTestSuite`

`232` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the enemy-turn overlap ("fast mode" pacing): - consecutive enemies hand control to the next one at the impact beat of their skill animation, so wind-downs…
- L14 `class RecordingUI extends GameUI` (members are not indexed)

Public API:
- L89-98 `test_consecutive_enemy_skills_overlap_at_the_impact_beat() -> void`
- L101-104 `test_overlap_lead_keeps_an_actual_overlap_window() -> void`
- L107-120 `test_enemy_ultimate_still_plays_in_full_after_the_skill() -> void`
- L123-136 `test_player_skill_still_waits_for_the_full_animation() -> void`
- L139-143 `test_lead_wait_is_a_slice_of_the_animation_duration() -> void`
- L146-149 `test_full_lead_means_wait_for_the_whole_animation() -> void`
- L152-154 `test_lead_wait_never_goes_negative() -> void`
- L169-187 `test_lead_beat_fires_once_once_the_animation_slice_elapsed() -> void`
- L190-201 `test_lead_beat_is_flushed_when_the_action_ends_early() -> void`
- L204-217 `test_lead_beat_is_flushed_while_the_portrait_is_dying() -> void`
- L220-232 `test_clearing_the_queue_releases_overlap_waiters() -> void`

Private:
- L34-35 `_make_skill`
- L38-47 `_make_enemy`
- L50-58 `_make_ally`
- L61-73 `_make_manager`
- L76-77 `_recorder`
- L81-86 `_play_enemy_turn`
- L159-166 `_make_bare_portrait`

Uses: Card, EnemyIntent, GameManager, GameState, GameUI, SkillData, SpinePortrait, Unit, UnitData
Used by: —
Loads: —

