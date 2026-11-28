<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/CodeIndexParser.gd` — `class_name CodeIndexParser` extends `RefCounted`

`806` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure parsing layer behind Tools/gen_code_index.gd. Every function here takes text in and returns plain Dictionaries: no file system access, no rendering, no CLI…

Sections: Constants · Public Methods · Private Methods

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
- L47-190 `static parse_script(res_path: String, text: String) -> Dictionary` — Parses one script into a flat record. Only top-level declarations (column 0) are indexed; function bodies and inner-class members are skipped on purpose, which…
- L195-253 `static parse_scene(res_path: String, text: String) -> Dictionary` — Parses one .tscn into a summary plus its full node tree, so @onready paths and instanced scenes can be checked without opening the scene file.
- L259-264 `static node_depth(parent_path: String) -> int` — Depth of a .tscn node. The root carries no parent attribute; `parent="."` is a direct child of the root; every other parent path adds one level per segment, so…
- L268-291 `static parse_data_file(res_path: String, text: String) -> Dictionary` — Shape of one runtime data file, so balancing work rarely needs the JSON open.
- L304-317 `static apply_dependencies(infos: Array[Dictionary], texts: Dictionary, class_names: PackedStringArray) -> void` — Records which `class_name` symbols and res:// paths each script touches, so a page can answer "what else do I have to check if I change this?". Two scans, becau…
- L321-327 `static strip_comments(text: String) -> String` — Drops whole-line `#` comments, which keeps prose out of the dependency scan.
- L333-337 `static strip_literals(text: String) -> String` — Blanks every quoted literal (and a trailing `#` comment), so a dependency scan of the result only ever sees code. Offsets are preserved - a literal becomes spac…
- L341-365 `static line_without_literals(line: String) -> String` — One line with its quoted literals and comment replaced by spaces.
- L369-370 `static script_page_file(repo_path_value: String) -> String` — Core/Card.gd -> Core/Card.md, relative to the directory holding the map.
- L374-375 `static scene_page_file(repo_path_value: String) -> String` — Scenes/BattleScene/BattleScene.tscn -> .../BattleScene.scene.md
- L379-384 `static line_range(record: Dictionary) -> String` — `12` for a single line, `12-40` for a range.
- L388-400 `static declaration_detail(record: Dictionary, with_value: bool) -> String` — Type/argument/value suffix used by both the TSV rows and the detail pages.
- L407-410 `static overview_role(role: String) -> String` — A shorter role for the overview table only. The per-script page carries the full sentence; the overview has a hard byte budget it has to stay inside (see Tools/…
- L415-430 `static script_role(info: Dictionary) -> String` — The map's "role" cell: the file's own header doc when it has one, otherwise a structural summary, so the column is never empty for a real file.
- L434-439 `static dict_string(source: Dictionary, key: String, fallback: String = "") -> String`
- L442-450 `static dict_int(source: Dictionary, key: String, fallback: int = 0) -> int`
- L453-458 `static dict_array(source: Dictionary, key: String) -> Array`
- L461-472 `static dict_string_array(source: Dictionary, key: String) -> PackedStringArray`
- L475-480 `static dict_bool(source: Dictionary, key: String, fallback: bool = false) -> bool`
- L485-495 `static function_end(lines: PackedStringArray, from_index: int, start_line: int) -> int` — Last line of a function body: everything up to the next column-0 declaration, which is what makes `path:start-end` ranges safe to read directly.
- L501-513 `static header_end_index(lines: PackedStringArray) -> int` — End (0-based, exclusive) of the file's leading `##` block, or -1 when there is none. A `##` block that sits after a real declaration is a member's doc comment,…
- L518-528 `static has_declaration_before(lines: PackedStringArray, index: int) -> bool` — True when anything other than the class_name/extends preamble, an annotation, a comment or a blank line already appeared before `index`.
- L531-540 `static header_summary(lines: PackedStringArray, header_end: int) -> String`
- L543-544 `static doc_text(line: String) -> String`
- L548-558 `static join_doc(doc: PackedStringArray) -> String` — Joins a `##` block into one line, dropping empty lines and `@tag` metadata.
- L561-566 `static leading_identifier(text: String) -> String`
- L569-576 `static is_identifier_char(character: String) -> bool`
- L580-588 `static extract_between(text: String, prefix: String, suffix: String) -> String` — Text between the first `prefix` and the next `suffix` after it, or "".
- L593-594 `static attribute(line: String, attribute_name: String) -> String` — Value of a `name="value"` attribute inside a .tscn header line, or "". The leading space keeps `id="..."` from matching inside `uid="..."`.
- L597-610 `static parse_signal(line: String) -> Dictionary`
- L613-639 `static parse_function(signature: String, line_number: int) -> Dictionary`
- L643-666 `static parse_named_declaration(line: String, keyword: String) -> Dictionary` — Splits `var/const/static var NAME: TYPE = VALUE` into its three parts.
- L671-693 `static parse_enum(lines: PackedStringArray, start_index: int, header_line: String) -> Dictionary` — Reads `enum Name { A, B = 3 }` in both the one-line and the block form. `next` is the 0-based index of the first line after the enum.
- L696-708 `static enum_values(body: String) -> PackedStringArray`
- L712-723 `static signature_complete(signature: String) -> bool` — True once a (possibly wrapped) function header ends in `:` with balanced brackets.
- L726-727 `static is_resource_path_char(character: String) -> bool`
- L731-745 `static contains_word(text: String, word: String) -> bool` — Whole-word search, so `Unit` does not match `UnitUI`.
- L751-765 `static scan_resource_refs(text: String) -> PackedStringArray` — res:// paths referenced by a script (preload/load), deduplicated and without vendor paths. The scan starts after the `res://` scheme itself, otherwise the first…
- L770-783 `static collect_keys(values: Array, depth: int) -> PackedStringArray` — Union of the dictionary keys found in `values`, walking nested arrays and objects a few levels deep. Capped so a wide schema cannot bloat the map.
- L787-791 `static keys_of(raw_keys: Array) -> PackedStringArray` — Stringifies raw JSON keys (object roots), then dedupes, sorts and caps them.
- L794-804 `static finalize_keys(keys: PackedStringArray) -> PackedStringArray`

Uses: —
Used by: GDTest/CodeIndexTest.gd, GDTest/DiffReviewTest.gd, GDTest/TriageParserTest.gd, Tools/DiffReviewFormatter.gd, Tools/DiffReviewParser.gd, Tools/TriageParser.gd, Tools/check_navigation.gd, Tools/gen_code_index.gd, Tools/review_diff.gd, Tools/triage.gd
Loads: res://

