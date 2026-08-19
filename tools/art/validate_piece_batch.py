#!/usr/bin/env python3
"""Validate the 14-piece purple-screen RGBA runtime batch."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image


SIZE_PATTERN = re.compile(r"-(512x768|768x768)-alpha-v2\.png$")


def validate_file(path: Path) -> dict[str, object]:
    match = SIZE_PATTERN.search(path.name)
    if not match:
        raise ValueError(f"Runtime filename lacks size profile: {path.name}")
    expected = tuple(int(value) for value in match.group(1).split("x"))
    image = Image.open(path)
    if image.mode != "RGBA":
        raise ValueError(f"{path.name}: expected RGBA, got {image.mode}")
    if image.size != expected:
        raise ValueError(f"{path.name}: expected {expected}, got {image.size}")

    rgba = np.asarray(image)
    alpha = rgba[..., 3]
    corners = [
        int(alpha[0, 0]),
        int(alpha[0, -1]),
        int(alpha[-1, 0]),
        int(alpha[-1, -1]),
    ]
    if corners != [0, 0, 0, 0]:
        raise ValueError(f"{path.name}: nontransparent corners {corners}")
    if int(alpha.max()) != 255:
        raise ValueError(f"{path.name}: subject has no fully opaque pixels")

    visible = alpha >= 32
    rgb = rgba[..., :3].astype(np.int16)
    magenta_dominance = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    purple_spill = int(np.count_nonzero(visible & (magenta_dominance > 90)))
    if purple_spill > 8:
        raise ValueError(f"{path.name}: purple spill pixels={purple_spill}")

    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    bbox = image.getchannel("A").getbbox()
    return {
        "file": path.as_posix(),
        "size": list(image.size),
        "mode": image.mode,
        "corner_alpha": corners,
        "alpha_min": int(alpha.min()),
        "alpha_max": int(alpha.max()),
        "partial_alpha_pixels": int(
            np.count_nonzero((alpha > 0) & (alpha < 255))
        ),
        "purple_spill_pixels": purple_spill,
        "alpha_bbox": list(bbox) if bbox else None,
        "sha256": digest,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("runtime_dir", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    paths = sorted(args.runtime_dir.glob("vs-piece-*-alpha-v2.png"))
    if len(paths) != 14:
        raise ValueError(f"Expected 14 runtime PNGs, found {len(paths)}")
    report = {
        "schema_version": "0.1",
        "status": "passed",
        "asset_count": len(paths),
        "method": "purple-screen chroma key + premultiplied-alpha resize",
        "assets": [validate_file(path) for path in paths],
    }
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded)


if __name__ == "__main__":
    main()
