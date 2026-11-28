#!/usr/bin/env python3
"""Regression suite for Tools/compare_snapshots.py - the pixel comparison itself.

    python Tools/compare_snapshots_test.py

Why this exists: this tool is the only thing in the repository that can catch a UI
regression, because every other gate runs headless where nothing is rasterised. A
comparison tool with a broken PNG decoder or an off-by-one in its filter arithmetic would
not crash - it would report "0 pixels changed" for two images that differ, which is the
most dangerous possible failure: a green tick over a change nobody looked at.

So the decoder is pinned against images built here, one per scanline filter, and the
comparison is pinned against fixtures whose expected pixel counts were worked out by hand.

The four that matter most:

  * every PNG scanline filter decodes to the bytes that were compressed. A single wrong
    reconstruction rule silently corrupts whole rows, and only for some images.
  * a one-pixel difference is reported as exactly one pixel, at exactly that coordinate.
    "Something changed" is not enough to review a diff.
  * a shot missing on one side is a failure, not a silent skip.
  * tolerance is a threshold on both numbers, so a single wildly-off pixel still fails.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import shutil
import struct
import tempfile
import zlib
from pathlib import Path

MODULE = Path(__file__).with_name("compare_snapshots.py")
WORK = Path(tempfile.mkdtemp(prefix="compare-snapshots-test-"))

spec = importlib.util.spec_from_file_location("compare", MODULE)
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)

results: list[tuple[str, bool, str]] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    results.append((name, bool(condition), detail))


def solid(width: int, height: int, rgba: tuple[int, int, int, int]) -> bytes:
    """One flat RGBA image."""
    return bytes(rgba) * (width * height)


def with_pixel(width: int, height: int, x: int, y: int, rgba: tuple[int, int, int, int]) -> bytes:
    """The same flat image with one pixel replaced."""
    image = bytearray(solid(width, height, (10, 20, 30, 255)))
    offset = (y * width + x) * 4
    image[offset:offset + 4] = bytes(rgba)
    return bytes(image)


def filtered_png(width: int, height: int, rgba: bytes, filters: list[int]) -> bytes:
    """A PNG whose scanlines use the filters given, one entry per row.

    Hand-built rather than reusing `write_png`, because the point of these fixtures is to
    be encoded by *something other than the code under test*: a writer and a reader that
    share a wrong belief about a filter would agree with each other and pass.
    """
    stride = width * 4
    raw = bytearray()
    for y in range(height):
        line = rgba[y * stride:(y + 1) * stride]
        previous = rgba[(y - 1) * stride:y * stride] if y else bytes(stride)
        encoded = bytearray(len(line))
        for i in range(len(line)):
            left = line[i - 4] if i >= 4 else 0
            up = previous[i]
            up_left = previous[i - 4] if i >= 4 else 0
            rule = filters[y]
            if rule == compare.FILTER_NONE:
                encoded[i] = line[i]
            elif rule == compare.FILTER_SUB:
                encoded[i] = (line[i] - left) & 0xFF
            elif rule == compare.FILTER_UP:
                encoded[i] = (line[i] - up) & 0xFF
            elif rule == compare.FILTER_AVERAGE:
                encoded[i] = (line[i] - ((left + up) >> 1)) & 0xFF
            elif rule == compare.FILTER_PAETH:
                estimate = left + up - up_left
                nearest = min((left, up, up_left), key=lambda v: abs(v - estimate))
                encoded[i] = (line[i] - nearest) & 0xFF
            else:
                raise ValueError(f"unknown fixture filter {rule}")
        raw.append(rule)
        raw += encoded

    def chunk(kind: bytes, body: bytes) -> bytes:
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

    return (compare.PNG_SIGNATURE
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))


def write(name: str, data: bytes) -> Path:
    path = WORK / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def run_main(argv: list[str]) -> tuple[int, str]:
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        code = compare.main(argv)
    return code, buffer.getvalue()

# --------------------------------------------------------------- the PNG decoder
ROUND_TRIP = with_pixel(4, 3, 2, 1, (200, 100, 50, 128))
written = write("round-trip.png", b"")
compare.write_png(written, 4, 3, ROUND_TRIP)
width, height, pixels = compare.read_png(written)
check("a written PNG reads back its size", (width, height) == (4, 3), f"{width}x{height}")
check("...and its pixels, byte for byte", pixels == ROUND_TRIP)

GRADIENT = bytes(
    component
    for y in range(5)
    for x in range(6)
    for component in (x * 40 % 256, y * 50 % 256, (x + y) * 30 % 256, 255)
)


def decodes_with(filter_type: int, label: str) -> None:
    path = write(f"filter-{label}.png", filtered_png(6, 5, GRADIENT, [filter_type] * 5))
    _, _, decoded = compare.read_png(path)
    check(f"a scanline filtered with {label} decodes to its source bytes", decoded == GRADIENT)


decodes_with(compare.FILTER_NONE, "None")
decodes_with(compare.FILTER_SUB, "Sub")
decodes_with(compare.FILTER_UP, "Up")
decodes_with(compare.FILTER_AVERAGE, "Average")
decodes_with(compare.FILTER_PAETH, "Paeth")

MIXED = write("filter-mixed.png",
              filtered_png(6, 5, GRADIENT,
                           [compare.FILTER_NONE, compare.FILTER_SUB, compare.FILTER_UP,
                            compare.FILTER_AVERAGE, compare.FILTER_PAETH]))
check("filters can change from row to row",
      compare.read_png(MIXED)[2] == GRADIENT)


def grey_png() -> bytes:
    """Colour type 0: one 8-bit channel and no alpha, which Godot never writes but a tool
    that claims to read PNGs should still not fall over."""
    raw = bytearray()
    for y in range(2):
        raw.append(0)
        raw += bytes((y * 10 + x for x in range(3)))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

    return (compare.PNG_SIGNATURE
            + chunk(b"IHDR", struct.pack(">IIBBBBB", 3, 2, 8, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))


grey = compare.read_png(write("grey.png", grey_png()))
check("a greyscale PNG is widened to RGBA with opaque alpha",
      grey[2][0:8] == bytes((0, 0, 0, 255, 1, 1, 1, 255)), str(grey[2][0:8]))

bad_crc = bytearray(filtered_png(2, 2, GRADIENT[:16], [0, 0]))
bad_crc[-1] ^= 0xFF
try:
    compare.read_png(write("bad-crc.png", bytes(bad_crc)))
    check("a corrupt chunk is refused", False, "no error raised")
except compare.PngError as error:
    check("a corrupt chunk is refused", "CRC" in str(error), str(error))

try:
    compare.read_png(write("not-a-png.png", b"definitely not a png"))
    check("a file that is not a PNG is refused", False, "no error raised")
except compare.PngError as error:
    check("a file that is not a PNG is refused", "not a PNG" in str(error), str(error))

# ------------------------------------------------------------ the comparison
SIZE = (8, 6)
FLAT = solid(*SIZE, (10, 20, 30, 255))
SAME = compare.compare_pixels(FLAT, FLAT, *SIZE)
check("two identical images have no changed pixels", SAME["changed_px"] == 0)
check("...no channel movement", SAME["max_channel_delta"] == 0)
check("...a zero rmse", SAME["rmse"] == 0.0)
check("...and no bounding box", SAME["bbox"] is None)

CHANGED = compare.compare_pixels(FLAT, with_pixel(*SIZE, 5, 4, (99, 20, 30, 255)), *SIZE)
check("one changed pixel is counted once", CHANGED["changed_px"] == 1, str(CHANGED))
check("...with its exact channel delta", CHANGED["max_channel_delta"] == 89, str(CHANGED))
check("...and a bounding box of exactly that pixel", CHANGED["bbox"] == [5, 4, 5, 4], str(CHANGED))
check("...and a positive rmse", CHANGED["rmse"] > 0.0)

# The fast path skips identical rows, so a change in the last row is the one an
# off-by-one would lose.
LAST_ROW = compare.compare_pixels(FLAT, with_pixel(*SIZE, 0, SIZE[1] - 1, (255, 255, 255, 255)), *SIZE)
check("a change in the final row is still found",
      LAST_ROW["bbox"] == [0, SIZE[1] - 1, 0, SIZE[1] - 1], str(LAST_ROW))

SPREAD = bytearray(FLAT)
for (x, y) in ((1, 1), (6, 3), (4, 2)):
    SPREAD[(y * SIZE[0] + x) * 4] = 200
SPREAD_METRICS = compare.compare_pixels(FLAT, bytes(SPREAD), *SIZE)
check("a scattered change is counted and bounded once",
      SPREAD_METRICS["changed_px"] == 3 and SPREAD_METRICS["bbox"] == [1, 1, 6, 3],
      str(SPREAD_METRICS))

# ------------------------------------------------------------------ the captures
BEFORE = WORK / "before"
AFTER = WORK / "after"
compare.write_png(BEFORE / "01_one.png", *SIZE, FLAT)
compare.write_png(BEFORE / "02_two.png", *SIZE, FLAT)
compare.write_png(AFTER / "01_one.png", *SIZE, FLAT)
compare.write_png(AFTER / "02_two.png", *SIZE, with_pixel(*SIZE, 3, 3, (250, 20, 30, 255)))

rows, problems = compare.compare_shots(BEFORE, AFTER)
check("a capture pair yields one row per shot", len(rows) == 2, str(len(rows)))
check("...with no problems", problems == [], str(problems))
MOVE_D = [row["file"] for row in rows if row["changed_px"]]
check("...naming the shot that moved", MOVE_D == ["02_two.png"], str(MOVE_D))

report, failures = compare.format_report(rows, problems, 0, 0)
check("an exact comparison reports one failure", failures == 1, report)
check("...and flags the failing shot in the table", "!02_two.png" in report, report)
check("...while the identical one is not flagged", " 01_one.png" in report, report)

_, tolerated = compare.format_report(rows, problems, 1, 255)
check("tolerance on both numbers passes a one-pixel change", tolerated == 0)
_, delta_only = compare.format_report(rows, problems, 1, 10)
check("a pixel over the channel tolerance still fails", delta_only == 1)

MISSING = WORK / "missing"
compare.write_png(MISSING / "01_one.png", *SIZE, FLAT)
_, missing_problems = compare.compare_shots(BEFORE, MISSING)
check("a shot captured on only one side is a problem",
      any("02_two.png" in problem for problem in missing_problems), str(missing_problems))

EXTRA = WORK / "extra"
for name in ("01_one.png", "02_two.png", "03_three.png"):
    compare.write_png(EXTRA / name, *SIZE, FLAT)
_, extra_problems = compare.compare_shots(BEFORE, EXTRA)
check("a shot only the new capture has is a problem too",
      any("03_three.png" in problem for problem in extra_problems), str(extra_problems))

ODD_SIZE = WORK / "odd-size"
compare.write_png(ODD_SIZE / "01_one.png", SIZE[0], SIZE[1] + 1,
                  solid(SIZE[0], SIZE[1] + 1, (10, 20, 30, 255)))
compare.write_png(ODD_SIZE / "02_two.png", *SIZE, FLAT)
_, size_problems = compare.compare_shots(BEFORE, ODD_SIZE)
check("a resized shot is reported, not compared",
      any("became" in problem for problem in size_problems), str(size_problems))

EMPTY = WORK / "empty"
EMPTY.mkdir(parents=True, exist_ok=True)
report, failures = compare.format_report(*compare.compare_shots(EMPTY, EMPTY), 0, 0)
check("two empty directories are a problem, not a pass",
      failures == 1 and "no PNGs" in report, report)

DIFF_DIR = WORK / "diff-images"
compare.compare_shots(BEFORE, AFTER, DIFF_DIR)
check("a diff image is written for the shot that differs",
      (DIFF_DIR / "diff_02_two.png").is_file())
DIFF_WIDTH, DIFF_HEIGHT, DIFF_PIXELS = compare.read_png(DIFF_DIR / "diff_02_two.png")
offset = (3 * DIFF_WIDTH + 3) * 4
check("...with the changed pixel painted red",
      DIFF_PIXELS[offset:offset + 3] == bytes((255, 32, 32)), str(DIFF_PIXELS[offset:offset + 3]))
check("...over a dimmed copy of the original",
      DIFF_PIXELS[0:3] == bytes((10 // 3, 20 // 3, 30 // 3)), str(DIFF_PIXELS[0:3]))

# ------------------------------------------------------------------------ the CLI
code, printed = run_main(["--before", str(BEFORE), "--after", str(AFTER)])
check("the CLI exits 1 when a shot moved", code == 1, printed[-200:])
code, printed = run_main(["--before", str(BEFORE), "--after", str(AFTER),
                          "--max-changed-px", "1", "--max-channel-delta", "255"])
check("the CLI exits 0 inside the stated tolerance", code == 0, printed[-200:])
code, printed = run_main(["--before", str(BEFORE), "--after", str(BEFORE)])
check("the CLI exits 0 for two identical captures", code == 0, printed[-200:])
code, printed = run_main(["--before", str(WORK / "nope"), "--after", str(BEFORE)])
check("the CLI exits 1 for a missing capture directory", code == 1, printed)

export = WORK / "compare.json"
run_main(["--before", str(BEFORE), "--after", str(AFTER), "--json", str(export),
          "--max-changed-px", "5"])
payload = json.loads(export.read_text(encoding="utf-8"))
check("the JSON export carries every shot",
      {row["file"] for row in payload["shots"]} == {"01_one.png", "02_two.png"},
      str(payload)[:200])
check("...and the tolerance it was judged against",
      payload["max_changed_px"] == 5 and payload["max_channel_delta"] == 0)


# --------------------------------------------------------------------- summary
failures = [entry for entry in results if not entry[1]]
for name, ok, detail in results:
    if not ok:
        print(f"FAIL {name}" + (f"  -> {detail}" if detail else ""))
shutil.rmtree(WORK, ignore_errors=True)
print(f"\n{len(results) - len(failures)}/{len(results)} checks passed")
raise SystemExit(1 if failures else 0)
