#!/usr/bin/env python3
"""Validate the flat-wall sample sources, import settings, and preset references."""

from __future__ import annotations

import hashlib
import re
import xml.etree.ElementTree as ET
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = PROJECT_ROOT / "assets/art/structures/terracotta_warriors/walls"
SCENE_PATH = PROJECT_ROOT / "scenes/dev/art/terracotta_warriors/walls/red_wall_plane_3d.tscn"
SCRIPT_PATH = PROJECT_ROOT / "scripts/dev/art/wall_plane_sample_3d.gd"
STATES = ("intact", "breached", "repairing")


def validate_svg_and_import(state: str) -> None:
    source = ASSET_ROOT / f"red_wall_{state}.svg"
    root = ET.parse(source).getroot()
    if root.attrib.get("width") != "2048" or root.attrib.get("height") != "192":
        raise RuntimeError(f"{source.name}: expected 2048x192")
    sidecar = Path(f"{source}.import").read_text(encoding="utf-8")
    res_path = f"res://{source.relative_to(PROJECT_ROOT).as_posix()}"
    expected_hash = hashlib.md5(res_path.encode("utf-8")).hexdigest()
    required = (
        expected_hash,
        "compress/mode=2",
        "mipmaps/generate=true",
        "process/fix_alpha_border=true",
        "process/size_limit=2048",
    )
    missing = [item for item in required if item not in sidecar]
    if missing:
        raise RuntimeError(f"{source.name}.import missing: {missing}")


def validate_scene() -> None:
    scene = SCENE_PATH.read_text(encoding="utf-8")
    declared = set(re.findall(r'\[ext_resource[^]]* id="([^"]+)"', scene))
    referenced = set(re.findall(r'ExtResource\("([^"]+)"\)', scene))
    if not referenced.issubset(declared):
        raise RuntimeError(f"undeclared external resources: {sorted(referenced - declared)}")
    for node_name in ("Intact", "Breached", "Repairing"):
        if f'name="{node_name}"' not in scene:
            raise RuntimeError(f"missing preset node: {node_name}")
    if "Collision" in scene or "Area3D" in scene:
        raise RuntimeError("wall sample must not own collision or input areas")


def validate_script_boundary() -> None:
    script = SCRIPT_PATH.read_text(encoding="utf-8")
    for forbidden in ("invading_piece_count", "repair_progress", "hidden_timer", "FullState"):
        if forbidden in script:
            raise RuntimeError(f"forbidden information dependency: {forbidden}")
    for status in ("INTACT", "BREACHED", "REPAIRING"):
        if status not in script:
            raise RuntimeError(f"missing public wall status: {status}")


def main() -> int:
    for state in STATES:
        validate_svg_and_import(state)
    validate_scene()
    validate_script_boundary()
    print(
        "WALL_STATIC_ASSET_PASS "
        "states=3 size=2048x192 imports=vram+mipmap preset_nodes=3 information_boundary=pass"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
