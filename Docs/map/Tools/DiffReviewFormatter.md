<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/DiffReviewFormatter.gd` — `class_name DiffReviewFormatter` extends `RefCounted`

`216` lines · [back to the map](../../CODEBASE_MAP.md)

> Rendering layer behind Tools/review_diff.gd. Turns the plain Dictionary that Tools/DiffReviewParser.gd produces into the markdown pull-request comment, the term…

Sections: Constants · Public Methods · Private Methods

Constants:
- L19 `MAX_REPORTED_FINDINGS: int = 30` — Cap the report: the point is to lower review cost, not add to it.
- L23 `UI_PREFIXES: Array[String] = ["Scenes/", "Shaders/"]` — Areas whose change moves pixels. Every headless gate uses the dummy renderer, which rasterises nothing, so a review that touches one of these needs the rendered…
- L27 `ADVERSARIAL_QUESTIONS: Array[String] = [` — The adversarial pass attacks invariants the linter cannot see. Style, naming and typing are deliberately absent: the gates own them, so re-raising them only add…

Public API:
- L41-60 `static format_markdown(result: Dictionary) -> String` — Compact markdown for a pull-request comment: the blast radius first (how deep a reader has to go), then a summary line and one table row per finding, so the who…
- L65-86 `static format_text(result: Dictionary) -> String` — Plain text for a terminal run, led by the same blast-radius line so a local run and the pull-request comment agree on how deep the review has to go.
- L97-119 `static adversarial_section(result: Dictionary, collapsible: bool = false) -> String` — The context-isolated brief for a *fresh* reviewer. An agent that wrote a change carries its whole authoring conversation, so it defends the shortcuts it took; t…
- L124-129 `static needs_ui_proof(changed: PackedStringArray) -> bool` — True when a change moved pixels: a headless run uses the dummy renderer and rasterises nothing, so a scene or a shader needs `reports/ui-snapshots/` for proof.

Private:
- L135-148 `_radius_section`
- L152-161 `_radius_lines`
- L166-169 `_gate_line`
- L172-177 `_radius_hint`
- L180-199 `_markdown_section`
- L204-207 `_capped`
- L210-214 `_dict`

Uses: CodeIndexParser, DiffReviewParser
Used by: GDTest/DiffReviewTest.gd, Tools/review_diff.gd
Loads: —

