<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/CardDrawAnimationTest.gd` — `class_name CardDrawAnimationTest` extends `GdUnitTestSuite`

`303` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks in the fake-3D card draw: - every CardUI owns its own warp material, so tilting one card can never tilt the rest of the hand - a dealt card leaves the dec…

Constants:
- L15 `CARD_UI_SCENE_PATH: String = "res://Scenes/Cards/CardUI.tscn"`
- L17 `FLIGHT_SETTLE_MILLIS: int = 900` — Comfortably longer than CardUI.DRAW_FLIGHT_TIME plus the largest deal stagger.

Public API:
- L66-76 `test_every_card_owns_its_fake_3d_material() -> void`
- L79-95 `test_dealt_card_starts_face_down_and_lands_flat() -> void`
- L98-122 `test_card_back_wears_the_emblem_image() -> void`
- L125-134 `test_grabbing_a_card_mid_flight_snaps_it_flat() -> void`
- L137-153 `test_set_hand_reuses_the_cards_already_in_the_row() -> void`
- L156-170 `test_set_hand_only_deals_the_new_cards() -> void`
- L173-187 `test_merged_card_appears_in_place_instead_of_flying_in() -> void`
- L190-205 `test_a_resting_card_renders_on_the_pixel_grid_of_its_slot() -> void`
- L208-222 `test_removed_card_leaves_the_row_at_once() -> void`
- L225-242 `test_merged_card_is_placed_at_its_model_slot() -> void`
- L245-268 `test_survivors_glide_instead_of_snapping_into_place() -> void`
- L271-278 `test_the_card_footprint_matches_its_layout_slot() -> void`
- L281-302 `test_hover_scales_the_card_without_warping_it() -> void`

Private:
- L21-27 `_make_card_ui`
- L32-44 `_make_hand_bar`
- L47-53 `_row`
- L57-63 `_tilt`

Uses: BattleScene, Card, CardUI, HandBar
Used by: —
Loads: res

