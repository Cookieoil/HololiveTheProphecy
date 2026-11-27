<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/review_diff.gd` extends `SceneTree`

`112` lines · [back to the map](../../CODEBASE_MAP.md)

> Second-pass reviewer for a branch: summarises the diff and flags the things a reviewer (human or the next agent) should look at, so the first look is a short re…

Sections: Constants · Lifecycle Methods · Private Methods

Constants:
- L22 `BASELINE_PATH: String = "res://Tools/slop_baseline.json"`
- L23 `ARG_BASE: String = "--base"`
- L24 `ARG_FORMAT: String = "--format"`
- L25 `ARG_OUTPUT: String = "--output"`
- L26 `ARG_STRICT: String = "--strict"`
- L27 `DEFAULT_BASE: String = "origin/main"`
- L28 `FORMAT_MARKDOWN: String = "markdown"`
- L29 `FORMAT_TEXT: String = "text"`
- L30 `GIT_FAILED: int = 2`

Private:
- L34-54 `_initialize`
- L61-68 `_git_diff`
- L71-74 `_format`
- L77-82 `_arg_value`
- L86-98 `_known_large_files`
- L101-110 `_write`

Uses: CodeIndexParser, DiffReviewParser
Used by: —
Loads: res://Tools/slop_baseline.json

