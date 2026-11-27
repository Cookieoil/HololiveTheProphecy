class_name TriageParserTest
extends GdUnitTestSuite
## Locks the task-intake rules (Tools/TriageParser.gd): every threshold, the ordering,
## the per-kind cap and the issue marker that makes filing idempotent.
##
## @author TheGreatJellyfish
## @version 11/27/2026

func _kinds(tasks: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for task: Dictionary in tasks:
		kinds.append(CodeIndexParser.dict_string(task, "kind"))
	return kinds


func _first_of(tasks: Array[Dictionary], kind: String) -> Dictionary:
	for task: Dictionary in tasks:
		if CodeIndexParser.dict_string(task, "kind") == kind:
			return task
	return {}


## A report carrying one of every telemetry signal the rules look for.
func _report() -> Dictionary:
	return {
		"runs": {
			"r1": {"abandoned": false, "victory": true, "run_seed": 111},
			"r2": {"abandoned": false, "victory": false, "run_seed": 222},
			"r3": {"abandoned": true, "victory": false, "run_seed": 333},
		},
		"pick_rates": {
			"skills": {"striker_2": {"offered": 60, "picked": 1, "pick_rate": 0.017}},
			"ultimates": {},
			"cards": {},
		},
		"roster_coverage": {
			"allies": {"healer": {"runs_in_lineup": 40, "runs_used": 0, "casts": 0, "coverage": 0.0}},
		},
		"win_loss": {
			"skill:buff_2": {"matches": 44, "raw_win_rate": 0.80, "advantage_adjusted_lift": 0.31},
		},
		"flag_cohorts": {
			"staged|abc": {"flag": "staged", "balance": "abc", "on": 80, "on_wins": 40, "off": 6, "off_wins": 3},
		},
	}


func test_every_signal_produces_its_task() -> void:
	var tasks: Array[Dictionary] = TriageParser.collect(_report(), [], PackedStringArray())
	assert_bool(_kinds(tasks).has("pick_rate_floor")).is_true()
	assert_bool(_kinds(tasks).has("roster_coverage_zero")).is_true()
	assert_bool(_kinds(tasks).has("win_lift_outlier")).is_true()
	assert_bool(_kinds(tasks).has("flag_decision")).is_true()
	# 1 abandoned of 3 runs is under both the sample floor and the rate alert.
	assert_bool(_kinds(tasks).has("abandon_rate")).is_false()


func test_the_evidence_carries_the_numbers_and_the_seeds() -> void:
	var tasks: Array[Dictionary] = TriageParser.collect(_report(), [], PackedStringArray())
	var task: Dictionary = _first_of(tasks, "pick_rate_floor")
	assert_bool(CodeIndexParser.dict_string(task, "title").contains("striker_2")).is_true()
	var evidence: PackedStringArray = CodeIndexParser.dict_string_array(task, "evidence")
	assert_bool(evidence[0].contains("offered 60")).is_true()
	# Only replayable seeds are offered, so the abandoned run's seed is left out.
	var repro: String = CodeIndexParser.dict_string(task, "repro")
	assert_bool(repro.contains("111")).is_true()
	assert_bool(repro.contains("333")).is_false()


func test_a_rarely_offered_skill_is_below_the_sample_floor() -> void:
	var report: Dictionary = {
		"pick_rates": {"skills": {"rare": {"offered": 5, "picked": 0, "pick_rate": 0.0}}},
	}
	assert_int(TriageParser.collect(report, [], PackedStringArray()).size()).is_equal(0)


func test_a_well_picked_skill_is_not_reported() -> void:
	var report: Dictionary = {
		"pick_rates": {"skills": {"common": {"offered": 90, "picked": 45, "pick_rate": 0.5}}},
	}
	assert_int(TriageParser.collect(report, [], PackedStringArray()).size()).is_equal(0)


func test_a_nearly_unused_ally_is_reported_and_sorts_first() -> void:
	var report: Dictionary = {
		"roster_coverage": {
			"allies": {"buffer": {"runs_in_lineup": 30, "runs_used": 2, "casts": 3, "coverage": 0.066}},
		},
		"pick_rates": {"skills": {"weak": {"offered": 60, "picked": 1, "pick_rate": 0.016}}},
	}
	var tasks: Array[Dictionary] = TriageParser.collect(report, [], PackedStringArray())
	assert_str(CodeIndexParser.dict_string(tasks[0], "kind")).is_equal("roster_coverage_zero")
	assert_str(CodeIndexParser.dict_string(tasks[0], "severity")).is_equal(TriageParser.SEVERITY_HIGH)
	assert_int(TriageParser.count_of_severity(tasks, TriageParser.SEVERITY_HIGH)).is_equal(1)


func test_a_lift_inside_the_band_is_not_reported() -> void:
	var report: Dictionary = {
		"win_loss": {"skill:ok": {"matches": 50, "advantage_adjusted_lift": 0.1}},
	}
	assert_int(TriageParser.collect(report, [], PackedStringArray()).size()).is_equal(0)


func test_an_abandon_spike_is_one_task() -> void:
	var runs: Dictionary = {}
	for index: int in range(8):
		runs["f%d" % index] = {"abandoned": false, "run_seed": index}
	for index: int in range(3):
		runs["a%d" % index] = {"abandoned": true}
	var tasks: Array[Dictionary] = TriageParser.collect({"runs": runs}, [], PackedStringArray())
	assert_int(tasks.size()).is_equal(1)
	assert_str(CodeIndexParser.dict_string(tasks[0], "kind")).is_equal("abandon_rate")
	assert_bool(CodeIndexParser.dict_string(tasks[0], "title").contains("27%")).is_true()


func test_a_flag_with_too_few_runs_is_left_alone() -> void:
	var report: Dictionary = {
		"flag_cohorts": {"young|x": {"flag": "young", "on": 4, "on_wins": 2, "off": 4, "off_wins": 2}},
	}
	assert_int(TriageParser.collect(report, [], PackedStringArray()).size()).is_equal(0)


func test_a_marker_becomes_a_task() -> void:
	var markers: Array[Dictionary] = [
		{"marker": "TODO", "where": "Core/Card.gd:12", "text": "# TODO: tidy this"},
	]
	var tasks: Array[Dictionary] = TriageParser.collect({}, markers, PackedStringArray())
	assert_int(tasks.size()).is_equal(1)
	assert_str(CodeIndexParser.dict_string(tasks[0], "kind")).is_equal("todo_marker")
	assert_bool(CodeIndexParser.dict_string(tasks[0], "repro").contains("Core/Card.gd:12")).is_true()


func test_a_ratchet_warning_becomes_a_task() -> void:
	var warnings: PackedStringArray = PackedStringArray([
		"Managers/GameManager.gd: WARNING: 1173 is below the ratchet baseline of 1182; tighten Tools/slop_baseline.json.",
	])
	var tasks: Array[Dictionary] = TriageParser.collect({}, [], warnings)
	assert_int(tasks.size()).is_equal(1)
	assert_str(CodeIndexParser.dict_string(tasks[0], "kind")).is_equal("ratchet_debt")
	assert_str(CodeIndexParser.dict_string(tasks[0], "subject")).is_equal("Managers/GameManager.gd")


func test_the_issue_marker_is_stable_and_embedded_in_the_body() -> void:
	var tasks: Array[Dictionary] = TriageParser.collect(_report(), [], PackedStringArray())
	var task: Dictionary = tasks[0]
	var marker: String = TriageParser.marker_for(task)
	assert_str(TriageParser.marker_for(task)).is_equal(marker)
	var body: String = TriageParser.issue_body(task)
	assert_bool(body.begins_with(marker)).is_true()
	assert_bool(body.contains("## Evidence")).is_true()
	assert_bool(body.contains("## Done when")).is_true()
	var other: Dictionary = {"kind": "todo_marker", "subject": "Core/Card.gd:12"}
	assert_bool(TriageParser.marker_for(other) != marker).is_true()


func test_the_per_kind_cap_holds() -> void:
	var markers: Array[Dictionary] = []
	for index: int in range(12):
		markers.append({"marker": "TODO", "where": "Core/Card.gd:%d" % index, "text": "# TODO"})
	var tasks: Array[Dictionary] = TriageParser.collect({}, markers, PackedStringArray())
	assert_int(tasks.size()).is_equal(TriageParser.MAX_TASKS_PER_KIND)


func test_the_list_is_ordered_by_severity_then_name() -> void:
	var markers: Array[Dictionary] = [
		{"marker": "TODO", "where": "b.gd:1", "text": "# TODO"},
		{"marker": "TODO", "where": "a.gd:1", "text": "# TODO"},
	]
	var tasks: Array[Dictionary] = TriageParser.collect(_report(), markers, PackedStringArray())
	assert_str(CodeIndexParser.dict_string(tasks[0], "severity")).is_equal(TriageParser.SEVERITY_HIGH)
	var last: Dictionary = tasks[tasks.size() - 1]
	assert_str(CodeIndexParser.dict_string(last, "severity")).is_equal(TriageParser.SEVERITY_LOW)
	# Same severity sorts by kind, then subject: a.gd before b.gd.
	var todo: Array[Dictionary] = []
	for task: Dictionary in tasks:
		if CodeIndexParser.dict_string(task, "kind") == "todo_marker":
			todo.append(task)
	assert_str(CodeIndexParser.dict_string(todo[0], "subject")).is_equal("a.gd:1")
	assert_str(CodeIndexParser.dict_string(todo[1], "subject")).is_equal("b.gd:1")


func test_an_empty_report_produces_nothing() -> void:
	assert_int(TriageParser.collect({}, [], PackedStringArray()).size()).is_equal(0)


## A leftover marker opens its comment; prose that merely mentions one is not a task.
func test_only_a_real_marker_counts() -> void:
	var found: Dictionary = TriageParser.marker_in_line("Core/Card.gd", 12, "\t# TODO: tidy this")
	assert_str(CodeIndexParser.dict_string(found, "where")).is_equal("Core/Card.gd:12")
	assert_str(CodeIndexParser.dict_string(found, "marker")).is_equal("TODO")
	assert_bool(TriageParser.marker_in_line("a.gd", 1, "## - `TODO:` markers become tasks").is_empty()).is_true()
	assert_bool(TriageParser.marker_in_line("a.gd", 1, "\tvar text: String = \"TODO:\"").is_empty()).is_true()
	assert_bool(TriageParser.marker_in_line("a.gd", 1, "\tpass").is_empty()).is_true()
	# A comment introducer inside a literal is data, not a comment.
	assert_bool(TriageParser.marker_in_line("a.gd", 1, "\tvar t: String = \"# TODO: x\"").is_empty()).is_true()
	var fixme: Dictionary = TriageParser.marker_in_line("a.gd", 3, "## FIXME(soon): drop the shim")
	assert_str(CodeIndexParser.dict_string(fixme, "marker")).is_equal("FIXME")
