<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/StatusCatalogTest.gd` — `class_name StatusCatalogTest` extends `GdUnitTestSuite`

`141` lines · [back to the map](../../CODEBASE_MAP.md)

> Tests for the buff/debuff status system: Unit.statuses + StatusIconCatalog.
- L95 `class FlatBuffUnit extends RefCounted` (members are not indexed)
- L103 `class SloppyBuffUnit extends RefCounted` (members are not indexed)

Constants:
- L8 `CATALOG_PATH: String`

Public API:
- L18-27 `test_catalog_resolves_sample_icons() -> void`
- L30-41 `test_regeneration_counts_down_and_heals() -> void`
- L44-54 `test_gloom_stacks_and_damages() -> void`
- L57-64 `test_statuses_clear_when_a_unit_dies() -> void`
- L67-90 `test_catalog_extracts_buff_and_debuff() -> void`
- L109-126 `test_catalog_reads_flat_buff_properties_and_their_charges() -> void`
- L129-140 `test_catalog_falls_back_to_properties_named_like_a_buff() -> void`

Private:
- L11-15 `_make_unit`

Uses: BattleScene, StatusIconCatalog, Unit, UnitData
Used by: —
Loads: res://Scenes/BattleScene/Assets/StatusIcons.tres

