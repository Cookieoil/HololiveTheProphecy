<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/BattleOverlayControllerTest.gd` — `class_name BattleOverlayControllerTest` extends `GdUnitTestSuite`

`150` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks how the overlay finds the scene it belongs to. `BattleOverlay` is a node in BattleScene.tscn, so the scene root owns it and the entity rows (`EntityOverla…

Public API:
- L58-89 `test_the_portrait_lookup_understands_every_row_shape() -> void` — The orb rails borrow the portrait the battle row already draws, because the unit list carries no art of its own. Whatever the row holds, this is what it can fin…
- L92-124 `test_the_portrait_lookup_ignores_the_intent_and_status_chrome() -> void`
- L127-135 `test_injected_scene_root_binds_both_entity_rows() -> void`
- L141-149 `test_an_unowned_parent_does_not_supply_the_rows() -> void` — The rows sit one node up in this tree - exactly where the removed upward walk used to look - and they are still not taken: row binding comes from an owned scene…

Private:
- L18-28 `_make_scene_root`
- L33-36 `_make_controller`
- L40-43 `_texture`
- L48-51 `_row_holder`

Uses: BattleOverlayController
Used by: —
Loads: —

