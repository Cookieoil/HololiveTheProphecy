class_name DiffReviewFormatter
extends RefCounted
## Rendering layer behind Tools/review_diff.gd.
##
## Turns the plain Dictionary that Tools/DiffReviewParser.gd produces into the markdown
## pull-request comment, the terminal report and the context-isolated brief for a fresh
## reviewer. It lives in its own file so the rule layer stays inside the anti-slop
## file-size ceiling (Tools/line_godot_slop.py) and so rewording the report never touches
## a rule.
##
## Pure on purpose: a Dictionary in, a String out, no file system. That keeps the report
## unit-testable against the same fixtures the rules use.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Constants
## Cap the report: the point is to lower review cost, not add to it.
const MAX_REPORTED_FINDINGS: int = 30
## Areas whose change moves pixels. Every headless gate uses the dummy renderer, which
## rasterises nothing, so a review that touches one of these needs the rendered snapshot
## as its proof rather than just a green gate.
const UI_PREFIXES: Array[String] = ["Scenes/", "Shaders/"]
## The adversarial pass attacks invariants the linter cannot see. Style, naming and
## typing are deliberately absent: the gates own them, so re-raising them only adds noise
## and buries the one thing that matters.
const ADVERSARIAL_QUESTIONS: Array[String] = [
	"Does a new path mutate `GameState` / `Unit` outside a method whose result a UI reacts to?",
	"Can the change make a run non-deterministic (a global RNG, `Time`, or an ordering a fixed `run_seed` no longer pins)?",
	"With the feature flag OFF, is the previous behaviour unchanged — not merely 'still works'?",
	"Can a signal be emitted twice, or after the node is freed, on the new path?",
	"Does it move a turn / action / Moxie invariant without a test that would catch the regression?",
	"Does it add a test that cannot fail (no assertion, or an assertion on a constant)?",
]
#endregion

#region Public Methods
## Compact markdown for a pull-request comment: the blast radius first (how deep a reader
## has to go), then a summary line and one table row per finding, so the whole review
## fits in a screenful.
static func format_markdown(result: Dictionary) -> String:
	var stats: Dictionary = _dict(result.get("stats"))
	var out: PackedStringArray = PackedStringArray()
	out.append("### Second-pass review")
	out.append("")
	out.append_array(_radius_section(result))
	out.append("%d file(s) changed, +%d / -%d lines." % [
		CodeIndexParser.dict_int(stats, "file_count"),
		CodeIndexParser.dict_int(stats, "added"),
		CodeIndexParser.dict_int(stats, "removed"),
	])
	out.append("")
	out.append("| area | files |")
	out.append("| --- | --- |")
	for area: String in ["game", "tests", "tools", "data", "docs", "other"]:
		out.append("| %s | %d |" % [area, CodeIndexParser.dict_int(stats, area)])
	out.append("")
	out.append_array(_markdown_section("Blocking", CodeIndexParser.dict_array(result, "blocking")))
	out.append_array(_markdown_section("Review-worthy", CodeIndexParser.dict_array(result, "advisory")))
	return "\n".join(out).strip_edges() + "\n"


