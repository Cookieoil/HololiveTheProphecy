<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/TriageParser.gd` — `class_name TriageParser` extends `RefCounted`

`490` lines · [back to the map](../../CODEBASE_MAP.md)

> Pure task-intake layer behind Tools/triage.gd: "forward pressure". Turns evidence into agent-ready task specs. The point is that a coding agent (or a human) sho…

Sections: Constants · Public Methods · Private Methods

Constants:
- L23 `SEVERITY_HIGH: String = "high"`
- L24 `SEVERITY_MEDIUM: String = "medium"`
- L25 `SEVERITY_LOW: String = "low"`
- L27 `SEVERITY_ORDER: Array[String]` — Severity order for sorting: earlier is more urgent.
- L30 `MIN_OFFERS_FOR_PICK_RATE: int = 20` — Thresholds. Every one is a decision, so it lives here with the reason next to it.
- L33 `LOW_PICK_RATE: float = 0.05` — Below this, a skill that is offered this often is not being picked - unreadable or simply worse than the alternative.
- L34 `MIN_RUNS_FOR_COVERAGE: int = 10`
- L35 `MIN_MATCHES_FOR_LIFT: int = 20`
- L37 `LIFT_OUTLIER: float = 0.20` — Advantage-adjusted lift beyond this is a real outlier, not noise.
- L38 `MIN_RUNS_FOR_ABANDON_RATE: int = 10`
- L39 `ABANDON_RATE_ALERT: float = 0.20`
- L41 `MIN_RUNS_FOR_FLAG_DECISION: int = 50` — An experiment with this many runs has enough evidence to decide on.
- L43 `MAX_TASKS_PER_KIND: int = 5` — Cap per kind, so a bad patch cannot file fifty issues in one pass.
- L44 `SEEDS_LISTED: int = 3`
- L47 `MARKERS: Array[String] = ["TODO:", "FIXME("]` — The review markers this tool turns into tasks. A marker has to open the comment to count, which is what separates a leftover from prose that mentions one.
- L49 `MIN_COVERAGE: float = 0.10` — Coverage below this counts as "never used" for a kit that was in the line-up.
- L51 `_PICK_GROUPS: Array[String] = ["skills", "ultimates", "cards"]` — The three pick-rate groups the report carries, in report order.

Public API:
- L56-70 `static collect(report: Dictionary, markers: Array[Dictionary], ratchet_warnings: PackedStringArray) -> Array[Dictionary]` — Every task the evidence supports, most urgent first.
- L74-78 `static marker_for(task: Dictionary) -> String` — The stable id of a task, used to recognise an issue that already exists.
- L82-86 `static issue_title(task: Dictionary) -> String` — The issue title: the severity first, so a list of them sorts by urgency on sight.
- L91-113 `static issue_body(task: Dictionary) -> String` — The issue body, which is also the prompt an agent starts from: what, the evidence, how to reproduce, and what "done" means.
- L117-122 `static count_of_severity(tasks: Array[Dictionary], severity: String) -> int` — How many tasks carry one severity, for the run summary.
- L128-140 `static marker_in_line(rel: String, line_number: int, line: String) -> Dictionary` — The leftover marker on one source line, or `{}`. Only a comment counts, and only when the marker opens it: a comment that starts with the marker is a task, whil…

Private:
- L148-154 `_comment_index`
- L157-171 `_inside_string`
- L175-203 `_pick_rate_tasks`
- L207-235 `_coverage_tasks`
- L240-266 `_lift_tasks`
- L271-296 `_abandon_task`
- L300-329 `_flag_decision_tasks`
- L334-349 `_marker_tasks`
- L354-370 `_ratchet_tasks`
- L373-374 `_sort_tasks`
- L379-388 `_task_before`
- L394-411 `_task`
- L414-419 `_count_kind`
- L424-444 `_report_repro`
- L447-450 `_rate_text`
- L453-457 `_dict`
- L460-467 `_float_of`
- L471-485 `_slug`

Uses: BattleScene, CodeIndexParser
Used by: GDTest/TriageParserTest.gd, Tools/triage.gd
Loads: —

