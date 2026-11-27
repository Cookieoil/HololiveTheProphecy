<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/DiffReviewParser.gd` — `class_name DiffReviewParser` extends `RefCounted`

`781` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure review layer behind Tools/review_diff.gd. Every function takes a unified diff as text and returns plain Dictionaries: no file system access, no git, no pri…

Sections: Constants · Public Methods · Private Methods

Constants:
- L27 `TEST_DIR: String = "GDTest/"`
- L28 `TOOLS_DIR: String = "Tools/"`
- L29 `CORE_DIR: String = "Core/"`
- L30 `DATA_DIR: String = "Data/"`
- L31 `SCRIPT_SUFFIX: String = ".gd"`
- L32 `SCENE_SUFFIX: String = ".tscn"`
- L34 `MAX_CHANGED_LINES: int = 400` — A diff this large cannot be reviewed properly in one pass; split it.
- L39 `STRICT_RULES: Array[String] = [` — Rules that `--strict` turns into failures. `untested_change` is deliberately not here: this repo names suites by behaviour (GDTest/TelemetryTest.gd covers GameM…
- L46 `BANNED_PATTERNS: Array[String] = [` — Banned patterns, mirrored from Tools/line_godot_slop.py but reported on the exact added line so the comment points at the spot. The lint gate remains the blocke…
- L53 `CORE_NODE_TYPES: Array[String] = [` — Core/ is the pure-logic layer; a Node type there cannot be tested headlessly.
- L56 `MARKER_TODO: String = "TODO"`
- L57 `MARKER_FIXME: String = "FIXME"`
- L58 `ASSERT_PREFIX: String = "assert"`
- L59 `TEST_FUNCTION_PREFIX: String = "test_"`
- L60 `DOCS_DIR: String = "Docs/"`
- L61 `JSON_SUFFIX: String = ".json"`
- L62 `FEATURES_PATH: String = "Data/json/features.json"`
- L63 `ROLLOUT_KEY: String = "rollout_percent"`
- L64 `ENABLED_KEY: String = "\"enabled\""`
- L68 `ROLLOUT_FULL: int = 100` — A rollout of every bucket is not a canary: a newly enabled flag that lands already at 100 (or with no `rollout_percent` at all, which means 100) skips the stage…
- L72 `TRUNK_PREFIXES: Array[String]` — Areas whose change carries the most blast radius: shared state and the core loops, the managers that own the turn machine, and the CI pipeline the gates themsel…
- L75 `TRUNK_FILES: Array[String] = [` — Single-instance seams that are trunk wherever they sit: the runtime config, the global signal bus, the shared effect interpreter and the one battle entry point.
- L87 `TRUNK_FAN_IN: int = 5` — A changed script this many others depend on is trunk by *measurement*, not by folder. Tools/review_diff.gd reads the fan-in off the generated map's `Used by` li…
- L88 `TIER_TRUNK: String = "trunk"`
- L89 `TIER_LEAF: String = "leaf"`
- L90 `RADIUS_HIGH: String = "high"`
- L91 `RADIUS_MEDIUM: String = "medium"`
- L92 `RADIUS_LOW: String = "low"`
- L98 `FEATURE_GATE_MARKERS: Array[String] = [` — Markers that show a change is behind a staged flag, which is what makes a leaf change safe to skim: the control path is untouched and the kill switch is one JSO…
- L106 `NON_SHIPPED_PREFIXES: Array[String] = [TEST_DIR, TOOLS_DIR]` — Paths that never ship in the game: a test suite or an offline tool. Nothing there can reach a player, so those files are neither trunk nor part of a script's *r…

Public API:
- L114-142 `static parse_diff(diff_text: String) -> Array[Dictionary]` — Parses a unified diff into one record per file: `{path, entries, added, removed, is_new, is_deleted}` where `entries` is an ordered list of `{kind, text, line}`…
- L146-159 `static hunk_start_line(header: String) -> int` — The new-file line number the hunk starts at: `@@ -3,7 +9,4 @@` -> 9.
- L166-195 `static review(diff_text: String, options: Dictionary = {}) -> Dictionary` — Reviews a diff and returns `{files, changed_paths, blocking, advisory, stats, blast_radius, trunk_paths, feature_gated}`. `options` accepts `strict: bool`, `kno…
- L199-201 `static has_findings(result: Dictionary) -> bool` — True when the report has anything a reviewer should look at.
- L205-206 `static blocking_count(result: Dictionary) -> int` — How many findings would fail the run.
- L211-212 `static exit_code(result: Dictionary) -> int` — 1 when the report would fail, 0 otherwise. Advisory findings never fail; only what `--strict` promoted (or a rule that is inherently blocking) does.
- L221-227 `static review_tier(path_value: String, trunk_files: PackedStringArray = PackedStringArray()) -> String` — The review tier of one changed path. `trunk` code is where a wrong line reaches every player (shared state, the core loops, the gates themselves); `leaf` code i…
- L233-237 `static is_non_shipped(path_value: String) -> bool` — True when a path never ships in the game (a test suite or an offline tool). Such a change cannot reach a player, so it is neither trunk nor part of another scri…
- L246-259 `static fan_in_from_map(page_text: String) -> int` — The *runtime* fan-in the generated map records for a script: how many of the entries on the `Used by:` line of `Docs/map/<path>.md` actually ship. Test suites a…

Private:
- L267-273 `_trunk_paths`
- L279-285 `_radius`
- L288-293 `_is_leaf_game_code`
- L300-310 `_feature_gated`
- L313-321 `_mentions_gate`
- L324-330 `_added_texts`
- L337-344 `_assertionless_findings`
- L347-360 `_file_assertionless`
- L370-385 `_body_asserts`
- L391-396 `_continues_body`
- L401-408 `_has_assertion`
- L417-423 `_rollout_findings`
- L426-440 `_unstaged_flags`
- L444-445 `_enables_flag`
- L451-459 `_rollout_after`
- L465-478 `_rollout_value`
- L481-485 `_dict`
- L489-497 `_start_file`
- L501-511 `_diff_path`
- L514-518 `_is_diff_header`
- L521-527 `_append_entry`
- L531-548 `_line_findings`
- L551-555 `_previous_line`
- L558-577 `_banned_finding`
- L583-589 `_code_part`
- L594-608 `_quoted_at`
- L616-628 `_todo_finding`
- L631-639 `_api_finding`
- L645-656 `_declared_function_name`
- L659-661 `_is_public_function`
- L666-671 `_risk_finding`
- L674-684 `_change_findings`
- L690-696 `_reviewable_lines`
- L701-707 `_needs_test`
- L710-716 `_line_totals`
- L719-735 `_stats`
- L738-749 `_area`
- L754-765 `_promote_strict`
- L768-777 `_finding`

Uses: CodeIndexParser
Used by: GDTest/DiffReviewTest.gd, Tools/DiffReviewFormatter.gd, Tools/review_diff.gd
Loads: —

