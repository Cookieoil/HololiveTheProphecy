#!/usr/bin/env python3
import pathlib
import re
import sys

RULES = [
    (
        re.compile(r"create_timer\s*\("),
        "Banned pattern `create_timer()`. Imperative timers cause race conditions and jank. "
        "Fix root cause using explicit signals, AnimationPlayer tracks, or deterministic delta counters."
    ),
    (
        re.compile(r"await\s+get_tree\(\)\.process_frame"),
        "Banned `await get_tree().process_frame` hack. Fix initialization order explicitly via `_ready()`, "
        "dependency injection, or signal readiness instead of waiting arbitrary frames."
    ),
    (
        re.compile(r'get_node\s*\(\s*["\']\.\.'),
        "Banned relative parent lookup `get_node(\"..\")`. Scenes must not reach upward into parent trees. "
        "Emit a typed `signal` upward or pass a reference downward via `@export`."
    ),
]

CORE_BANNED = re.compile(r"\b(Node|Node2D|Node3D|Control|SceneTree)\b")

errors = []
for path in pathlib.Path(".").rglob("*.gd"):
    if "addons" in path.parts or ".godot" in path.parts:
        continue
    lines = path.read_text(encoding="utf-8").splitlines()
    is_core = "core" in path.parts

    for line_no, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        for pattern, message in RULES:
            if pattern.search(line):
                errors.append(f"{path}:{line_no}: ERROR: {message}")
        if is_core and CORE_BANNED.search(line):
            errors.append(
                f"{path}:{line_no}: ERROR: `res://core/` must remain pure logic (`RefCounted`/`Resource`) "
                "with zero `Node` or `SceneTree` dependencies so it can be unit-tested headlessly."
            )

if errors:
    print("\n".join(errors))
    sys.exit(1)

print("Lint checks passed.")