"""Deterministically slice the approved LAN lobby mockup into Godot-ready PNG assets."""

from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = PROJECT_ROOT / "assets/art/ui/lan_lobby/lan_lobby_full_plate_v2.png"
OUTPUT_DIR = PROJECT_ROOT / "assets/art/ui/lan_lobby/slices_v3"
EXPECTED_SIZE = (1672, 941)


# Coordinates are in the approved 1672 x 941 reference canvas.
SLICES: dict[str, tuple[int, int, int, int]] = {
    "header_frame": (0, 0, 1672, 98),
    "return_button": (3, 17, 114, 82),
    "connection_bars": (1477, 34, 1521, 67),
    "room_info_panel": (36, 189, 381, 739),
    "copy_address_button": (82, 491, 334, 556),
    "versus_panel": (393, 189, 1277, 739),
    "rules_panel": (1291, 189, 1635, 739),
    "status_panel": (36, 828, 798, 919),
    "action_group": (816, 828, 1635, 919),
    "disconnect_button": (818, 830, 1077, 917),
    "join_button": (1096, 830, 1336, 917),
    "host_button": (1353, 830, 1633, 917),
}

BACKINGS: dict[str, tuple[tuple[int, int], tuple[int, int, int]]] = {
    "header_status_backing": ((512, 128), (9, 13, 13)),
    "room_value_backing": ((512, 128), (8, 14, 13)),
    "red_status_backing": ((512, 96), (55, 15, 9)),
    "black_status_backing": ((512, 96), (5, 29, 22)),
}


def _crop(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return source.crop(box).convert("RGBA")


def _button_state(source: Image.Image, mode: str) -> Image.Image:
    if mode == "hover":
        state = ImageEnhance.Brightness(source).enhance(1.13)
        glow = Image.new("RGBA", state.size, (214, 162, 55, 0))
        draw = ImageDraw.Draw(glow)
        draw.rectangle((2, 2, state.width - 3, state.height - 3), outline=(235, 185, 70, 185), width=3)
        glow = glow.filter(ImageFilter.GaussianBlur(2.0))
        return Image.alpha_composite(state, glow)
    if mode == "pressed":
        state = ImageEnhance.Brightness(source).enhance(0.88)
        shade = Image.new("RGBA", state.size, (64, 35, 4, 35))
        return Image.alpha_composite(state, shade)
    if mode == "disabled":
        gray = ImageEnhance.Color(source).enhance(0.25)
        gray.putalpha(Image.new("L", source.size, 255))
        return gray
    raise ValueError(f"Unknown button state: {mode}")


def _textured_backing(size: tuple[int, int], base: tuple[int, int, int], seed: int) -> Image.Image:
    rng = random.Random(seed)
    pixels: list[tuple[int, int, int, int]] = []
    for _index in range(size[0] * size[1]):
        grain = rng.randint(-5, 5)
        pixels.append(tuple(max(0, min(255, channel + grain)) for channel in base) + (255,))
    image = Image.new("RGBA", size)
    image.putdata(pixels)
    return image.filter(ImageFilter.GaussianBlur(0.35))


def main() -> None:
    source = Image.open(SOURCE_PATH).convert("RGBA")
    if source.size != EXPECTED_SIZE:
        raise RuntimeError(f"Unexpected source size {source.size}; expected {EXPECTED_SIZE}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {
        "source": SOURCE_PATH.relative_to(PROJECT_ROOT).as_posix(),
        "source_size": list(source.size),
        "slices": {},
    }

    for name, box in SLICES.items():
        image = _crop(source, box)
        output_path = OUTPUT_DIR / f"{name}.png"
        image.save(output_path, optimize=True)
        manifest["slices"][name] = {
            "source_rect": [box[0], box[1], box[2] - box[0], box[3] - box[1]],
            "file": output_path.relative_to(PROJECT_ROOT).as_posix(),
        }

        if not name.endswith("button"):
            continue
        for mode in ("hover", "pressed", "disabled"):
            state_path = OUTPUT_DIR / f"{name}_{mode}.png"
            _button_state(image, mode).save(state_path, optimize=True)

    for seed, (name, (size, base)) in enumerate(BACKINGS.items(), start=4107):
        backing_path = OUTPUT_DIR / f"{name}.png"
        _textured_backing(size, base, seed).save(backing_path, optimize=True)
        manifest["slices"][name] = {
            "derived": "deterministic textured backing for dynamic text",
            "file": backing_path.relative_to(PROJECT_ROOT).as_posix(),
        }

    manifest_path = OUTPUT_DIR / "slice_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(SLICES)} slices in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
