#!/usr/bin/env python3
"""Compare printer streams with alignment, regions, entropy, and byte evidence."""
from __future__ import annotations

import argparse
import difflib
import hashlib
import math
from pathlib import Path


RASTER_START = b"\x1b*r1A"
RASTER_END = b"\x1b*rC"
PJL_ENTER = b"@PJL ENTER LANGUAGE=PCL3GUI\n"


def entropy(data: bytes) -> float:
    if not data:
        return 0.0
    counts = [0] * 256
    for value in data:
        counts[value] += 1
    size = len(data)
    return -sum(
        (count / size) * math.log2(count / size) for count in counts if count
    )


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def stream_regions(data: bytes) -> dict[str, tuple[int, int]]:
    raster_start = data.find(RASTER_START)
    raster_end = data.find(RASTER_END, raster_start + len(RASTER_START))
    pjl_end = data.find(PJL_ENTER)
    if pjl_end >= 0:
        pjl_end += len(PJL_ENTER)
    else:
        pjl_end = max(raster_start, 0)
    if raster_start < 0:
        raster_start = len(data)
    if raster_end < 0:
        raster_end = len(data)
    else:
        raster_end += len(RASTER_END)
    return {
        "pjl": (0, min(pjl_end, len(data))),
        "pcl_init": (min(pjl_end, len(data)), min(raster_start, len(data))),
        "raster": (min(raster_start, len(data)), min(raster_end, len(data))),
        "trailer": (min(raster_end, len(data)), len(data)),
    }


def preview(data: bytes, limit: int) -> str:
    clipped = data[:limit]
    suffix = " ..." if len(data) > limit else ""
    return clipped.hex(" ") + suffix


def ascii_preview(data: bytes, limit: int) -> str:
    clipped = data[:limit]
    text = "".join(chr(value) if 32 <= value <= 126 else "." for value in clipped)
    return text + ("..." if len(data) > limit else "")


def aligned_differences(a: bytes, b: bytes):
    matcher = difflib.SequenceMatcher(None, a, b, autojunk=True)
    differences = [
        opcode for opcode in matcher.get_opcodes() if opcode[0] != "equal"
    ]
    return matcher, differences


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("a", type=Path)
    parser.add_argument("b", type=Path)
    parser.add_argument("--max-runs", type=int, default=20)
    parser.add_argument("--max-bytes", type=int, default=48)
    parser.add_argument("--common-blocks", type=int, default=8)
    args = parser.parse_args()

    a = args.a.read_bytes()
    b = args.b.read_bytes()
    print(
        f"A: {args.a} bytes={len(a)} sha256={digest(a)} entropy={entropy(a):.4f}"
    )
    print(
        f"B: {args.b} bytes={len(b)} sha256={digest(b)} entropy={entropy(b):.4f}"
    )

    regions_a = stream_regions(a)
    regions_b = stream_regions(b)
    print("regions:")
    for name in ("pjl", "pcl_init", "raster", "trailer"):
        a_start, a_end = regions_a[name]
        b_start, b_end = regions_b[name]
        a_region = a[a_start:a_end]
        b_region = b[b_start:b_end]
        print(
            f"  {name}: A=[0x{a_start:x},0x{a_end:x})/{len(a_region)} "
            f"B=[0x{b_start:x},0x{b_end:x})/{len(b_region)} "
            f"equal={a_region == b_region} "
            f"entropy={entropy(a_region):.4f}/{entropy(b_region):.4f} "
            f"sha256={digest(a_region)[:16]}/{digest(b_region)[:16]}"
        )

    matcher, differences = aligned_differences(a, b)
    print(f"aligned-difference-runs={len(differences)}")
    for index, (tag, a_start, a_end, b_start, b_end) in enumerate(
        differences[: args.max_runs], 1
    ):
        region_a = next(
            (
                name
                for name, (start, end) in regions_a.items()
                if start <= a_start < end
            ),
            "end",
        )
        region_b = next(
            (
                name
                for name, (start, end) in regions_b.items()
                if start <= b_start < end
            ),
            "end",
        )
        a_bytes = a[a_start:a_end]
        b_bytes = b[b_start:b_end]
        print(
            f"difference={index} tag={tag} "
            f"A_offset=0x{a_start:08x} A_length={len(a_bytes)} A_region={region_a} "
            f"B_offset=0x{b_start:08x} B_length={len(b_bytes)} B_region={region_b}"
        )
        print(
            f"  A hex={preview(a_bytes, args.max_bytes)} "
            f"ascii={ascii_preview(a_bytes, args.max_bytes)!r}"
        )
        print(
            f"  B hex={preview(b_bytes, args.max_bytes)} "
            f"ascii={ascii_preview(b_bytes, args.max_bytes)!r}"
        )
    if len(differences) > args.max_runs:
        print(f"omitted-difference-runs={len(differences) - args.max_runs}")

    matching = [
        block for block in matcher.get_matching_blocks() if block.size > 0
    ]
    matching.sort(key=lambda block: block.size, reverse=True)
    print(f"largest-common-blocks={min(len(matching), args.common_blocks)}")
    for block in matching[: args.common_blocks]:
        print(
            f"  A_offset=0x{block.a:08x} B_offset=0x{block.b:08x} "
            f"length={block.size} "
            f"sha256={digest(a[block.a:block.a + block.size])[:16]}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
