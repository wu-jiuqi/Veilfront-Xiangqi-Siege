#!/usr/bin/env python3
"""Convert a baked light checkerboard into real PNG transparency.

The operation is deliberately conservative: it flood-fills only light pixels
connected to explicit background seeds. This preserves enclosed dark UI faces
and metallic highlights while removing the generated preview background.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


DEFAULT_GLOB = "*.png"
FILL_COLOR = (1, 0, 1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--threshold", type=int, default=34)
    parser.add_argument("--backup-dir", default="source_rgb")
    parser.add_argument("--name", help="Process one PNG filename instead of the directory glob")
    parser.add_argument("--validate", action="store_true", help="Validate production PNG alpha contracts")
    return parser.parse_args()


def background_seeds(path: Path, size: tuple[int, int]) -> list[tuple[int, int]]:
    width, height = size
    seeds = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    if path.name == "minimap_frame_v1.png":
        seeds.append((width // 2, height // 2))
    return seeds


def build_alpha(source: Image.Image, seeds: list[tuple[int, int]], threshold: int) -> Image.Image:
    work = source.convert("RGB")
    original = work.copy()
    for seed in seeds:
        ImageDraw.floodfill(work, seed, FILL_COLOR, thresh=threshold)

    original_array = np.asarray(original)
    work_array = np.asarray(work)
    changed = np.any(work_array != original_array, axis=2)
    transparent = Image.fromarray((changed.astype(np.uint8) * 255), mode="L")

    # Remove a one-pixel checkerboard fringe, then soften only that cut edge.
    transparent = transparent.filter(ImageFilter.MaxFilter(3))
    transparent = transparent.filter(ImageFilter.GaussianBlur(0.55))
    return Image.eval(transparent, lambda value: 255 - value)


def process_file(path: Path, args: argparse.Namespace) -> dict[str, int | str]:
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        alpha = build_alpha(rgb, background_seeds(path, rgb.size), args.threshold)
        histogram = alpha.histogram()
        transparent_pixels = sum(histogram[:8])
        opaque_pixels = sum(histogram[248:])
        total_pixels = rgb.width * rgb.height

        if args.apply:
            backup_dir = path.parent / args.backup_dir
            backup_dir.mkdir(exist_ok=True)
            backup_path = backup_dir / path.name
            if not backup_path.exists():
                shutil.copy2(path, backup_path)
            rgba = rgb.convert("RGBA")
            rgba.putalpha(alpha)
            rgba.save(path, format="PNG", optimize=True)

    return {
        "name": path.name,
        "width": rgb.width,
        "height": rgb.height,
        "transparent": transparent_pixels,
        "opaque": opaque_pixels,
        "total": total_pixels,
    }


def validate_file(path: Path) -> None:
    with Image.open(path) as image:
        if image.mode != "RGBA":
            raise ValueError(f"{path.name}: expected RGBA, got {image.mode}")
        alpha = image.getchannel("A")
        width, height = image.size
        if alpha.getpixel((0, 0)) != 0:
            raise ValueError(f"{path.name}: exterior corner is not transparent")
        center_alpha = alpha.getpixel((width // 2, height // 2))
        if path.name in {"minimap_frame_v1.png", "ui_decor_atlas_v1.png"}:
            if center_alpha != 0:
                raise ValueError(f"{path.name}: transparent center contract failed")
        elif path.name == "action_button_states_v1.png":
            for index in range(4):
                x = int((index + 0.5) * width / 4)
                if alpha.getpixel((x, height // 2)) < 248:
                    raise ValueError(f"{path.name}: state {index} center is not opaque")
        elif center_alpha < 248:
            raise ValueError(f"{path.name}: solid center contract failed")


def validate_directory(directory: Path) -> int:
    files = sorted(path for path in directory.glob(DEFAULT_GLOB) if path.is_file())
    for path in files:
        validate_file(path)
        print(f"VALID {path.name}")
    return 0


def main() -> int:
    args = parse_args()
    directory = args.directory.resolve()
    if args.validate:
        return validate_directory(directory)
    if args.name:
        files = [directory / args.name]
    else:
        files = sorted(path for path in directory.glob(DEFAULT_GLOB) if path.is_file())
    if not files:
        raise SystemExit(f"No PNG files found in {directory}")

    for path in files:
        stats = process_file(path, args)
        mode = "APPLY" if args.apply else "DRY-RUN"
        print(
            f"{mode} {stats['name']} {stats['width']}x{stats['height']} "
            f"transparent={stats['transparent']}/{stats['total']} "
            f"opaque={stats['opaque']}/{stats['total']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
