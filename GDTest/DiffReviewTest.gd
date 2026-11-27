class_name DiffReviewTest
extends GdUnitTestSuite
## Fixture tests for Tools/DiffReviewParser.gd, the pure review layer behind
## Tools/review_diff.gd. Each fixture is an inline unified diff, so the test never
## depends on the shape of the current branch and the expected line numbers are
## meaningful rather than incidental.
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
	var report: String = DiffReviewParser.format_markdown(_review(_banned_fixture()))
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
