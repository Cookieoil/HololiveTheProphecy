<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/triage.gd` extends `SceneTree`

`222` lines · [back to the map](../../CODEBASE_MAP.md)

> Forward pressure: turns evidence into agent-ready task issues. An agent (or a human) should never have to *notice* work. This collects the signals the repositor…

Sections: Constants · Lifecycle Methods · Private Methods

Constants:
- L28 `SOURCE_DIRS: Array[String] = [`
- L36 `LINT_SCRIPT: String = "res://Tools/line_godot_slop.py"`
- L37 `ARG_REPORT: String = "--report"`
- L38 `ARG_CREATE: String = "--create"`
- L39 `ARG_LABEL: String = "--label"`
- L40 `ARG_JSON: String = "--json"`
- L41 `ARG_PYTHON: String = "--python"`
- L42 `DEFAULT_LABEL: String = "agent-task"`
- L43 `DEFAULT_PYTHON: String = "python"`

Private:
- L47-56 `_initialize`
- L59-64 `_arg_value`
- L70-79 `_read_report`
- L84-92 `_collect_markers`
- L95-104 `_scan_dir`
- L107-114 `_scan_file`
- L119-128 `_ratchet_warnings`
- L131-146 `_print_summary`
- L149-159 `_write_json`
- L164-174 `_file_issues`
- L178-185 `_ensure_label`
- L189-198 `_open_issue_text`
- L202-220 `_create_issue`

Uses: CodeIndexParser, TriageParser
Used by: —
Loads: res://Core, res://Managers, res://Scenes, res://Skills, res://Tools, res://GDTest, res://Tools/line_godot_slop.py

