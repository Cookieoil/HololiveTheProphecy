<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/review_diff.gd` extends `SceneTree`

`150` lines · [back to the map](../../CODEBASE_MAP.md)

> Second-pass reviewer for a branch: summarises the diff and flags the things a reviewer (human or the next agent) should look at, so the first look is a short re…

Sections: Constants · Lifecycle Methods · Private Methods

Constants:
- L33 `BASELINE_PATH: String = "res://Tools/slop_baseline.json"`
- L34 `ARG_BASE: String = "--base"`
- L35 `ARG_FORMAT: String = "--format"`
- L36 `ARG_OUTPUT: String = "--output"`
- L37 `ARG_STRICT: String = "--strict"`
- L38 `ARG_ADVERSARIAL: String = "--adversarial"`
- L39 `DEFAULT_BASE: String = "origin/main"`
- L40 `FORMAT_MARKDOWN: String = "markdown"`
- L41 `FORMAT_TEXT: String = "text"`
- L42 `GIT_FAILED: int = 2`
- L45 `MAP_DIR: String = "Docs/map"` — The generated map: its `Used by:` line is the measured fan-in that decides which changed scripts are trunk, whatever folder they happen to sit in.
- L46 `SCRIPT_SUFFIX: String = ".gd"`

Private:
- L50-74 `_initialize`
- L81-88 `_git_diff`
- L91-94 `_format`
- L97-102 `_arg_value`
- L106-118 `_known_large_files`
- L125-136 `_measure_trunk_files`
- L139-148 `_write`

Uses: CodeIndexParser, DiffReviewParser
Used by: —
Loads: res://Tools/slop_baseline.json

