# tools/prepare_spine_portrait.py
#!/usr/bin/env python3
"""
Validate a Spine 4.2 binary skeleton, normalize its atlas to the supplied PNG,
and generate a shared SpineSkeletonDataResource for spine-godot.

Example:
python tools/prepare_spine_portrait.py \
    --skel downloads/300101_zhujue.skel \
    --atlas downloads/300101_zhujue.atlas \
    --png downloads/300101_zhujue.png \
    --json downloads/300101_zhujue.json \
    --bloom downloads/300101_zhujue_bloom.png \
    --name 300101_zhujue \
    --out res://Scenes/GameUI/GraphicalUI/BattleUnit/Spine/300101_zhujue
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import struct
from pathlib import Path


def png_size(path: Path) -> tuple[int, int]:
    """Read the PNG dimensions without requiring Pillow."""
    with path.open("rb") as file:
        header = file.read(24)

    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a valid PNG: {path}")

    return struct.unpack(">II", header[16:24])


def read_positive_varint(
    data: bytes,
    offset: int,
) -> tuple[int, int]:
    """Read Spine's positive, 7-bit variable-length integer."""
    result = 0
    shift = 0

    for _ in range(5):
        if offset >= len(data):
            raise ValueError("Unexpected end of binary skeleton data")

        byte = data[offset]
        offset += 1

        result |= (byte & 0x7F) << shift

        if (byte & 0x80) == 0:
            return result, offset

        shift += 7

    raise ValueError("Invalid variable-length integer in binary skeleton")


def read_binary_spine_version(path: Path) -> str:
    """
    Read the version from a Spine 4.x binary header.
    """
    data = path.read_bytes()

    if data.lstrip().startswith(b"{"):
        raise ValueError(
            f"{path} contains JSON text despite its .skel extension. "
            "Use the actual binary .skel export, or supply the JSON file "
            "with a .spine-json extension instead."
        )

    if len(data) < 9:
        raise ValueError(
            f"{path} is too short to be a Spine binary skeleton"
        )

    # Skip the 64-bit hash present in the Spine 4.x binary format.
    string_count, offset = read_positive_varint(data, 8)

    if string_count <= 1:
        raise ValueError(
            "The binary skeleton does not contain a Spine version string"
        )

    version_byte_count = string_count - 1

    if version_byte_count > 64:
        raise ValueError(
            "Invalid version-string length. This does not appear to be "
            "a supported Spine 4.x binary skeleton"
        )

    version_end = offset + version_byte_count
    if version_end > len(data):
        raise ValueError("Unexpected end of binary skeleton version string")

    try:
        version = data[offset:version_end].decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError(
            "Invalid UTF-8 in the binary skeleton version string"
        ) from exc

    if not re.match(r"^\d+\.\d+\.\d+", version):
        raise ValueError(
            f"Unexpected Spine version string: {version!r}. "
            "The file may not be a valid Spine 4.x binary skeleton"
        )

    return version


def parse_int_pair(value: str, field: str) -> tuple[int, int]:
    try:
        first, second = value.split(",", 1)
        return int(first.strip()), int(second.strip())
    except ValueError as exc:
        raise ValueError(f"Invalid atlas {field}: {value!r}") from exc


def scaled_pair(value: str, scale: float, field: str) -> str:
    x, y = parse_int_pair(value, field)

    # Atlas rectangles must remain at least one pixel wide/high.
    return (
        f"{max(1, round(x * scale))}, "
        f"{max(1, round(y * scale))}"
    )


