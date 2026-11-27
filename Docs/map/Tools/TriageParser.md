<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/TriageParser.gd` — `class_name TriageParser` extends `RefCounted`

`488` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L145-151 `_comment_index`
- L154-168 `_inside_string`
- L173-201 `_pick_rate_tasks`
- L205-233 `_coverage_tasks`
- L238-264 `_lift_tasks`
- L269-294 `_abandon_task`
- L298-327 `_flag_decision_tasks`
- L332-347 `_marker_tasks`
- L352-368 `_ratchet_tasks`
- L371-372 `_sort_tasks`
- L377-386 `_task_before`
- L392-409 `_task`
- L412-417 `_count_kind`
- L422-442 `_report_repro`
- L445-448 `_rate_text`
- L451-455 `_dict`
- L458-465 `_float_of`
- L469-483 `_slug`

Uses: BattleScene, CodeIndexParser
Used by: GDTest/TriageParserTest.gd, Tools/triage.gd
Loads: —

