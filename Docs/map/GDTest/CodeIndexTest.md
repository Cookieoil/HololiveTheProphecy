<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/CodeIndexTest.gd` — `class_name CodeIndexTest` extends `GdUnitTestSuite`

`332` lines · [back to the map](../../CODEBASE_MAP.md)

> Fixture tests for Tools/CodeIndexParser.gd, the pure parsing layer behind the generated navigation set (Docs/). Each fixture is an inline script so the test nev…

Constants:
- L11 `SCRIPT_PATH: String = "res://Fixture/Thing.gd"`
- L12 `SCENE_PATH: String = "res://Fixture/Thing.tscn"`

Public API:
- L102-107 `test_script_header_doc_becomes_the_summary() -> void`
- L110-115 `test_member_doc_is_not_the_file_summary() -> void`
- L120-125 `test_the_overview_role_is_capped_without_touching_short_roles() -> void` — The overview table is the one artifact with a hard byte budget, so its role cell is capped harder than a page header; the full sentence stays on the script's pa…
- L128-144 `test_declarations_are_classified_by_kind() -> void`
- L147-156 `test_wrapped_signature_keeps_arguments_and_return_type() -> void`
- L159-164 `test_last_function_range_reaches_the_end_of_the_file() -> void`
- L167-175 `test_enum_block_range_and_values() -> void`
- L178-188 `test_one_line_enum_is_parsed() -> void`
- L191-209 `test_inner_class_is_listed_without_flattening_members() -> void`
- L212-218 `test_crlf_input_matches_lf_input() -> void`
- L221-227 `test_scene_script_reference_uses_the_path_not_the_uid() -> void`
- L230-239 `test_scene_node_depths_and_instance() -> void`
- L242-250 `test_scene_without_a_script_still_parses() -> void`
- L253-259 `test_data_file_shape_entries_and_keys() -> void`
- L262-266 `test_data_file_array_shape() -> void`
- L269-272 `test_page_file_names_are_derived_from_the_source_path() -> void`
- L275-287 `test_dependency_scan_ignores_comments() -> void`
- L293-306 `test_dependency_scan_ignores_class_names_inside_string_literals() -> void` — A class name that only ever appears inside a string - a tool's rule list, a fixture, a scene path - is not a dependency. Counted as one, it inflates the class's…
- L311-317 `test_strip_literals_keeps_the_lines_shape() -> void` — The literal is blanked rather than removed, so the line's shape - and therefore a whole-word match next to it - is unchanged. A trailing comment is dropped.
- L320-331 `test_resource_refs_are_deduplicated_and_skip_addons() -> void`

Private:
- L15-45 `_script_fixture`
- L49-60 `_member_doc_fixture`
- L63-69 `_function_named`
- L74-79 `_entry_at`
- L82-99 `_scene_fixture`

Uses: CodeIndexParser
Used by: —
Loads: res://Fixture/Thing.gd, res://Fixture/Thing.tscn, res://Scenes/Cards/CardUI.tscn, res://Data/json/units.json, res://Data/json/waves.json

