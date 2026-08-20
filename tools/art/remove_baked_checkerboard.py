#!/usr/bin/env python3
"""Convert a baked light checkerboard into real PNG transparency.

The operation is deliberately conservative: it flood-fills only light pixels
connected to explicit background seeds. This preserves enclosed dark UI faces
and metallic highlights while removing the generated preview background.

HUD V2 additionally supports a deterministic purple-screen repair pass. It
first builds the coarse checkerboard matte, keeps only seeded UI components,
places them on an exact #FF00FF screen, and keys that screen back to alpha.
The RGB source artwork is never regenerated or recoloured.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


DEFAULT_GLOB = "*.png"
FILL_COLOR = (1, 0, 1)
PURPLE_SCREEN = (255, 0, 255)
MASK_FOREGROUND = (255, 255, 255)
MASK_BACKGROUND = (0, 0, 0)
MASK_KEEP = (128, 0, 0)
VISIBLE_ALPHA_THRESHOLD = 8
PALE_LUMA_THRESHOLD = 170
PALE_CHROMA_THRESHOLD = 36
INTERIOR_FILTER_SIZE = 9

# Normalized points deliberately land inside every independent production
# component. They are part of the extraction contract, not inferred content.
LEGITIMATE_SEEDS: dict[str, list[tuple[float, float]]] = {
    "action_bar_frame_v1.png": [(0.50, 0.50)],
    "action_button_states_v1.png": [
        (0.125, 0.50),
        (0.375, 0.50),
        (0.625, 0.50),
        (0.875, 0.50),
    ],
    "faction_status_plate_v1.png": [(0.50, 0.50)],
    "hud_panel_9slice_v1.png": [(0.50, 0.50)],
    "minimap_frame_v1.png": [(0.50, 0.08)],
    "objective_event_panel_v1.png": [(0.50, 0.50)],
    "turn_status_bar_v1.png": [(0.50, 0.50)],
    "ui_decor_atlas_v1.png": [
        (0.14, 0.28),
        (0.37, 0.28),
        (0.63, 0.28),
        (0.86, 0.28),
        (0.15, 0.63),
        (0.38, 0.63),
        (0.86, 0.63),
    ],
    "unit_info_card_v1.png": [(0.50, 0.50)],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--threshold", type=int, default=34)
    parser.add_argument("--backup-dir", default="source_rgb")
    parser.add_argument("--name", help="Process one PNG filename instead of the directory glob")
    parser.add_argument("--validate", action="store_true", help="Validate production PNG alpha contracts")
    parser.add_argument(
        "--chroma-repair",
        action="store_true",
        help="Rebuild HUD V2 alpha through a deterministic #FF00FF intermediate",
    )
    parser.add_argument(
        "--preview-dir",
        type=Path,
        help="Optional directory for purple-screen and dark-background inspection PNGs",
    )
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


def _find_seed(mask: Image.Image, point: tuple[float, float]) -> tuple[int, int]:
    width, height = mask.size
    origin_x = min(width - 1, max(0, int(point[0] * width)))
    origin_y = min(height - 1, max(0, int(point[1] * height)))
    pixels = mask.load()
    max_radius = min(100, max(width, height))
    for radius in range(max_radius + 1):
        candidates = (
            (origin_x + radius, origin_y),
            (origin_x - radius, origin_y),
            (origin_x, origin_y + radius),
            (origin_x, origin_y - radius),
        )
        for x, y in candidates:
            if 0 <= x < width and 0 <= y < height and pixels[x, y] == MASK_FOREGROUND:
                return x, y
    raise ValueError(f"No foreground pixel found near normalized seed {point}")


def build_legitimate_mask(path: Path, rgb: Image.Image, alpha: Image.Image) -> np.ndarray:
    seed_points = LEGITIMATE_SEEDS.get(path.name)
    if not seed_points:
        raise ValueError(f"{path.name}: no legitimate component seeds configured")

    rgb_array = np.asarray(rgb.convert("RGB"), dtype=np.int16)
    alpha_array = np.asarray(alpha, dtype=np.uint8)
    visible = alpha_array > VISIBLE_ALPHA_THRESHOLD
    luma = rgb_array.mean(axis=2)
    chroma = rgb_array.max(axis=2) - rgb_array.min(axis=2)
    pale_neutral = (luma >= PALE_LUMA_THRESHOLD) & (chroma <= PALE_CHROMA_THRESHOLD)

    visible_image = Image.fromarray(visible.astype(np.uint8) * 255, mode="L")
    interior = np.asarray(
        visible_image.filter(ImageFilter.MinFilter(INTERIOR_FILTER_SIZE)),
        dtype=np.uint8,
    ) > 0
    candidate = visible & (~pale_neutral | interior)
    mask_array = np.where(candidate[..., None], MASK_FOREGROUND, MASK_BACKGROUND).astype(np.uint8)
    mask = Image.fromarray(mask_array, mode="RGB")

    for point in seed_points:
        seed = _find_seed(mask, point)
        ImageDraw.floodfill(mask, seed, MASK_KEEP, thresh=0)

    keyed_mask = np.asarray(mask, dtype=np.uint8)
    return np.all(keyed_mask == np.asarray(MASK_KEEP, dtype=np.uint8), axis=2)


def build_purple_screen(rgb: Image.Image, legitimate: np.ndarray) -> Image.Image:
    rgb_array = np.asarray(rgb.convert("RGB"), dtype=np.uint8)
    purple = np.empty_like(rgb_array)
    purple[:, :] = PURPLE_SCREEN
    purple[legitimate] = rgb_array[legitimate]
    return Image.fromarray(purple, mode="RGB")


def key_purple_screen(purple: Image.Image, coarse_alpha: Image.Image) -> Image.Image:
    purple_array = np.asarray(purple.convert("RGB"), dtype=np.uint8)
    is_screen = np.all(purple_array == np.asarray(PURPLE_SCREEN, dtype=np.uint8), axis=2)
    alpha_array = np.asarray(coarse_alpha, dtype=np.uint8)
    keyed_alpha = np.where(is_screen, 0, alpha_array).astype(np.uint8)
    return Image.fromarray(keyed_alpha, mode="L")


def save_previews(
    preview_dir: Path,
    name: str,
    purple: Image.Image,
    rgba: Image.Image,
) -> None:
    preview_dir.mkdir(parents=True, exist_ok=True)
    purple.save(preview_dir / f"purple_{name}", format="PNG", optimize=True)
    dark = Image.new("RGBA", rgba.size, (18, 19, 24, 255))
    dark.alpha_composite(rgba)
    dark.convert("RGB").save(preview_dir / f"dark_{name}", format="PNG", optimize=True)


def process_chroma_file(path: Path, args: argparse.Namespace) -> dict[str, int | str]:
    source_path = path.parent / args.backup_dir / path.name
    if not source_path.is_file():
        raise ValueError(f"{path.name}: RGB source not found at {source_path}")

    with Image.open(source_path) as source_image:
        rgb = source_image.convert("RGB")
        coarse_alpha = build_alpha(rgb, background_seeds(path, rgb.size), args.threshold)
        legitimate = build_legitimate_mask(path, rgb, coarse_alpha)
        purple = build_purple_screen(rgb, legitimate)
        alpha = key_purple_screen(purple, coarse_alpha)
        rgba = rgb.convert("RGBA")
        rgba.putalpha(alpha)

        coarse_visible = np.asarray(coarse_alpha, dtype=np.uint8) > VISIBLE_ALPHA_THRESHOLD
        final_visible = np.asarray(alpha, dtype=np.uint8) > VISIBLE_ALPHA_THRESHOLD
        removed_pixels = int(np.count_nonzero(coarse_visible & ~final_visible))
        histogram = alpha.histogram()
        transparent_pixels = sum(histogram[:8])
        opaque_pixels = sum(histogram[248:])
        total_pixels = rgb.width * rgb.height

        if args.preview_dir:
            save_previews(args.preview_dir.resolve(), path.name, purple, rgba)
        if args.apply:
            rgba.save(path, format="PNG", optimize=True)

    return {
        "name": path.name,
        "width": rgb.width,
        "height": rgb.height,
        "transparent": transparent_pixels,
        "opaque": opaque_pixels,
        "removed": removed_pixels,
        "total": total_pixels,
    }


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


def validate_file(path: Path, backup_dir: str, threshold: int) -> None:
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

        if path.name in LEGITIMATE_SEEDS:
            source_path = path.parent / backup_dir / path.name
            if not source_path.is_file():
                raise ValueError(f"{path.name}: RGB source not found at {source_path}")
            with Image.open(source_path) as source_image:
                source_rgb = source_image.convert("RGB")
                source_array = np.asarray(source_rgb, dtype=np.uint8)
                production_array = np.asarray(image.convert("RGB"), dtype=np.uint8)
                recoloured = int(np.count_nonzero(source_array != production_array))
                if recoloured:
                    raise ValueError(f"{path.name}: {recoloured} RGB channels differ from source artwork")
                coarse_alpha = build_alpha(
                    source_rgb,
                    background_seeds(path, source_rgb.size),
                    threshold,
                )
                legitimate = build_legitimate_mask(path, source_rgb, coarse_alpha)
                purple = build_purple_screen(source_rgb, legitimate)
                expected_alpha = key_purple_screen(purple, coarse_alpha)
            actual_array = np.asarray(alpha, dtype=np.uint8)
            expected_array = np.asarray(expected_alpha, dtype=np.uint8)
            mismatched = int(np.count_nonzero(actual_array != expected_array))
            if mismatched:
                raise ValueError(f"{path.name}: {mismatched} alpha pixels differ from purple-screen contract")


def validate_directory(directory: Path, backup_dir: str, threshold: int) -> int:
    files = sorted(path for path in directory.glob(DEFAULT_GLOB) if path.is_file())
    for path in files:
        validate_file(path, backup_dir, threshold)
        print(f"VALID {path.name}")
    return 0


def main() -> int:
    args = parse_args()
    directory = args.directory.resolve()
    if args.validate:
        return validate_directory(directory, args.backup_dir, args.threshold)
    if args.name:
        files = [directory / args.name]
    else:
        files = sorted(path for path in directory.glob(DEFAULT_GLOB) if path.is_file())
    if not files:
        raise SystemExit(f"No PNG files found in {directory}")

    for path in files:
        stats = process_chroma_file(path, args) if args.chroma_repair else process_file(path, args)
        mode = "APPLY" if args.apply else "DRY-RUN"
        removed = f" removed={stats['removed']}" if "removed" in stats else ""
        print(
            f"{mode} {stats['name']} {stats['width']}x{stats['height']} "
            f"transparent={stats['transparent']}/{stats['total']} "
            f"opaque={stats['opaque']}/{stats['total']}{removed}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