## Plain text for a terminal run, led by the same blast-radius line so a local run and
## the pull-request comment agree on how deep the review has to go.
static func format_text(result: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append_array(_radius_lines(result))
	var listed: int = 0
	var total: int = 0
	for section: String in ["blocking", "advisory"]:
		var findings: Array = CodeIndexParser.dict_array(result, section)
		total += findings.size()
		for raw: Variant in _capped(findings):
			var finding: Dictionary = _dict(raw)
			listed += 1
			out.append("[%s] %s  %s  %s" % [
				section,
				CodeIndexParser.dict_string(finding, "rule"),
				CodeIndexParser.dict_string(finding, "where"),
				CodeIndexParser.dict_string(finding, "detail"),
			])
	if total == 0:
		out.append("No review-worthy findings.")
	elif total > listed:
		out.append("... and %d more finding(s) hidden." % [total - listed])
	return "\n".join(out) + "\n"


## The context-isolated brief for a *fresh* reviewer. An agent that wrote a change carries
## its whole authoring conversation, so it defends the shortcuts it took; the remedy is to
## hand a new reviewer only the diff, the touched scripts' public API and the invariants
## below, and to ask it to break the change. Style is excluded on purpose - the compiler
## and the linter already own it.
##
## `collapsible` wraps the markdown in `<details>`, so the pull-request comment stays a
## screenful while the brief is one click away for whoever reviews next.
static func adversarial_section(result: Dictionary, collapsible: bool = false) -> String:
	var out: PackedStringArray = PackedStringArray()
	if collapsible:
		out.append("<details><summary>Adversarial review brief (context-isolated)</summary>")
		out.append("")
	out.append("#### Adversarial review (context-isolated)")
	out.append("")
	out.append("Feed a **fresh** reviewer only this report, the diff, those `Docs/map/` pages and `AGENTS.md`.")
	out.append("It must not see the authoring conversation: ask it to break the change, not to defend it.")
	out.append("")
	var trunk: PackedStringArray = CodeIndexParser.dict_string_array(result, "trunk_paths")
	if trunk.is_empty():
		out.append("Deep context: none (leaf-only change).")
	else:
		out.append("Deep context (read these in full): " + ", ".join(trunk))
	out.append("")
	out.append("Attack these invariants:")
	for question: String in ADVERSARIAL_QUESTIONS:
		out.append("- " + question)
	if collapsible:
		out.append("")
		out.append("</details>")
	return "\n".join(out)


## True when a change moved pixels: a headless run uses the dummy renderer and rasterises
## nothing, so a scene or a shader needs `reports/ui-snapshots/` for proof.
static func needs_ui_proof(changed: PackedStringArray) -> bool:
	for path_value: String in changed:
		for prefix: String in UI_PREFIXES:
			if path_value.begins_with(prefix):
				return true
	return false
#endregion

#region Private Methods
## The blast-radius block: how deep a reader has to go, whether a kill switch already
## bounds the change, and whether the pixels moved.
static func _radius_section(result: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var radius: String = CodeIndexParser.dict_string(result, "blast_radius")
	out.append("**Blast radius: %s** — %s" % [radius.to_upper(), _radius_hint(radius)])
	var trunk: PackedStringArray = CodeIndexParser.dict_string_array(result, "trunk_paths")
	if not trunk.is_empty():
		out.append("")
		out.append("Trunk (read line by line): " + ", ".join(trunk))
	out.append("")
	out.append(_gate_line(CodeIndexParser.dict_bool(result, "feature_gated")))
	if needs_ui_proof(CodeIndexParser.dict_string_array(result, "changed_paths")):
		out.append("Visual proof: required — `Scenes/`/`Shaders/` changed, so check `reports/ui-snapshots/` (`pwsh -File Tools/preflight.ps1 -Snapshots`).")
	out.append("")
	return out


## The same summary for a terminal run, where bold markdown would only be noise.
static func _radius_lines(result: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("blast_radius: %s  trunk: %d file(s)  feature_gate: %s" % [
		CodeIndexParser.dict_string(result, "blast_radius"),
		CodeIndexParser.dict_string_array(result, "trunk_paths").size(),
		str(CodeIndexParser.dict_bool(result, "feature_gated")),
	])
	if needs_ui_proof(CodeIndexParser.dict_string_array(result, "changed_paths")):
		out.append("visual_proof: required (Scenes/ or Shaders/ changed; see reports/ui-snapshots/)")
	return out


## Whether a kill switch bounds the change is the second question a reader has, right
## after how deep the read has to go.
static func _gate_line(feature_gated: bool) -> String:
	if feature_gated:
		return "Feature gate: present — the change is behind (or is) a staged flag, so a rollback is one JSON edit."
	return "Feature gate: none — nothing to kill-switch; the change is live as soon as it merges."


static func _radius_hint(radius: String) -> String:
	if radius == DiffReviewParser.RADIUS_HIGH:
		return "trunk or high fan-in code; a human reads every line and checks the callers below it"
	if radius == DiffReviewParser.RADIUS_MEDIUM:
		return "leaf game code; skim once the gates are green and confirm the flag-off path"
	return "tests, tools or docs only; the gates are the reviewer"


static func _markdown_section(title: String, findings: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if findings.is_empty():
		return out
	out.append("#### %s (%d)" % [title, findings.size()])
	out.append("")
	out.append("| rule | where | detail |")
	out.append("| --- | --- | --- |")
	for raw: Variant in _capped(findings):
		var finding: Dictionary = _dict(raw)
		out.append("| `%s` | `%s` | %s |" % [
			CodeIndexParser.dict_string(finding, "rule"),
			CodeIndexParser.dict_string(finding, "where"),
			CodeIndexParser.dict_string(finding, "detail").replace("|", "\\|"),
		])
	out.append("")
	if findings.size() > MAX_REPORTED_FINDINGS:
		out.append("_… and %d more finding(s) hidden._" % [findings.size() - MAX_REPORTED_FINDINGS])
		out.append("")
	return out


## The first `MAX_REPORTED_FINDINGS` of a list, so a broad refactor cannot turn the report
## into a wall of rows nobody reads.
static func _capped(findings: Array) -> Array:
	if findings.size() <= MAX_REPORTED_FINDINGS:
		return findings
	return findings.slice(0, MAX_REPORTED_FINDINGS)


static func _dict(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		var value: Dictionary = raw
		return value
	return {}
#endregion
