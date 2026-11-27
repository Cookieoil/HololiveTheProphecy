<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/UiSnapshotTest.gd` — `class_name UiSnapshotTest` extends `GdUnitTestSuite`

`82` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the seams the UI snapshot pipeline (Tools/snapshot_runner.tscn) relies on: a fixed seed must reproduce the deal, and the overlay must expose a bounded, ca…

Constants:
- L10 `SCENE_PATH: String`
- L12 `MAX_BOARD_FRAMES: int = 900` — Enough frames for the seeded board to deal and reach the player-action phase.
- L13 `SEED_PINNED: int = 1337`

Public API:
- L55-64 `test_fixed_seed_reproduces_the_dealt_hand() -> void`
- L67-81 `test_ultimate_callout_seam_is_bounded_and_exposes_the_tooltip() -> void`

Private:
- L16-28 `_mount`
- L31-38 `_wait_for_board`
- L42-46 `_hand_signature`
- L49-52 `_release`

Uses: BattleScene, Card
Used by: —
Loads: res://Scenes/BattleScene/BattleScene.tscn

