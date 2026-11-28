class_name ValidationReporter
extends RefCounted
## GitHub Actions reporting for the game-data validator: workflow annotations that point
## at the exact data file (and line, when it can be located) and the Markdown job
## summary.
##
## Split out of Tools/validate_gameData.gd, which had grown the CI plumbing inside the
## rule engine. Nothing here validates anything - it takes the diagnostics the validator
## already collected plus the raw file text and renders them - which is what makes the
## line locator testable on its own: no files, no scene tree, no exit code.
##
## @author TheGreatJellyfish
## @version 11/28/2026

#region Constants
## GitHub Actions environment variables used for CI reporting.
const ENV_GITHUB_ACTIONS: String = "GITHUB_ACTIONS"
#endregion

#region Public Methods
## Emits GitHub Actions workflow commands so a failure annotates the exact file (and,
## when it can be located, line) inside the pull request. A no-op outside CI.
## @param raw_text - the source text of each data file, keyed by res:// path
## @param paths - diagnostic needle -> res:// path (see the runner's DIAGNOSTIC_PATHS)
static func emit_annotations(
	errors: PackedStringArray,
	warnings: PackedStringArray,
	raw_text: Dictionary,
	paths: Dictionary
) -> void:
	if OS.get_environment(ENV_GITHUB_ACTIONS) != "true":
		return
	for message: String in errors:
		_emit_annotation("error", message, raw_text, paths)
	for message: String in warnings:
		_emit_annotation("warning", message, raw_text, paths)


## Maps a diagnostic message to the repo-relative data file it belongs to, or "" when
## the message names no file. The needles are the `paths` keys, in their order.
static func diagnostic_file(message: String, paths: Dictionary) -> String:
	for needle: String in paths:
		if message.contains(needle):
			return _repo_path(str(paths[needle]))
	return ""


## Best-effort 1-based source line for a diagnostic, 0 when it cannot be located.
static func diagnostic_line(message: String, raw_text: Dictionary, paths: Dictionary) -> int:
	if message.contains("skills.json"):
		return _skills_line(message, raw_text, paths)
	if message.contains("allies.json") or message.contains("enemies.json"):
		return _unit_line(message, raw_text, paths)
	if message.contains("waves.json"):
		return _waves_line(message, raw_text, paths)
	if message.contains("config.json"):
		return _config_line(message, raw_text, paths)
	return 0


## The Markdown report appended to the GitHub Actions job summary, so the result is
## readable on the run page without digging through the raw log.
## @param counts - {skills, allies, enemies, waves} for the shape table
static func step_summary(
	exit_code: int,
	errors: PackedStringArray,
	warnings: PackedStringArray,
	counts: Dictionary
) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("## Game data validation")
	lines.append("")
	if exit_code == 0:
		lines.append("Result: **PASSED** (%d warning(s))" % warnings.size())
	else:
		lines.append("Result: **FAILED** (%d error(s), %d warning(s))" % [errors.size(), warnings.size()])
	lines.append("")
	lines.append("| Skills | Allies | Enemies | Waves |")
	lines.append("| --- | --- | --- | --- |")
	lines.append("| %d | %d | %d | %d |" % [
		_count(counts, "skills"),
		_count(counts, "allies"),
		_count(counts, "enemies"),
		_count(counts, "waves"),
	])
	lines.append("")
	if not errors.is_empty():
		lines.append("### Errors")
		lines.append("")
		for message: String in errors:
			lines.append("- `%s`" % message)
		lines.append("")
	if not warnings.is_empty():
		lines.append("### Warnings")
		lines.append("")
		for message: String in warnings:
			lines.append("- `%s`" % message)
		lines.append("")
	return "\n".join(lines)
#endregion


#region Private Methods
## One entry of the shape table as an int (it is read back out of a Dictionary).
static func _count(counts: Dictionary, key: String) -> int:
	var value: Variant = counts.get(key, 0)
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	return 0