def normalize_atlas(
    atlas_text: str,
    actual_size: tuple[int, int],
) -> tuple[str, tuple[int, int], float]:
    """Scale a single-page libgdx/Spine atlas to the actual PNG dimensions."""
    page_match = re.search(
        r"^size:\s*(\d+),\s*(\d+)\s*$",
        atlas_text,
        re.MULTILINE,
    )
    if not page_match:
        raise ValueError("Could not find atlas page dimensions")

    expected_size = (
        int(page_match.group(1)),
        int(page_match.group(2)),
    )

    if expected_size == actual_size:
        return atlas_text, expected_size, 1.0

    if expected_size[0] <= 0 or expected_size[1] <= 0:
        raise ValueError(f"Invalid atlas dimensions: {expected_size}")

    scale_x = actual_size[0] / expected_size[0]
    scale_y = actual_size[1] / expected_size[1]

    if abs(scale_x - scale_y) > 0.001:
        raise ValueError(
            f"Atlas and PNG have different aspect ratios: "
            f"atlas={expected_size}, PNG={actual_size}. "
            "Supply the original texture or an aspect-correct export."
        )

    scale = scale_x
    output: list[str] = []

    for line in atlas_text.splitlines():
        size_match = re.match(r"^size:\s*(.+)$", line)
        if size_match:
            output.append(f"size: {actual_size[0]}, {actual_size[1]}")
            continue

        pair_match = re.match(
            r"^(\s*)(xy|size|orig|offset):\s*(.+)$",
            line,
        )
        if pair_match:
            indent = pair_match.group(1)
            field = pair_match.group(2)
            value = pair_match.group(3)

            if field == "offset":
                x, y = parse_int_pair(value, field)
                output.append(
                    f"{indent}offset: "
                    f"{round(x * scale)}, {round(y * scale)}"
                )
            else:
                output.append(
                    f"{indent}{field}: "
                    f"{scaled_pair(value, scale, field)}"
                )
            continue

        output.append(line)

    normalized = "\n".join(output)
    if atlas_text.endswith("\n"):
        normalized += "\n"

    return normalized, expected_size, scale


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Prepare a Spine binary skeleton, atlas, and PNG for spine-godot"
        )
    )
    parser.add_argument(
        "--skel",
        type=Path,
        required=True,
        help="Path to the binary Spine .skel file",
    )
    parser.add_argument("--atlas", type=Path, required=True)
    parser.add_argument("--png", type=Path, required=True)
    parser.add_argument(
        "--json", 
        type=Path, 
        required=False, 
        help="Optional: Path to the JSON version of the skeleton to display animations."
    )
    parser.add_argument(
        "--bloom", 
        type=Path, 
        required=False, 
        help="Optional: Path to the bloom/emission PNG."
    )
    parser.add_argument("--name", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"[A-Za-z0-9_]+", args.name):
        raise ValueError(
            "--name may contain only letters, numbers, and underscores"
        )

    if args.skel.suffix.lower() != ".skel":
        raise ValueError(
            f"Expected a .skel file, received: {args.skel}"
        )

    spine_version = read_binary_spine_version(args.skel)

    if not spine_version.startswith("4.2."):
        raise ValueError(
            f"Expected a Spine 4.2 binary export, "
            f"found {spine_version!r}. "
            "Use a compatible runtime or re-export from Spine 4.2."
        )

    atlas_bytes = args.atlas.read_bytes()

    if b"\x00" in atlas_bytes:
        raise ValueError(
            "The atlas contains NUL bytes. It is probably UTF-16/UTF-32 "
            "encoded. Save it as UTF-8, or convert it before running this tool."
        )

    # Remove a possible UTF-8 BOM and normalize all line endings.
    atlas_text = atlas_bytes.decode("utf-8-sig")
    atlas_text = atlas_text.replace("\r\n", "\n").replace("\r", "\n")

    if not atlas_text.strip():
        raise ValueError("The atlas file is empty")

    actual_size = png_size(args.png)
    first_line = atlas_text.splitlines()[0].strip()

    if first_line != f"{args.name}.png":
        raise ValueError(
            f"Unexpected atlas page-image name: {first_line!r}. "
            f"Expected {args.name + '.png'!r}"
        )

    normalized_atlas, original_size, scale = normalize_atlas(
        atlas_text,
        actual_size,
    )

    if "pma: true" in atlas_text.lower():
        raise ValueError(
            "This atlas uses premultiplied alpha. Export a "
            "non-premultiplied-alpha atlas for spine-godot."
        )

    args.out.mkdir(parents=True, exist_ok=True)

    skeleton_out = args.out / f"{args.name}.skel"
    atlas_out = args.out / f"{args.name}.atlas"
    png_out = args.out / f"{args.name}.png"
    resource_out = args.out / f"{args.name}.tres"

    # Binary data must be copied as bytes; do not decode or re-encode it.
    shutil.copy2(args.skel, skeleton_out)

    normalized_atlas = normalized_atlas.rstrip("\r\n")
    atlas_out.write_text(
        normalized_atlas,
        encoding="utf-8",
        newline="\n",
    )

    shutil.copy2(args.png, png_out)

    resource_out.write_text(
        f'''[gd_resource type="SpineSkeletonDataResource" load_steps=3 format=3]

[ext_resource type="SpineSkeletonFileResource" path="{skeleton_out.as_posix()}" id="1_skeleton"]
[ext_resource type="SpineAtlasResource" path="{atlas_out.as_posix()}" id="2_atlas"]

[resource]
skeleton_file_res = ExtResource("1_skeleton")
atlas_res = ExtResource("2_atlas")
''',
        encoding="utf-8",
    )

    print(f"Skeleton: binary Spine {spine_version}")

    if scale != 1.0:
        print(
            f"Normalized atlas: "
            f"{original_size[0]}x{original_size[1]} "
            f"-> {actual_size[0]}x{actual_size[1]} "
            f"(scale {scale:.6f})"
        )
    else:
        print(f"Atlas already matches PNG: {actual_size}")

    print(f"Prepared: {args.out}")

    # Handle Bloom file if provided
    if args.bloom:
        if args.bloom.exists():
            bloom_out = args.out / f"{args.name}_bloom.png"
            shutil.copy2(args.bloom, bloom_out)
            print(f"Copied bloom map to: {bloom_out.name}")
        else:
            print(f"Warning: Provided bloom file not found at {args.bloom}")

    # Read animations from provided JSON if it exists
    if args.json:
        if args.json.exists():
            try:
                with args.json.open("r", encoding="utf-8") as f:
                    data = json.load(f)
                    animations = list(data.get("animations", {}).keys())
                    if animations:
                        print(f"Detected animations ({len(animations)}): {', '.join(animations)}")
                    else:
                        print("JSON provided, but no animations found inside.")
            except Exception as e:
                print(f"Warning: Could not parse JSON file: {e}")
        else:
            print(f"Warning: Provided JSON file not found at {args.json}")

    print(
        "Open Godot and allow the new assets to finish importing. "
        "Godot/spine-godot will perform full skeleton validation."
    )


if __name__ == "__main__":
    main()