#!/usr/bin/env python3
"""Create a checkerboard review sheet for two transparent faction assets."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def _checker(size: tuple[int, int], cell: int = 32) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size, (50, 56, 62))
    draw = ImageDraw.Draw(image)
    colours = ((50, 56, 62), (74, 81, 88))
    for y in range(0, height, cell):
        for x in range(0, width, cell):
            draw.rectangle(
                (x, y, min(x + cell, width), min(y + cell, height)),
                fill=colours[(x // cell + y // cell) % 2],
            )
    return image


def _fit(image: Image.Image, box: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(box, Image.Resampling.LANCZOS)
    return copy


def _centered_text(
    draw: ImageDraw.ImageDraw,
    center_x: int,
    y: int,
    text: str,
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int],
) -> None:
    bounds = draw.textbbox((0, 0), text, font=font)
    width = bounds[2] - bounds[0]
    draw.text((center_x - width // 2, y), text, font=font, fill=fill)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("left", type=Path)
    parser.add_argument("right", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--left-label", default="银白钨钢·兵")
    parser.add_argument("--right-label", default="墨绿青铜·兵")
    args = parser.parse_args()

    canvas = Image.new("RGB", (1440, 1080), (24, 29, 34))
    draw = ImageDraw.Draw(canvas)
    title_font = _font(42)
    label_font = _font(32)
    note_font = _font(22)
    gold = (211, 169, 78)
    _centered_text(draw, 720, 24, "兵马俑阵营与透明背景校验", title_font, gold)
    _centered_text(
        draw,
        720,
        78,
        "同一尺寸 · 同一脚底线 · 棋盘格区域为透明像素",
        note_font,
        (198, 204, 210),
    )

    panel_y = 122
    panel_size = (640, 880)
    for index, (path, label) in enumerate(
        ((args.left, args.left_label), (args.right, args.right_label))
    ):
        panel_x = 56 + index * 688
        panel = _checker(panel_size)
        asset = _fit(Image.open(path).convert("RGBA"), (560, 790))
        x = (panel_size[0] - asset.width) // 2
        y = 44 + 790 - asset.height
        panel.paste(asset, (x, y), asset)
        canvas.paste(panel, (panel_x, panel_y))
        draw.rectangle(
            (
                panel_x - 2,
                panel_y - 2,
                panel_x + panel_size[0] + 1,
                panel_y + panel_size[1] + 1,
            ),
            outline=gold,
            width=2,
        )
        _centered_text(
            draw,
            panel_x + panel_size[0] // 2,
            1020,
            label,
            label_font,
            (232, 235, 238),
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output, optimize=True)
    print({"output": str(args.output), "size": canvas.size, "mode": canvas.mode})


if __name__ == "__main__":
    main()
