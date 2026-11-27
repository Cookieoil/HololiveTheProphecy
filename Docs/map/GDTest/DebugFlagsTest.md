<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DebugFlagsTest.gd` — `class_name DebugFlagsTest` extends `GdUnitTestSuite`

`87` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the debug palette's Flags tab (Scenes/HUD/DebugMenuPopup.gd): it renders one toggle per staged flag from the snapshot, it is gated like every other mutati…

Constants:
- L10 `FLAG_NAME: String = "exp"`

Public API:
- L38-48 `test_the_flags_tab_lists_a_toggle_per_staged_flag() -> void`
- L51-57 `test_an_empty_registry_leaves_the_tab_without_toggles() -> void`
- L60-86 `test_toggling_a_flag_asks_the_turn_loop_to_apply_it() -> void`

Private:
- L13-18 `_snapshot`
- L21-28 `_panel`
- L31-35 `_toggle`

Uses: DebugMenuPopup
Used by: —
Loads: —

