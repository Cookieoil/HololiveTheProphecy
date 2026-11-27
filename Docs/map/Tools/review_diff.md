<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/review_diff.gd` extends `SceneTree`

`159` lines · [back to the map](../../CODEBASE_MAP.md)

> Second-pass reviewer for a branch: summarises the diff and flags the things a reviewer (human or the next agent) should look at, so the first look is a short re…

Sections: Constants · Lifecycle Methods · Private Methods

Constants:
- L36 `BASELINE_PATH: String = "res://Tools/slop_baseline.json"`
- L37 `ARG_BASE: String = "--base"`
- L38 `ARG_FORMAT: String = "--format"`
- L39 `ARG_OUTPUT: String = "--output"`
- L40 `ARG_STRICT: String = "--strict"`
- L41 `ARG_ADVERSARIAL: String = "--adversarial"`
- L42 `DEFAULT_BASE: String = "origin/main"`
- L43 `FORMAT_MARKDOWN: String = "markdown"`
- L44 `FORMAT_TEXT: String = "text"`
- L45 `GIT_FAILED: int = 2`
- L48 `MAP_DIR: String = "res://Docs/map"` — The generated map: its `Used by:` line is the measured fan-in that decides which changed scripts are trunk, whatever folder they happen to sit in.
- L49 `SCRIPT_SUFFIX: String = ".gd"`

Private:
- L53-77 `_initialize`
- L84-91 `_git_diff`
- L94-97 `_format`
- L101-102 `_is_markdown`
- L105-110 `_arg_value`
- L114-126 `_known_large_files`
- L134-145 `_measure_trunk_files`
- L148-157 `_write`

Uses: CodeIndexParser, DiffReviewFormatter, DiffReviewParser
Used by: —
Loads: res://Tools/slop_baseline.json, res://Docs/map

