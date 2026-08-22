#!/usr/bin/env python3
"""Extract generated UI artwork from a near-magenta purple screen.

Image generators rarely emit a mathematically flat #FF00FF screen. This tool
builds a soft alpha matte from magenta dominance, removes edge spill against an
estimated screen colour, and optionally trims or resizes the result. The RGB
source remains untouched so production assets can be rebuilt deterministically.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--trim", action="store_true")
    parser.add_argument("--padding", type=int, default=0)
    parser.add_argument("--size", type=int, nargs=2, metavar=("WIDTH", "HEIGHT"))
    parser.add_argument("--max-width", type=int)
    return parser.parse_args()


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    amount = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return amount * amount * (3.0 - 2.0 * amount)


def estimate_screen(rgb: np.ndarray) -> np.ndarray:
    height, width, _channels = rgb.shape
    border = max(1, min(height, width) // 40)
    samples = np.concatenate(
        [
            rgb[:border].reshape(-1, 3),
            rgb[-border:].reshape(-1, 3),
            rgb[:, :border].reshape(-1, 3),
            rgb[:, -border:].reshape(-1, 3),
        ],
        axis=0,
    )
    return np.median(samples, axis=0)


def build_alpha(rgb: np.ndarray) -> np.ndarray:
    red = rgb[..., 0]
    green = rgb[..., 1]
    blue = rgb[..., 2]
    # Generated screen pixels remain red/blue-balanced even where antialiasing
    # darkens them. Intentional violet enamel is more blue-biased, so channel
    # balance is the safest separator at the asset edge.
    magenta_level = smoothstep(92.0, 222.0, np.minimum(red, blue))
    low_green = 1.0 - smoothstep(54.0, 142.0, green)
    balanced_magenta = 1.0 - smoothstep(14.0, 52.0, np.abs(red - blue))
    screen_strength = np.minimum(np.minimum(magenta_level, low_green), balanced_magenta)
    return np.clip(1.0 - screen_strength, 0.0, 1.0)


def suppress_boundary_spill(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    transparent = Image.fromarray(
        ((alpha <= 0.04).astype(np.uint8) * 255), mode="L"
    ).filter(ImageFilter.MaxFilter(7))
    near_background = np.asarray(transparent, dtype=np.uint8) > 0
    red = rgb[..., 0]
    green = rgb[..., 1]
    blue = rgb[..., 2]
    balanced = np.abs(red - blue) < 30.0
    screen_coloured = np.minimum(red, blue) > np.maximum(green * 1.35, 45.0)
    cleaned = alpha.copy()
    cleaned[near_background & balanced & screen_coloured] = 0.0
    return cleaned


def remove_spill(rgb: np.ndarray, alpha: np.ndarray, screen: np.ndarray) -> np.ndarray:
    safe_alpha = np.maximum(alpha[..., None], 0.035)
    foreground = (rgb - (1.0 - alpha[..., None]) * screen) / safe_alpha
    foreground = np.clip(foreground, 0.0, 255.0)
    opaque = alpha >= 0.995
    foreground[opaque] = rgb[opaque]
    return foreground


def trim_transparent(image: Image.Image, padding: int) -> Image.Image:
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    visible_y, visible_x = np.where(alpha > 8)
    if visible_x.size == 0 or visible_y.size == 0:
        raise ValueError("No visible artwork remained after purple-screen extraction")
    left = max(0, int(visible_x.min()) - padding)
    top = max(0, int(visible_y.min()) - padding)
    right = min(image.width, int(visible_x.max()) + 1 + padding)
    bottom = min(image.height, int(visible_y.max()) + 1 + padding)
    return image.crop((left, top, right, bottom))


def resize_output(
    image: Image.Image,
    size: tuple[int, int] | None,
    max_width: int | None,
) -> Image.Image:
    target: tuple[int, int] | None = size
    if target is None and max_width is not None and image.width > max_width:
        scale = max_width / float(image.width)
        target = (max_width, max(1, round(image.height * scale)))
    if target is None or target == image.size:
        return image
    rgba = np.asarray(image, dtype=np.float32) / 255.0
    alpha = rgba[..., 3:4]
    premultiplied = np.dstack([rgba[..., :3] * alpha, alpha])
    resized = Image.fromarray(
        np.round(premultiplied * 255.0).astype(np.uint8), mode="RGBA"
    ).resize(target, Image.Resampling.LANCZOS)
    resized_array = np.asarray(resized, dtype=np.float32) / 255.0
    resized_alpha = resized_array[..., 3:4]
    rgb = np.divide(
        resized_array[..., :3],
        np.maximum(resized_alpha, 1.0 / 255.0),
        out=np.zeros_like(resized_array[..., :3]),
        where=resized_alpha > 0.0,
    )
    straight = np.dstack([np.clip(rgb, 0.0, 1.0), resized_alpha])
    straight[resized_alpha[..., 0] <= 1.0 / 255.0] = 0.0
    return Image.fromarray(np.round(straight * 255.0).astype(np.uint8), mode="RGBA")


def main() -> int:
    args = parse_args()
    with Image.open(args.source) as source_image:
        rgb = np.asarray(source_image.convert("RGB"), dtype=np.float32)
    screen = estimate_screen(rgb)
    alpha = suppress_boundary_spill(rgb, build_alpha(rgb))
    foreground = remove_spill(rgb, alpha, screen)
    foreground[alpha <= 0.005] = 0.0
    rgba = np.dstack(
        [
            foreground.astype(np.uint8),
            np.round(alpha * 255.0).astype(np.uint8),
        ]
    )
    output = Image.fromarray(rgba, mode="RGBA")
    if args.trim:
        output = trim_transparent(output, args.padding)
    requested_size = tuple(args.size) if args.size is not None else None
    output = resize_output(output, requested_size, args.max_width)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, format="PNG", optimize=True)
    alpha_channel = np.asarray(output.getchannel("A"), dtype=np.uint8)
    transparent = int(np.count_nonzero(alpha_channel <= 8))
    opaque = int(np.count_nonzero(alpha_channel >= 248))
    print(
        f"PURPLE_SCREEN_EXTRACT_PASS {args.output} {output.width}x{output.height} "
        f"transparent={transparent} opaque={opaque} screen={screen.round().astype(int).tolist()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
