#!/usr/bin/env python3
"""Resize an RGBA source with premultiplied alpha to avoid pale edge halos."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def resize_premultiplied(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    alpha = rgba[..., 3:4]
    premultiplied = rgba[..., :3] * alpha

    premul_image = Image.fromarray(
        np.rint(premultiplied * 255.0).astype(np.uint8), mode="RGB"
    ).resize(size, Image.Resampling.LANCZOS)
    alpha_image = Image.fromarray(
        np.rint(alpha[..., 0] * 255.0).astype(np.uint8), mode="L"
    ).resize(size, Image.Resampling.LANCZOS)

    resized_premul = np.asarray(premul_image, dtype=np.float32) / 255.0
    resized_alpha = np.asarray(alpha_image, dtype=np.float32) / 255.0
    safe_alpha = np.maximum(resized_alpha[..., None], 1.0 / 255.0)
    straight_rgb = np.clip(resized_premul / safe_alpha, 0.0, 1.0)
    straight_rgb[resized_alpha <= 0.0] = 0.0
    output = np.dstack((straight_rgb, resized_alpha))
    return Image.fromarray(np.rint(output * 255.0).astype(np.uint8), mode="RGBA")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--size", required=True, metavar="WIDTHxHEIGHT")
    args = parser.parse_args()

    width, height = args.size.lower().split("x", maxsplit=1)
    result = resize_premultiplied(
        Image.open(args.source), (int(width), int(height))
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output, optimize=True)

    alpha = np.asarray(result.getchannel("A"))
    print(
        {
            "source": str(args.source),
            "output": str(args.output),
            "size": result.size,
            "mode": result.mode,
            "alpha_min": int(alpha.min()),
            "alpha_max": int(alpha.max()),
            "corner_alpha": [
                int(alpha[0, 0]),
                int(alpha[0, -1]),
                int(alpha[-1, 0]),
                int(alpha[-1, -1]),
            ],
        }
    )


if __name__ == "__main__":
    main()
