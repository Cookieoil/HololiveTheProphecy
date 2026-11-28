#!/usr/bin/env python3
"""Pixel-level comparison of two `Tools/snapshot_runner.tscn` captures.

Why this exists: every gate in this repository is headless, and Godot's headless display
driver is the dummy renderer, which rasterises nothing - so a layout, margin or shader
regression cannot show up in any of them. The snapshot runner renders the real screens
with the real OpenGL renderer; this compares two runs of it and says *where* they differ.
A pair of sha256 sums can only say that they do, and a human comparing nine PNGs side by
side by eye is exactly the review the gates exist to replace.

Capture both sides with the same fixed clock, or the comparison is noise: without
`--fixed-fps` the frame delta follows wall-clock time, so shader `TIME` and every
`delta`-driven animation land somewhere slightly different on a second run.

    godot --audio-driver Dummy --position -4000,-4000 --fixed-fps 60 --path . \\
        res://Tools/snapshot_runner.tscn -- --output-dir reports/ui-snapshots/before
    # ...make the change...
    godot --audio-driver Dummy --position -4000,-4000 --fixed-fps 60 --path . \\
        res://Tools/snapshot_runner.tscn -- --output-dir reports/ui-snapshots/after
    python Tools/compare_snapshots.py --before reports/ui-snapshots/before \\
                                      --after  reports/ui-snapshots/after

Standard library only, like every other tool in Tools/: a PNG needs `zlib` and `struct`
and nothing else, and a verification tool that cannot run is worse than no tool at all.

Exit codes: 0 within tolerance, 1 a difference over it, a missing shot, or an extra one.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import struct
import sys
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
## Channels per pixel for each PNG colour type, for the 8-bit non-interlaced files Godot
## writes. 3 (palette) is not emitted by `Image.save_png`, so it is refused rather than
## half-supported.
CHANNELS = {0: 1, 2: 3, 4: 2, 6: 4}
FILTER_NONE, FILTER_SUB, FILTER_UP, FILTER_AVERAGE, FILTER_PAETH = range(5)
## A capture is only useful as evidence if the tolerance is stated, so both defaults are
## zero: by default two captures must agree exactly.
DEFAULT_MAX_CHANGED_PX = 0
DEFAULT_MAX_CHANNEL_DELTA = 0


class PngError(ValueError):
    """Raised for anything that is not a PNG this tool can read."""


def _chunks(data: bytes):
    """Yields `(kind, body)` for every chunk, verifying each CRC as it goes."""
    position = len(PNG_SIGNATURE)
    while position + 12 <= len(data):
        length = struct.unpack(">I", data[position:position + 4])[0]
        kind = data[position + 4:position + 8]
        body = data[position + 8:position + 8 + length]
        expected = struct.unpack(">I", data[position + 8 + length:position + 12 + length])[0]
        if zlib.crc32(kind + body) & 0xFFFFFFFF != expected:
            raise PngError(f"corrupt {kind.decode('ascii', 'replace')} chunk (bad CRC)")
        yield kind, body
        position += 12 + length


def _unfilter(raw: bytes, width: int, height: int, channels: int) -> bytearray:
    """Reverses the five PNG scanline filters into one flat pixel buffer."""
    stride = width * channels
    out = bytearray(stride * height)
    position = 0
    for y in range(height):
        filter_type = raw[position]
        position += 1
        line = bytearray(raw[position:position + stride])
        position += stride
        previous = out[(y - 1) * stride:y * stride] if y else bytes(stride)
        if filter_type == FILTER_SUB:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif filter_type == FILTER_UP:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filter_type == FILTER_AVERAGE:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif filter_type == FILTER_PAETH:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                up = previous[i]
                up_left = previous[i - channels] if i >= channels else 0
                estimate = left + up - up_left
                nearest = min((left, up, up_left), key=lambda v: abs(v - estimate))
                line[i] = (line[i] + nearest) & 0xFF
        elif filter_type != FILTER_NONE:
            raise PngError(f"unknown scanline filter {filter_type}")
        out[y * stride:(y + 1) * stride] = line
    return out

def read_png(path: pathlib.Path) -> tuple[int, int, bytes]:
    """`(width, height, rgba)` for an 8-bit non-interlaced PNG, whatever its colour type."""
    data = pathlib.Path(path).read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise PngError(f"{path}: not a PNG")
    width = height = channels = None
    compressed = bytearray()
    for kind, body in _chunks(data):
        if kind == b"IHDR":
            width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8:
                raise PngError(f"{path}: {depth}-bit samples are not supported")
            if interlace:
                raise PngError(f"{path}: interlaced PNGs are not supported")
            if colour not in CHANNELS:
                raise PngError(f"{path}: colour type {colour} is not supported")
            channels = CHANNELS[colour]
        elif kind == b"IDAT":
            compressed += body
        elif kind == b"IEND":
            break
    if width is None:
        raise PngError(f"{path}: no IHDR chunk")

    pixels = _unfilter(zlib.decompress(bytes(compressed)), width, height, channels)
    if channels == 4:
        return width, height, bytes(pixels)
    # Grey and grey+alpha are widened here rather than at every call site, so the
    # comparison itself only ever sees one layout.
    rgba = bytearray(width * height * 4)
    for i in range(width * height):
        source = i * channels
        target = i * 4
        if channels == 1:
            grey = pixels[source]
            rgba[target:target + 4] = bytes((grey, grey, grey, 255))
        elif channels == 2:
            grey, alpha = pixels[source], pixels[source + 1]
            rgba[target:target + 4] = bytes((grey, grey, grey, alpha))
        else:
            rgba[target:target + 3] = pixels[source:source + 3]
            rgba[target + 3] = 255
    return width, height, bytes(rgba)


def write_png(path: pathlib.Path, width: int, height: int, rgba: bytes) -> None:
    """Writes an 8-bit RGBA PNG with no filtering, for the diff images and the fixtures."""
    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(FILTER_NONE)
        raw += rgba[y * stride:(y + 1) * stride]

    def chunk(kind: bytes, body: bytes) -> bytes:
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        PNG_SIGNATURE
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )

def compare_pixels(before: bytes, after: bytes, width: int, height: int) -> dict:
    """Counts the differing pixels, the worst channel delta and where they are.

    Row-sliced on purpose: two identical rows are one `bytes` comparison at C speed, and a
    nine-shot capture is mostly identical rows. Only rows that actually differ are walked
    pixel by pixel.
    """
    stride = width * 4
    changed = 0
    worst = 0
    squared = 0
    bounds = None
    for y in range(height):
        start = y * stride
        row_before = before[start:start + stride]
        row_after = after[start:start + stride]
        if row_before == row_after:
            continue
        for x in range(width):
            offset = x * 4
            delta = 0
            for channel in range(4):
                difference = abs(row_before[offset + channel] - row_after[offset + channel])
                if difference > delta:
                    delta = difference
            if not delta:
                continue
            changed += 1
            squared += delta * delta
            if delta > worst:
                worst = delta
            if bounds is None:
                bounds = (x, y, x, y)
            else:
                bounds = (min(bounds[0], x), min(bounds[1], y),
                          max(bounds[2], x), max(bounds[3], y))
    return {
        "changed_px": changed,
        "max_channel_delta": worst,
        "rmse": round((squared / (width * height)) ** 0.5, 6),
        "bbox": list(bounds) if bounds else None,
    }


def write_diff_image(path: pathlib.Path, before: bytes, after: bytes, width: int, height: int) -> None:
    """A dimmed copy of `--before` with every differing pixel painted red, so a reviewer can
    see *where* two runs disagree instead of opening both and hunting for the change."""
    out = bytearray(width * height * 4)
    for i in range(width * height):
        offset = i * 4
        if before[offset:offset + 4] == after[offset:offset + 4]:
            out[offset] = before[offset] // 3
            out[offset + 1] = before[offset + 1] // 3
            out[offset + 2] = before[offset + 2] // 3
        else:
            out[offset] = 255
            out[offset + 1] = 32
            out[offset + 2] = 32
        out[offset + 3] = 255
    write_png(path, width, height, bytes(out))

def compare_shots(before_dir: pathlib.Path, after_dir: pathlib.Path,
                  diff_dir: pathlib.Path | None = None) -> tuple[list, list]:
    """One metrics row per shot present on both sides, plus the problems that are not a
    pixel difference (a shot only one side has, or one whose size changed)."""
    rows: list[dict] = []
    problems: list[str] = []
    before_dir = pathlib.Path(before_dir)
    after_dir = pathlib.Path(after_dir)
    before_shots = sorted(path.name for path in before_dir.glob("*.png"))
    after_shots = sorted(path.name for path in after_dir.glob("*.png"))
    for missing in sorted(set(before_shots) - set(after_shots)):
        problems.append(f"{missing}: captured on --before but not on --after")
    for extra in sorted(set(after_shots) - set(before_shots)):
        problems.append(f"{extra}: captured on --after but not on --before")

    for name in [shot for shot in before_shots if shot in set(after_shots)]:
        before_width, before_height, before_pixels = read_png(before_dir / name)
        after_width, after_height, after_pixels = read_png(after_dir / name)
        if (before_width, before_height) != (after_width, after_height):
            problems.append(f"{name}: {before_width}x{before_height} became {after_width}x{after_height}")
            continue
        metrics = compare_pixels(before_pixels, after_pixels, before_width, before_height)
        metrics["file"] = name
        metrics["width"] = before_width
        metrics["height"] = before_height
        rows.append(metrics)
        if diff_dir is not None and metrics["changed_px"]:
            write_diff_image(pathlib.Path(diff_dir) / f"diff_{name}",
                             before_pixels, after_pixels, before_width, before_height)
    return rows, problems


def format_report(rows: list, problems: list, max_changed: int, max_delta: int) -> tuple[str, int]:
    """The table a reviewer reads, plus how many shots (or problems) were over tolerance."""
    lines = [f"{'shot':<28} {'size':>11} {'changed px':>11} {'max delta':>10} {'rmse':>8}  bbox"]
    failures = 0
    for row in rows:
        over = row["changed_px"] > max_changed or row["max_channel_delta"] > max_delta
        if over:
            failures += 1
        bbox = row["bbox"]
        bounds = f"{bbox[0]},{bbox[1]} to {bbox[2]},{bbox[3]}" if bbox else "-"
        lines.append(
            f"{'!' if over else ' '}{row['file']:<27} {row['width']}x{row['height']:<6}"
            f" {row['changed_px']:>11} {row['max_channel_delta']:>10} {row['rmse']:>8.4f}  {bounds}"
        )
    lines.append("")
    lines.append(f"{len(rows)} shot(s) compared, {failures} over tolerance "
                 f"(max changed px {max_changed}, max channel delta {max_delta})")
    for problem in problems:
        lines.append(f"PROBLEM {problem}")
        failures += 1
    if not rows and not problems:
        lines.append("PROBLEM no PNGs found to compare - did the capture run?")
        failures += 1
    return "\n".join(lines), failures


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--before", required=True, type=pathlib.Path,
                        help="capture directory taken before the change")
    parser.add_argument("--after", required=True, type=pathlib.Path,
                        help="capture directory taken after it")
    parser.add_argument("--max-changed-px", type=int, default=DEFAULT_MAX_CHANGED_PX,
                        help="how many pixels are allowed to differ (default 0)")
    parser.add_argument("--max-channel-delta", type=int, default=DEFAULT_MAX_CHANNEL_DELTA,
                        help="how far a channel may move, 0-255 (default 0)")
    parser.add_argument("--write-diff", type=pathlib.Path, default=None,
                        help="directory for a diff image per shot that differs")
    parser.add_argument("--json", type=pathlib.Path, default=None,
                        help="write the numbers to JSON as well as the table")
    args = parser.parse_args(argv)

    for directory in (args.before, args.after):
        if not directory.is_dir():
            print(f"ERROR: no such capture directory: {directory}", file=sys.stderr)
            return 1

    rows, problems = compare_shots(args.before, args.after, args.write_diff)
    report, failures = format_report(rows, problems, args.max_changed_px, args.max_channel_delta)
    print(report)
    if args.json is not None:
        args.json.write_text(json.dumps({
            "before": str(args.before),
            "after": str(args.after),
            "max_changed_px": args.max_changed_px,
            "max_channel_delta": args.max_channel_delta,
            "shots": rows,
            "problems": problems,
        }, indent=2), encoding="utf-8")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
