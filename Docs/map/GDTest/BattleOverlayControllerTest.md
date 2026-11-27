<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/BattleOverlayControllerTest.gd` — `class_name BattleOverlayControllerTest` extends `GdUnitTestSuite`

`62` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks how the overlay finds the scene it belongs to. `BattleOverlay` is a node in BattleScene.tscn, so the scene root owns it and the entity rows (`EntityOverla…

Public API:
- L39-47 `test_injected_scene_root_binds_both_entity_rows() -> void`
- L53-61 `test_an_unowned_parent_does_not_supply_the_rows() -> void` — The rows sit one node up in this tree - exactly where the removed upward walk used to look - and they are still not taken: row binding comes from an owned scene…

Private:
- L18-28 `_make_scene_root`
- L33-36 `_make_controller`

Uses: BattleOverlayController
Used by: —
Loads: —

