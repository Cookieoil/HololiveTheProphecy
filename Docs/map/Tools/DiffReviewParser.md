<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/DiffReviewParser.gd` — `class_name DiffReviewParser` extends `RefCounted`

`475` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L35 `STRICT_RULES: Array[String] = [` — Rules that `--strict` turns into failures. `untested_change` is deliberately not here: this repo names suites by behaviour (GDTest/TelemetryTest.gd covers GameM…
- L41 `BANNED_PATTERNS: Array[String] = [` — Banned patterns, mirrored from Tools/line_godot_slop.py but reported on the exact added line so the comment points at the spot. The lint gate remains the blocke…
- L48 `CORE_NODE_TYPES: Array[String] = [` — Core/ is the pure-logic layer; a Node type there cannot be tested headlessly.
- L51 `MARKER_TODO: String = "TODO"`
- L52 `MARKER_FIXME: String = "FIXME"`

Public API:
- L60-88 `static parse_diff(diff_text: String) -> Array[Dictionary]` — Parses a unified diff into one record per file: `{path, entries, added, removed, is_new, is_deleted}` where `entries` is an ordered list of `{kind, text, line}`…
- L92-105 `static hunk_start_line(header: String) -> int` — The new-file line number the hunk starts at: `@@ -3,7 +9,4 @@` -> 9.
- L110-133 `static review(diff_text: String, options: Dictionary = {}) -> Dictionary` — Reviews a diff and returns `{files, changed_paths, blocking, advisory, stats}`. `options` accepts `strict: bool` and `known_large_files: PackedStringArray`.
- L137-139 `static has_findings(result: Dictionary) -> bool` — True when the report has anything a reviewer should look at.
- L143-144 `static blocking_count(result: Dictionary) -> int` — How many findings would fail the run.
- L149-150 `static exit_code(result: Dictionary) -> int` — 1 when the report would fail, 0 otherwise. Advisory findings never fail; only what `--strict` promoted (or a rule that is inherently blocking) does.
- L155-175 `static format_markdown(result: Dictionary) -> String` — Compact markdown for a pull-request comment: a summary line, then one table row per finding, so the whole review fits in a screenful.
- L179-192 `static format_text(result: Dictionary) -> String` — Plain text for a terminal run.

Private:
- L196-212 `_markdown_section`
- L215-219 `_dict`
- L223-231 `_start_file`
- L235-245 `_diff_path`
- L248-252 `_is_diff_header`
- L255-261 `_append_entry`
- L265-282 `_line_findings`
- L285-289 `_previous_line`
- L292-305 `_banned_finding`
- L310-324 `_quoted_at`
- L332-344 `_todo_finding`
- L347-355 `_api_finding`
- L358-366 `_is_public_function`
- L371-376 `_risk_finding`
- L379-390 `_change_findings`
- L395-401 `_needs_test`
- L404-410 `_line_totals`
- L413-429 `_stats`
- L432-443 `_area`
- L448-459 `_promote_strict`
- L462-471 `_finding`

Uses: CodeIndexParser
Used by: GDTest/DiffReviewTest.gd, Tools/review_diff.gd
Loads: —

