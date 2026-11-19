<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/CardMergeAnimationTest.gd` — `class_name CardMergeAnimationTest` extends `GdUnitTestSuite`

`564` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks in the merge: the card the player was carrying is picked up from the exact point they released it, the two cards drift into each other and fold closed int…

Constants:
- L27 `MERGE_SETTLE_MILLIS: int = 900` — Comfortably longer than CardUI's converge + reveal.
- L30 `FOLDED_MILLIS: int = 360` — Just past the point the two cards have folded away and the merged card has taken over from the edge they left: CardUI.MERGE_CONVERGE_TIME plus a margin.
- L32 `HALF_WAY_MILLIS: int = 150` — Part way through CardUI.MERGE_CONVERGE_TIME, for looking at cards mid-drift.
- L34 `LAYOUT_SETTLE_MILLIS: int = 60` — Long enough for the hand layout to settle, so slot positions are real.

Public API:
- L117-160 `test_the_two_cards_are_mounted_where_they_were_and_the_layout_never_moves() -> void`
- L165-207 `test_the_merge_starts_from_where_the_card_was_released() -> void` — The point of the whole animation: the card the player was carrying is picked up where they let go of it, not where it was dragged out of.
- L212-225 `test_a_merge_with_no_release_starts_from_the_cards_own_slot() -> void` — A merge driven on the model rather than by a drag has no release point to pick up from, so the carried card starts from its own slot instead.
- L232-286 `test_the_cards_fold_over_and_the_merged_card_unfolds_out_of_the_same_pose() -> void` — The two cards fold over as they arrive, and the merged card takes over from that exact pose - the same angle and the same faintness - and unfolds out of it. The…
- L294-304 `test_a_card_at_the_fold_angle_is_not_drawn_at_all() -> void` — A card at the fold angle must not be drawn at all. This curve is the whole reason the fold can run all the way to edge on without ending in a thin bright line,…
- L307-330 `test_the_merged_card_settles_flat_and_the_merge_is_cleaned_up() -> void`
- L333-347 `test_the_merged_card_takes_the_slot_the_merge_produced() -> void`
- L351-368 `test_the_hand_refresh_reuses_the_merging_card() -> void`
- L371-395 `test_the_hand_refresh_never_slides_the_merging_card() -> void`
- L398-416 `test_grabbing_a_merging_card_snaps_it_flat() -> void`
- L419-442 `test_the_survivors_glide_into_the_gap_the_merge_left() -> void`
- L446-471 `test_a_double_merge_merges_a_free_play_card() -> void`
- L477-492 `test_every_card_wears_the_same_frame() -> void` — Every card wears the same frame, whatever it has been through. Merging used to repaint the frame, which made a merged card look like a different object rather t…
- L499-537 `test_the_two_cards_are_never_hidden_before_the_merged_card() -> void` — The user-visible contract: the two cards must never be taken off screen before the merged card is on it. They are children of the very node that used to be dimm…
- L542-551 `test_the_merged_card_is_drawn_in_front_of_the_two_cards_that_made_it() -> void` — The card that comes out of the merge has to be the thing the player watches, so both cards that made it are parked behind it in the draw order.
- L557-563 `test_the_two_cards_are_drawn_detached_from_the_hand_layout() -> void` — The two cards are drawn in viewport space, detached from the hand's layout, so the merge can glide between the point of release and the slot it lands in without…

Private:
- L39-51 `_make_hand_bar`
- L54-60 `_row`
- L63-66 `_card_ui`
- L71-81 `_plates`
- L85-91 `_tilt`
- L95-102 `_ready_hand`
- L107-113 `_merge_on_state`

Uses: Card, CardUI, ForgePlate, GameState, HandBar
Used by: —
Loads: —

