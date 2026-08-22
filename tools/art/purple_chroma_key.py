#!/usr/bin/env python3
"""Convert a solid purple-screen PNG into a tightly cropped RGBA game asset."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


KEY_RGB = np.array((255.0, 0.0, 255.0), dtype=np.float32)


def key_image(
	source: Path,
	destination: Path,
	key_distance: float,
	despill_distance: float,
	feather_radius: float,
	padding: int,
	max_size: int,
	square_canvas: bool,
) -> None:
	source_image = Image.open(source).convert("RGBA")
	pixels = np.asarray(source_image, dtype=np.uint8).copy()
	rgb = pixels[:, :, :3].astype(np.float32)
	distance = np.linalg.norm(rgb - KEY_RGB, axis=2)
	foreground = distance >= key_distance
	binary_alpha = Image.fromarray((foreground * 255).astype(np.uint8), mode="L")
	soft_alpha = binary_alpha.filter(ImageFilter.GaussianBlur(feather_radius))
	# Feather inward only so no purple background pixel contributes visible RGB.
	alpha = np.minimum(np.asarray(soft_alpha, dtype=np.uint8), np.asarray(binary_alpha))
	alpha = (
		alpha.astype(np.float32) * (pixels[:, :, 3].astype(np.float32) / 255.0)
	).astype(np.uint8)

	# Suppress magenta spill on the retained antialiased edge without damaging red,
	# gold, silver, or green faction materials.
	spill = np.maximum(0.0, np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1])
	despill_strength = 1.0 - np.clip(
		(distance - key_distance) / max(despill_distance - key_distance, 1.0), 0.0, 1.0
	)
	despill_strength = np.where(alpha < 250, 1.0, despill_strength)
	rgb[:, :, 0] -= spill * despill_strength
	rgb[:, :, 2] -= spill * despill_strength
	pixels[:, :, :3] = np.clip(rgb, 0.0, 255.0).astype(np.uint8)
	pixels[:, :, 3] = alpha
	pixels[alpha == 0, :3] = 0
	image = Image.fromarray(pixels, mode="RGBA")

	width, height = image.size
	alpha_channel = image.getchannel("A")
	bbox = alpha_channel.point(lambda value: 255 if value >= 8 else 0).getbbox()
	if bbox is None:
		raise ValueError(f"No foreground remained after chroma keying: {source}")
	left = max(0, bbox[0] - padding)
	top = max(0, bbox[1] - padding)
	right = min(width, bbox[2] + padding)
	bottom = min(height, bbox[3] + padding)
	image = image.crop((left, top, right, bottom))
	if square_canvas and image.width != image.height:
		side = max(image.size)
		square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
		square.alpha_composite(
			image,
			((side - image.width) // 2, (side - image.height) // 2),
		)
		image = square
	if max_size > 0 and max(image.size) > max_size:
		scale = max_size / float(max(image.size))
		resized = (
			max(1, round(image.width * scale)),
			max(1, round(image.height * scale)),
		)
		image = image.resize(resized, Image.Resampling.LANCZOS)

	destination.parent.mkdir(parents=True, exist_ok=True)
	image.save(destination, format="PNG", optimize=True)


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("source", type=Path)
	parser.add_argument("destination", type=Path)
	parser.add_argument("--key-distance", type=float, default=68.0)
	parser.add_argument("--despill-distance", type=float, default=190.0)
	parser.add_argument("--feather-radius", type=float, default=1.1)
	parser.add_argument("--padding", type=int, default=24)
	parser.add_argument("--max-size", type=int, default=0)
	parser.add_argument("--square-canvas", action="store_true")
	args = parser.parse_args()
	key_image(
		args.source,
		args.destination,
		args.key_distance,
		args.despill_distance,
		args.feather_radius,
		args.padding,
		args.max_size,
		args.square_canvas,
	)


if __name__ == "__main__":
	main()
