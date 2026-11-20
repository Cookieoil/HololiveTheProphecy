# Tools/rig_combat_actor.py
#!/usr/bin/env python3
"""
Give a Spine JSON export the combat rig the game expects (task I-1) without
touching the Spine editor UI.

The script reads a Spine JSON export and writes a patched copy that:

  * adds the bones ``Center_Hit_Point`` and ``Cast_Origin_Point``,
  * adds the events ``event_vfx_spawn`` and ``event_hit_frame``,
  * keys those two events into the attack animations you name.

Spine turns that JSON into an editable project:

  & 'C:\\Program Files\\Spine\\Spine.com' -i rig_combat.json -o rig.spine --to rig -r

Open `rig.spine`, place the two bones exactly where you want them and re-time the
event keys, then export for Godot with `Tools/export_spine_to_godot.ps1`.

Every edit is idempotent: an existing bone, event definition or event key is left
alone, so the script is safe to re-run after an artist has adjusted the rig.
Pass `--force` to re-time keys the script previously wrote.

Examples:
  python Tools/rig_combat_actor.py --input rig.json --dry-run
  python Tools/rig_combat_actor.py --input rig.json --output out.json --all-attacks
  python Tools/rig_combat_actor.py --input rig.json --output out.json --anim skill1:0.3:0.55 --anim unique:0.75s:12f
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# Must match the spine-godot runtime in bin/. Tools/check_spine_runtime.gd asserts
# that every committed rig was exported from this Spine version.
SPINE_RUNTIME_MAJOR_MINOR = "4.3"

# The I-1 combat-rig contract.
HIT_BONE = "Center_Hit_Point"
CAST_BONE = "Cast_Origin_Point"
SPAWN_EVENT = "event_vfx_spawn"
HIT_EVENT = "event_hit_frame"

# Nonessential data (colour + icon) so the two new bones are obvious in the editor.
HIT_BONE_STYLE = {"color": "ff2d2dff", "icon": "circle"}
CAST_BONE_STYLE = {"color": "2d9bffff", "icon": "particles"}

# Where the new bones sit along their parent bone, as a fraction of its length.
HIT_BONE_OFFSET = 0.5
CAST_BONE_OFFSET = 1.0

# Default event timing, as a fraction of the animation's duration.
DEFAULT_SPAWN_FRACTION = 0.30
DEFAULT_HIT_FRACTION = 0.55
DEFAULT_FPS = 30.0
DEFAULT_ATTACK_PATTERN = r"(?:^|[_\W])(?:skill|unique|ult|attack)"

# Spine keeps an object on one line only while every value in it is a scalar and it
# has at most this many members; anything else wraps. Both numbers were measured by
# re-serializing Spine's own 4.3 example exports and diffing: 6 and a generous width
# reproduce those files byte for byte, while a smaller width wraps objects Spine
# keeps inline. The width is a safety valve, not the real rule.
MAX_INLINE_WIDTH = 1000
MAX_INLINE_MEMBERS = 6


def format_number(value: object) -> str:
    """
    Format a number the way Spine writes it.

    Spine is a Java application, so its JSON writer uses `Double.toString`: the
    shortest round-tripping digits, but scientific notation with an upper-case `E`
    and a digit after the point (``1.0E-5``, ``5.4E-4``) outside the range
    ``1E-3`` .. ``1E7``. Plain decimals always keep a fractional digit
    (``40.0``). Python's `repr` supplies the digits; only the layout differs.
    """
    if isinstance(value, int):
        return str(value)

    text = repr(float(value))
    sign = ""
    if text.startswith("-"):
        sign, text = "-", text[1:]
    mantissa, marker, exponent = text.partition("e")
    whole, _, fraction = mantissa.partition(".")
    raw = whole + fraction
    power = (int(exponent) if marker else 0) - len(fraction)

    trimmed = raw.rstrip("0")
    power += len(raw) - len(trimmed)
    digits = trimmed.lstrip("0")
    if not digits:
        return f"{sign}0.0"

    magnitude = power + len(digits) - 1
    if -3 <= magnitude < 7:
        if magnitude >= 0:
            whole_part = digits[: magnitude + 1].ljust(magnitude + 1, "0")
            fraction_part = digits[magnitude + 1 :]
        else:
            whole_part = "0"
            fraction_part = "0" * (-magnitude - 1) + digits
        return f"{sign}{whole_part}.{fraction_part or '0'}"

    return f"{sign}{digits[0]}.{digits[1:] or '0'}E{magnitude}"


def is_scalar(value: object) -> bool:
    """
    True for a value that can sit inside an object kept on one line.

    Spine wraps an object as soon as one of its values is itself an object *or an
    array* — only scalar-only members stay on one line.
    """
    return not isinstance(value, (dict, list))


def dumps_spine(value: object, line_indent: int = -1) -> str:
    """
    Serialize like Spine's own pretty-printed export.

    `line_indent` is the tab indent of the line the value starts on, and the root
    object is written with -1 because Spine puts the root's members at column 0. A
    wrapped object or array puts its members one tab deeper and closes at the
    value's own indent; scalars-only arrays stay on one line however long they
    get, while an object stays on one line only while it is short.
    """
    width = max(0, line_indent) * 4
    if isinstance(value, dict):
        if not value:
            return "{}"
        inline = "{ " + ", ".join(
            f"{json.dumps(str(key))}: {dumps_spine(item, line_indent + 1)}"
            for key, item in value.items()
        ) + " }"
        if (
            "\n" not in inline
            and len(value) <= MAX_INLINE_MEMBERS
            and all(is_scalar(item) for item in value.values())
            and len(inline) + width <= MAX_INLINE_WIDTH
        ):
            return inline
        pad = "\t" * max(0, line_indent + 1)
        body = ",\n".join(
            f"{pad}{json.dumps(str(key))}: {dumps_spine(item, line_indent + 1)}"
            for key, item in value.items()
        )
        return "{\n" + body + "\n" + "\t" * max(0, line_indent) + "}"
    if isinstance(value, list):
        if not value:
            return "[]"
        # Spine keeps arrays of scalars (uvs, vertices, curve, skin bone names) on
        # one line however long they get, and puts one object per line.
        if all(not isinstance(item, (dict, list)) for item in value):
            return "[ " + ", ".join(
                dumps_spine(item, line_indent + 1) for item in value
            ) + " ]"
        pad = "\t" * max(0, line_indent + 1)
        items = ",\n".join(f"{pad}{dumps_spine(item, line_indent + 1)}" for item in value)
        return "[\n" + items + "\n" + "\t" * max(0, line_indent) + "]"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return format_number(value)
    return json.dumps(value, ensure_ascii=False)


def load_spine_json(path: Path) -> dict:
    """Read a Spine JSON export, rejecting anything that is not one."""
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"{path} is not valid JSON: {exc}. Export the rig from Spine with "
            "Format: JSON and 'Nonessential data' checked."
        ) from exc
    if not isinstance(data, dict) or "skeleton" not in data:
        raise ValueError(
            f"{path} has no 'skeleton' section, so it is not a Spine JSON export. "
            "A .skel binary or a .spine project cannot be patched — export JSON first."
        )
    return data


def spine_version(data: dict) -> str:
    """The Spine version the data was exported from, or "" if it is missing."""
    skeleton = data.get("skeleton")
    if isinstance(skeleton, dict):
        version = skeleton.get("spine")
        if isinstance(version, str):
            return version
    return ""


def is_number(value: object) -> bool:
    """True for a JSON number (`bool` is an int in Python, so exclude it)."""
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def bones_by_name(data: dict) -> dict:
    """Every declared bone, keyed by name, in declaration order."""
    result: dict = {}
    bones = data.get("bones")
    if isinstance(bones, list):
        for bone in bones:
            if isinstance(bone, dict) and isinstance(bone.get("name"), str):
                result[bone["name"]] = bone
    return result


def bone_child_counts(data: dict) -> dict:
    """Direct-child count per declared bone, in declaration order."""
    counts: dict = {}
    bones = data.get("bones")
    if not isinstance(bones, list):
        return counts
    for bone in bones:
        if not isinstance(bone, dict) or not isinstance(bone.get("name"), str):
            continue
        name = bone["name"]
        counts.setdefault(name, 0)
        parent = bone.get("parent")
        if isinstance(parent, str):
            counts[parent] = counts.get(parent, 0) + 1
    return counts


def hub_candidates(data: dict, limit: int = 3) -> list:
    """
    The `limit` bones with the most direct children, as `[(name, count), ...]`.

    These are the plausible torso hubs of the rig. `sorted` is stable, so equal
    counts keep declaration order.
    """
    ranked = sorted(bone_child_counts(data).items(), key=lambda item: -item[1])
    return ranked[:limit]


def pick_hub_bone(data: dict) -> str:
    """The likely torso hub (`hip`, `z_tun`, ...), or "" for a rig with no bones."""
    candidates = hub_candidates(data, 1)
    return candidates[0][0] if candidates else ""


def bone_length(bone: object) -> float:
    """The length of a bone, or 0.0 when it has none (a transform-only bone)."""
    if isinstance(bone, dict) and is_number(bone.get("length")):
        return float(bone["length"])
    return 0.0


def animation_duration(animation: object) -> float:
    """
    How long an animation lasts, as the latest key time found anywhere in it.

    Spine JSON has no duration field, so this walks every timeline in the
    animation. A pose with no keys at all returns 0.0.
    """
    latest = 0.0
    stack: list = [animation]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            time = node.get("time")
            if is_number(time):
                latest = max(latest, float(time))
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
    return latest


def parse_time_value(text: str, duration: float, fps: float, label: str) -> float:
    """
    Turn one `--anim` timing into seconds.

    `0.55` is a fraction of the animation, `0.75s` is seconds, `12f` is a frame
    at `fps`. A bare number above 1.0 is rejected, because it is ambiguous.
    """
    raw = text.strip().lower()
    if raw.endswith("s"):
        try:
            return float(raw[:-1])
        except ValueError as exc:
            raise ValueError(f"{label}: {text!r} is not a number of seconds (e.g. 0.75s)") from exc
    if raw.endswith("f"):
        try:
            frame = float(raw[:-1])
        except ValueError as exc:
            raise ValueError(f"{label}: {text!r} is not a frame number (e.g. 12f)") from exc
        if fps <= 0.0:
            raise ValueError(f"{label}: --fps must be above 0 to use frames")
        return frame / fps
    try:
        value = float(raw)
    except ValueError as exc:
        raise ValueError(f"{label}: {text!r} is not a number") from exc
    if 0.0 <= value <= 1.0:
        if duration <= 0.0:
            raise ValueError(
                f"{label}: {text!r} is a fraction of the animation, but the animation has no "
                f"keyed times to take a fraction of. Use seconds ({text}s) or frames ({text}f)."
            )
        return value * duration
    raise ValueError(
        f"{label}: {text!r} is ambiguous. Use 0..1 for a fraction of the animation, "
        f"{text}s for seconds, or {text}f for a frame at --fps."
    )


def parse_anim_spec(spec: str) -> tuple:
    """Split `NAME[:SPAWN[:HIT]]` into its three parts (missing parts are None)."""
    parts = [part.strip() for part in spec.split(":")]
    if not parts[0]:
        raise ValueError(f"--anim {spec!r}: the animation name is empty")
    if len(parts) > 3:
        raise ValueError(f"--anim {spec!r}: expected NAME[:SPAWN[:HIT]]")
    spawn = parts[1] if len(parts) > 1 and parts[1] else None
    hit = parts[2] if len(parts) > 2 and parts[2] else None
    return parts[0], spawn, hit


def add_bone(data: dict, name: str, parent: str, offset: float, style: dict, report: list) -> None:
    """Append one transform bone under `parent`, unless it already exists."""
    bones = data.get("bones")
    if not isinstance(bones, list):
        raise ValueError("the 'bones' section is missing, so the rig cannot be patched")

    existing = bones_by_name(data)
    if name in existing:
        report.append(f"bone {name}: already present, left as is")
        return
    if parent not in existing:
        raise ValueError(
            f"parent bone {parent!r} does not exist. Pass --torso/--cast-parent with "
            f"one of: {', '.join(existing) or 'none'}"
        )

    bone: dict = {"name": name, "parent": parent}
    length = bone_length(existing[parent])
    if length > 0.0:
        bone["x"] = round(length * offset, 6)
    else:
        report.append(
            f"bone {name}: parent {parent!r} has no length, so it sits on the parent "
            "origin — move it in Spine"
        )
    bone.update(style)
    bones.append(bone)
    report.append(f"bone {name}: added under {parent!r}")


def add_event(data: dict, name: str, report: list) -> None:
    """Declare one event, unless it is already declared."""
    events = data.get("events")
    if not isinstance(events, dict):
        events = {}
        data["events"] = events
    if name in events:
        report.append(f"event {name}: already defined, left as is")
        return
    events[name] = {}
    report.append(f"event {name}: defined")


def require_animation(data: dict, name: str) -> dict:
    """The named animation, or a clear error listing what the rig does have."""
    animations = data.get("animations")
    if not isinstance(animations, dict) or not animations:
        raise ValueError(f"the rig has no animations, so {name!r} cannot be keyed")
    if name not in animations:
        raise ValueError(
            f"animation {name!r} not found. Available: {', '.join(sorted(animations))}"
        )
    animation = animations[name]
    if not isinstance(animation, dict):
        raise ValueError(f"animation {name!r} is not an object")
    return animation


def key_events(
    animation: dict,
    anim_name: str,
    spawn_seconds: float,
    hit_seconds: float,
    force: bool,
    report: list,
) -> None:
    """Key `event_vfx_spawn` then `event_hit_frame` into one animation."""
    timeline = animation.get("events")
    if not isinstance(timeline, list):
        timeline = []
        animation["events"] = timeline

    if force:
        kept = [
            key for key in timeline
            if not (isinstance(key, dict) and key.get("name") in (SPAWN_EVENT, HIT_EVENT))
        ]
        if len(kept) != len(timeline):
            report.append(f"animation {anim_name}: --force re-timed the combat event keys")
        timeline[:] = kept

    for event_name, seconds in ((SPAWN_EVENT, spawn_seconds), (HIT_EVENT, hit_seconds)):
        if any(isinstance(key, dict) and key.get("name") == event_name for key in timeline):
            report.append(
                f"animation {anim_name}: {event_name} is already keyed, left as is "
                "(pass --force to re-time it)"
            )
            continue
        timeline.append({"time": round(seconds, 6), "name": event_name})
        report.append(f"animation {anim_name}: {event_name} keyed at {round(seconds, 6):g}s")

    timeline.sort(key=lambda key: float(key.get("time", 0.0)) if isinstance(key, dict) and is_number(key.get("time")) else 0.0)


def resolve_parents(data: dict, args: argparse.Namespace, report: list) -> tuple:
    """Pick the parent bones for the two new bones, defaulting to the rig hub."""
    existing = bones_by_name(data)
    if not existing:
        raise ValueError("the rig declares no bones, so there is nothing to parent to")

    hub = pick_hub_bone(data)
    torso = args.torso or hub
    if torso not in existing:
        raise ValueError(f"--torso {torso!r} is not a bone. Available: {', '.join(existing)}")
    if args.torso:
        report.append(f"Center_Hit_Point parent: {torso!r} (from --torso)")
    else:
        candidates = ", ".join(f"{name} ({count})" for name, count in hub_candidates(data))
        report.append(
            f"Center_Hit_Point parent: {torso!r} — auto-detected as the bone with the most "
            f"children. Candidates by child count: {candidates}. Check it, or pass --torso."
        )

    cast_parent = args.cast_parent or torso
    if cast_parent not in existing:
        raise ValueError(
            f"--cast-parent {cast_parent!r} is not a bone. Available: {', '.join(existing)}"
        )
    report.append(f"Cast_Origin_Point parent: {cast_parent!r}")
    return torso, cast_parent


def selected_animations(data: dict, args: argparse.Namespace) -> list:
    """The `(name, spawn, hit)` specs to key, from --anim and --all-attacks."""
    specs = [parse_anim_spec(spec) for spec in args.anim]
    names = {spec[0] for spec in specs}

    if args.all_attacks:
        animations = data.get("animations")
        pattern = re.compile(args.attack_pattern)
        if isinstance(animations, dict):
            for name in sorted(animations):
                if pattern.search(name) and name not in names:
                    specs.append((name, None, None))
                    names.add(name)
    return specs


def run(args: argparse.Namespace) -> int:
    """Patch the input export and, unless --dry-run, write the result."""
    report: list = []
    data = load_spine_json(args.input)

    version = spine_version(data)
    if version and not version.startswith(f"{SPINE_RUNTIME_MAJOR_MINOR}."):
        print(
            f"warning: this export is Spine {version} but the runtime is "
            f"{SPINE_RUNTIME_MAJOR_MINOR}; re-export from Spine {SPINE_RUNTIME_MAJOR_MINOR} "
            "before shipping.",
            file=sys.stderr,
        )

    torso, cast_parent = resolve_parents(data, args, report)
    add_bone(data, HIT_BONE, torso, args.hit_bone_offset, HIT_BONE_STYLE, report)
    add_bone(data, CAST_BONE, cast_parent, args.cast_bone_offset, CAST_BONE_STYLE, report)
    add_event(data, SPAWN_EVENT, report)
    add_event(data, HIT_EVENT, report)

    specs = selected_animations(data, args)
    if not specs:
        report.append(
            "no animations selected, so the events are declared but not keyed "
            "(use --anim or --all-attacks)"
        )
    for name, spawn_text, hit_text in specs:
        animation = require_animation(data, name)
        duration = animation_duration(animation)
        if duration <= 0.0:
            raise ValueError(
                f"animation {name!r} has no keyed times, so a fraction of its duration cannot "
                f"be resolved. Pass explicit values, e.g. --anim {name}:0.2s:0.5s"
            )
        spawn_seconds = (
            parse_time_value(spawn_text, duration, args.fps, f"--anim {name} spawn")
            if spawn_text
            else duration * args.spawn_fraction
        )
        hit_seconds = (
            parse_time_value(hit_text, duration, args.fps, f"--anim {name} hit")
            if hit_text
            else duration * args.hit_fraction
        )
        key_events(animation, name, spawn_seconds, hit_seconds, args.force, report)

    print(f"{args.input}: Spine {version or 'unknown'}")
    for line in report:
        print(f"  - {line}")

    if args.dry_run:
        print("\ndry run: nothing written")
        return 0

    output = args.output or args.input.with_name(f"{args.input.stem}_combat.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    # No trailing newline: that is how a Spine export ends, so a re-export from the
    # editor produces no spurious diff.
    output.write_text(dumps_spine(data), encoding="utf-8", newline="\n")
    print(f"\nwrote {output}")

    skeleton = output.stem
    print("\nNext step — turn the patched JSON into an editable project:")
    print(
        "  & 'C:\\Program Files\\Spine\\Spine.com' -i "
        f"{output.as_posix()} -o SpineSource/{skeleton}.spine --to {skeleton} -r"
    )
    print("Then place the two bones and re-time the event keys in the editor, and export with")
    print("  pwsh -File Tools/export_spine_to_godot.ps1 -CharId <char_id>")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Add the I-1 combat rig (Center_Hit_Point, Cast_Origin_Point, "
            "event_vfx_spawn, event_hit_frame) to a Spine JSON export."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "examples:\n"
            "  python Tools/rig_combat_actor.py --input rig.json --dry-run\n"
            "  python Tools/rig_combat_actor.py --input rig.json --all-attacks\n"
            "  python Tools/rig_combat_actor.py --input rig.json --torso hip "
            "--anim skill1:0.3:0.55 --anim unique:0.75s:12f\n"
        ),
    )
    parser.add_argument("--input", type=Path, required=True, help="Spine JSON export to patch")
    parser.add_argument(
        "--output",
        type=Path,
        help="where to write the patched JSON (default: <input>_combat.json)",
    )
    parser.add_argument(
        "--torso",
        help="parent bone for Center_Hit_Point (default: the bone with the most children)",
    )
    parser.add_argument(
        "--cast-parent",
        help="parent bone for Cast_Origin_Point (default: the same as --torso)",
    )
    parser.add_argument(
        "--anim",
        action="append",
        default=[],
        metavar="NAME[:SPAWN[:HIT]]",
        help=(
            "animation to key, repeatable. Timings are fractions of the animation (0.55), "
            "seconds (0.75s) or frames at --fps (12f); omit them for the defaults."
        ),
    )
    parser.add_argument(
        "--all-attacks",
        action="store_true",
        help="also key every animation whose name matches --attack-pattern",
    )
    parser.add_argument(
        "--attack-pattern",
        default=DEFAULT_ATTACK_PATTERN,
        help=f"regex used by --all-attacks (default: {DEFAULT_ATTACK_PATTERN})",
    )
    parser.add_argument(
        "--spawn-fraction",
        type=float,
        default=DEFAULT_SPAWN_FRACTION,
        help=f"default spawn time, as a fraction of the animation (default: {DEFAULT_SPAWN_FRACTION})",
    )
    parser.add_argument(
        "--hit-fraction",
        type=float,
        default=DEFAULT_HIT_FRACTION,
        help=f"default hit time, as a fraction of the animation (default: {DEFAULT_HIT_FRACTION})",
    )
    parser.add_argument(
        "--fps",
        type=float,
        default=DEFAULT_FPS,
        help=f"frames per second used by the 'f' timing form (default: {DEFAULT_FPS:g})",
    )
    parser.add_argument(
        "--hit-bone-offset",
        type=float,
        default=HIT_BONE_OFFSET,
        help=f"Center_Hit_Point position along its parent, 0..1 (default: {HIT_BONE_OFFSET})",
    )
    parser.add_argument(
        "--cast-bone-offset",
        type=float,
        default=CAST_BONE_OFFSET,
        help=f"Cast_Origin_Point position along its parent, 0..1 (default: {CAST_BONE_OFFSET})",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="re-time combat event keys that are already present",
    )
    parser.add_argument("--dry-run", action="store_true", help="report the changes without writing")

    args = parser.parse_args()
    try:
        return run(args)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
