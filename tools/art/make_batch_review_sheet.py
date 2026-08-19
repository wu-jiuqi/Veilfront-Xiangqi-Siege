#!/usr/bin/env python3
"""Create a 2x7 checkerboard review sheet for the complete piece batch."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PIECES = (
    ("兵", "01-red-infantry-512x768", "02-black-infantry-512x768"),
    ("炮", "05-red-trebuchet-768x768", "06-black-trebuchet-768x768"),
    ("车", "07-red-chariot-768x768", "08-black-chariot-768x768"),
    ("马", "03-red-cavalry-768x768", "04-black-cavalry-768x768"),
    ("相", "09-red-minister-512x768", "10-black-minister-512x768"),
    ("士", "11-red-guard-512x768", "12-black-guard-512x768"),
    ("将", "13-red-general-512x768", "14-black-general-512x768"),
)


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/msyh.ttc"), Path("C:/Windows/Fonts/simhei.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def checker(size: tuple[int, int], cell: int = 24) -> Image.Image:
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    colours = ((47, 53, 59), (70, 77, 84))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            draw.rectangle(
                (x, y, min(x + cell, size[0]), min(y + cell, size[1])),
                fill=colours[(x // cell + y // cell) % 2],
            )
    return image


def centered(draw: ImageDraw.ImageDraw, x: int, y: int, value: str, face: ImageFont.ImageFont, fill: tuple[int, int, int]) -> None:
    bounds = draw.textbbox((0, 0), value, font=face)
    draw.text((x - (bounds[2] - bounds[0]) // 2, y), value, font=face, fill=fill)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("runtime_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    canvas = Image.new("RGB", (2320, 1370), (22, 27, 32))
    draw = ImageDraw.Draw(canvas)
    gold = (214, 173, 79)
    centered(draw, 1160, 24, "兵马俑 · 14枚静态棋子透明资产总审查", font(44), gold)
    centered(draw, 1160, 78, "上排银白钨钢 · 下排墨绿青铜 · 棋盘格为真实透明区域", font(24), (204, 210, 216))

    panel_w, panel_h = 304, 560
    start_x, gap_x = 56, 20
    row_y = (130, 750)
    for column, (character, red_name, black_name) in enumerate(PIECES):
        for row, (name, faction) in enumerate(((red_name, "银白"), (black_name, "墨绿"))):
            x = start_x + column * (panel_w + gap_x)
            y = row_y[row]
            panel = checker((panel_w, panel_h))
            asset = Image.open(args.runtime_dir / f"vs-piece-{name}-alpha-v2.png").convert("RGBA")
            asset.thumbnail((276, 500), Image.Resampling.LANCZOS)
            px = (panel_w - asset.width) // 2
            py = 18 + 500 - asset.height
            panel.paste(asset, (px, py), asset)
            canvas.paste(panel, (x, y))
            draw.rectangle((x - 1, y - 1, x + panel_w, y + panel_h), outline=gold, width=2)
            centered(draw, x + panel_w // 2, y + panel_h + 10, f"{faction}·{character}", font(26), (235, 237, 239))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output, optimize=True)
    print({"output": str(args.output), "size": canvas.size, "asset_count": 14})


if __name__ == "__main__":
    main()
