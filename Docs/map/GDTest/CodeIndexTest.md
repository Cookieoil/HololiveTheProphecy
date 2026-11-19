<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/CodeIndexTest.gd` — `class_name CodeIndexTest` extends `GdUnitTestSuite`

`292` lines · [back to the map](../../CODEBASE_MAP.md)

> Fixture tests for Tools/CodeIndexParser.gd, the pure parsing layer behind the generated navigation set (Docs/). Each fixture is an inline script so the test nev…

Constants:
- L11 `SCRIPT_PATH: String = "res://Fixture/Thing.gd"`
- L12 `SCENE_PATH: String = "res://Fixture/Thing.tscn"`

Public API:
- L102-107 `test_script_header_doc_becomes_the_summary() -> void`
- L110-115 `test_member_doc_is_not_the_file_summary() -> void`
- L118-134 `test_declarations_are_classified_by_kind() -> void`
- L137-146 `test_wrapped_signature_keeps_arguments_and_return_type() -> void`
- L149-154 `test_last_function_range_reaches_the_end_of_the_file() -> void`
- L157-165 `test_enum_block_range_and_values() -> void`
- L168-178 `test_one_line_enum_is_parsed() -> void`
- L181-199 `test_inner_class_is_listed_without_flattening_members() -> void`
- L202-208 `test_crlf_input_matches_lf_input() -> void`
- L211-217 `test_scene_script_reference_uses_the_path_not_the_uid() -> void`
- L220-229 `test_scene_node_depths_and_instance() -> void`
- L232-240 `test_scene_without_a_script_still_parses() -> void`
- L243-249 `test_data_file_shape_entries_and_keys() -> void`
- L252-256 `test_data_file_array_shape() -> void`
- L259-262 `test_page_file_names_are_derived_from_the_source_path() -> void`
- L265-277 `test_dependency_scan_ignores_comments() -> void`
- L280-291 `test_resource_refs_are_deduplicated_and_skip_addons() -> void`

Private:
- L15-45 `_script_fixture`
- L49-60 `_member_doc_fixture`
- L63-69 `_function_named`
- L74-79 `_entry_at`
- L82-99 `_scene_fixture`

Uses: BattleScene, Card, CardUI, CodeIndexParser, GameUI, Unit
Used by: —
Loads: res://Fixture/Thing.gd, res://Fixture/Thing.tscn, res://Scenes/Cards/CardUI.tscn, res://Data/json/units.json, res://Data/json/waves.json

