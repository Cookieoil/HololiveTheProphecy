class_name TriageParser
extends RefCounted
## Pure task-intake layer behind Tools/triage.gd: "forward pressure".
##
## Turns evidence into agent-ready task specs. The point is that a coding agent (or a
## human) should never have to *notice* work: the numbers say what is wrong, the spec
## carries the evidence and the repro, and the fix has an acceptance test before
## anybody starts.
##
## Three evidence sources, all free of secrets:
##   - the telemetry report Tools/analyze_telemetry.py --json writes,
##   - leftover review markers in first-party comments,
##   - the anti-slop lint's stale-ratchet warnings (a self-cleaning loop).
##
## Pure on purpose: plain Dictionaries in, `Array[Dictionary]` out, no file system, no
## `gh`. That keeps every threshold and every edge case unit-testable in
## GDTest/TriageParserTest.gd.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Constants
const SEVERITY_HIGH: String = "high"
const SEVERITY_MEDIUM: String = "medium"
const SEVERITY_LOW: String = "low"
## Severity order for sorting: earlier is more urgent.
const SEVERITY_ORDER: Array[String] = [SEVERITY_HIGH, SEVERITY_MEDIUM, SEVERITY_LOW]

## Thresholds. Every one is a decision, so it lives here with the reason next to it.
const MIN_OFFERS_FOR_PICK_RATE: int = 20
## Below this, a skill that is offered this often is not being picked - unreadable or
## simply worse than the alternative.
const LOW_PICK_RATE: float = 0.05
const MIN_RUNS_FOR_COVERAGE: int = 10
const MIN_MATCHES_FOR_LIFT: int = 20
## Advantage-adjusted lift beyond this is a real outlier, not noise.
const LIFT_OUTLIER: float = 0.20
const MIN_RUNS_FOR_ABANDON_RATE: int = 10
const ABANDON_RATE_ALERT: float = 0.20
## An experiment with this many runs has enough evidence to decide on.
const MIN_RUNS_FOR_FLAG_DECISION: int = 50
## Cap per kind, so a bad patch cannot file fifty issues in one pass.
const MAX_TASKS_PER_KIND: int = 5
const SEEDS_LISTED: int = 3
## The review markers this tool turns into tasks. A marker has to open the comment to
## count, which is what separates a leftover from prose that mentions one.
const MARKERS: Array[String] = ["TODO:", "FIXME("]
## Coverage below this counts as "never used" for a kit that was in the line-up.
const MIN_COVERAGE: float = 0.10
## The three pick-rate groups the report carries, in report order.
const _PICK_GROUPS: Array[String] = ["skills", "ultimates", "cards"]
#endregion

#region Public Methods
## Every task the evidence supports, most urgent first.
static func collect(
	report: Dictionary,
	markers: Array[Dictionary],
	ratchet_warnings: PackedStringArray
) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	tasks.append_array(_pick_rate_tasks(report))
	tasks.append_array(_coverage_tasks(report))
	tasks.append_array(_lift_tasks(report))
	tasks.append_array(_abandon_task(report))
	tasks.append_array(_flag_decision_tasks(report))
	tasks.append_array(_marker_tasks(markers))
	tasks.append_array(_ratchet_tasks(ratchet_warnings))
	_sort_tasks(tasks)
	return tasks


## The stable id of a task, used to recognise an issue that already exists.
static func marker_for(task: Dictionary) -> String:
	return "<!-- triage:%s:%s -->" % [
		CodeIndexParser.dict_string(task, "kind"),
		_slug(CodeIndexParser.dict_string(task, "subject")),
	]


## The issue title: the severity first, so a list of them sorts by urgency on sight.
static func issue_title(task: Dictionary) -> String:
	return "[%s] %s" % [
		CodeIndexParser.dict_string(task, "severity"),
		CodeIndexParser.dict_string(task, "title"),
	]


