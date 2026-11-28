<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/ValidationReporter.gd` — `class_name ValidationReporter` extends `RefCounted`

`235` lines · [back to the map](../../CODEBASE_MAP.md)

> GitHub Actions reporting for the game-data validator: workflow annotations that point at the exact data file (and line, when it can be located) and the Markdown…

Sections: Constants · Public Methods · Private Methods

Constants:
- L17 `ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"` — GitHub Actions environment variables used for CI reporting.

Public API:
- L25-36 `static emit_annotations(errors: PackedStringArray, warnings: PackedStringArray, raw_text: Dictionary, paths: Dictionary) -> void` — Emits GitHub Actions workflow commands so a failure annotates the exact file (and, when it can be located, line) inside the pull request. A no-op outside CI.
- L41-45 `static diagnostic_file(message: String, paths: Dictionary) -> String` — Maps a diagnostic message to the repo-relative data file it belongs to, or "" when the message names no file. The needles are the `paths` keys, in their order.
- L49-58 `static diagnostic_line(message: String, raw_text: Dictionary, paths: Dictionary) -> int` — Best-effort 1-based source line for a diagnostic, 0 when it cannot be located.
- L64-99 `static step_summary(exit_code: int, errors: PackedStringArray, warnings: PackedStringArray, counts: Dictionary) -> String` — The Markdown report appended to the GitHub Actions job summary, so the result is readable on the run page without digging through the raw log.

Private:
- L105-113 `_count`
- L116-130 `_emit_annotation`
- L133-136 `_repo_path`
- L141-152 `_skills_line`
- L155-160 `_unit_line`
- L163-174 `_waves_line`
- L177-189 `_config_line`
- L194-207 `_line_of`
- L211-218 `_first_quoted`
- L222-233 `_bracket_index`

Uses: —
Used by: GDTest/GameDataValidatorTest.gd, Tools/validate_gameData.gd
Loads: res://

