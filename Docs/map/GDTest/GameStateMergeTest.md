<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/GameStateMergeTest.gd` — `class_name GameStateMergeTest` extends `GdUnitTestSuite`

`89` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks in where a merged card lands in hand: it takes the slot of the card the player merged *into*, so a merge never teleports the result to the far right.

Public API:
- L26-39 `test_cross_merge_takes_the_slot_of_the_target() -> void`
- L42-55 `test_cross_merge_onto_an_earlier_card_keeps_that_slot() -> void`
- L58-69 `test_cross_merge_onto_the_last_card_stays_last() -> void`
- L72-88 `test_double_merge_takes_the_slot_of_the_target() -> void`

Private:
- L11-17 `_make_state`
- L21-23 `_value_at`

Uses: Card, GameState
Used by: —
Loads: —

