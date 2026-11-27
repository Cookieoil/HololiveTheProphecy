<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/CodeIndexParser.gd` — `class_name CodeIndexParser` extends `RefCounted`

`759` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure parsing layer behind Tools/gen_code_index.gd. Every function here takes text in and returns plain Dictionaries: no file system access, no rendering, no CLI…

Sections: Constants · Public Methods · Private Methods

Constants:
- L16 `TEST_DIR_PREFIX: String = "GDTest/"` — Tests live here; they get their own overview table so game code stays visible.
- L18 `RES_SCHEME: String = "res://"` — Every resource reference starts with this scheme.
- L20 `MAX_ITEM_KEYS: int = 24` — Caps that keep the generated artifacts cheap to read.
- L21 `MAX_DOC_CHARS: int = 160`
- L24 `OVERVIEW_ROLE_CHARS: int = 96` — The role cell in the overview table is capped harder than a page header, because the overview has a byte budget and one line per script (see overview_role()).
- L25 `MAX_REFS_LISTED: int = 20`
- L26 `HEADER_SCAN_LINES: int = 40`
- L27 `KEY_COLLECT_DEPTH: int = 3`

Public API:
- L32-33 `static normalized_text(text: String) -> String` — Normalises line endings, so CRLF and LF sources produce identical output.
- L36-39 `static repo_path(res_path: String) -> String`
- L45-188 `static parse_script(res_path: String, text: String) -> Dictionary` — Parses one script into a flat record. Only top-level declarations (column 0) are indexed; function bodies and inner-class members are skipped on purpose, which…
- L193-251 `static parse_scene(res_path: String, text: String) -> Dictionary` — Parses one .tscn into a summary plus its full node tree, so @onready paths and instanced scenes can be checked without opening the scene file.
- L257-262 `static node_depth(parent_path: String) -> int` — Depth of a .tscn node. The root carries no parent attribute; `parent="."` is a direct child of the root; every other parent path adds one level per segment, so…
- L266-289 `static parse_data_file(res_path: String, text: String) -> Dictionary` — Shape of one runtime data file, so balancing work rarely needs the JSON open.
- L296-308 `static apply_dependencies(infos: Array[Dictionary], texts: Dictionary, class_names: PackedStringArray) -> void` — Records which `class_name` symbols and res:// paths each script touches, so a page can answer "what else do I have to check if I change this?". Comments are str…
- L312-318 `static strip_comments(text: String) -> String` — Drops whole-line `#` comments, which keeps prose out of the dependency scan.
- L322-323 `static script_page_file(repo_path_value: String) -> String` — Core/Card.gd -> Core/Card.md, relative to the directory holding the map.
- L327-328 `static scene_page_file(repo_path_value: String) -> String` — Scenes/BattleScene/BattleScene.tscn -> .../BattleScene.scene.md
- L332-337 `static line_range(record: Dictionary) -> String` — `12` for a single line, `12-40` for a range.
- L341-353 `static declaration_detail(record: Dictionary, with_value: bool) -> String` — Type/argument/value suffix used by both the TSV rows and the detail pages.
- L360-363 `static overview_role(role: String) -> String` — A shorter role for the overview table only. The per-script page carries the full sentence; the overview has a hard byte budget it has to stay inside (see Tools/…
- L368-383 `static script_role(info: Dictionary) -> String` — The map's "role" cell: the file's own header doc when it has one, otherwise a structural summary, so the column is never empty for a real file.
- L387-392 `static dict_string(source: Dictionary, key: String, fallback: String = "") -> String`
- L395-403 `static dict_int(source: Dictionary, key: String, fallback: int = 0) -> int`
- L406-411 `static dict_array(source: Dictionary, key: String) -> Array`
- L414-425 `static dict_string_array(source: Dictionary, key: String) -> PackedStringArray`
- L428-433 `static dict_bool(source: Dictionary, key: String, fallback: bool = false) -> bool`
- L438-448 `static function_end(lines: PackedStringArray, from_index: int, start_line: int) -> int` — Last line of a function body: everything up to the next column-0 declaration, which is what makes `path:start-end` ranges safe to read directly.
- L454-466 `static header_end_index(lines: PackedStringArray) -> int` — End (0-based, exclusive) of the file's leading `##` block, or -1 when there is none. A `##` block that sits after a real declaration is a member's doc comment,…
- L471-481 `static has_declaration_before(lines: PackedStringArray, index: int) -> bool` — True when anything other than the class_name/extends preamble, an annotation, a comment or a blank line already appeared before `index`.
- L484-493 `static header_summary(lines: PackedStringArray, header_end: int) -> String`
- L496-497 `static doc_text(line: String) -> String`
- L501-511 `static join_doc(doc: PackedStringArray) -> String` — Joins a `##` block into one line, dropping empty lines and `@tag` metadata.
- L514-519 `static leading_identifier(text: String) -> String`
- L522-529 `static is_identifier_char(character: String) -> bool`
- L533-541 `static extract_between(text: String, prefix: String, suffix: String) -> String` — Text between the first `prefix` and the next `suffix` after it, or "".
- L546-547 `static attribute(line: String, attribute_name: String) -> String` — Value of a `name="value"` attribute inside a .tscn header line, or "". The leading space keeps `id="..."` from matching inside `uid="..."`.
- L550-563 `static parse_signal(line: String) -> Dictionary`
- L566-592 `static parse_function(signature: String, line_number: int) -> Dictionary`
- L596-619 `static parse_named_declaration(line: String, keyword: String) -> Dictionary` — Splits `var/const/static var NAME: TYPE = VALUE` into its three parts.
- L624-646 `static parse_enum(lines: PackedStringArray, start_index: int, header_line: String) -> Dictionary` — Reads `enum Name { A, B = 3 }` in both the one-line and the block form. `next` is the 0-based index of the first line after the enum.
- L649-661 `static enum_values(body: String) -> PackedStringArray`
- L665-676 `static signature_complete(signature: String) -> bool` — True once a (possibly wrapped) function header ends in `:` with balanced brackets.
- L679-680 `static is_resource_path_char(character: String) -> bool`
- L684-698 `static contains_word(text: String, word: String) -> bool` — Whole-word search, so `Unit` does not match `UnitUI`.
- L704-718 `static scan_resource_refs(text: String) -> PackedStringArray` — res:// paths referenced by a script (preload/load), deduplicated and without vendor paths. The scan starts after the `res://` scheme itself, otherwise the first…
- L723-736 `static collect_keys(values: Array, depth: int) -> PackedStringArray` — Union of the dictionary keys found in `values`, walking nested arrays and objects a few levels deep. Capped so a wide schema cannot bloat the map.
- L740-744 `static keys_of(raw_keys: Array) -> PackedStringArray` — Stringifies raw JSON keys (object roots), then dedupes, sorts and caps them.
- L747-757 `static finalize_keys(keys: PackedStringArray) -> PackedStringArray`

Uses: —
Used by: GDTest/CodeIndexTest.gd, GDTest/DiffReviewTest.gd, GDTest/TriageParserTest.gd, Tools/DiffReviewParser.gd, Tools/TriageParser.gd, Tools/check_navigation.gd, Tools/gen_code_index.gd, Tools/review_diff.gd, Tools/triage.gd
Loads: res://

