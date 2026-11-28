<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/CodeIndexParser.gd` — `class_name CodeIndexParser` extends `RefCounted`

`879` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure parsing layer behind Tools/gen_code_index.gd. Every function here takes text in and returns plain Dictionaries: no file system access, no rendering, no CLI…

Sections: Constants · Public Methods · Private Methods
- L60 `class ScriptScan extends ` (members are not indexed)

Constants:
- L16 `TEST_DIR_PREFIX: String = "GDTest/"` — Tests live here; they get their own overview table so game code stays visible.
- L18 `RES_SCHEME: String = "res://"` — Every resource reference starts with this scheme.
- L20 `MAX_ITEM_KEYS: int = 24` — Caps that keep the generated artifacts cheap to read.
- L21 `MAX_DOC_CHARS: int = 160`
- L26 `OVERVIEW_ROLE_CHARS: int = 72` — The role cell in the overview table is capped harder than a page header, because the overview has a byte budget and one line per script (see overview_role()). 9…
- L27 `MAX_REFS_LISTED: int = 20`
- L28 `HEADER_SCAN_LINES: int = 40`
- L29 `KEY_COLLECT_DEPTH: int = 3`

Public API:
- L34-35 `static normalized_text(text: String) -> String` — Normalises line endings, so CRLF and LF sources produce identical output.
- L38-41 `static repo_path(res_path: String) -> String`
- L47-53 `static parse_script(res_path: String, text: String) -> Dictionary` — Parses one script into a flat record. Only top-level declarations (column 0) are indexed; function bodies and inner-class members are skipped on purpose, which…
- L268-326 `static parse_scene(res_path: String, text: String) -> Dictionary` — Parses one .tscn into a summary plus its full node tree, so @onready paths and instanced scenes can be checked without opening the scene file.
- L332-337 `static node_depth(parent_path: String) -> int` — Depth of a .tscn node. The root carries no parent attribute; `parent="."` is a direct child of the root; every other parent path adds one level per segment, so…
- L341-364 `static parse_data_file(res_path: String, text: String) -> Dictionary` — Shape of one runtime data file, so balancing work rarely needs the JSON open.
- L377-390 `static apply_dependencies(infos: Array[Dictionary], texts: Dictionary, class_names: PackedStringArray) -> void` — Records which `class_name` symbols and res:// paths each script touches, so a page can answer "what else do I have to check if I change this?". Two scans, becau…
- L394-400 `static strip_comments(text: String) -> String` — Drops whole-line `#` comments, which keeps prose out of the dependency scan.
- L406-410 `static strip_literals(text: String) -> String` — Blanks every quoted literal (and a trailing `#` comment), so a dependency scan of the result only ever sees code. Offsets are preserved - a literal becomes spac…
- L414-438 `static line_without_literals(line: String) -> String` — One line with its quoted literals and comment replaced by spaces.
- L442-443 `static script_page_file(repo_path_value: String) -> String` — Core/Card.gd -> Core/Card.md, relative to the directory holding the map.
- L447-448 `static scene_page_file(repo_path_value: String) -> String` — Scenes/BattleScene/BattleScene.tscn -> .../BattleScene.scene.md
- L452-457 `static line_range(record: Dictionary) -> String` — `12` for a single line, `12-40` for a range.
- L461-473 `static declaration_detail(record: Dictionary, with_value: bool) -> String` — Type/argument/value suffix used by both the TSV rows and the detail pages.
- L480-483 `static overview_role(role: String) -> String` — A shorter role for the overview table only. The per-script page carries the full sentence; the overview has a hard byte budget it has to stay inside (see Tools/…
- L488-503 `static script_role(info: Dictionary) -> String` — The map's "role" cell: the file's own header doc when it has one, otherwise a structural summary, so the column is never empty for a real file.
- L507-512 `static dict_string(source: Dictionary, key: String, fallback: String = "") -> String`
- L515-523 `static dict_int(source: Dictionary, key: String, fallback: int = 0) -> int`
- L526-531 `static dict_array(source: Dictionary, key: String) -> Array`
- L534-545 `static dict_string_array(source: Dictionary, key: String) -> PackedStringArray`
- L548-553 `static dict_bool(source: Dictionary, key: String, fallback: bool = false) -> bool`
- L558-568 `static function_end(lines: PackedStringArray, from_index: int, start_line: int) -> int` — Last line of a function body: everything up to the next column-0 declaration, which is what makes `path:start-end` ranges safe to read directly.
- L574-586 `static header_end_index(lines: PackedStringArray) -> int` — End (0-based, exclusive) of the file's leading `##` block, or -1 when there is none. A `##` block that sits after a real declaration is a member's doc comment,…
- L591-601 `static has_declaration_before(lines: PackedStringArray, index: int) -> bool` — True when anything other than the class_name/extends preamble, an annotation, a comment or a blank line already appeared before `index`.
- L604-613 `static header_summary(lines: PackedStringArray, header_end: int) -> String`
- L616-617 `static doc_text(line: String) -> String`
- L621-631 `static join_doc(doc: PackedStringArray) -> String` — Joins a `##` block into one line, dropping empty lines and `@tag` metadata.
- L634-639 `static leading_identifier(text: String) -> String`
- L642-649 `static is_identifier_char(character: String) -> bool`
- L653-661 `static extract_between(text: String, prefix: String, suffix: String) -> String` — Text between the first `prefix` and the next `suffix` after it, or "".
- L666-667 `static attribute(line: String, attribute_name: String) -> String` — Value of a `name="value"` attribute inside a .tscn header line, or "". The leading space keeps `id="..."` from matching inside `uid="..."`.
- L670-683 `static parse_signal(line: String) -> Dictionary`
- L686-712 `static parse_function(signature: String, line_number: int) -> Dictionary`
- L716-739 `static parse_named_declaration(line: String, keyword: String) -> Dictionary` — Splits `var/const/static var NAME: TYPE = VALUE` into its three parts.
- L744-766 `static parse_enum(lines: PackedStringArray, start_index: int, header_line: String) -> Dictionary` — Reads `enum Name { A, B = 3 }` in both the one-line and the block form. `next` is the 0-based index of the first line after the enum.
- L769-781 `static enum_values(body: String) -> PackedStringArray`
- L785-796 `static signature_complete(signature: String) -> bool` — True once a (possibly wrapped) function header ends in `:` with balanced brackets.
- L799-800 `static is_resource_path_char(character: String) -> bool`
- L804-818 `static contains_word(text: String, word: String) -> bool` — Whole-word search, so `Unit` does not match `UnitUI`.
- L824-838 `static scan_resource_refs(text: String) -> PackedStringArray` — res:// paths referenced by a script (preload/load), deduplicated and without vendor paths. The scan starts after the `res://` scheme itself, otherwise the first…
- L843-856 `static collect_keys(values: Array, depth: int) -> PackedStringArray` — Union of the dictionary keys found in `values`, walking nested arrays and objects a few levels deep. Capped so a wide schema cannot bloat the map.
- L860-864 `static keys_of(raw_keys: Array) -> PackedStringArray` — Stringifies raw JSON keys (object roots), then dedupes, sorts and caps them.
- L867-877 `static finalize_keys(keys: PackedStringArray) -> PackedStringArray`

Private:
- L86-107 `_parse_script_line`
- L112-114 `_collect_doc`
- L118-137 `_parse_preamble_line`
- L145-160 `_parse_annotation_line`
- L164-168 `_annotated_declaration`
- L172-185 `_parse_member_line`
- L190-194 `_described`
- L199-205 `_parse_enum_line`
- L209-219 `_parse_variable_line`
- L225-239 `_parse_function_line`
- L243-262 `_script_record`

Uses: —
Used by: GDTest/CodeIndexTest.gd, GDTest/DiffReviewTest.gd, GDTest/TriageParserTest.gd, Tools/DiffReviewFormatter.gd, Tools/DiffReviewParser.gd, Tools/TriageParser.gd, Tools/check_navigation.gd, Tools/gen_code_index.gd, Tools/review_diff.gd, Tools/triage.gd
Loads: res://

