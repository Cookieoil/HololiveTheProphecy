<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TurnLoopTest.gd` — `class_name TurnLoopTest` extends `GdUnitTestSuite`

`750` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the turn machine in Managers/GameManager.gd: the eight round steps in order, where each side's shields and the once-per-turn Ultimate lock are cleared, wh…

Sections: Skill fixtures · Harness · Observation helpers · The intro gate · Round order · Shield and Ultimate-lock lifecycle · Wave transitions: FULL_TURN · Wave transitions: IMMEDIATE_SKIP · (+3 more)
- L23 `class MemorySink extends TelemetrySink` (members are not indexed)
- L42 `class TurnUI extends GameUI` (members are not indexed)

Constants:
- L17 `TEMP_ROOT: String = "user://turn_loop_test"`

State:
- L18 `_temp_dir: String = ""`
- L19 `_run_index: int = 0`

Public API:
- L194-195 `before() -> void`
- L198-203 `after() -> void`
- L380-398 `test_the_intro_is_shown_once_across_turns() -> void` — The how-to-play block is a first-run courtesy, not a per-turn banner: it is shown on the first turn only, however many turns the run lasts.
- L405-419 `test_a_round_opens_with_the_intent_preview() -> void` — Every round opens by rolling and previewing the enemy intents, before the player is asked for anything: the preview is the first thing the loop touches.
- L426-450 `test_an_ally_shield_survives_the_enemy_turn_and_clears_at_the_next_turn_start() -> void` — An ally's shield is spent defending the enemy turn and cleared at the start of the player's *next* turn - not at the end of the turn it was raised in.
- L455-471 `test_an_enemy_shield_survives_the_player_phase_and_clears_before_the_enemy_acts() -> void` — An enemy's shield covers the player phase and is cleared right before the enemy turn (Step 6), so what the player saw while choosing is what the shield actually…
- L476-493 `test_both_sides_release_the_ultimate_lock_at_the_turn_start() -> void` — The once-per-turn Ultimate lock is released for both sides at the start of the round, so a lock left behind by the previous round can never strand an Ultimate.
- L501-532 `test_a_full_turn_advance_skips_the_enemy_turn_and_the_round_tick() -> void` — A FULL_TURN clear ends the round there: the next wave is spawned at the start of the following turn, so the cleared wave's enemy turn *and* the round-end status…
- L538-556 `test_a_full_turn_advance_lets_the_new_wave_act_on_the_next_turn() -> void` — The skipped turn belongs to the cleared wave only: a wave spawned by a FULL_TURN advance acts normally from the next turn, and losing there is reported as an al…
- L564-592 `test_an_immediate_skip_advance_spawns_the_next_wave_inside_the_player_phase() -> void` — An IMMEDIATE_SKIP clear spawns the next wave inside the player phase and empties the intent row, so the new enemies stand still for the rest of the turn - but t…
- L599-619 `test_an_enemy_turn_wipe_ends_the_battle_before_the_round_tick() -> void` — A wipe during the enemy turn closes the turn record and ends the battle on the spot: the round tick never runs, so a status that was about to fire does not get…
- L626-642 `test_a_round_end_tick_that_kills_the_last_ally_reports_a_status_death() -> void` — A tick that kills the last ally reports a *status* death, not an ally wipe: the two share the defeat outcome but not the reason the balance report reads.
- L647-663 `test_a_round_end_tick_that_kills_the_last_enemy_wins_the_battle() -> void` — A tick that kills the last enemy on the final wave wins the battle: a win is not reserved for a played card.
- L669-690 `test_a_round_end_tick_on_a_non_final_wave_advances_the_run() -> void` — A tick that clears a wave with a successor advances the run instead of ending it. That record is closed before the advance is attempted (Step 8 closes, then che…
- L695-712 `test_a_mutual_round_end_wipe_resolves_as_a_defeat() -> void` — When the round tick kills both sides the run is a defeat: the ally check comes first, so a mutual wipe can never be recorded as a win.
- L720-747 `test_a_wave_cleared_during_the_enemy_turn_still_ticks_the_round() -> void` — A wave can be cleared by the enemy turn too - the last enemy dies to its own skill. That path advances the wave and then *falls through* to Step 8, so the round…

Private:
- L115-122 `_damage_skill`
- L126-133 `_shield_skill`
- L138-145 `_self_destruct_skill`
- L148-153 `_wrap_skill`
- L158-165 `_ally_data`
- L170-179 `_enemy_data`
- L183-189 `_waves`
- L207-215 `_remove_tree`
- L221-255 `_prepare`
- L259-264 `_play`
- L270-275 `_first_at`
- L280-287 `_shield_of`
- L291-297 `_asks_on`
- L302-311 `_animations_for`
- L316-321 `_while_acting`
- L325-330 `_messages_with`
- L334-338 `_ticked`
- L341-346 `_events_of`
- L350-355 `_turn_ended`
- L359-364 `_run_ended`
- L367-369 `_victory`
- L372-373 `_reason`

Uses: Card, EffectBlock, EnemyIntent, GameManager, GameState, GameUI, SkillData, SkillEffect, TelemetryConsent, TelemetryConsentPopup, TelemetryManager, TelemetrySchema, TelemetrySink, Unit, UnitData
Used by: —
Loads: —

