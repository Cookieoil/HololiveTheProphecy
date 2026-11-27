#!/usr/bin/env python3
"""Anti-slop lint gate for the first-party GDScript in this repository.

This is the "back pressure" layer for the patterns an LLM reaches for when it
takes the shortest path to a green screen: imperative timers, frame pumping,
upward tree walks and Node types leaking into the pure-logic core. It also
ratchets file size, function size, function branching and `get_parent()` use
against Tools/slop_baseline.json, so a class can only shrink and a function can
only get flatter, never quietly grow into a god object one PR at a time.

Why a hand-written checker instead of gdlint: the rules here are architectural
(where a type may live, which APIs are banned outright), not formatting. Keeping
them in one small, dependency-free script means CI and preflight run exactly the
same gate with no install step.

Usage:
    python Tools/line_godot_slop.py            # repo root inferred from this file
    python Tools/line_godot_slop.py --root .   # explicit root
    python Tools/line_godot_slop.py --strict   # warnings are fatal too

Exit codes: 0 clean, 1 violations (or warnings with --strict).

Run it with --strict in CI: a stale ratchet entry is otherwise only a warning,
which leaves slack for the next PR to fill back in.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

# Generated output, third-party code and scratch space are never linted.
EXCLUDED_PARTS = {"addons", ".godot", "Trash", "bin", "reports", "__pycache__"}

# Tests legitimately need real frames to let containers lay out, so the frame
# pump ban applies to shipped code only. Timers are still banned everywhere.
FRAME_PUMP_EXEMPT_PARTS = {"GDTest"}

# Banned outright in every first-party script (except where noted).
BANNED_PATTERNS = [
    (
        re.compile(r"create_timer\s*\("),
        "banned `create_timer()`. Imperative timers race scene teardown and ignore "
        "Engine.time_scale. Use a Timer node, an AnimationPlayer track or a "
        "deterministic delta counter instead.",
    ),
    (
        re.compile(r"await\s+get_tree\(\)\.process_frame"),
        "banned `await get_tree().process_frame` frame pump. Fix initialization order "
        "explicitly via `_ready()`, dependency injection or signal readiness instead "
        "of waiting an arbitrary number of frames. (Tests are exempt.)",
    ),
    (
        re.compile(r"""get_node\s*\(\s*["']\.\."""),
        "banned relative parent lookup `get_node(\"..\")`. Scenes must not reach "
        "upward into parent trees. Emit a typed signal upward or pass a reference "
        "downward via `@export`.",
    ),
]

# Core/ is the pure-logic layer: RefCounted/Resource only, so it can be unit
# tested headlessly. The abstract UI contract is the single documented exception.
CORE_EXTENDS_BANNED = re.compile(
    r"^extends\s+(Node|Node2D|Node3D|Control|SceneTree|CanvasItem)\b"
)
CORE_EXTENDS_EXCEPTIONS = {
    "Core/GameUI.gd": "abstract UI contract that BattleScene implements",
}

BASELINE_RELATIVE = "Tools/slop_baseline.json"
DEFAULT_MAX_FILE_LINES = 900
DEFAULT_MAX_FUNCTION_LINES = 80
## Branching score of a function: 1 + one point per `if` / `elif` / `for` / `while` /
## `match` statement in its body. Line length alone cannot see nested spaghetti, and
## the complexity number is the one Slop Code Bench-style benches actually measure.
DEFAULT_MAX_COMPLEXITY = 12
## `get_parent()` walks upward into a tree the node does not own, so a file may only
## keep the calls it already had (the ratchet records them, nothing may be added).
DEFAULT_MAX_GET_PARENT = 0

FUNC_START = re.compile(r"^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\s*\(")
BRANCH_STATEMENT = re.compile(r"^(?:if|elif|for|while|match)\b")
GET_PARENT_CALL = re.compile(r"\bget_parent\s*\(")
# A function ends at the next top-level declaration. `##` starts a doc comment
# block that belongs to the next declaration, not to the function above it.
TOP_LEVEL = re.compile(
    r"^(?:func |static func |#region|#endregion|class_name|extends|@|const |var |enum |signal |##)"
)


