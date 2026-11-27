#!/usr/bin/env python3
"""Anti-slop lint gate for the first-party GDScript in this repository.

This is the "back pressure" layer for the patterns an LLM reaches for when it
takes the shortest path to a green screen: imperative timers, frame pumping,
upward tree walks and Node types leaking into the pure-logic core. It also
ratchets file and function size so a class can only shrink, never quietly grow
into a god object one PR at a time.

Why a hand-written checker instead of gdlint: the rules here are architectural
(where a type may live, which APIs are banned outright), not formatting. Keeping
them in one small, dependency-free script means CI and preflight run exactly the
same gate with no install step.

Usage:
    python Tools/line_godot_slop.py            # repo root inferred from this file
    python Tools/line_godot_slop.py --root .   # explicit root
    python Tools/line_godot_slop.py --strict   # warnings are fatal too

Exit codes: 0 clean, 1 violations (or warnings with --strict).
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

FUNC_START = re.compile(r"^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\s*\(")
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


def _function_lengths(lines: list[str]) -> dict[str, int]:
    lengths: dict[str, int] = {}
    index = 0
    while index < len(lines):
        match = FUNC_START.match(lines[index])
        if not match:
            index += 1
            continue
        end = index + 1
        while end < len(lines) and not TOP_LEVEL.match(lines[end]):
            end += 1
        lengths[match.group(1)] = end - index
        index = end
    return lengths


def _load_baseline(root: pathlib.Path) -> dict:
    path = root / BASELINE_RELATIVE
    if not path.is_file():
        raise SystemExit(f"ERROR: missing ratchet baseline: {BASELINE_RELATIVE}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: {BASELINE_RELATIVE} is not valid JSON: {exc}")
    data.setdefault("defaults", {})
    data.setdefault("files", {})
    data.setdefault("functions", {})
    return data


def lint(root: pathlib.Path, strict: bool) -> int:
    baseline = _load_baseline(root)
    defaults = baseline["defaults"]
    max_file_lines = int(defaults.get("max_file_lines", DEFAULT_MAX_FILE_LINES))
    max_function_lines = int(defaults.get("max_function_lines", DEFAULT_MAX_FUNCTION_LINES))
    file_baseline: dict[str, int] = baseline["files"]
    function_baseline: dict[str, int] = baseline["functions"]

    errors: list[str] = []
    warnings: list[str] = []
    seen_files: set[str] = set()
    seen_functions: set[str] = set()

    for path in _iter_scripts(root):
        rel = _rel(path, root)
        seen_files.add(rel)
        lines = path.read_text(encoding="utf-8").splitlines()

        for line_no, line in enumerate(lines, start=1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            for pattern, message in BANNED_PATTERNS:
                if not pattern.search(line):
                    continue
                if (
                    pattern.pattern.startswith("await")
                    and FRAME_PUMP_EXEMPT_PARTS.intersection(path.parts)
                ):
                    continue
                errors.append(f"{rel}:{line_no}: ERROR: {message}")

        if "Core" in path.parts and rel not in CORE_EXTENDS_EXCEPTIONS:
            for line_no, line in enumerate(lines, start=1):
                if CORE_EXTENDS_BANNED.match(line):
                    errors.append(
                        f"{rel}:{line_no}: ERROR: `Core/` must stay pure logic "
                        "(`RefCounted`/`Resource`) so it can be tested headlessly. "
                        "Move the Node into `Managers/` or `Scenes/`."
                    )

        allowed = int(file_baseline.get(rel, max_file_lines))
        if len(lines) > allowed:
            errors.append(
                f"{rel}: ERROR: {len(lines)} lines exceeds the ratchet ceiling of "
                f"{allowed}. Split the class instead of growing it."
            )
        elif rel in file_baseline and len(lines) < allowed:
            warnings.append(
                f"{rel}: WARNING: {len(lines)} lines is below the ratchet baseline "
                f"of {allowed}; tighten {BASELINE_RELATIVE}."
            )

        for name, length in _function_lengths(lines).items():
            key = f"{rel}::{name}"
            seen_functions.add(key)
            allowed = int(function_baseline.get(key, max_function_lines))
            if length > allowed:
                errors.append(
                    f"{rel}: ERROR: `{name}()` is {length} lines, over the ratchet "
                    f"ceiling of {allowed}. Extract a helper instead of extending it."
                )
            elif key in function_baseline and length < allowed:
                warnings.append(
                    f"{key}: WARNING: {length} lines is below the ratchet baseline "
                    f"of {allowed}; tighten {BASELINE_RELATIVE}."
                )

    for stale in sorted(set(file_baseline) - seen_files):
        warnings.append(
            f"{stale}: WARNING: baseline entry for a missing file; remove it from "
            f"{BASELINE_RELATIVE}."
        )
    for stale in sorted(set(function_baseline) - seen_functions):
        warnings.append(
            f"{stale}: WARNING: baseline entry for a missing function; remove it from "
            f"{BASELINE_RELATIVE}."
        )

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
