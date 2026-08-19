#!/usr/bin/env python3
"""Convert a flat purple/green screen image into a clean RGBA asset."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def _border_pixels(rgb: np.ndarray, width: int) -> np.ndarray:
    return np.concatenate(
        (
            rgb[:width].reshape(-1, 3),
            rgb[-width:].reshape(-1, 3),
            rgb[:, :width].reshape(-1, 3),
            rgb[:, -width:].reshape(-1, 3),
        ),
        axis=0,
    )


def remove_chroma(
    source: Path,
    output: Path,
    screen: str,
    border: int,
    opaque_floor: float,
    canvas_size: tuple[int, int] | None,
) -> dict[str, object]:
    image = Image.open(source).convert("RGB")
    rgb = np.asarray(image, dtype=np.float32) / 255.0
    key = np.median(_border_pixels(rgb, border), axis=0)

    if screen == "purple":
        dominance = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
        key_dominance = min(key[0], key[2]) - key[1]
        border_rgb = _border_pixels(rgb, border)
        border_dominance = (
            np.minimum(border_rgb[:, 0], border_rgb[:, 2]) - border_rgb[:, 1]
        )
    else:
        dominance = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
        key_dominance = key[1] - max(key[0], key[2])
        border_rgb = _border_pixels(rgb, border)
        border_dominance = border_rgb[:, 1] - np.maximum(
            border_rgb[:, 0], border_rgb[:, 2]
        )

    if key_dominance < 0.35:
        raise ValueError(
            f"Border is not a strong {screen} screen: dominance={key_dominance:.3f}"
        )

    background_cutoff = max(0.50, float(border_dominance.min()) - 0.02)
    alpha = np.clip(
        (background_cutoff - dominance)
        / max(background_cutoff - opaque_floor, 1e-6),
        0.0,
        1.0,
    )
    alpha[alpha < 0.015] = 0.0
    alpha[alpha > 0.985] = 1.0

    # Reverse the screen composite on edge pixels to remove purple/green spill.
    reconstructed = np.zeros_like(rgb)
    stable_alpha = np.maximum(alpha[..., None], 1.0 / 255.0)
    reconstructed = (rgb - (1.0 - alpha[..., None]) * key) / stable_alpha
    reconstructed = np.clip(reconstructed, 0.0, 1.0)
    reconstructed[alpha >= 0.985] = rgb[alpha >= 0.985]
    reconstructed[alpha <= 0.0] = 0.0

    rgba = np.dstack((reconstructed, alpha))
    result = Image.fromarray(np.rint(rgba * 255.0).astype(np.uint8), mode="RGBA")
    if canvas_size is not None and result.size != canvas_size:
        if result.width > canvas_size[0] or result.height > canvas_size[1]:
            raise ValueError(
                f"Source {result.size} exceeds requested canvas {canvas_size}; refusing crop"
            )
        canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        canvas.paste(result, (0, 0))
        result = canvas
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output, optimize=True)

    alpha_u8 = np.asarray(result.getchannel("A"))
    return {
        "source": str(source),
        "output": str(output),
        "size": result.size,
        "mode": result.mode,
        "screen": screen,
        "estimated_key_rgb": [int(round(channel * 255)) for channel in key],
        "key_dominance": round(float(key_dominance), 4),
        "background_cutoff": round(float(background_cutoff), 4),
        "alpha_min": int(alpha_u8.min()),
        "alpha_max": int(alpha_u8.max()),
        "transparent": int(np.count_nonzero(alpha_u8 == 0)),
        "partial": int(np.count_nonzero((alpha_u8 > 0) & (alpha_u8 < 255))),
        "opaque": int(np.count_nonzero(alpha_u8 == 255)),
        "corner_alpha": [
            int(alpha_u8[0, 0]),
            int(alpha_u8[0, -1]),
            int(alpha_u8[-1, 0]),
            int(alpha_u8[-1, -1]),
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--screen", choices=("purple", "green"), default="purple")
    parser.add_argument("--border", type=int, default=12)
    parser.add_argument(
        "--opaque-floor",
        type=float,
        default=0.10,
        help="screen dominance treated as fully opaque subject, in normalized RGB",
    )
    parser.add_argument("--canvas-size", metavar="WIDTHxHEIGHT")
    args = parser.parse_args()
    canvas_size = None
    if args.canvas_size:
        width, height = args.canvas_size.lower().split("x", maxsplit=1)
        canvas_size = (int(width), int(height))
    print(
        remove_chroma(
            args.source,
            args.output,
            args.screen,
            args.border,
            args.opaque_floor,
            canvas_size,
        )
    )


if __name__ == "__main__":
    main()
