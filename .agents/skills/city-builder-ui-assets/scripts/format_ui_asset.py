#!/usr/bin/env python3
"""Preserve a high-resolution UI master and create deterministic PNG derivatives."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from PIL import Image


def parse_sizes(value: str) -> list[int]:
    sizes = []
    for item in value.split(","):
        item = item.strip()
        if item:
            size = int(item)
            if size < 1:
                raise argparse.ArgumentTypeError("sizes must be positive")
            sizes.append(size)
    return sorted(set(sizes))


def save_rgba(image: Image.Image, path: Path, size: int) -> None:
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    resized.save(path, format="PNG", optimize=True, compress_level=9)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--slug", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runtime-size", type=int, default=128)
    parser.add_argument("--proof-sizes", type=parse_sizes, default=parse_sizes("16,20,24"))
    parser.add_argument("--role", default="icon")
    parser.add_argument("--display-min", type=int, default=16)
    parser.add_argument("--display-max", type=int, default=24)
    args = parser.parse_args()

    if args.runtime_size < 1 or args.display_min < 1 or args.display_max < args.display_min:
        parser.error("invalid runtime or display size")
    if not args.input.is_file():
        parser.error(f"input does not exist: {args.input}")

    output = args.output
    master_path = output / "masters" / f"{args.slug}{args.input.suffix.lower()}"
    runtime_path = output / "game" / f"{args.slug}.png"
    master_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.input, master_path)

    with Image.open(args.input) as opened:
        original_size = opened.size
        image = opened.convert("RGBA")
        save_rgba(image, runtime_path, args.runtime_size)
        for size in args.proof_sizes:
            save_rgba(image, output / "review" / f"{size}px" / f"{args.slug}.png", size)

    metadata = {
        "slug": args.slug,
        "role": args.role,
        "source_path": str(master_path.relative_to(output)),
        "source_dimensions": list(original_size),
        "runtime_path": str(runtime_path.relative_to(output)),
        "runtime_dimensions": [args.runtime_size, args.runtime_size],
        "display_size_range": [args.display_min, args.display_max],
        "format": "PNG",
        "colour_mode": "RGBA",
        "resampling": "Lanczos",
        "proof_sizes": args.proof_sizes,
    }
    metadata_path = output / "manifests" / f"{args.slug}.json"
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(metadata_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
