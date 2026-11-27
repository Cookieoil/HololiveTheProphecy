<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/DiffReviewParser.gd` — `class_name DiffReviewParser` extends `RefCounted`

`473` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure review layer behind Tools/review_diff.gd. Every function takes a unified diff as text and returns plain Dictionaries: no file system access, no git, no pri…

Sections: Constants · Public Methods · Private Methods

Constants:
- L21 `TEST_DIR: String = "GDTest/"`
- L22 `TOOLS_DIR: String = "Tools/"`
- L23 `CORE_DIR: String = "Core/"`
- L24 `DATA_DIR: String = "Data/"`
- L25 `SCRIPT_SUFFIX: String = ".gd"`
- L26 `SCENE_SUFFIX: String = ".tscn"`
- L28 `MAX_REPORTED_FINDINGS: int = 30` — Cap the report: the point is to lower review cost, not add to it.
- L30 `MAX_CHANGED_LINES: int = 400` — A diff this large cannot be reviewed properly in one pass; split it.
- L33 `STRICT_RULES: Array[String] = [` — Rules that `--strict` turns into failures. The others stay advisory because they need judgement (a Tools/ change or a data edit may not need a unit test).
- L40 `BANNED_PATTERNS: Array[String] = [` — Banned patterns, mirrored from Tools/line_godot_slop.py but reported on the exact added line so the comment points at the spot. The lint gate remains the blocke…
- L47 `CORE_NODE_TYPES: Array[String] = [` — Core/ is the pure-logic layer; a Node type there cannot be tested headlessly.
- L50 `MARKER_TODO: String = "TODO"`
- L51 `MARKER_FIXME: String = "FIXME"`

Public API:
- L59-87 `static parse_diff(diff_text: String) -> Array[Dictionary]` — Parses a unified diff into one record per file: `{path, entries, added, removed, is_new, is_deleted}` where `entries` is an ordered list of `{kind, text, line}`…
- L91-104 `static hunk_start_line(header: String) -> int` — The new-file line number the hunk starts at: `@@ -3,7 +9,4 @@` -> 9.
- L109-132 `static review(diff_text: String, options: Dictionary = {}) -> Dictionary` — Reviews a diff and returns `{files, changed_paths, blocking, advisory, stats}`. `options` accepts `strict: bool` and `known_large_files: PackedStringArray`.
- L136-138 `static has_findings(result: Dictionary) -> bool` — True when the report has anything a reviewer should look at.
- L142-143 `static blocking_count(result: Dictionary) -> int` — How many findings would fail the run.
- L148-149 `static exit_code(result: Dictionary) -> int` — 1 when the report would fail, 0 otherwise. Advisory findings never fail; only what `--strict` promoted (or a rule that is inherently blocking) does.
- L154-174 `static format_markdown(result: Dictionary) -> String` — Compact markdown for a pull-request comment: a summary line, then one table row per finding, so the whole review fits in a screenful.
- L178-191 `static format_text(result: Dictionary) -> String` — Plain text for a terminal run.

Private:
- L195-211 `_markdown_section`
- L214-218 `_dict`
- L222-230 `_start_file`
- L234-244 `_diff_path`
- L247-251 `_is_diff_header`
- L254-260 `_append_entry`
- L264-281 `_line_findings`
- L284-288 `_previous_line`
- L291-304 `_banned_finding`
- L309-323 `_quoted_at`
- L330-342 `_todo_finding`
- L345-353 `_api_finding`
- L356-364 `_is_public_function`
- L369-374 `_risk_finding`
- L377-388 `_change_findings`
- L393-399 `_needs_test`
- L402-408 `_line_totals`
- L411-427 `_stats`
- L430-441 `_area`
- L446-457 `_promote_strict`
- L460-469 `_finding`

Uses: CodeIndexParser
Used by: GDTest/DiffReviewTest.gd, Tools/review_diff.gd
Loads: —