static func _emit_annotation(
	severity: String,
	message: String,
	raw_text: Dictionary,
	paths: Dictionary
) -> void:
	var text: String = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
	var file: String = diagnostic_file(message, paths)
	var line: int = diagnostic_line(message, raw_text, paths)
	if file.is_empty():
		print("::%s title=Game data::%s" % [severity, text])
	elif line > 0:
		print("::%s file=%s,line=%d,title=Game data::%s" % [severity, file, line, text])
	else:
		print("::%s file=%s,title=Game data::%s" % [severity, file, text])


static func _repo_path(res_path: String) -> String:
	if res_path.begins_with("res://"):
		return res_path.substr("res://".length())
	return res_path


## 1-based line of the diagnostic inside skills.json: the skill's own line, or the
## effect block's line when the message names one.
static func _skills_line(message: String, raw_text: Dictionary, paths: Dictionary) -> int:
	var skill_id: String = _first_quoted(message)
	if skill_id.is_empty():
		return 0
	var path: String = str(paths.get("skills.json", ""))
	var skill_line: int = _line_of(raw_text, path, "\"%s\": {" % skill_id, 0)
	var effect_index: int = _bracket_index(message, "effect[")
	if effect_index >= 0:
		var effect_line: int = _line_of(raw_text, path, "\"effect_id\":", effect_index, maxi(0, skill_line - 1))
		if effect_line > 0:
			return effect_line
	return skill_line


static func _unit_line(message: String, raw_text: Dictionary, paths: Dictionary) -> int:
	var label: String = "allies.json" if message.contains("allies.json") else "enemies.json"
	var unit_id: String = _first_quoted(message)
	if unit_id.is_empty():
		return 0
	return _line_of(raw_text, str(paths.get(label, "")), "\"%s\": {" % unit_id, 0)


static func _waves_line(message: String, raw_text: Dictionary, paths: Dictionary) -> int:
	var path: String = str(paths.get("waves.json", ""))
	var wave_index: int = _bracket_index(message, "wave[")
	if wave_index < 0:
		return _line_of(raw_text, path, "\"waves\"", 0)
	var wave_line: int = _line_of(raw_text, path, "\"wave_index\"", wave_index)
	var enemy_index: int = _bracket_index(message, "enemy[")
	if enemy_index >= 0 and wave_line > 0:
		var enemy_line: int = _line_of(raw_text, path, "\"unit_id\"", enemy_index, wave_line - 1)
		if enemy_line > 0:
			return enemy_line
	return wave_line


static func _config_line(message: String, raw_text: Dictionary, paths: Dictionary) -> int:
	var key: String = _first_quoted(message)
	if key.is_empty():
		for candidate: String in [
			"decklist", "dice_progression", "allies", "hand_size",
			"actions_per_turn", "merges_per_turn", "wave_transition_mode",
		]:
			if message.contains(candidate):
				key = candidate
				break
	if key.is_empty():
		return 0
	return _line_of(raw_text, str(paths.get("config.json", "")), "\"%s\"" % key, 0)


## 1-based line of the `occurrence`-th (0-based) line at or after `from_line` that
## contains `needle`, or 0 when it is not found.
static func _line_of(raw_text: Dictionary, path: String, needle: String, occurrence: int, from_line: int = 0) -> int:
	var text: String = str(raw_text.get(path, ""))
	if text.is_empty():
		return 0
	var lines: PackedStringArray = text.split("\n")
	var found: int = 0
	for index: int in lines.size():
		if index < from_line:
			continue
		if lines[index].contains(needle):
			if found == occurrence:
				return index + 1
			found += 1
	return 0


## The first 'single quoted' token of a diagnostic message, or "".
static func _first_quoted(message: String) -> String:
	var start: int = message.find("'")
	if start < 0:
		return ""
	var end: int = message.find("'", start + 1)
	if end < 0:
		return ""
	return message.substr(start + 1, end - start - 1)


## The integer inside the first "<marker>N]" token, or -1 when absent.
static func _bracket_index(message: String, marker: String) -> int:
	var start: int = message.find(marker)
	if start < 0:
		return -1
	start += marker.length()
	var end: int = message.find("]", start)
	if end < 0:
		return -1
	var digits: String = message.substr(start, end - start)
	if not digits.is_valid_int():
		return -1
	return digits.to_int()
#endregion
