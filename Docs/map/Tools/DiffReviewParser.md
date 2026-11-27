<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/DiffReviewParser.gd` — `class_name DiffReviewParser` extends `RefCounted`

`803` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure review layer behind Tools/review_diff.gd. Every function takes a unified diff as text and returns plain Dictionaries: no file system access, no git, no pri…

Sections: Constants · Public Methods · Private Methods

Constants:
- L27 `TEST_DIR: String = "GDTest/"`
- L28 `TOOLS_DIR: String = "Tools/"`
- L29 `CORE_DIR: String = "Core/"`
- L30 `DATA_DIR: String = "Data/"`
- L31 `SCRIPT_SUFFIX: String = ".gd"`
- L32 `SCENE_SUFFIX: String = ".tscn"`
- L34 `MAX_REPORTED_FINDINGS: int = 30` — Cap the report: the point is to lower review cost, not add to it.
- L36 `MAX_CHANGED_LINES: int = 400` — A diff this large cannot be reviewed properly in one pass; split it.
- L41 `STRICT_RULES: Array[String] = [` — Rules that `--strict` turns into failures. `untested_change` is deliberately not here: this repo names suites by behaviour (GDTest/TelemetryTest.gd covers GameM…
- L48 `BANNED_PATTERNS: Array[String] = [` — Banned patterns, mirrored from Tools/line_godot_slop.py but reported on the exact added line so the comment points at the spot. The lint gate remains the blocke…
- L55 `CORE_NODE_TYPES: Array[String] = [` — Core/ is the pure-logic layer; a Node type there cannot be tested headlessly.
- L58 `MARKER_TODO: String = "TODO"`
- L59 `MARKER_FIXME: String = "FIXME"`
- L60 `ASSERT_PREFIX: String = "assert"`
- L61 `TEST_FUNCTION_PREFIX: String = "test_"`
- L62 `DOCS_DIR: String = "Docs/"`
- L63 `JSON_SUFFIX: String = ".json"`
- L64 `FEATURES_PATH: String = "Data/json/features.json"`
- L65 `ROLLOUT_KEY: String = "rollout_percent"`
- L66 `ENABLED_KEY: String = "\"enabled\""`
- L70 `ROLLOUT_FULL: int = 100` — A rollout of every bucket is not a canary: a newly enabled flag that lands already at 100 (or with no `rollout_percent` at all, which means 100) skips the stage…
- L73 `TRUNK_PREFIXES: Array[String] = ["Core/", "Managers/", ".github/"]` — Areas whose change carries the most blast radius: shared state and the core loops, the managers that own the turn machine, and the pipeline the gates themselves…
- L76 `TRUNK_FILES: Array[String] = [` — Single-instance seams that are trunk wherever they sit: the runtime config, the global signal bus, the shared effect interpreter and the one battle entry point.
- L88 `TRUNK_FAN_IN: int = 5` — A changed script this many others depend on is trunk by *measurement*, not by folder. Tools/review_diff.gd reads the fan-in off the generated map's `Used by` li…
- L89 `TIER_TRUNK: String = "trunk"`
- L90 `TIER_LEAF: String = "leaf"`
- L91 `RADIUS_HIGH: String = "high"`
- L92 `RADIUS_MEDIUM: String = "medium"`
- L93 `RADIUS_LOW: String = "low"`
- L97 `FEATURE_GATE_MARKERS: Array[String] = [` — Markers that show a change is (or sits behind) a staged flag, which is what makes a leaf change safe to skim: the control path is untouched and the kill switch…
- L104 `ADVERSARIAL_QUESTIONS: Array[String] = [` — The adversarial pass attacks invariants the linter cannot see. Style, naming and typing are deliberately absent: the gates own them, so re-raising them only add…

Public API:
- L119-147 `static parse_diff(diff_text: String) -> Array[Dictionary]` — Parses a unified diff into one record per file: `{path, entries, added, removed, is_new, is_deleted}` where `entries` is an ordered list of `{kind, text, line}`…
- L151-164 `static hunk_start_line(header: String) -> int` — The new-file line number the hunk starts at: `@@ -3,7 +9,4 @@` -> 9.
- L171-200 `static review(diff_text: String, options: Dictionary = {}) -> Dictionary` — Reviews a diff and returns `{files, changed_paths, blocking, advisory, stats, blast_radius, trunk_paths, feature_gated}`. `options` accepts `strict: bool`, `kno…
- L204-206 `static has_findings(result: Dictionary) -> bool` — True when the report has anything a reviewer should look at.
- L210-211 `static blocking_count(result: Dictionary) -> int` — How many findings would fail the run.
- L216-217 `static exit_code(result: Dictionary) -> int` — 1 when the report would fail, 0 otherwise. Advisory findings never fail; only what `--strict` promoted (or a rule that is inherently blocking) does.
- L223-244 `static format_markdown(result: Dictionary) -> String` — Compact markdown for a pull-request comment: the blast radius first (how deep a reader has to go), then a summary line and one table row per finding, so the who…
- L249-269 `static format_text(result: Dictionary) -> String` — Plain text for a terminal run, led by the same blast-radius line so a local run and the pull-request comment agree on how deep the review has to go.
- L278-284 `static review_tier(path_value: String, trunk_files: PackedStringArray = PackedStringArray()) -> String` — The review tier of one changed path. `trunk` code is where a wrong line reaches every player (shared state, the core loops, the gates themselves); `leaf` code i…
- L291-299 `static fan_in_from_map(page_text: String) -> int` — The fan-in the generated map records for a script: the number of entries on the `Used by:` line of `Docs/map/<path>.md`. Reading the committed map turns "blast…
- L307-323 `static adversarial_section(result: Dictionary) -> String` — The context-isolated brief for a *fresh* reviewer. An agent that wrote a change carries its whole authoring conversation, so it defends the shortcuts it took; t…

Private:
- L329-335 `_trunk_paths`
- L341-347 `_radius`
- L350-355 `_is_leaf_game_code`
- L360-368 `_feature_gated`
- L371-377 `_added_texts`
- L382-396 `_radius_section`
- L399-406 `_radius_hint`
- L413-420 `_assertionless_findings`
- L423-436 `_file_assertionless`
- L442-455 `_body_asserts`
- L462-472 `_rollout_findings`
- L475-479 `_enables_flag`
- L482-487 `_rollout_is_staged`
- L493-506 `_rollout_value`
- L509-525 `_markdown_section`
- L528-532 `_dict`
- L536-544 `_start_file`
- L548-558 `_diff_path`
- L561-565 `_is_diff_header`
- L568-574 `_append_entry`
- L578-595 `_line_findings`
- L598-602 `_previous_line`
- L605-622 `_banned_finding`
- L627-641 `_quoted_at`
- L649-661 `_todo_finding`
- L664-672 `_api_finding`
- L678-689 `_declared_function_name`
- L692-694 `_is_public_function`
- L699-704 `_risk_finding`
- L707-718 `_change_findings`
- L723-729 `_needs_test`
- L732-738 `_line_totals`
- L741-757 `_stats`
- L760-771 `_area`
- L776-787 `_promote_strict`
- L790-799 `_finding`

Uses: BattleScene, CodeIndexParser, EffectBlock, FeatureFlags, GameState, Unit
Used by: GDTest/DiffReviewTest.gd, Tools/review_diff.gd
Loads: —

