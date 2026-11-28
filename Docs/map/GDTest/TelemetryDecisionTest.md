<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryDecisionTest.gd` — `class_name TelemetryDecisionTest` extends `GdUnitTestSuite`

`194` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks Core/Telemetry/TelemetryDecision.gd directly. GDTest/TelemetryTest.gd covers the same shapes end to end through a real battle, but it can only assert the…

Sections: Fixtures · Offered · Chosen

Public API:
- L78-91 `test_offered_describes_the_hand_the_roster_and_the_plays() -> void`
- L94-103 `test_a_defeated_ally_is_reported_as_dead_not_living() -> void`
- L108-119 `test_a_defeated_enemy_is_not_a_threat() -> void` — A defeated enemy keeps its stale intent in the list until the turn rolls over, and a stale intent must not read as a live threat.
- L124-131 `test_a_card_that_costs_an_action_is_not_offered_with_no_actions_left() -> void` — A card that costs an action is not playable with none left, so it must not inflate the pick-rate denominator.
- L134-146 `test_legal_merge_pairs_name_the_value_the_merge_would_produce() -> void`
- L151-164 `test_chosen_play_tells_a_rejected_play_from_an_applied_one() -> void`
- L169-175 `test_chosen_merge_reports_a_rejected_merge_as_not_applied() -> void` — The recorder notes the forged card only when the merge actually happened, so an empty note is exactly "this merge was rejected".
- L178-192 `test_chosen_ultimate_requires_the_caster_to_have_spent_it() -> void`

Private:
- L14-18 `_skill`
- L21-31 `_unit`
- L36-47 `_state`
- L50-51 `_no_intents`
- L56-57 `_int_of`
- L60-65 `_bool_of`
- L68-73 `_array_of`

Uses: Card, EnemyIntent, GameState, SkillData, TelemetryDecision, TelemetrySchema, Unit, UnitData
Used by: —
Loads: —