def _iter_scripts(root: pathlib.Path):
    for path in sorted(root.rglob("*.gd")):
        if EXCLUDED_PARTS.intersection(path.parts):
            continue
        yield path


def _rel(path: pathlib.Path, root: pathlib.Path) -> str:
    return path.relative_to(root).as_posix()


def _function_bodies(lines: list[str]) -> list[tuple[str, int, int]]:
    """`(name, start_index, end_index)` for every top-level function."""
    spans: list[tuple[str, int, int]] = []
    index = 0
    while index < len(lines):
        match = FUNC_START.match(lines[index])
        if not match:
            index += 1
            continue
        end = index + 1
        while end < len(lines) and not TOP_LEVEL.match(lines[end]):
            end += 1
        spans.append((match.group(1), index, end))
        index = end
    return spans


def _complexity(lines: list[str], start: int, end: int) -> int:
    """1 + the decision points in one function body.

    `and` / `or` are deliberately not counted: they are cheap, and counting them
    makes the number noisy without catching the nesting that actually hurts.
    """
    score = 1
    for line in lines[start:end]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if BRANCH_STATEMENT.match(stripped):
            score += 1
    return score


def _count_get_parent(lines: list[str]) -> int:
    """Upward tree walks in this file, ignoring comments and quoted text."""
    total = 0
    for line in lines:
        if line.strip().startswith("#"):
            continue
        for match in GET_PARENT_CALL.finditer(line):
            if not _inside_string(line, match.start()):
                total += 1
    return total


def _load_baseline(root: pathlib.Path) -> dict:
    path = root / BASELINE_RELATIVE
    if not path.is_file():
        raise SystemExit(f"ERROR: missing ratchet baseline: {BASELINE_RELATIVE}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: {BASELINE_RELATIVE} is not valid JSON: {exc}")
    for section in ("defaults", "files", "functions", "complexity", "get_parent"):
        data.setdefault(section, {})
    return data


def _inside_string(line: str, index: int) -> bool:
    """True when `index` sits inside a quoted literal.

    A banned pattern that only appears as *data* (the reviewer's own rule list, a
    test fixture that feeds the parser a diff) is not a call, so it must not fail
    the gate; the rule is about API usage, not about the text.
    """
    quote = ""
    escaped = False
    for char in line[:index]:
        if escaped:
            escaped = False
        elif char == "\\":
            escaped = True
        elif quote:
            if char == quote:
                quote = ""
        elif char in "\"'":
            quote = char
    return bool(quote)


def _banned_matches(line: str) -> list[str]:
    """Messages for every banned pattern used as code (not quoted) on this line."""
    messages: list[str] = []
    for pattern, message in BANNED_PATTERNS:
        for match in pattern.finditer(line):
            if not _inside_string(line, match.start()):
                messages.append(message)
                break
    return messages


def _check_ratchet(
    where: str,
    measured: int,
    allowed: int,
    tracked: bool,
    hint: str,
    errors: list[str],
    warnings: list[str],
) -> None:
    """Fails above a ceiling; warns below it, so the ceiling gets tightened."""
    if measured > allowed:
        errors.append(
            f"{where}: ERROR: {measured} is over the ratchet ceiling of {allowed}. {hint}"
        )
    elif tracked and measured < allowed:
        warnings.append(
            f"{where}: WARNING: {measured} is below the ratchet baseline of "
            f"{allowed}; tighten {BASELINE_RELATIVE}."
        )


def _check_banned_lines(rel: str, path: pathlib.Path, lines: list[str], errors: list[str]) -> None:
    for line_no, line in enumerate(lines, start=1):
        if line.strip().startswith("#"):
            continue
        for message in _banned_matches(line):
            if "process_frame" in message and FRAME_PUMP_EXEMPT_PARTS.intersection(path.parts):
                continue
            errors.append(f"{rel}:{line_no}: ERROR: {message}")


