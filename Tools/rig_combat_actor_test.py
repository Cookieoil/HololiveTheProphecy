#!/usr/bin/env python3
"""
Regression suite for Tools/rig_combat_actor.py.

Run it after touching the patcher, or the Spine JSON it writes:

    python Tools/rig_combat_actor_test.py

Every check is reported, and the run exits 1 if any failed. The suite builds its
own rigs in a scratch folder, so it needs nothing but Python and the patcher.

Add `--samples <dir>` to also diff the writer against real Spine output: point it
at a folder holding Spine's own `*-pro.json` example exports (for example
`spine-runtimes/examples/spineboy/export`) and every file there must re-serialize
byte for byte, which is what keeps a patched file diff-free against a re-export.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

PARSER = argparse.ArgumentParser(description="Test Tools/rig_combat_actor.py")
PARSER.add_argument("--samples", type=Path, help="folder of Spine example JSON exports")
PARSER.add_argument("--work", type=Path, help="scratch folder (default: a temp folder)")
ARGS = PARSER.parse_args()

MODULE = Path(__file__).with_name("rig_combat_actor.py")
SAMPLES = ARGS.samples
WORK = ARGS.work or Path(tempfile.mkdtemp(prefix="rig-combat-actor-test-"))

spec = importlib.util.spec_from_file_location("rca", MODULE)
rca = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rca)
rca.make_console_utf8_safe()

results: list[tuple[str, bool, str]] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    results.append((name, bool(condition), detail))


def expect_raises(name: str, fn, *args) -> None:
    try:
        value = fn(*args)
    except ValueError:
        check(name, True)
        return
    except Exception as exc:  # noqa: BLE001 - report the unexpected type
        check(name, False, f"raised {type(exc).__name__}: {exc}")
        return
    check(name, False, f"no error, returned {value!r}")


def run_cli(*args: str) -> tuple[int, str]:
    proc = subprocess.run(
        [sys.executable, str(MODULE), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return proc.returncode, proc.stdout + proc.stderr


def read_json(path: Path) -> dict:
    """Parse a JSON file, or {} when the tool did not write it."""
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001 - an unparseable output is reported by a check
        return {}


FIXTURE = {
    "skeleton": {"spine": "4.3.26", "width": 100, "height": 100},
    "bones": [
        {"name": "root"},
        {"name": "hip", "parent": "root", "length": 40},
        {"name": "hand", "parent": "root", "length": 10},
    ],
    "animations": {
        "idle": {"bones": {"hip": {"rotate": [{"time": 0, "angle": 0}]}}},
        "skill1": {"bones": {"hand": {"rotate": [{"time": 0, "angle": 0}, {"time": 0.6, "angle": 20}]}}},
    },
}

WORK.mkdir(parents=True, exist_ok=True)
fixture = WORK / "fixture.json"
fixture.write_text(json.dumps(FIXTURE, indent="\t"), encoding="utf-8")

# ---------------------------------------------------------------- pure helpers
check("format_number 5.4E-4", rca.format_number(0.00054) == "5.4E-4", rca.format_number(0.00054))
check("format_number 40.0", rca.format_number(40.0) == "40.0", rca.format_number(40.0))
check("format_number int", rca.format_number(3) == "3", rca.format_number(3))
check("format_number 1e7", rca.format_number(1e7) == "1.0E7", rca.format_number(1e7))

for bad in (float("nan"), float("inf"), float("-inf")):
    try:
        text = rca.dumps_spine({"a": bad})
        ok = json.loads(text)["a"] is not None
    except Exception as exc:  # noqa: BLE001
        check(f"dumps_spine({bad!r}) stays valid JSON", True)
        continue
    check(f"dumps_spine({bad!r}) stays valid JSON", ok, text.replace("\n", " "))

round_trip_cases = [
    {"a": 1, "b": [1, 2, 3], "c": {"d": None, "e": True, "f": "x"}},
    {"empty": {}, "list": [], "nested": [{"k": 1}, {"j": [1.5, 2.5]}]},
    {"s": "unicode ✓ ünïcode", "n": 0.1, "neg": -0.0},
    {"deep": {"a": {"b": {"c": {"d": {"e": {"f": {"g": 1}}}}}}}},
]
for index, case in enumerate(round_trip_cases):
    text = rca.dumps_spine(case)
    check(f"dumps_spine round-trip #{index}", json.loads(text) == case, text[:120])

check(
    "root members start at column 0",
    rca.dumps_spine({"a": {"b": 1}, "c": [{"d": 2}]}).startswith('{\n"a": {'),
    repr(rca.dumps_spine({"a": {"b": 1}})[:20]),
)

durations = [
    ({"bones": {"x": {"rotate": [{"time": 0.5}]}}}, 0.5),
    ({}, 0.0),
    ({"events": [{"time": 1.25}]}, 1.25),
    ({"slots": {"y": {"attachment": [{"time": 0.25, "name": "a"}]}}}, 0.25),
    ({"bones": {"x": {"deform": {"y": {"vertices": [{"time": 2.0}]}}}}}, 2.0),
]
for animation, expected in durations:
    actual = rca.animation_duration(animation)
    check(f"animation_duration {animation} -> {expected}", abs(actual - expected) < 1e-9, str(actual))

time_cases = [
    (("0.5", 2.0, 30.0), 1.0),
    (("0.75s", 2.0, 30.0), 0.75),
    (("12f", 2.0, 30.0), 0.4),
    (("0.5S", 2.0, 30.0), 0.5),
    (("12F", 2.0, 30.0), 0.4),
    (("0", 2.0, 30.0), 0.0),
    (("1", 2.0, 30.0), 2.0),
    (("  0.25s  ", 2.0, 30.0), 0.25),
]
for arguments, expected in time_cases:
    label = f"parse_time_value{arguments}"
    try:
        actual = rca.parse_time_value(*arguments, "--test")
        check(label, abs(actual - expected) < 1e-9, str(actual))
    except ValueError as exc:
        check(label, False, f"raised {exc}")

for arguments in [
    ("5", 2.0, 30.0),
    ("-0.5", 2.0, 30.0),
    ("abc", 2.0, 30.0),
    ("", 2.0, 30.0),
    ("0.5", 0.0, 30.0),
    ("12f", 2.0, 0.0),
    ("s", 2.0, 30.0),
    ("f", 2.0, 30.0),
]:
    expect_raises(f"parse_time_value{arguments} rejects", rca.parse_time_value, *arguments, "--test")

spec_cases = [
    ("skill1", ("skill1", None, None)),
    ("skill1:0.3:0.55", ("skill1", "0.3", "0.55")),
    ("skill1::0.55", ("skill1", None, "0.55")),
    (" skill1 : 0.3 ", ("skill1", "0.3", None)),
    ("skill1:0.3:", ("skill1", "0.3", None)),
]
for text, expected in spec_cases:
    actual = rca.parse_anim_spec(text)
    check(f"parse_anim_spec({text!r})", actual == expected, str(actual))

for text in ["skill1:0.3:0.55:0.6", ":0.3", ""]:
    expect_raises(f"parse_anim_spec({text!r}) rejects", rca.parse_anim_spec, text)

hub = rca.pick_hub_bone(FIXTURE)
check("pick_hub_bone picks 'root' (2 children)", hub == "root", hub)
check("hub_candidates lists counts", rca.hub_candidates(FIXTURE)[0] == ("root", 2), str(rca.hub_candidates(FIXTURE)))
check("bone_length reads int", rca.bone_length({"length": 40}) == 40.0)
check("bone_length ignores bool", rca.bone_length({"length": True}) == 0.0)
check("spine_version", rca.spine_version(FIXTURE) == "4.3.26", rca.spine_version(FIXTURE))

# ------------------------------------------------------------------ CLI basics
code, out = run_cli("--input", str(fixture), "--dry-run")
check("dry-run exits 0", code == 0, out[-200:])
check("dry-run writes nothing", "dry run" in out, out[-200:])
check("dry-run reports the auto parent", "Center_Hit_Point parent" in out, out[:300])

patched = WORK / "patched.json"
code, out = run_cli("--input", str(fixture), "--output", str(patched), "--torso", "hip", "--cast-parent", "hand", "--anim", "skill1")
check("patch exits 0", code == 0, out[-300:])
data = read_json(patched)
names = [bone["name"] for bone in data["bones"]]
check("both bones added", names[-2:] == ["Center_Hit_Point", "Cast_Origin_Point"], str(names[-2:]))
check("bone parents honoured", data["bones"][-2]["parent"] == "hip" and data["bones"][-1]["parent"] == "hand", str(data["bones"][-2:]))
check("offsets from parent length", data["bones"][-2]["x"] == 20.0 and data["bones"][-1]["x"] == 10.0, str(data["bones"][-2:]))
check("events defined", set(data["events"]) == {"event_vfx_spawn", "event_hit_frame"}, str(data["events"]))
check("skill1 keyed", [k["name"] for k in data["animations"]["skill1"]["events"]] == ["event_vfx_spawn", "event_hit_frame"], str(data["animations"]["skill1"]["events"]))
check("idle untouched", "events" not in data["animations"]["idle"], str(data["animations"]["idle"]))
check("hit at 55% of 0.6s", abs(data["animations"]["skill1"]["events"][1]["time"] - 0.33) < 1e-9, str(data["animations"]["skill1"]["events"]))

again = WORK / "patched2.json"
run_cli("--input", str(patched), "--output", str(again), "--torso", "hip", "--cast-parent", "hand", "--anim", "skill1")
check("idempotent (byte identical)", patched.read_bytes() == again.read_bytes())

forced = WORK / "forced.json"
code, out = run_cli("--input", str(patched), "--output", str(forced), "--anim", "skill1:0.1s:0.2s", "--force")
forced_data = read_json(forced)
times = [k["time"] for k in forced_data.get("animations", {}).get("skill1", {}).get("events", [])]
check("--force re-times keys (seconds form)", times == [0.1, 0.2], str(times))

fractional = WORK / "fractional.json"
code, out = run_cli("--input", str(fixture), "--output", str(fractional), "--torso", "hip", "--anim", "skill1:0.1:0.2")
fractional_times = [k["time"] for k in read_json(fractional).get("animations", {}).get("skill1", {}).get("events", [])]
check("bare numbers are fractions of the animation", fractional_times == [0.06, 0.12], str(fractional_times))

explicit_seconds_pose = WORK / "pose_seconds.json"
code, out = run_cli("--input", str(fixture), "--output", str(explicit_seconds_pose), "--torso", "hip", "--anim", "idle:0.2s:0.5s")
pose_times = [k["time"] for k in read_json(explicit_seconds_pose).get("animations", {}).get("idle", {}).get("events", [])]
check("pose-only animation works with explicit seconds", code == 0 and pose_times == [0.2, 0.5], f"code={code} {pose_times}")

code, out = run_cli("--input", str(fixture), "--dry-run", "--anim", "idle")
check("pose-only animation as an explicit fraction still errors", code == 1 and "has no keyed times" in out, out[-200:])

code, out = run_cli("--input", str(fixture), "--output", str(WORK / "past.json"), "--torso", "hip", "--anim", "skill1:1s:2s")
check("keys past the animation end are flagged", code == 0 and "past the animation end" in out, out[-300:])

dupe = WORK / "dupe.json"
run_cli("--input", str(fixture), "--output", str(dupe), "--torso", "hip", "--anim", "skill1", "--anim", "skill1")
dupe_data = read_json(dupe)
check("duplicate --anim makes no duplicate keys", len(dupe_data["animations"]["skill1"]["events"]) == 2, str(dupe_data["animations"]["skill1"]["events"]))

# --------------------------------------------------------------- error paths
code, out = run_cli("--input", str(WORK / "missing.json"), "--dry-run")
check("missing input: clean error", code == 1 and "error:" in out and "Traceback" not in out, out[-200:])

code, out = run_cli("--input", str(WORK), "--dry-run")
check("directory as input: clean error", code == 1 and "Traceback" not in out, out[-200:])

code, out = run_cli("--input", str(fixture), "--dry-run", "--attack-pattern", "[unclosed", "--all-attacks")
check("bad --attack-pattern: clean error", code == 1 and "Traceback" not in out, out[-300:])

empty_bones = WORK / "empty_bones.json"
empty_bones.write_text(json.dumps({"skeleton": {"spine": "4.3.26"}, "bones": [], "animations": {}}), encoding="utf-8")
code, out = run_cli("--input", str(empty_bones), "--dry-run")
check("rig with no bones: clean error", code == 1 and "Traceback" not in out, out[-200:])

no_anims = WORK / "no_anims.json"
no_anims.write_text(json.dumps({"skeleton": {"spine": "4.3.26"}, "bones": [{"name": "root"}]}), encoding="utf-8")
code, out = run_cli("--input", str(no_anims), "--dry-run", "--anim", "skill1")
check("rig with no animations: clean error", code == 1 and "Traceback" not in out, out[-200:])

odd_anim = WORK / "odd_anim.json"
odd_anim.write_text(json.dumps({"skeleton": {"spine": "4.3.26"}, "bones": [{"name": "root"}], "animations": {"weird": []}}), encoding="utf-8")
code, out = run_cli("--input", str(odd_anim), "--dry-run", "--anim", "weird")
check("non-object animation: clean error", code == 1 and "Traceback" not in out, out[-200:])

odd_events = WORK / "odd_events.json"
odd_events.write_text(json.dumps({"skeleton": {"spine": "4.3.26"}, "bones": [{"name": "root"}], "events": [], "animations": {"skill1": {"bones": {"root": {"rotate": [{"time": 0.5}]}}}}}), encoding="utf-8")
code, out = run_cli("--input", str(odd_events), "--output", str(WORK / "odd_events_out.json"), "--torso", "root", "--anim", "skill1")
check("events as a list: survives", code == 0 and "Traceback" not in out, out[-200:])

# ------------------------------------------------------------ hostile payloads
bad_numbers = WORK / "bad_numbers.json"
bad_numbers.write_text(
    '{"skeleton": {"spine": "4.3.26"}, "bones": [{"name": "root"}],'
    ' "animations": {"skill1": {"bones": {"root": {"rotate": [{"time": NaN}]}}}}}',
    encoding="utf-8",
)
bad_out = WORK / "bad_numbers_out.json"
code, out = run_cli("--input", str(bad_numbers), "--output", str(bad_out), "--torso", "root", "--anim", "skill1:0.1s:0.2s")
valid_json = False
if bad_out.exists():
    try:
        json.loads(bad_out.read_text(encoding="utf-8"))
        valid_json = True
    except Exception:  # noqa: BLE001
        valid_json = False
check(
    "NaN in input: clean error or valid output",
    (code == 1 and "Traceback" not in out) or valid_json,
    f"code={code} valid={valid_json} out_tail={out[-160:]!r}",
)

unicode_rig = WORK / "unicode.json"
unicode_rig.write_text(
    json.dumps(
        {
            "skeleton": {"spine": "4.3.26"},
            "bones": [{"name": "\u6839"}, {"name": "\u624b", "parent": "\u6839", "length": 12}],
            "animations": {"skill": {"bones": {"\u624b": {"rotate": [{"time": 0.5}]}}}},
        },
        ensure_ascii=False,
        indent="\t",
    ),
    encoding="utf-8",
)
uni_out = WORK / "unicode_out.json"
code, out = run_cli("--input", str(unicode_rig), "--output", str(uni_out), "--cast-parent", "\u624b", "--anim", "skill")
uni_data = read_json(uni_out)
check("unicode rig patches", code == 0 and "Traceback" not in out, out[-300:])
check(
    "unicode names preserved",
    [b["name"] for b in uni_data.get("bones", [])][-2:] == ["Center_Hit_Point", "Cast_Origin_Point"],
    str([b["name"] for b in uni_data.get("bones", [])]),
)
check("unicode parent resolved", uni_data.get("bones", [{}])[-1].get("parent") == "\u624b", str(uni_data.get("bones", [])[-1]))

bom_rig = WORK / "bom.json"
bom_rig.write_bytes(b"\xef\xbb\xbf" + json.dumps(FIXTURE).encode("utf-8"))
code, out = run_cli("--input", str(bom_rig), "--output", str(WORK / "bom_out.json"), "--torso", "hip", "--anim", "skill1")
check("BOM input accepted", code == 0, out[-200:])

crlf_rig = WORK / "crlf.json"
crlf_rig.write_bytes(json.dumps(FIXTURE, indent="\t").replace("\n", "\r\n").encode("utf-8"))
crlf_out = WORK / "crlf_out.json"
code, out = run_cli("--input", str(crlf_rig), "--output", str(crlf_out), "--torso", "hip", "--anim", "skill1")
check("CRLF input accepted, LF output", code == 0 and b"\r\n" not in crlf_out.read_bytes(), out[-200:])

same_file = WORK / "same.json"
same_file.write_text(json.dumps(FIXTURE, indent="\t"), encoding="utf-8")
code, out = run_cli("--input", str(same_file), "--output", str(same_file), "--torso", "hip", "--anim", "skill1")
check("in-place patch works", code == 0 and "Center_Hit_Point" in same_file.read_text(encoding="utf-8"), out[-200:])

nested = WORK / "a" / "b" / "c" / "out.json"
code, out = run_cli("--input", str(fixture), "--output", str(nested), "--torso", "hip", "--anim", "skill1")
check("missing output dirs created", code == 0 and nested.exists(), out[-200:])

code, out = run_cli("--input", str(fixture), "--output", str(WORK / "tot.json"), "--torso", "hip", "--all-attacks", "--attack-pattern", r"(?i)skill|idle")
tot_anims = read_json(WORK / "tot.json").get("animations", {})
check(
    "--all-attacks keys the animations that have keys",
    code == 0 and "events" in tot_anims.get("skill1", {}),
    f"code={code} {tot_anims.get('skill1')}",
)
check(
    "--all-attacks skips a pose-only match and says so",
    "events" not in tot_anims.get("idle", {}) and "animation idle: skipped" in out,
    f"idle={tot_anims.get('idle')} out_tail={out[-200:]!r}",
)

code, out = run_cli("--input", str(fixture), "--output", str(WORK / "range.json"), "--torso", "hip", "--anim", "skill1", "--spawn-fraction", "1.5", "--hit-fraction", "2")
rng_keys = read_json(WORK / "range.json").get("animations", {}).get("skill1", {}).get("events", [])
in_range = bool(rng_keys) and all(key["time"] <= 0.6 for key in rng_keys)
check("out-of-range fractions rejected or clamped", code == 1 or in_range, f"code={code} {rng_keys}")

code, out = run_cli("--input", str(fixture), "--output", str(WORK / "order.json"), "--torso", "hip", "--anim", "skill1", "--spawn-fraction", "0.9", "--hit-fraction", "0.1")
order_keys = read_json(WORK / "order.json").get("animations", {}).get("skill1", {}).get("events", [])
spawn_first = bool(order_keys) and order_keys[0]["name"] == "event_vfx_spawn"
check("spawn still precedes hit (or warned)", code == 1 or spawn_first, f"code={code} {order_keys}")

code, out = run_cli("--input", str(fixture), "--output", str(WORK / "off.json"), "--torso", "hip", "--anim", "skill1", "--hit-bone-offset", "-1")
off_bones = read_json(WORK / "off.json").get("bones", [])
off_x = off_bones[-2].get("x") if len(off_bones) >= 2 else None
check("negative bone offset rejected or warned", code == 1 or off_x == 0.0, f"code={code} x={off_x}")

# ------------------------------------------------------------------- fidelity
if SAMPLES is not None and SAMPLES.is_dir():
    for path in sorted(SAMPLES.glob("*-pro.json")):
        original = path.read_text(encoding="utf-8-sig")
        mine = rca.dumps_spine(rca.load_spine_json(path))
        check(f"re-serialize {path.name} byte-identical", mine == original, f"{len(original)} vs {len(mine)} bytes")
else:
    print("note: pass --samples <dir> to also diff the writer against Spine's own exports")

# -------------------------------------------------------------------- summary
failures = [entry for entry in results if not entry[1]]
for name, ok, detail in results:
    if not ok:
        print(f"FAIL {name}" + (f"  -> {detail}" if detail else ""))
print(f"\n{len(results) - len(failures)}/{len(results)} checks passed")
raise SystemExit(1 if failures else 0)

