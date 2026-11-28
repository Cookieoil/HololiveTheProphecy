#!/usr/bin/env python3
"""Regression suite for Tools/line_godot_slop.py - the anti-slop gate itself.

    python Tools/line_godot_slop_test.py

Why this exists: the lint is what stops the next change from quietly growing a class,
flattening a function or slipping an imperative timer back in. A gate nobody tests is a
gate that silently stops gating, so its rules are pinned here - first as units, then end
to end against a scratch tree the suite writes itself.

The interesting cases are the ones a naive implementation gets wrong:

  * a banned pattern that only appears as *data* (a reviewer's own rule list, a fixture
    that feeds the parser a diff) is not a call, and must not fail the gate;
  * a `##` doc block belongs to the declaration *below* it, not to the function above,
    or every documented function measures longer than it is;
  * an entry sitting exactly on its ceiling passes - the ratchet tightens when the code
    shrinks, it does not forbid the current size.

Run it after touching the lint, the baseline format or the exclusion rules.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import shutil
import tempfile
from pathlib import Path

MODULE = Path(__file__).with_name("line_godot_slop.py")
REPO_ROOT = MODULE.resolve().parent.parent
WORK = Path(tempfile.mkdtemp(prefix="slop-test-"))

spec = importlib.util.spec_from_file_location("slop", MODULE)
slop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(slop)

results: list[tuple[str, bool, str]] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    results.append((name, bool(condition), detail))


def write(rel: str, text: str) -> Path:
    """Writes one scratch script, so the gate can be judged end to end."""
    path = WORK / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def write_baseline(data: dict) -> None:
    """Replaces the scratch ratchet baseline (missing sections are filled in)."""
    path = WORK / slop.BASELINE_RELATIVE
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data), encoding="utf-8")


def clear() -> None:
    """Empties the scratch tree, so every end-to-end run starts from nothing."""
    if not WORK.is_dir():
        WORK.mkdir(parents=True, exist_ok=True)
        return
    for child in WORK.iterdir():
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()


def scene(scripts: dict, baseline: dict | None = None) -> None:
    """Lays out one whole tree: the scripts, plus the ratchet baseline judging them.

    Every end-to-end run goes through here, because `clear()` takes the baseline with
    it - a scenario that forgot to re-write one would fail as a missing-baseline crash
    rather than as the rule under test.
    """
    clear()
    for rel, text in scripts.items():
        write(rel, text)
    write_baseline(baseline if baseline is not None else {})


def run_lint(strict: bool = False) -> tuple[int, str]:
    """Runs the real gate over the scratch tree, capturing what it printed."""
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        code = slop.lint(WORK, strict)
    return code, buffer.getvalue()


def expect_exit(function) -> bool:
    """True when calling `function` exits via SystemExit (how the lint reports)."""
    try:
        function()
    except SystemExit:
        return True
    except Exception:  # noqa: BLE001 - an unexpected type is a failed check
        return False
    return False


def non_blank(text: str) -> str:
    return " | ".join(line.strip() for line in text.splitlines() if line.strip())


# ------------------------------------------------- the string-literal exemption
code_line = "    var timer = create_timer(1.0)"
literal_line = '    push_warning("create_timer(1.0)")'
check("a call in code is not inside a literal",
      not slop._inside_string(code_line, code_line.index("create_timer")))
check("a call in a literal is inside one",
      slop._inside_string(literal_line, literal_line.index("create_timer")))
check("single quotes count as a literal", slop._inside_string("    x = 'get_parent()'", 12))
escaped = '    x = "a\\"b get_parent()'
check("an escaped quote keeps the literal open",
      slop._inside_string(escaped, escaped.index("get_parent")))
closed = '    x = "s" + get_parent()'
check("text after a closed literal is code again",
      not slop._inside_string(closed, closed.index("get_parent")))

check("create_timer in code is reported", len(slop._banned_matches(code_line)) == 1)
check("create_timer in a literal is data, not a call", not slop._banned_matches(literal_line))
check("the frame pump is reported",
      len(slop._banned_matches("    await get_tree().process_frame")) == 1)
check("a relative parent walk is reported", len(slop._banned_matches('    get_node("../HUD")')) == 1)
check("one message per pattern per line",
      len(slop._banned_matches("    create_timer(1); create_timer(2)")) == 1)

# ------------------------------------------------------------------- measuring
branchy = [
    "func f() -> void:",
    "\tif a:",
    "\t\tpass",
    "\tfor i in 3:",
    "\t\tpass",
    "\twhile b:",
    "\t\tpass",
    "\tmatch c:",
    "\t\t_:",
    "\t\t\tpass",
    "\tvar x = 1 if y else 2",
    "\t# if z: a comment is not a branch",
]
check("branch score is 1 plus one per if/for/while/match",
      slop._complexity(branchy, 0, len(branchy)) == 5)
check("an empty body still scores 1", slop._complexity([], 0, 0) == 1)

spans = {name: (start, end) for name, start, end in slop._function_bodies([
    "func first() -> void:",
    "\tpass",
    "",
    "",
    "## doc for second",
    "func second(a: int) -> int:",
    "\treturn a",
    "#endregion",
    "static func third() -> void:",
    "\tpass",
])}
check("a doc block belongs to the declaration below it", spans["first"] == (0, 4), str(spans))
check("a function ends at the next top-level declaration", spans["second"] == (5, 7), str(spans))
check("a static function is a top-level function", spans["third"] == (8, 10), str(spans))

walkers = [
    "func f() -> void:",
    "\tvar a = get_parent()",
    "\t# var b = get_parent()",
    '\tpush_warning("get_parent()")',
]
check("get_parent is counted in code only", slop._count_get_parent(walkers) == 1)


# --------------------------------------------------------------- ratchet maths
def ratchet(measured: int, allowed: int, tracked: bool) -> tuple[list, list]:
    errors: list = []
    warnings: list = []
    slop._check_ratchet("thing", measured, allowed, tracked, "hint", errors, warnings)
    return errors, warnings


errors, warnings = ratchet(901, 900, True)
check("over the ceiling is an error", bool(errors) and not warnings)
errors, warnings = ratchet(900, 900, True)
check("exactly on the ceiling passes", not errors and not warnings)
errors, warnings = ratchet(800, 900, True)
check("below a tracked baseline warns, so it gets tightened", not errors and bool(warnings))
errors, warnings = ratchet(800, 900, False)
check("below an untracked default is silent", not errors and not warnings)


# ------------------------------------------------------------ baseline loading
clear()
check("a missing baseline exits", expect_exit(lambda: slop._load_baseline(WORK)))
write_baseline({"files": {}})
(WORK / slop.BASELINE_RELATIVE).write_text("{not json", encoding="utf-8")
check("a corrupt baseline exits", expect_exit(lambda: slop._load_baseline(WORK)))
write_baseline({"defaults": {"max_file_lines": 900}})
loaded = slop._load_baseline(WORK)
check("missing sections are filled in", all(
    section in loaded for section in ("defaults", "files", "functions", "complexity", "get_parent")
))


# ----------------------------------------------------------- end to end: bans
CLEAN_SCRIPT = "extends RefCounted\n\n\nfunc f() -> void:\n\tpass\n"
TIMER_SCRIPT = "extends Node\n\n\nfunc f() -> void:\n\tvar t = create_timer(1.0)\n"
PUMP_SCRIPT = "extends Node\n\n\nfunc f() -> void:\n\tawait get_tree().process_frame\n"

scene({"Managers/Thing.gd": CLEAN_SCRIPT})
code, output = run_lint()
check("a clean tree passes", code == 0, output)

scene({"Managers/Thing.gd": TIMER_SCRIPT})
code, output = run_lint()
check("an imperative timer fails the gate", code == 1 and "create_timer" in output, output)

scene({"GDTest/ThingTest.gd": PUMP_SCRIPT})
code, output = run_lint()
check("a frame pump is allowed in the test suite", code == 0, output)

scene({"Managers/Thing.gd": PUMP_SCRIPT})
code, output = run_lint()
check("the same frame pump is banned in shipped code", code == 1 and "process_frame" in output, output)

scene({"addons/ThirdParty.gd": TIMER_SCRIPT})
code, output = run_lint()
check("addons/ is never linted", code == 0, output)


# ------------------------------------------------------ end to end: core purity
scene({"Core/Thing.gd": "extends Node\n"})
code, output = run_lint()
check("a Node in Core/ fails the purity rule", code == 1 and "pure logic" in output, output)

scene({"Core/GameUI.gd": "extends Node\n"})
code, output = run_lint()
check("Core/GameUI.gd is the one documented exception", code == 0, output)


# -------------------------------------------------------- end to end: ratchets
BIG_FILE = "extends RefCounted\n" + "\n".join("# padding %d" % index for index in range(30))
BIG_LINES = len(BIG_FILE.splitlines())

scene({"Managers/Big.gd": BIG_FILE}, {"files": {"Managers/Big.gd": BIG_LINES}})
check("a file exactly on its baseline passes", run_lint()[0] == 0)
scene({"Managers/Big.gd": BIG_FILE}, {"files": {"Managers/Big.gd": BIG_LINES - 1}})
code, output = run_lint()
check("a file over its baseline fails", code == 1 and "ratchet ceiling" in output, output)
scene({"Managers/Big.gd": BIG_FILE}, {"files": {"Managers/Big.gd": BIG_LINES + 5}})
code, output = run_lint()
check("a file under its baseline asks for a tighter entry", code == 0 and "tighten" in output, output)

# 90 body lines is over the 80-line default ceiling, so the entries below are what is
# being measured, not the default.
LONG_FUNCTION = "extends RefCounted\n\n\nfunc f() -> void:\n" + "\n".join(
    "\tpass" for _ in range(90)
)
FUNCTION_SPAN = slop._function_bodies(LONG_FUNCTION.splitlines())[0]
FUNCTION_LENGTH = FUNCTION_SPAN[2] - FUNCTION_SPAN[1]
check("the fixture really is over the default ceiling", FUNCTION_LENGTH > 80, str(FUNCTION_LENGTH))
scene({"Managers/Long.gd": LONG_FUNCTION})
code, output = run_lint()
check("a function past the default ceiling fails", code == 1, output)
scene({"Managers/Long.gd": LONG_FUNCTION}, {"functions": {"Managers/Long.gd::f": FUNCTION_LENGTH}})
check("a recorded function passes at its own size", run_lint()[0] == 0)

BRANCHY = "extends RefCounted\n\n\nfunc f() -> void:\n" + "\n".join("\tif x:" for _ in range(12))
scene({"Managers/Branchy.gd": BRANCHY}, {"complexity": {"Managers/Branchy.gd::f": 13}})
check("branch score exactly on its baseline passes", run_lint()[0] == 0)
scene({"Managers/Branchy.gd": BRANCHY}, {"complexity": {"Managers/Branchy.gd::f": 12}})
code, output = run_lint()
check("branch score over its baseline fails", code == 1, output)

WALKER = "extends RefCounted\n\n\nfunc f() -> void:\n\tvar p = get_parent()\n"
scene({"Managers/Walker.gd": WALKER})
code, output = run_lint()
check("an upward tree walk fails by default", code == 1 and "get_parent" in output, output)
scene({"Managers/Walker.gd": WALKER}, {"get_parent": {"Managers/Walker.gd": 1}})
code, output = run_lint()
check("a recorded walk passes, so the ratchet only holds", code == 0, output)


# ------------------------------------------------------- end to end: staleness
scene({"Managers/Thing.gd": CLEAN_SCRIPT}, {"files": {"Managers/Gone.gd": 10}})
code, output = run_lint()
check("a stale baseline entry only warns", code == 0 and "Gone.gd" in output, output)
check("--strict makes a stale entry fatal", run_lint(strict=True)[0] == 1)

scene({"Managers/Thing.gd": CLEAN_SCRIPT}, {"functions": {"Managers/Thing.gd::vanished": 5}})
check("a stale function entry warns too", "vanished" in run_lint()[1])

scene({"Managers/Thing.gd": CLEAN_SCRIPT}, {"get_parent": {"Managers/Nowhere.gd": 2}})
check("a stale get_parent entry warns too", "Nowhere.gd" in run_lint()[1])


# -------------------------------------------------------- the repository itself
clear()
shutil.rmtree(WORK, ignore_errors=True)
check(
    "this repository passes its own gate",
    slop.lint(REPO_ROOT, strict=True) == 0,
    "run `python Tools/line_godot_slop.py --strict` for the detail",
)


# -------------------------------------------------------------------- summary
failures = [entry for entry in results if not entry[1]]
for name, ok, detail in results:
    if not ok:
        print(f"FAIL {name}" + (f"  -> {non_blank(detail)}" if detail else ""))
print(f"\n{len(results) - len(failures)}/{len(results)} checks passed")
raise SystemExit(1 if failures else 0)