## The issue body, which is also the prompt an agent starts from: what, the evidence,
## how to reproduce, and what "done" means.
static func issue_body(task: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(marker_for(task))
	lines.append("")
	lines.append("**Kind:** `%s`  **Severity:** %s" % [
		CodeIndexParser.dict_string(task, "kind"),
		CodeIndexParser.dict_string(task, "severity"),
	])
	lines.append("")
	lines.append(CodeIndexParser.dict_string(task, "title"))
	lines.append("")
	lines.append("## Evidence")
	for line: String in CodeIndexParser.dict_string_array(task, "evidence"):
		lines.append("- " + line)
	lines.append("")
	lines.append("## Reproduce")
	lines.append("```")
	lines.append(CodeIndexParser.dict_string(task, "repro"))
	lines.append("```")
	lines.append("")
	lines.append("## Done when")
	lines.append(CodeIndexParser.dict_string(task, "acceptance"))
	return "\n".join(lines)


## How many tasks carry one severity, for the run summary.
static func count_of_severity(tasks: Array[Dictionary], severity: String) -> int:
	var total: int = 0
	for task: Dictionary in tasks:
		if CodeIndexParser.dict_string(task, "severity") == severity:
			total += 1
	return total


## The leftover marker on one source line, or `{}`. Only a comment counts, and only when
## the marker opens it: a comment that starts with the marker is a task, while prose that
## merely mentions one (this file's own header, a fixture that feeds the parser) is not.
static func marker_in_line(rel: String, line_number: int, line: String) -> Dictionary:
	var comment: int = _comment_index(line)
	if comment < 0:
		return {}
	var comment_text: String = line.substr(comment).lstrip("#").strip_edges()
	for marker: String in MARKERS:
		if comment_text.begins_with(marker):
			return {
				"marker": marker.trim_suffix(":").trim_suffix("("),
				"where": "%s:%d" % [rel, line_number],
				"text": line.strip_edges(),
			}
	return {}


#endregion

#region Private Methods
## The comment introducer, or -1. A `#` inside a quoted literal is data (a fixture
## feeding this parser a comment), not the start of a comment.
static func _comment_index(line: String) -> int:
	var index: int = line.find("#")
	while index >= 0:
		if not _inside_string(line, index):
			return index
		index = line.find("#", index + 1)
	return -1


static func _inside_string(line: String, index: int) -> bool:
	var quote: String = ""
	var escaped: bool = false
	for position: int in range(index):
		var character: String = line[position]
		if escaped:
			escaped = false
		elif character == "\\":
			escaped = true
		elif not quote.is_empty():
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
	return not quote.is_empty()


## Skills / Ultimates / cards that are offered often and picked almost never.
static func _pick_rate_tasks(report: Dictionary) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	var picks: Dictionary = _dict(report.get("pick_rates", {}))
	for group: String in _PICK_GROUPS:
		var rows: Dictionary = _dict(picks.get(group, {}))
		var keys: Array = rows.keys()
		keys.sort()
		for key: Variant in keys:
			var row: Dictionary = _dict(rows[key])
			var offered: int = CodeIndexParser.dict_int(row, "offered")
			var rate: float = _float_of(row.get("pick_rate", 1.0), 1.0)
			if offered < MIN_OFFERS_FOR_PICK_RATE or rate >= LOW_PICK_RATE:
				continue
			tasks.append(_task(
				"pick_rate_floor",
				SEVERITY_MEDIUM,
				"%s:%s" % [group, str(key)],
				"%s '%s' was offered %d time(s) and picked %.1f%% of them"
					% [group.trim_suffix("s"), str(key), offered, rate * 100.0],
				["offered %d, picked %d (%.1f%%)" % [
					offered, CodeIndexParser.dict_int(row, "picked"), rate * 100.0,
				]],
				_report_repro(report),
				"Either the option becomes readable and worth taking, or the numbers "
					+ "say it is intentionally niche - record that decision in the PR."
			))
			if _count_kind(tasks, "pick_rate_floor") >= MAX_TASKS_PER_KIND:
				return tasks
	return tasks


## An ally that is in the line-up for run after run and never gets a turn.
static func _coverage_tasks(report: Dictionary) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	var coverage: Dictionary = _dict(report.get("roster_coverage", {}))
	var allies: Dictionary = _dict(coverage.get("allies", {}))
	var keys: Array = allies.keys()
	keys.sort()
	for key: Variant in keys:
		var row: Dictionary = _dict(allies[key])
		var in_lineup: int = CodeIndexParser.dict_int(row, "runs_in_lineup")
		var used: int = CodeIndexParser.dict_int(row, "runs_used")
		var rate: float = _float_of(row.get("coverage", 0.0))
		if in_lineup < MIN_RUNS_FOR_COVERAGE or rate >= MIN_COVERAGE:
			continue
		tasks.append(_task(
			"roster_coverage_zero",
			SEVERITY_HIGH,
			str(key),
			"Ally '%s' was in the line-up for %d run(s) and cast in %d"
				% [str(key), in_lineup, used],
			["runs_in_lineup %d, runs_used %d, casts %d, coverage %.0f%%" % [
				in_lineup, used, CodeIndexParser.dict_int(row, "casts"), rate * 100.0,
			]],
			_report_repro(report),
			"An ally nobody casts is unusable or undiscoverable: fix one of the two, or "
				+ "take it out of the default line-up."
		))
		if _count_kind(tasks, "roster_coverage_zero") >= MAX_TASKS_PER_KIND:
			return tasks
	return tasks


## A pick whose advantage-adjusted lift is far from its own baseline: the de-biased
## version of "this looks overpowered".
static func _lift_tasks(report: Dictionary) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	var rows: Dictionary = _dict(report.get("win_loss", {}))
	var keys: Array = rows.keys()
	keys.sort()
	for key: Variant in keys:
		var row: Dictionary = _dict(rows[key])
		var matches: int = CodeIndexParser.dict_int(row, "matches")
		var lift: float = _float_of(row.get("advantage_adjusted_lift", 0.0))
		if matches < MIN_MATCHES_FOR_LIFT or absf(lift) < LIFT_OUTLIER:
			continue
		tasks.append(_task(
			"win_lift_outlier",
			SEVERITY_MEDIUM,
			str(key),
			"%s is %+.2f above/below its own advantage baseline over %d match(es)"
				% [str(key), lift, matches],
			["raw win rate %.1f%%, advantage-adjusted lift %+.2f, matches %d" % [
				_float_of(row.get("raw_win_rate", 0.0)) * 100.0, lift, matches,
			]],
			_report_repro(report),
			"Bring the lift inside +/-%.2f, or document why the outlier is intended."
				% LIFT_OUTLIER
		))
		if _count_kind(tasks, "win_lift_outlier") >= MAX_TASKS_PER_KIND:
			return tasks
	return tasks


## Players who start a run and never finish it: a pacing or onboarding signal that no
## win rate shows, because an abandoned run is not a loss.
static func _abandon_task(report: Dictionary) -> Array[Dictionary]:
	var runs: Dictionary = _dict(report.get("runs", {}))
	var finished: int = 0
	var abandoned: int = 0
	for key: Variant in runs.keys():
		var run: Dictionary = _dict(runs[key])
		if CodeIndexParser.dict_bool(run, "abandoned"):
			abandoned += 1
		else:
			finished += 1
	var total: int = finished + abandoned
	if total < MIN_RUNS_FOR_ABANDON_RATE:
		return []
	var rate: float = float(abandoned) / float(total)
	if rate <= ABANDON_RATE_ALERT:
		return []
	return [_task(
		"abandon_rate",
		SEVERITY_HIGH,
		"run",
		"%.0f%% of runs are abandoned (%d of %d)" % [rate * 100.0, abandoned, total],
		["abandoned %d, finished %d" % [abandoned, finished]],
		_report_repro(report),
		"Find the wave or turn where runs stop and make it survivable, or record why "
			+ "players are expected to leave there."
	)]


## An experiment with enough runs behind it has a decision waiting: ship it or kill it.
static func _flag_decision_tasks(report: Dictionary) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	var cohorts: Dictionary = _dict(report.get("flag_cohorts", {}))
	var keys: Array = cohorts.keys()
	keys.sort()
	for key: Variant in keys:
		var row: Dictionary = _dict(cohorts[key])
		var flag_name: String = CodeIndexParser.dict_string(row, "flag")
		var on: int = CodeIndexParser.dict_int(row, "on")
		if on < MIN_RUNS_FOR_FLAG_DECISION:
			continue
		tasks.append(_task(
			"flag_decision",
			SEVERITY_MEDIUM,
			flag_name,
			"Staged flag '%s' has %d run(s) on it: read it, then ship it or kill it"
				% [flag_name, on],
			["on %d run(s), win %s | off %d run(s), win %s" % [
				on,
				_rate_text(CodeIndexParser.dict_int(row, "on_wins"), on),
				CodeIndexParser.dict_int(row, "off"),
				_rate_text(CodeIndexParser.dict_int(row, "off_wins"), CodeIndexParser.dict_int(row, "off")),
			]],
			"python Tools/analyze_telemetry.py   # section 11, same balance patch",
			"Set the flag to 100%% and delete the off path, or switch it off and remove "
				+ "it: an experiment nobody reads is debt."
		))
		if tasks.size() >= MAX_TASKS_PER_KIND:
			break
	return tasks


## Leftover review markers in first-party code. The lint gate reports them on every run,
## so this is the loop that empties that list instead of growing it.
static func _marker_tasks(markers: Array[Dictionary]) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	for marker: Dictionary in markers:
		if tasks.size() >= MAX_TASKS_PER_KIND:
			break
		var where: String = CodeIndexParser.dict_string(marker, "where")
		tasks.append(_task(
			"todo_marker",
			SEVERITY_LOW,
			where,
			"Leftover %s marker in %s" % [CodeIndexParser.dict_string(marker, "marker"), where],
			[CodeIndexParser.dict_string(marker, "text")],
			"rg -n \"TODO|FIXME\" %s" % where,
			"`%s` no longer carries a TODO/FIXME marker." % where
		))
	return tasks


## The anti-slop lint's stale-ratchet warnings: each one is a ceiling that was lowered
## by a refactor and never tightened.
static func _ratchet_tasks(warnings: PackedStringArray) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	for line: String in warnings:
		if tasks.size() >= MAX_TASKS_PER_KIND:
			break
		var where: String = line.split(":")[0].strip_edges()
		tasks.append(_task(
			"ratchet_debt",
			SEVERITY_LOW,
			where,
			"Ratchet baseline is stale for %s" % where,
			[line.strip_edges()],
			"python Tools/line_godot_slop.py --strict",
			"Tools/slop_baseline.json records the measured value and the lint reports "
				+ "no stale entry."
		))
	return tasks


static func _sort_tasks(tasks: Array[Dictionary]) -> void:
	tasks.sort_custom(_task_before)


## Severity first, then kind and subject: the order is stable, so the same evidence
## always produces the same list.
static func _task_before(a: Dictionary, b: Dictionary) -> bool:
	var rank_a: int = SEVERITY_ORDER.find(CodeIndexParser.dict_string(a, "severity"))
	var rank_b: int = SEVERITY_ORDER.find(CodeIndexParser.dict_string(b, "severity"))
	if rank_a != rank_b:
		return rank_a < rank_b
	var kind_a: String = CodeIndexParser.dict_string(a, "kind")
	var kind_b: String = CodeIndexParser.dict_string(b, "kind")
	if kind_a != kind_b:
		return kind_a < kind_b
	return CodeIndexParser.dict_string(a, "subject") < CodeIndexParser.dict_string(b, "subject")


## One task spec. `evidence` is what a reader needs to believe the title, `repro` is how
## to see it again, and `acceptance` is what "done" means - the same three things a
## human reviewer would ask for.
static func _task(
	kind: String,
	severity: String,
	subject: String,
	title: String,
	evidence: PackedStringArray,
	repro: String,
	acceptance: String
) -> Dictionary:
	return {
		"kind": kind,
		"severity": severity,
		"subject": subject,
		"title": title,
		"evidence": evidence,
		"repro": repro,
		"acceptance": acceptance,
	}


static func _count_kind(tasks: Array[Dictionary], kind: String) -> int:
	var total: int = 0
	for task: Dictionary in tasks:
		if CodeIndexParser.dict_string(task, "kind") == kind:
			total += 1
	return total


## How to see the number again: the report command, plus seeds that produced it so a
## flagged battle can be replayed instead of guessed at.
static func _report_repro(report: Dictionary) -> String:
	var seeds: PackedStringArray = PackedStringArray()
	var runs: Dictionary = _dict(report.get("runs", {}))
	var ids: Array = runs.keys()
	ids.sort()
	for key: Variant in ids:
		var run: Dictionary = _dict(runs[key])
		if CodeIndexParser.dict_bool(run, "abandoned"):
			continue
		var raw_seed: Variant = run.get("run_seed")
		if raw_seed == null:
			continue
		seeds.append(str(raw_seed))
		if seeds.size() >= SEEDS_LISTED:
			break
	var lines: PackedStringArray = PackedStringArray()
	lines.append("python Tools/analyze_telemetry.py --json report.json")
	if not seeds.is_empty():
		lines.append("# replayable seeds: " + ", ".join(seeds))
		lines.append("# set BattleScene.fixed_seed_override to one of them and play the battle")
	return "\n".join(lines)


static func _rate_text(wins: int, total: int) -> String:
	if total <= 0:
		return "n/a"
	return "%.1f%%" % (float(wins) / float(total) * 100.0)


static func _dict(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		var value: Dictionary = raw
		return value
	return {}


static func _float_of(raw: Variant, fallback: float = 0.0) -> float:
	if raw is float:
		var float_value: float = raw
		return float_value
	if raw is int:
		var int_value: int = raw
		return float(int_value)
	return fallback


## A stable, lowercase, dash-separated id fragment for an issue marker.
static func _slug(text: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for index: int in range(text.length()):
		var character: String = text[index].to_lower()
		var keep: bool = character.is_valid_identifier() or character.is_valid_int()
		if keep:
			parts.append(character)
		elif parts.size() > 0 and parts[parts.size() - 1] != "-":
			parts.append("-")
	var slug: String = "".join(parts)
	while slug.begins_with("-"):
		slug = slug.substr(1)
	while slug.ends_with("-"):
		slug = slug.substr(0, slug.length() - 1)
	return slug if not slug.is_empty() else "task"
#endregion



