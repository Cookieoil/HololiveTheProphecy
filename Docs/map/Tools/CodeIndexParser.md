<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/CodeIndexParser.gd` — `class_name CodeIndexParser` extends `RefCounted`

`746` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure parsing layer behind Tools/gen_code_index.gd. Every function here takes text in and returns plain Dictionaries: no file system access, no rendering, no CLI…

Sections: Constants · Public Methods · Private Methods

Constants:
- L16 `TEST_DIR_PREFIX: String = "GDTest/"` — Tests live here; they get their own overview table so game code stays visible.
- L18 `RES_SCHEME: String = "res://"` — Every resource reference starts with this scheme.
- L20 `MAX_ITEM_KEYS: int = 24` — Caps that keep the generated artifacts cheap to read.
- L21 `MAX_DOC_CHARS: int = 160`
- L22 `MAX_REFS_LISTED: int = 20`
- L23 `HEADER_SCAN_LINES: int = 40`
- L24 `KEY_COLLECT_DEPTH: int = 3`

Public API:
- L29-30 `static normalized_text(text: String) -> String` — Normalises line endings, so CRLF and LF sources produce identical output.
- L33-36 `static repo_path(res_path: String) -> String`
- L42-185 `static parse_script(res_path: String, text: String) -> Dictionary` — Parses one script into a flat record. Only top-level declarations (column 0) are indexed; function bodies and inner-class members are skipped on purpose, which…
- L190-248 `static parse_scene(res_path: String, text: String) -> Dictionary` — Parses one .tscn into a summary plus its full node tree, so @onready paths and instanced scenes can be checked without opening the scene file.
- L254-259 `static node_depth(parent_path: String) -> int` — Depth of a .tscn node. The root carries no parent attribute; `parent="."` is a direct child of the root; every other parent path adds one level per segment, so…
- L263-286 `static parse_data_file(res_path: String, text: String) -> Dictionary` — Shape of one runtime data file, so balancing work rarely needs the JSON open.
- L293-305 `static apply_dependencies(infos: Array[Dictionary], texts: Dictionary, class_names: PackedStringArray) -> void` — Records which `class_name` symbols and res:// paths each script touches, so a page can answer "what else do I have to check if I change this?". Comments are str…
- L309-315 `static strip_comments(text: String) -> String` — Drops whole-line `#` comments, which keeps prose out of the dependency scan.
- L319-320 `static script_page_file(repo_path_value: String) -> String` — Core/Card.gd -> Core/Card.md, relative to the directory holding the map.
- L324-325 `static scene_page_file(repo_path_value: String) -> String` — Scenes/BattleScene/BattleScene.tscn -> .../BattleScene.scene.md
- L329-334 `static line_range(record: Dictionary) -> String` — `12` for a single line, `12-40` for a range.
- L338-350 `static declaration_detail(record: Dictionary, with_value: bool) -> String` — Type/argument/value suffix used by both the TSV rows and the detail pages.
- L355-370 `static script_role(info: Dictionary) -> String` — The map's "role" cell: the file's own header doc when it has one, otherwise a structural summary, so the column is never empty for a real file.
- L374-379 `static dict_string(source: Dictionary, key: String, fallback: String = "") -> String`
- L382-390 `static dict_int(source: Dictionary, key: String, fallback: int = 0) -> int`
- L393-398 `static dict_array(source: Dictionary, key: String) -> Array`
- L401-412 `static dict_string_array(source: Dictionary, key: String) -> PackedStringArray`
- L415-420 `static dict_bool(source: Dictionary, key: String, fallback: bool = false) -> bool`
- L425-435 `static function_end(lines: PackedStringArray, from_index: int, start_line: int) -> int` — Last line of a function body: everything up to the next column-0 declaration, which is what makes `path:start-end` ranges safe to read directly.
- L441-453 `static header_end_index(lines: PackedStringArray) -> int` — End (0-based, exclusive) of the file's leading `##` block, or -1 when there is none. A `##` block that sits after a real declaration is a member's doc comment,…
- L458-468 `static has_declaration_before(lines: PackedStringArray, index: int) -> bool` — True when anything other than the class_name/extends preamble, an annotation, a comment or a blank line already appeared before `index`.
- L471-480 `static header_summary(lines: PackedStringArray, header_end: int) -> String`
- L483-484 `static doc_text(line: String) -> String`
- L488-498 `static join_doc(doc: PackedStringArray) -> String` — Joins a `##` block into one line, dropping empty lines and `@tag` metadata.
- L501-506 `static leading_identifier(text: String) -> String`
- L509-516 `static is_identifier_char(character: String) -> bool`
- L520-528 `static extract_between(text: String, prefix: String, suffix: String) -> String` — Text between the first `prefix` and the next `suffix` after it, or "".
- L533-534 `static attribute(line: String, attribute_name: String) -> String` — Value of a `name="value"` attribute inside a .tscn header line, or "". The leading space keeps `id="..."` from matching inside `uid="..."`.
- L537-550 `static parse_signal(line: String) -> Dictionary`
- L553-579 `static parse_function(signature: String, line_number: int) -> Dictionary`
- L583-606 `static parse_named_declaration(line: String, keyword: String) -> Dictionary` — Splits `var/const/static var NAME: TYPE = VALUE` into its three parts.
- L611-633 `static parse_enum(lines: PackedStringArray, start_index: int, header_line: String) -> Dictionary` — Reads `enum Name { A, B = 3 }` in both the one-line and the block form. `next` is the 0-based index of the first line after the enum.
- L636-648 `static enum_values(body: String) -> PackedStringArray`
- L652-663 `static signature_complete(signature: String) -> bool` — True once a (possibly wrapped) function header ends in `:` with balanced brackets.
- L666-667 `static is_resource_path_char(character: String) -> bool`
- L671-685 `static contains_word(text: String, word: String) -> bool` — Whole-word search, so `Unit` does not match `UnitUI`.
- L691-705 `static scan_resource_refs(text: String) -> PackedStringArray` — res:// paths referenced by a script (preload/load), deduplicated and without vendor paths. The scan starts after the `res://` scheme itself, otherwise the first…
- L710-723 `static collect_keys(values: Array, depth: int) -> PackedStringArray` — Union of the dictionary keys found in `values`, walking nested arrays and objects a few levels deep. Capped so a wide schema cannot bloat the map.
- L727-731 `static keys_of(raw_keys: Array) -> PackedStringArray` — Stringifies raw JSON keys (object roots), then dedupes, sorts and caps them.
- L734-744 `static finalize_keys(keys: PackedStringArray) -> PackedStringArray`

Uses: —
Used by: GDTest/CodeIndexTest.gd, Tools/check_navigation.gd, Tools/gen_code_index.gd
Loads: res://