def _check_core_purity(rel: str, path: pathlib.Path, lines: list[str], errors: list[str]) -> None:
    if "Core" not in path.parts or rel in CORE_EXTENDS_EXCEPTIONS:
        return
    for line_no, line in enumerate(lines, start=1):
        if CORE_EXTENDS_BANNED.match(line):
            errors.append(
                f"{rel}:{line_no}: ERROR: `Core/` must stay pure logic "
                "(`RefCounted`/`Resource`) so it can be tested headlessly. "
                "Move the Node into `Managers/` or `Scenes/`."
            )


def _warn_stale(tracked: set[str], seen: set[str], what: str, warnings: list[str]) -> None:
    for stale in sorted(tracked - seen):
        warnings.append(
            f"{stale}: WARNING: baseline entry for a missing {what}; remove it from "
            f"{BASELINE_RELATIVE}."
        )


def lint(root: pathlib.Path, strict: bool) -> int:
    baseline = _load_baseline(root)
    defaults = baseline["defaults"]
    max_file_lines = int(defaults.get("max_file_lines", DEFAULT_MAX_FILE_LINES))
    max_function_lines = int(defaults.get("max_function_lines", DEFAULT_MAX_FUNCTION_LINES))
    max_complexity = int(defaults.get("max_complexity", DEFAULT_MAX_COMPLEXITY))
    file_baseline: dict = baseline["files"]
    function_baseline: dict = baseline["functions"]
    complexity_baseline: dict = baseline["complexity"]
    get_parent_baseline: dict = baseline["get_parent"]

    errors: list[str] = []
    warnings: list[str] = []
    seen_files: set[str] = set()
    seen_functions: set[str] = set()
    seen_get_parent: set[str] = set()

    for path in _iter_scripts(root):
        rel = _rel(path, root)
        seen_files.add(rel)
        lines = path.read_text(encoding="utf-8").splitlines()

        _check_banned_lines(rel, path, lines, errors)
        _check_core_purity(rel, path, lines, errors)
        _check_ratchet(
            rel,
            len(lines),
            int(file_baseline.get(rel, max_file_lines)),
            rel in file_baseline,
            "Split the class instead of growing it.",
            errors,
            warnings,
        )

        for name, start, end in _function_bodies(lines):
            key = f"{rel}::{name}"
            seen_functions.add(key)
            _check_ratchet(
                f"`{key}()`",
                end - start,
                int(function_baseline.get(key, max_function_lines)),
                key in function_baseline,
                "Extract a helper instead of extending it.",
                errors,
                warnings,
            )
            _check_ratchet(
                f"`{key}()` branch score",
                _complexity(lines, start, end),
                int(complexity_baseline.get(key, max_complexity)),
                key in complexity_baseline,
                "Flatten the branches or extract a helper.",
                errors,
                warnings,
            )

        seen_get_parent.add(rel)
        _check_ratchet(
            f"`{rel}` get_parent() calls",
            _count_get_parent(lines),
            int(get_parent_baseline.get(rel, DEFAULT_MAX_GET_PARENT)),
            rel in get_parent_baseline,
            "A child must not walk up into a tree it does not own: emit a signal instead.",
            errors,
            warnings,
        )

    _warn_stale(set(file_baseline), seen_files, "file", warnings)
    _warn_stale(set(function_baseline), seen_functions, "function", warnings)
    _warn_stale(set(complexity_baseline), seen_functions, "function", warnings)
    _warn_stale(set(get_parent_baseline), seen_get_parent, "file", warnings)

    for message in warnings:
        print(message)
    if errors:
        print("\n".join(errors))
        print(f"\nAnti-slop lint failed: {len(errors)} error(s), {len(warnings)} warning(s).")
        return 1
    if warnings and strict:
        print(f"\nAnti-slop lint failed: {len(warnings)} warning(s) under --strict.")
        return 1

    print(f"Anti-slop lint passed ({len(warnings)} warning(s)).")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parent.parent,
        help="Repository root (defaults to the parent of Tools/).",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as failures (stale ratchet baselines).",
    )
    args = parser.parse_args()
    return lint(args.root.resolve(), args.strict)


if __name__ == "__main__":
    sys.exit(main())
