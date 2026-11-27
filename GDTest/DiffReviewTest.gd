class_name DiffReviewTest
extends GdUnitTestSuite
## Fixture tests for the review layer behind Tools/review_diff.gd: the rules in
## Tools/DiffReviewParser.gd and the rendering in Tools/DiffReviewFormatter.gd. Each
## fixture is an inline unified diff, so the test never depends on the shape of the
## current branch and the expected line numbers are meaningful rather than incidental.
##
## @author TheGreatJellyfish
## @version 11/27/2026

## Rule names of every finding in the result, blocking first.
func _rules(result: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for section: String in ["blocking", "advisory"]:
		for raw: Variant in CodeIndexParser.dict_array(result, section):
			if not (raw is Dictionary):
				continue
			var finding: Dictionary = raw
			names.append(CodeIndexParser.dict_string(finding, "rule"))
	return names


## The `where` of the first finding with this rule, or "".
func _where(result: Dictionary, rule: String) -> String:
	for section: String in ["blocking", "advisory"]:
		for raw: Variant in CodeIndexParser.dict_array(result, section):
			if not (raw is Dictionary):
				continue
			var finding: Dictionary = raw
			if CodeIndexParser.dict_string(finding, "rule") == rule:
				return CodeIndexParser.dict_string(finding, "where")
	return ""


func _review(fixture: String, strict: bool = false) -> Dictionary:
	return DiffReviewParser.review(fixture, {"strict": strict})


## A banned API added twice, with the line above as context (git always supplies it).
func _banned_fixture() -> String:
	return "\n".join([
		"diff --git a/Scenes/Thing.gd b/Scenes/Thing.gd",
		"index 1111111..2222222 100644",
		"--- a/Scenes/Thing.gd",
		"+++ b/Scenes/Thing.gd",
		"@@ -10,3 +10,5 @@ func thing():",
		" pass",
		"+\tget_tree().create_timer(1.0)",
		"+\tawait get_tree().process_frame",
		"",
	])


func _game_change_fixture(with_test: bool) -> String:
	var lines: Array[String] = [
		"diff --git a/Managers/GameManager.gd b/Managers/GameManager.gd",
		"--- a/Managers/GameManager.gd",
		"+++ b/Managers/GameManager.gd",
		"@@ -20,2 +20,3 @@ func go():",
		"\tpass",
		"+\tprint(\"changed\")",
	]
	if with_test:
		lines.append_array([
			"diff --git a/GDTest/GameManagerTest.gd b/GDTest/GameManagerTest.gd",
			"--- a/GDTest/GameManagerTest.gd",
			"+++ b/GDTest/GameManagerTest.gd",
			"@@ -5,1 +5,2 @@ func test_thing():",
			"\tpass",
			"+\tassert_bool(true).is_true()",
		])
	return "\n".join(lines)


func _api_fixture(document: bool) -> String:
	var lines: Array[String] = [
		"diff --git a/Scenes/Thing.gd b/Scenes/Thing.gd",
		"--- a/Scenes/Thing.gd",
		"+++ b/Scenes/Thing.gd",
		"@@ -30,1 +30,3 @@",
		" func before() -> void:",
	]
	if document:
		lines.append("+## Does the thing.")
	lines.append("+func do_thing() -> void:")
	lines.append("+\tpass")
	return "\n".join(lines)


## A Core/ purity break; the paired test keeps `untested_change` out of the picture,
## so only one rule can be promoted.
func _core_fixture() -> String:
	return "\n".join([
		"diff --git a/Core/Thing.gd b/Core/Thing.gd",
		"--- a/Core/Thing.gd",
		"+++ b/Core/Thing.gd",
		"@@ -1,1 +1,2 @@",
		" extends RefCounted",
		"+extends Node",
		"",
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+func _helper() -> void:",
		"",
	])


func test_parse_diff_reads_paths_counts_and_lines() -> void:
	var files: Array[Dictionary] = DiffReviewParser.parse_diff(_banned_fixture())
	assert_int(files.size()).is_equal(1)
	assert_str(CodeIndexParser.dict_string(files[0], "path")).is_equal("Scenes/Thing.gd")
	assert_int(CodeIndexParser.dict_int(files[0], "added")).is_equal(2)
	assert_int(CodeIndexParser.dict_int(files[0], "removed")).is_equal(0)
	assert_bool(CodeIndexParser.dict_bool(files[0], "is_new")).is_false()


func test_hunk_start_line_reads_the_new_file_side() -> void:
	assert_int(DiffReviewParser.hunk_start_line("@@ -10,3 +10,5 @@ func thing():")).is_equal(10)
	assert_int(DiffReviewParser.hunk_start_line("@@ -1 +7 @@")).is_equal(7)
	assert_int(DiffReviewParser.hunk_start_line("not a hunk")).is_equal(0)


func test_banned_patterns_are_reported_on_the_added_line() -> void:
	var result: Dictionary = _review(_banned_fixture())
	assert_bool(_rules(result).has("banned_pattern")).is_true()
	assert_str(_where(result, "banned_pattern")).is_equal("Scenes/Thing.gd:11")
	assert_int(DiffReviewParser.exit_code(result)).is_equal(0)


func test_a_changed_script_without_its_test_is_flagged() -> void:
	var flagged: Dictionary = _review(_game_change_fixture(false))
	assert_bool(_rules(flagged).has("untested_change")).is_true()
	var covered: Dictionary = _review(_game_change_fixture(true))
	assert_bool(_rules(covered).has("untested_change")).is_false()


func test_an_undocumented_public_function_is_flagged_only_without_a_doc_line() -> void:
	var flagged: Dictionary = _review(_api_fixture(false))
	assert_bool(_rules(flagged).has("undocumented_api")).is_true()
	assert_str(_where(flagged, "undocumented_api")).is_equal("Scenes/Thing.gd:31")
	var documented: Dictionary = _review(_api_fixture(true))
	assert_bool(_rules(documented).has("undocumented_api")).is_false()


func test_core_purity_is_advisory_until_strict() -> void:
	var advisory: Dictionary = _review(_core_fixture())
	assert_bool(_rules(advisory).has("core_purity")).is_true()
	assert_int(DiffReviewParser.exit_code(advisory)).is_equal(0)
	var strict: Dictionary = _review(_core_fixture(), true)
	assert_int(DiffReviewParser.blocking_count(strict)).is_equal(1)
	assert_int(DiffReviewParser.exit_code(strict)).is_equal(1)
	assert_bool(_rules(strict).has("core_purity")).is_true()


func test_a_todo_in_added_code_is_flagged() -> void:
	var fixture: String = "\n".join([
		"diff --git a/Scenes/Thing.gd b/Scenes/Thing.gd",
		"--- a/Scenes/Thing.gd",
		"+++ b/Scenes/Thing.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+# TODO: revisit this",
		"",
	])
	assert_bool(_rules(_review(fixture)).has("todo_added")).is_true()


## The marker naming the rule (and a docs page quoting it) is not a leftover TODO.
func test_a_quoted_marker_or_a_docs_line_is_not_a_todo() -> void:
	var quoted: String = "\n".join([
		"diff --git a/Tools/Thing.gd b/Tools/Thing.gd",
		"--- a/Tools/Thing.gd",
		"+++ b/Tools/Thing.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\tconst MARKER: String = \"TODO\"",
		"",
	])
	assert_bool(_rules(_review(quoted)).has("todo_added")).is_false()
	var named_constant: String = "\n".join([
		"diff --git a/Tools/Thing.gd b/Tools/Thing.gd",
		"--- a/Tools/Thing.gd",
		"+++ b/Tools/Thing.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\tconst MARKER_TODO: String = \"TODO\"",
		"",
	])
	assert_bool(_rules(_review(named_constant)).has("todo_added")).is_false()
	var prose: String = "\n".join([
		"diff --git a/Tools/Thing.gd b/Tools/Thing.gd",
		"--- a/Tools/Thing.gd",
		"+++ b/Tools/Thing.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+## This is not a leftover TODO, it is prose.",
		"",
	])
	assert_bool(_rules(_review(prose)).has("todo_added")).is_false()
	var docs: String = "\n".join([
		"diff --git a/Docs/map/Tools/Thing.md b/Docs/map/Tools/Thing.md",
		"--- a/Docs/map/Tools/Thing.md",
		"+++ b/Docs/map/Tools/Thing.md",
		"@@ -1,1 +1,2 @@",
		" # Thing",
		"+- `MARKER: String = TODO`",
		"",
	])
	assert_bool(_rules(_review(docs)).has("todo_added")).is_false()


func test_markdown_report_lists_the_findings() -> void:
	var report: String = DiffReviewFormatter.format_markdown(_review(_banned_fixture()))
	assert_bool(report.contains("### Second-pass review")).is_true()
	assert_bool(report.contains("banned_pattern")).is_true()
	assert_bool(report.contains("Scenes/Thing.gd:11")).is_true()


## A fixture that feeds the parser a banned-looking string is data, not a call.
func test_a_banned_pattern_inside_a_string_literal_is_not_flagged() -> void:
	var quoted: String = "\n".join([
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\tvar line: String = \"create_timer(1.0)\"",
		"",
	])
	assert_bool(_rules(_review(quoted)).has("banned_pattern")).is_false()
	var unquoted: String = "\n".join([
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\tvar factor: float = create_timer(1.0)",
		"",
	])
	assert_bool(_rules(_review(unquoted)).has("banned_pattern")).is_true()


## Documentation mentions the ban on purpose; only GDScript can call the API.
func test_a_banned_pattern_documented_in_markdown_is_not_flagged() -> void:
	var docs: String = "\n".join([
		"diff --git a/AGENTS.md b/AGENTS.md",
		"--- a/AGENTS.md",
		"+++ b/AGENTS.md",
		"@@ -1,1 +1,2 @@",
		" # Rules",
		"+- Never use `create_timer()` to sequence anything.",
		"",
	])
	assert_bool(_rules(_review(docs)).has("banned_pattern")).is_false()


## GDScript has no private tests, so a suite's method names are not "new API surface".
func test_test_suite_methods_are_not_treated_as_public_api() -> void:
	var fixture: String = "\n".join([
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -10,1 +10,2 @@",
		" pass",
		"+func test_something() -> void:",
		"",
	])
	assert_bool(_rules(_review(fixture)).has("undocumented_api")).is_false()


## A trunk-only change: Core/ is where a wrong line reaches every player.
func _trunk_fixture() -> String:
	return "\n".join([
		"diff --git a/Core/GameState.gd b/Core/GameState.gd",
		"--- a/Core/GameState.gd",
		"+++ b/Core/GameState.gd",
		"@@ -1,1 +1,2 @@",
		" extends RefCounted",
		"+\tvar extra: int = 1",
		"",
	])


## Leaf game code: one isolated HUD widget.
func _leaf_fixture() -> String:
	return "\n".join([
		"diff --git a/Scenes/HUD/HudTooltip.gd b/Scenes/HUD/HudTooltip.gd",
		"--- a/Scenes/HUD/HudTooltip.gd",
		"+++ b/Scenes/HUD/HudTooltip.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\tvar extra: int = 1",
		"",
	])


## Neither trunk nor leaf game code: a tool and a generated docs page.
func _tooling_fixture() -> String:
	return "\n".join([
		"diff --git a/Tools/Thing.gd b/Tools/Thing.gd",
		"--- a/Tools/Thing.gd",
		"+++ b/Tools/Thing.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\tvar extra: int = 1",
		"",
		"diff --git a/Docs/map/Tools/Thing.md b/Docs/map/Tools/Thing.md",
		"--- a/Docs/map/Tools/Thing.md",
		"+++ b/Docs/map/Tools/Thing.md",
		"@@ -1,1 +1,2 @@",
		" # Thing",
		"+line",
		"",
	])


## A features.json edit: a flag enabled at a full rollout, or staged behind a canary.
func _feature_fixture(staged: bool) -> String:
	var lines: Array[String] = [
		"diff --git a/Data/json/features.json b/Data/json/features.json",
		"--- a/Data/json/features.json",
		"+++ b/Data/json/features.json",
		"@@ -1,1 +1,6 @@",
		" {",
		"+\t\"flags\": {\"my_experiment\": {",
		"+\t\t\"enabled\": true,",
	]
	if staged:
		lines.append("+\t\t\"rollout_percent\": 25,")
	lines.append_array([
		"+\t\t\"description\": \"what is being tried\"",
		"+\t}}",
		" }",
		"",
	])
	return "\n".join(lines)


## A new test method in GDTest/, with or without an assertion in its body.
func _test_fixture(with_assert: bool) -> String:
	var lines: Array[String] = [
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -1,1 +1,3 @@",
		" pass",
		"+func test_thing() -> void:",
	]
	lines.append("+\tassert_bool(true).is_true()" if with_assert else "+\tpass")
	return "\n".join(lines)


func test_review_tier_covers_folders_files_and_measured_fan_in() -> void:
	assert_str(DiffReviewParser.review_tier("Core/GameState.gd")).is_equal("trunk")
	assert_str(DiffReviewParser.review_tier("Managers/GameManager.gd")).is_equal("trunk")
	assert_str(DiffReviewParser.review_tier(".github/workflows/x.yml")).is_equal("trunk")
	assert_str(DiffReviewParser.review_tier("project.godot")).is_equal("trunk")
	assert_str(DiffReviewParser.review_tier("Scenes/HUD/HudTooltip.gd")).is_equal("leaf")
	assert_str(DiffReviewParser.review_tier(".github/PULL_REQUEST_TEMPLATE.md")).is_equal("leaf")
	var measured: PackedStringArray = PackedStringArray(["Scenes/Cards/CardUI.gd"])
	assert_str(DiffReviewParser.review_tier("Scenes/Cards/CardUI.gd", measured)).is_equal("trunk")
	assert_str(DiffReviewParser.review_tier("Scenes/Cards/HandBar.gd", measured)).is_equal("leaf")


## A diff that adds `count` plain lines to one file, for the size rule.
func _bulk_fixture(path_value: String, count: int) -> String:
	var lines: Array[String] = [
		"diff --git a/%s b/%s" % [path_value, path_value],
		"--- a/%s" % path_value,
		"+++ b/%s" % path_value,
		"@@ -1,1 +1,%d @@" % (count + 1),
		" pass",
	]
	for index: int in range(count):
		lines.append("+line %d" % index)
	return "\n".join(lines)


func test_oversize_counts_source_churn_but_not_regenerated_docs() -> void:
	var docs: Dictionary = _review(_bulk_fixture("Docs/map/Tools/Thing.md", 500))
	assert_bool(_rules(docs).has("oversize_diff")).is_false()
	var source: Dictionary = _review(_bulk_fixture("Scenes/HUD/HudTooltip.gd", 500))
	assert_bool(_rules(source).has("oversize_diff")).is_true()


func test_a_docs_mention_of_the_flag_registry_is_not_a_feature_gate() -> void:
	var docs: String = "\n".join([
		"diff --git a/Docs/map/Tools/Thing.md b/Docs/map/Tools/Thing.md",
		"--- a/Docs/map/Tools/Thing.md",
		"+++ b/Docs/map/Tools/Thing.md",
		"@@ -1,1 +1,2 @@",
		" # Thing",
		"+- add an entry to Data/json/features.json",
		"",
	])
	assert_bool(CodeIndexParser.dict_bool(_review(docs), "feature_gated")).is_false()
	var gate_call: String = "\n".join([
		"diff --git a/Scenes/HUD/HudTooltip.gd b/Scenes/HUD/HudTooltip.gd",
		"--- a/Scenes/HUD/HudTooltip.gd",
		"+++ b/Scenes/HUD/HudTooltip.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\tif FeatureFlags.is_active(state.flags, \"my_experiment\"):",
		"",
	])
	assert_bool(CodeIndexParser.dict_bool(_review(gate_call), "feature_gated")).is_true()
	var quoted: String = "\n".join([
		"diff --git a/Tools/Thing.gd b/Tools/Thing.gd",
		"--- a/Tools/Thing.gd",
		"+++ b/Tools/Thing.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\tconst MARKER: String = \"FeatureFlags.is_active\"",
		"",
	])
	assert_bool(CodeIndexParser.dict_bool(_review(quoted), "feature_gated")).is_false()
	assert_bool(CodeIndexParser.dict_bool(_review(gate_call.replace("Scenes/HUD/HudTooltip.gd", "GDTest/ThingTest.gd")), "feature_gated")).is_false()


func test_fan_in_from_map_reads_the_used_by_line() -> void:
	var page: String = "# `Core/GameState.gd`\n\nUsed by: A.gd, B.gd, C.gd\nLoads: —\n"
	assert_int(DiffReviewParser.fan_in_from_map(page)).is_equal(3)
	assert_int(DiffReviewParser.fan_in_from_map("Used by: —\n")).is_equal(0)
	assert_int(DiffReviewParser.fan_in_from_map("# nothing here\n")).is_equal(0)


func test_blast_radius_follows_the_trunk_rule() -> void:
	assert_str(CodeIndexParser.dict_string(_review(_trunk_fixture()), "blast_radius")).is_equal("high")
	assert_str(CodeIndexParser.dict_string(_review(_leaf_fixture()), "blast_radius")).is_equal("medium")
	assert_str(CodeIndexParser.dict_string(_review(_tooling_fixture()), "blast_radius")).is_equal("low")


func test_markdown_report_leads_with_the_blast_radius() -> void:
	var report: String = DiffReviewFormatter.format_markdown(_review(_trunk_fixture()))
	assert_bool(report.contains("Blast radius: HIGH")).is_true()
	assert_bool(report.contains("Core/GameState.gd")).is_true()


## A blank line between arrange and act must not be read as the end of the test: every
## suite here writes it that way, and the rule is blocking under --strict.
func test_a_blank_line_inside_a_new_test_does_not_hide_its_assertion() -> void:
	var fixture: String = "\n".join([
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -1,1 +1,5 @@",
		" pass",
		"+func test_thing() -> void:",
		"+\tvar value: int = 1",
		"+",
		"+\tassert_int(value).is_equal(1)",
		"",
	])
	var result: Dictionary = _review(fixture, true)
	assert_bool(_rules(result).has("assertionless_test")).is_false()
	assert_int(DiffReviewParser.blocking_count(result)).is_equal(0)


## A wrapped signature keeps the body open until the `:` closes it.
func test_a_wrapped_test_signature_still_finds_its_assertion() -> void:
	var fixture: String = "\n".join([
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -1,1 +1,6 @@",
		" pass",
		"+func test_thing(",
		"+\tvalue: int",
		"+) -> void:",
		"+\tassert_int(value).is_equal(1)",
		"",
	])
	assert_bool(_rules(_review(fixture, true)).has("assertionless_test")).is_false()


## A test whose only mention of the word is a comment still cannot fail.
func test_a_comment_mentioning_assert_does_not_count_as_an_assertion() -> void:
	var fixture: String = "\n".join([
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -1,1 +1,3 @@",
		" pass",
		"+func test_thing() -> void:",
		"+\t# nothing to assert here",
		"",
	])
	assert_bool(_rules(_review(fixture)).has("assertionless_test")).is_true()


## Two tests added back to back: the first one's empty body must not borrow the
## second one's assertion.
func test_an_empty_test_does_not_borrow_the_next_tests_assertion() -> void:
	var fixture: String = "\n".join([
		"diff --git a/GDTest/ThingTest.gd b/GDTest/ThingTest.gd",
		"--- a/GDTest/ThingTest.gd",
		"+++ b/GDTest/ThingTest.gd",
		"@@ -1,1 +1,5 @@",
		" pass",
		"+func test_first() -> void:",
		"+	pass",
		"+func test_second() -> void:",
		"+\tassert_bool(true).is_true()",
		"",
	])
	var result: Dictionary = _review(fixture)
	var flagged: PackedStringArray = PackedStringArray()
	for raw: Variant in CodeIndexParser.dict_array(result, "advisory"):
		if CodeIndexParser.dict_string(_finding_of(raw), "rule") == "assertionless_test":
			flagged.append(CodeIndexParser.dict_string(_finding_of(raw), "where"))
	assert_array(flagged).contains_exactly(["GDTest/ThingTest.gd:2"])


func _finding_of(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		var finding: Dictionary = raw
		return finding
	return {}


func test_adversarial_section_names_the_deep_context_and_the_invariants() -> void:
	var section: String = DiffReviewFormatter.adversarial_section(_review(_trunk_fixture()))
	assert_bool(section.contains("Adversarial review (context-isolated)")).is_true()
	assert_bool(section.contains("Core/GameState.gd")).is_true()
	assert_bool(section.contains("feature flag OFF")).is_true()
	var leaf: String = DiffReviewFormatter.adversarial_section(_review(_tooling_fixture()))
	assert_bool(leaf.contains("leaf-only change")).is_true()


## The brief is collapsed in the pull-request comment so the report stays a screenful.
func test_a_collapsible_adversarial_brief_is_wrapped_in_details() -> void:
	var section: String = DiffReviewFormatter.adversarial_section(_review(_trunk_fixture()), true)
	assert_bool(section.begins_with("<details>")).is_true()
	assert_bool(section.ends_with("</details>")).is_true()


## Only what ships decides the fan-in: otherwise adding unit tests to an isolated leaf
## widget would promote it to trunk and demand a line-by-line read of a HUD tooltip.
func test_fan_in_counts_runtime_dependents_only() -> void:
	var page: String = "Used by: Scenes/Cards/HandBar.gd, GDTest/CardUITest.gd, Tools/check_navigation.gd\n"
	assert_int(DiffReviewParser.fan_in_from_map(page)).is_equal(1)
	assert_bool(DiffReviewParser.is_non_shipped("GDTest/ThingTest.gd")).is_true()
	assert_bool(DiffReviewParser.is_non_shipped("Tools/review_diff.gd")).is_true()
	assert_bool(DiffReviewParser.is_non_shipped("Scenes/Cards/CardUI.gd")).is_false()


## A flagged change that touches scenes or shaders needs the rendered snapshot: the
## headless gates rasterise nothing.
func test_a_scene_or_shader_change_asks_for_visual_proof() -> void:
	assert_bool(DiffReviewFormatter.needs_ui_proof(PackedStringArray(["Scenes/HUD/HudTooltip.gd"]))).is_true()
	assert_bool(DiffReviewFormatter.needs_ui_proof(PackedStringArray(["Shaders/FakeCard3D.gdshader"]))).is_true()
	assert_bool(DiffReviewFormatter.needs_ui_proof(PackedStringArray(["Core/GameState.gd"]))).is_false()
	var report: String = DiffReviewFormatter.format_markdown(_review(_leaf_fixture()))
	assert_bool(report.contains("Visual proof: required")).is_true()


## A report longer than the cap is cut with a footer, not dumped: the reviewer exists to
## lower review cost.
func test_the_report_caps_its_finding_list() -> void:
	var findings: Array[Dictionary] = []
	for index: int in range(DiffReviewFormatter.MAX_REPORTED_FINDINGS + 3):
		findings.append({"rule": "todo_added", "where": "a.gd:%d" % index, "detail": "x"})
	var report: String = DiffReviewFormatter.format_markdown({
		"stats": {"file_count": 1, "added": 1, "removed": 0},
		"blocking": [],
		"advisory": findings,
		"blast_radius": DiffReviewParser.RADIUS_LOW,
		"trunk_paths": PackedStringArray(),
		"feature_gated": false,
		"changed_paths": PackedStringArray(["Tools/a.gd"]),
	})
	assert_bool(report.contains("and 3 more finding(s) hidden")).is_true()
	assert_bool(report.contains("a.gd:0")).is_true()
	assert_bool(report.contains("a.gd:%d" % DiffReviewFormatter.MAX_REPORTED_FINDINGS)).is_false()


## A note-to-self that names a flag is prose: only a real read counts as a gate.
func test_a_comment_naming_the_flag_api_is_not_a_feature_gate() -> void:
	var fixture: String = "\n".join([
		"diff --git a/Scenes/HUD/HudTooltip.gd b/Scenes/HUD/HudTooltip.gd",
		"--- a/Scenes/HUD/HudTooltip.gd",
		"+++ b/Scenes/HUD/HudTooltip.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\t# TODO: gate this on FeatureFlags.is_active later",
		"",
	])
	assert_bool(CodeIndexParser.dict_bool(_review(fixture), "feature_gated")).is_false()


## Documenting a ban in a comment is not a call to the banned API.
func test_a_banned_pattern_in_a_comment_is_not_flagged() -> void:
	var fixture: String = "\n".join([
		"diff --git a/Scenes/HUD/HudTooltip.gd b/Scenes/HUD/HudTooltip.gd",
		"--- a/Scenes/HUD/HudTooltip.gd",
		"+++ b/Scenes/HUD/HudTooltip.gd",
		"@@ -1,1 +1,2 @@",
		" pass",
		"+\t# never use create_timer() to sequence this",
		"",
	])
	assert_bool(_rules(_review(fixture)).has("banned_pattern")).is_false()


## Each enabled flag is judged on its own rollout, so a second one cannot hide behind the
## first, and a staged value already on an unchanged line still counts as staged.
func test_unstaged_rollout_is_judged_per_flag() -> void:
	var second_flag_bare: String = "\n".join([
		"diff --git a/Data/json/features.json b/Data/json/features.json",
		"--- a/Data/json/features.json",
		"+++ b/Data/json/features.json",
		"@@ -1,1 +1,3 @@",
		" {",
		"+\t\"a\": {\"enabled\": true, \"rollout_percent\": 25, \"description\": \"x\"},",
		"+\t\"b\": {\"enabled\": true, \"description\": \"y\"}",
		" }",
		"",
	])
	assert_bool(_rules(_review(second_flag_bare)).has("unstaged_rollout")).is_true()
	var staged_context_line: String = "\n".join([
		"diff --git a/Data/json/features.json b/Data/json/features.json",
		"--- a/Data/json/features.json",
		"+++ b/Data/json/features.json",
		"@@ -1,3 +1,3 @@",
		" \t\"flags\": {\"my_experiment\": {",
		"-\t\t\"enabled\": false,",
		"+\t\t\"enabled\": true,",
		" \t\t\"rollout_percent\": 25,",
		" }",
		"",
	])
	assert_bool(_rules(_review(staged_context_line)).has("unstaged_rollout")).is_false()


func test_a_feature_gated_change_is_reported_and_an_unstaged_rollout_is_flagged() -> void:
	var gated: Dictionary = _review(_feature_fixture(false))
	assert_bool(CodeIndexParser.dict_bool(gated, "feature_gated")).is_true()
	assert_bool(_rules(gated).has("unstaged_rollout")).is_true()
	var staged: Dictionary = _review(_feature_fixture(true))
	assert_bool(CodeIndexParser.dict_bool(staged, "feature_gated")).is_true()
	assert_bool(_rules(staged).has("unstaged_rollout")).is_false()


func test_a_new_test_without_an_assertion_is_flagged_and_promoted_by_strict() -> void:
	var advisory: Dictionary = _review(_test_fixture(false))
	assert_bool(_rules(advisory).has("assertionless_test")).is_true()
	assert_int(DiffReviewParser.exit_code(advisory)).is_equal(0)
	var strict: Dictionary = _review(_test_fixture(false), true)
	assert_int(DiffReviewParser.blocking_count(strict)).is_equal(1)
	assert_bool(_rules(strict).has("assertionless_test")).is_true()
	var covered: Dictionary = _review(_test_fixture(true))
	assert_bool(_rules(covered).has("assertionless_test")).is_false()
