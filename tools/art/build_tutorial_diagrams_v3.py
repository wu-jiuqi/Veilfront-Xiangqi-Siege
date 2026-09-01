#!/usr/bin/env python3
"""Build the deterministic, accuracy-first tutorial diagram set (v3)."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from functools import lru_cache
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "assets" / "art" / "tutorial" / "diagram_v3"
FONT_PATH = ROOT / "assets" / "fonts" / "noto_sans_sc" / "NotoSansSC-VariableFont_wght.ttf"
WIDTH = 1200
HEIGHT = 800

BG = "#F3F1E8"
PANEL = "#FFFEFA"
INK = "#243142"
MUTED = "#697586"
GRID = "#758195"
RED = "#C94545"
BLUE = "#3568A9"
GREEN = "#2C8A61"
AMBER = "#D18B28"
GOLD = "#C99A27"
FOG = "#7A8492"
PALE_RED = "#F8DDDA"
PALE_BLUE = "#DCE9F8"
PALE_GREEN = "#DCF2E6"
PALE_AMBER = "#F8E9CA"
PALE_FOG = "#D9DEE5"
WHITE = "#FFFFFF"

PAGE_FILES = (
    "page_00_board_turns.png",
    "page_01_pawn.png",
    "page_02_horse_elephant.png",
    "page_03_rook_cannon.png",
    "page_04_palace_general.png",
    "page_05_fog_flag_memory.png",
    "page_06_special_eligibility.png",
    "page_07_hidden_horse_elephant_field.png",
    "page_08_special_rook_pawn.png",
    "page_09_bombardment.png",
    "page_10_advisor_sacrifice.png",
    "page_11_wall_breach_entry.png",
    "page_12_wall_repair.png",
    "page_13_flag_capture.png",
    "page_14_flag_contest.png",
    "page_15_victory.png",
    "page_16_casualty_reserve.png",
    "page_17_action_preview.png",
)

RULE_REFS = (
    "§1 坐标、区域与回合术语",
    "§3 普通行动：兵卒",
    "§3 普通行动：马与相",
    "§3 普通行动：车与炮",
    "§1/§3 九宫与将帅",
    "§6 迷雾与旗帜发现记忆",
    "§4 特殊行动共同资格",
    "§4 特殊马与相田",
    "§4 特殊车与特殊兵",
    "§4/§8 区域轰炸",
    "§6 士献祭复活",
    "§3/§5 缓冲区与破墙",
    "§5 城墙修复状态机",
    "§6 旗帜占领",
    "§6 旗帜争夺",
    "§6/§8 胜负结算",
    "§2/§7 阵亡记录与后备",
    "information-boundary-v1 行动预览",
)


@lru_cache(maxsize=None)
def font(size: int) -> ImageFont.FreeTypeFont:
    result = ImageFont.truetype(str(FONT_PATH), size=size)
    result.set_variation_by_axes([500])
    return result


def text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    value: str,
    size: int = 30,
    fill: str = INK,
    anchor: str = "mm",
    stroke_width: int = 0,
    stroke_fill: str | None = None,
) -> None:
    draw.text(
        xy,
        value,
        font=font(size),
        fill=fill,
        anchor=anchor,
        stroke_width=stroke_width,
        stroke_fill=stroke_fill or fill,
    )


def panel(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], label: str = "") -> None:
    draw.rounded_rectangle(box, radius=28, fill=PANEL, outline=INK, width=4)
    if label:
        x1, y1, x2, _ = box
        bounds = draw.textbbox((0, 0), label, font=font(27))
        label_width = bounds[2] - bounds[0]
        label_right = min(x2 - 22, x1 + 72 + label_width)
        draw.rounded_rectangle((x1 + 22, y1 + 18, label_right, y1 + 68), radius=16, fill=INK)
        text(draw, (x1 + 42, y1 + 43), label, 27, WHITE, "lm")


def arrow(
    draw: ImageDraw.ImageDraw,
    start: tuple[float, float],
    end: tuple[float, float],
    color: str = GREEN,
    width: int = 12,
    head: int = 24,
    dashed: bool = False,
) -> None:
    sx, sy = start
    ex, ey = end
    dx, dy = ex - sx, ey - sy
    length = math.hypot(dx, dy)
    if length <= 0:
        return
    ux, uy = dx / length, dy / length
    line_end = (ex - ux * head * 0.65, ey - uy * head * 0.65)
    if dashed:
        step = 30
        cursor = 0.0
        while cursor < max(0.0, length - head):
            a = cursor
            b = min(cursor + 18, length - head)
            draw.line((sx + ux * a, sy + uy * a, sx + ux * b, sy + uy * b), fill=color, width=width)
            cursor += step
    else:
        draw.line((sx, sy, line_end[0], line_end[1]), fill=color, width=width)
    px, py = -uy, ux
    points = [
        (ex, ey),
        (ex - ux * head + px * head * 0.55, ey - uy * head + py * head * 0.55),
        (ex - ux * head - px * head * 0.55, ey - uy * head - py * head * 0.55),
    ]
    draw.polygon(points, fill=color)


def cross(draw: ImageDraw.ImageDraw, center: tuple[float, float], color: str = RED, size: int = 24, width: int = 9) -> None:
    x, y = center
    draw.line((x - size, y - size, x + size, y + size), fill=color, width=width)
    draw.line((x - size, y + size, x + size, y - size), fill=color, width=width)


def check(draw: ImageDraw.ImageDraw, center: tuple[float, float], color: str = GREEN, size: int = 26, width: int = 9) -> None:
    x, y = center
    draw.line((x - size, y, x - 7, y + size * 0.65), fill=color, width=width)
    draw.line((x - 7, y + size * 0.65, x + size, y - size), fill=color, width=width)


def badge(draw: ImageDraw.ImageDraw, center: tuple[int, int], value: str, fill: str = INK, radius: int = 28) -> None:
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill, outline=WHITE, width=3)
    text(draw, center, value, int(radius * 1.05), WHITE)


def piece(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    glyph: str,
    side: str = "red",
    radius: int = 37,
    alpha_fill: str | None = None,
) -> None:
    x, y = center
    fill = alpha_fill or (RED if side == "red" else BLUE)
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=WHITE, outline=fill, width=9)
    draw.ellipse((x - radius + 8, y - radius + 8, x + radius - 8, y + radius - 8), outline=fill, width=3)
    text(draw, center, glyph, int(radius * 0.95), fill)


def flag(draw: ImageDraw.ImageDraw, origin: tuple[float, float], side: str = "neutral", scale: float = 1.0) -> None:
    x, y = origin
    color = GOLD if side == "neutral" else (RED if side == "red" else BLUE)
    draw.line((x, y + 54 * scale, x, y - 50 * scale), fill=INK, width=max(4, int(7 * scale)))
    draw.polygon(
        ((x, y - 48 * scale), (x + 66 * scale, y - 30 * scale), (x, y - 8 * scale)),
        fill=color,
        outline=INK,
    )
    draw.ellipse((x - 11 * scale, y + 43 * scale, x + 11 * scale, y + 65 * scale), fill=INK)


def eye_slash(draw: ImageDraw.ImageDraw, center: tuple[float, float], scale: float = 1.0) -> None:
    x, y = center
    w, h = 72 * scale, 42 * scale
    draw.ellipse((x - w, y - h, x + w, y + h), outline=FOG, width=max(5, int(8 * scale)))
    draw.ellipse((x - 15 * scale, y - 15 * scale, x + 15 * scale, y + 15 * scale), fill=FOG)
    draw.line((x - 78 * scale, y + 55 * scale, x + 78 * scale, y - 55 * scale), fill=RED, width=max(6, int(10 * scale)))


def grid(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    cols: int,
    rows: int,
    fill: str | None = None,
    line_color: str = GRID,
    width: int = 4,
) -> Callable[[float, float], tuple[float, float]]:
    x1, y1, x2, y2 = box
    if fill:
        draw.rectangle(box, fill=fill)
    for col in range(cols):
        x = x1 + (x2 - x1) * col / max(1, cols - 1)
        draw.line((x, y1, x, y2), fill=line_color, width=width)
    for row in range(rows):
        y = y1 + (y2 - y1) * row / max(1, rows - 1)
        draw.line((x1, y, x2, y), fill=line_color, width=width)

    def point(col: float, row: float) -> tuple[float, float]:
        return (
            x1 + (x2 - x1) * col / max(1, cols - 1),
            y1 + (y2 - y1) * row / max(1, rows - 1),
        )

    return point


def page_base() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((20, 20, WIDTH - 20, HEIGHT - 20), radius=34, fill=BG, outline="#CCD2D8", width=3)
    return image, draw


def page_00(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (55, 70, 515, 730), "棋子落在线的交点")
    p = grid(draw, (115, 185, 455, 615), 5, 6, PALE_AMBER)
    target = p(2, 3)
    draw.ellipse((target[0] - 68, target[1] - 68, target[0] + 68, target[1] + 68), fill="#FFF3BE", outline=GOLD, width=6)
    draw.line((target[0] - 110, target[1], target[0] + 110, target[1]), fill=GOLD, width=8)
    draw.line((target[0], target[1] - 110, target[0], target[1] + 110), fill=GOLD, width=8)
    piece(draw, target, "兵")
    text(draw, (285, 668), "不是格子中央", 29, MUTED)

    panel(draw, (560, 70, 1145, 730), "一个完整轮")
    stages = ((700, 250, RED, "1", "赤方行动"), (1000, 250, BLUE, "2", "玄方行动"))
    for x, y, color, number, label in stages:
        draw.rounded_rectangle((x - 105, y - 75, x + 105, y + 75), radius=24, fill=WHITE, outline=color, width=7)
        badge(draw, (x - 80, y - 52), number, color, 24)
        text(draw, (x, y + 5), label, 32, color)
    arrow(draw, (815, 250), (885, 250), INK, 10, 22)
    arrow(draw, (1000, 340), (850, 470), INK, 10, 22)
    draw.rounded_rectangle((680, 485, 1020, 625), radius=32, fill=PALE_GREEN, outline=GREEN, width=7)
    text(draw, (850, 535), "完整轮", 38, GREEN)
    text(draw, (850, 585), "+1", 44, GREEN)


def page_01(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (75, 55, 1125, 745), "兵卒：前、左、右各一格")
    p = grid(draw, (285, 155, 915, 665), 7, 7, PALE_BLUE)
    center = p(3, 3)
    piece(draw, center, "兵")
    destinations = (p(3, 1.75), p(1.75, 3), p(4.25, 3))
    for end in destinations:
        arrow(draw, center, end, GREEN, 13, 26)
        draw.ellipse((end[0] - 24, end[1] - 24, end[0] + 24, end[1] + 24), fill=PALE_GREEN, outline=GREEN, width=5)
    backward = p(3, 4.45)
    arrow(draw, center, backward, RED, 10, 24, dashed=True)
    cross(draw, backward, RED, 30, 11)
    text(draw, (600, 110), "前", 34, GREEN)
    text(draw, (600, 708), "不可后退", 32, RED)


def page_02(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 60, 580, 740), "马走日 · 先看马腿")
    p = grid(draw, (110, 170, 515, 630), 5, 5, PALE_BLUE)
    start = p(1, 3)
    leg = p(1, 2)
    end = p(2, 1)
    piece(draw, start, "马")
    arrow(draw, start, end, AMBER, 10, 22, dashed=True)
    piece(draw, leg, "兵", "red", 28)
    cross(draw, leg, RED, 37, 10)
    draw.ellipse((end[0] - 28, end[1] - 28, end[0] + 28, end[1] + 28), outline=RED, width=7)
    text(draw, (310, 680), "马腿被占 → 该日字落点不可达", 27, RED)

    panel(draw, (620, 60, 1155, 740), "相走田 · 先看象眼")
    p = grid(draw, (685, 170, 1090, 630), 5, 5, PALE_AMBER)
    start = p(1, 3)
    eye = p(2, 2)
    end = p(3, 1)
    piece(draw, start, "相")
    arrow(draw, start, end, AMBER, 10, 22, dashed=True)
    piece(draw, eye, "兵", "red", 28)
    cross(draw, eye, RED, 37, 10)
    draw.ellipse((end[0] - 28, end[1] - 28, end[0] + 28, end[1] + 28), outline=RED, width=7)
    text(draw, (887, 680), "象眼被占 → 该田字落点不可达", 27, RED)


def page_03(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (55, 65, 560, 735), "车：整条直线必须畅通")
    p = grid(draw, (125, 190, 490, 620), 5, 6, PALE_GREEN)
    start, end = p(2, 4.5), p(2, 0.7)
    arrow(draw, start, end, GREEN, 14, 28)
    piece(draw, start, "车")
    draw.ellipse((end[0] - 28, end[1] - 28, end[0] + 28, end[1] + 28), fill=PALE_GREEN, outline=GREEN, width=6)
    text(draw, (307, 675), "横走或竖走 · 不穿子", 30, GREEN)

    panel(draw, (610, 65, 1145, 735), "炮吃子：中间恰好一枚炮架")
    p = grid(draw, (680, 190, 1075, 620), 5, 6, PALE_AMBER)
    cannon, screen, target = p(2, 4.7), p(2, 2.8), p(2, 0.65)
    draw.line((cannon, target), fill=AMBER, width=12)
    piece(draw, cannon, "炮")
    piece(draw, screen, "兵", "red", 30)
    badge(draw, (screen[0] + 75, screen[1]), "1", AMBER, 25)
    piece(draw, target, "卒", "blue")
    cross(draw, target, RED, 31, 9)
    text(draw, (877, 675), "炮 · 炮架 · 目标必须共线", 29, AMBER)


def palace(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], glyph: str, diagonal: bool) -> None:
    p = grid(draw, box, 3, 3, PALE_AMBER)
    x1, y1, x2, y2 = box
    draw.line((x1, y1, x2, y2), fill=GRID, width=4)
    draw.line((x2, y1, x1, y2), fill=GRID, width=4)
    center = p(1, 1)
    piece(draw, center, glyph)
    targets = (p(0, 0), p(2, 0), p(0, 2), p(2, 2)) if diagonal else (p(1, 0), p(0, 1), p(2, 1), p(1, 2))
    for target in targets:
        arrow(draw, center, target, GREEN, 9, 20)


def page_04(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (55, 65, 560, 735), "士：九宫内斜走一格")
    palace(draw, (135, 190, 480, 610), "士", True)
    text(draw, (307, 670), "只能落在九宫交点", 31, GREEN)
    panel(draw, (640, 65, 1145, 735), "将帅：九宫内横竖一格")
    palace(draw, (720, 190, 1065, 610), "帅", False)
    text(draw, (892, 670), "可以进入受威胁点", 31, AMBER)


def vision_grid(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], piece_col: int, flag_col: int, fog_old: bool) -> None:
    p = grid(draw, box, 6, 6, PALE_FOG)
    pc = p(piece_col, 3)
    for cx in range(max(0, piece_col - 1), min(5, piece_col + 1) + 1):
        for cy in range(2, 5):
            px, py = p(cx, cy)
            draw.ellipse((px - 29, py - 29, px + 29, py + 29), fill="#FFF2B8", outline=GOLD, width=5)
    grid(draw, box, 6, 6, None)
    piece(draw, pc, "兵", radius=31)
    fp = p(flag_col, 2)
    flag(draw, fp, "neutral", 0.55)
    if fog_old:
        draw.rounded_rectangle((fp[0] - 55, fp[1] - 55, fp[0] + 55, fp[1] + 55), radius=14, fill="#AAB1BB88", outline=FOG, width=5)
        flag(draw, fp, "neutral", 0.55)
        draw.ellipse((fp[0] - 67, fp[1] - 67, fp[0] + 67, fp[1] + 67), outline=GOLD, width=6)


def page_05(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 65, 560, 735), "移动前 · 3×3 当前视野")
    vision_grid(draw, (105, 185, 500, 620), 2, 3, False)
    text(draw, (302, 675), "旗帜进入视野 → 记住位置", 28, GOLD)
    arrow(draw, (565, 400), (635, 400), INK, 12, 24)
    panel(draw, (640, 65, 1155, 735), "移动后 · 旧区域重新入雾")
    vision_grid(draw, (700, 185, 1095, 620), 4, 2, True)
    text(draw, (897, 675), "入雾后旗帜图标仍保留", 28, GOLD)


def condition_card(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], title: str, ok: bool, detail: str) -> None:
    color = GREEN if ok else RED
    pale = PALE_GREEN if ok else PALE_RED
    draw.rounded_rectangle(box, radius=28, fill=pale, outline=color, width=6)
    x1, y1, x2, y2 = box
    (check if ok else cross)(draw, (x1 + 55, (y1 + y2) / 2), color, 24, 9)
    text(draw, (x1 + 100, y1 + 52), title, 27, color, "lm")
    text(draw, (x1 + 100, y2 - 45), detail, 21, INK, "lm")


def page_06(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (55, 55, 1145, 745), "马 / 相 / 车 / 兵的特殊移动资格")
    condition_card(draw, (105, 150, 520, 305), "条件 1：目标城墙完整", True, "INTACT")
    condition_card(draw, (680, 150, 1095, 305), "条件 2：全路径留在战区", True, "起点 · 经过点 · 终点 / Y = 4..21")
    text(draw, (600, 227), "且", 50, INK)
    arrow(draw, (600, 325), (600, 405), INK, 12, 25)
    draw.rounded_rectangle((360, 420, 840, 570), radius=34, fill=PALE_GREEN, outline=GREEN, width=8)
    text(draw, (600, 475), "两个条件同时成立", 36, GREEN)
    text(draw, (600, 530), "特殊移动才可提交", 40, GREEN)
    draw.line((175, 655, 1025, 655), fill=GRID, width=7)
    draw.line((870, 610, 870, 700), fill=RED, width=13)
    arrow(draw, (650, 655), (965, 655), RED, 11, 24, dashed=True)
    cross(draw, (870, 655), RED, 31, 10)
    text(draw, (600, 710), "路径越界或穿墙 → 不合资格", 30, RED)


def page_07(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 60, 560, 740), "特殊马：越腿后隐身")
    p = grid(draw, (105, 170, 500, 595), 5, 5, PALE_BLUE)
    start, leg, end = p(1, 3), p(1, 2), p(2, 1)
    piece(draw, start, "马")
    piece(draw, leg, "兵", "red", 27)
    arrow(draw, start, end, BLUE, 11, 24, dashed=True)
    piece(draw, end, "马", "red", 34, FOG)
    eye_slash(draw, (305, 665), 0.65)
    text(draw, (420, 665), "隐身", 31, FOG)

    panel(draw, (620, 60, 1155, 740), "特殊相：布下田字阻挡区")
    p = grid(draw, (680, 155, 1095, 620), 5, 5, PALE_GREEN)
    field_points = [p(c, r) for c in (1, 2, 3) for r in (1, 2, 3)]
    for x, y in field_points:
        draw.ellipse((x - 28, y - 28, x + 28, y + 28), fill="#BFE6CF", outline=GREEN, width=4)
    piece(draw, p(2, 2), "相")
    incoming = p(0, 2)
    stop = p(1, 2)
    piece(draw, incoming, "车", "blue", 30)
    arrow(draw, incoming, p(3, 2), BLUE, 10, 22, dashed=True)
    draw.line((stop[0] - 6, stop[1] - 48, stop[0] - 6, stop[1] + 48), fill=RED, width=12)
    text(draw, (887, 680), "敌车 / 敌兵首次进入时停在首点", 27, RED)


def page_08(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 55, 1155, 385), "特殊车：按从近到远依次处理沿途敌棋")
    y = 235
    arrow(draw, (165, y), (1030, y), RED, 14, 30)
    piece(draw, (145, y), "车")
    for x, glyph in ((405, "卒"), (650, "马"), (885, "炮")):
        piece(draw, (x, y), glyph, "blue", 34)
        cross(draw, (x, y), RED, 40, 10)
    badge(draw, (405, 320), "1", RED, 24)
    badge(draw, (650, 320), "2", RED, 24)
    badge(draw, (885, 320), "3", RED, 24)

    panel(draw, (45, 415, 1155, 745), "特殊兵：穿过敌棋但不伤害，终点必须为空")
    y = 595
    arrow(draw, (165, y), (1030, y), GREEN, 14, 30)
    piece(draw, (145, y), "兵")
    for x, glyph in ((455, "卒"), (690, "马")):
        piece(draw, (x, y), glyph, "blue", 34)
        check(draw, (x, y + 70), GREEN, 20, 8)
    draw.ellipse((1030 - 34, y - 34, 1030 + 34, y + 34), fill=PALE_GREEN, outline=GREEN, width=7)
    text(draw, (1030, y + 75), "空", 27, GREEN)


def page_09(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (55, 55, 1145, 745), "炮击：3×3 九点候选区中随机命中三个不同点")
    x0, y0 = 300, 190
    gap = 180
    points = [(x0 + c * gap, y0 + r * gap) for r in range(3) for c in range(3)]
    for row in range(3):
        draw.line((x0, y0 + row * gap, x0 + 2 * gap, y0 + row * gap), fill=GRID, width=7)
    for col in range(3):
        draw.line((x0 + col * gap, y0, x0 + col * gap, y0 + 2 * gap), fill=GRID, width=7)
    hits = {0, 4, 8}
    for index, (x, y) in enumerate(points):
        if index in hits:
            draw.ellipse((x - 45, y - 45, x + 45, y + 45), fill=RED, outline=WHITE, width=7)
            text(draw, (x, y), "命", 31, WHITE)
        else:
            draw.ellipse((x - 25, y - 25, x + 25, y + 25), fill=WHITE, outline=INK, width=6)
    draw.rounded_rectangle((785, 185, 1060, 300), radius=25, fill=PALE_AMBER, outline=AMBER, width=6)
    text(draw, (922, 225), "候选点", 28, AMBER)
    text(draw, (922, 270), "9", 42, AMBER)
    draw.rounded_rectangle((785, 345, 1060, 460), radius=25, fill=PALE_RED, outline=RED, width=6)
    text(draw, (922, 385), "命中点", 28, RED)
    text(draw, (922, 430), "3", 42, RED)
    draw.rounded_rectangle((750, 520, 1090, 645), radius=28, fill=PALE_BLUE, outline=BLUE, width=6)
    text(draw, (920, 565), "同一结算窗口", 31, BLUE)
    text(draw, (920, 610), "同时受击", 36, BLUE)
    assert len(points) == 9 and len(hits) == 3


def page_10(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 60, 345, 740), "1 · 主动献祭")
    piece(draw, (195, 315), "士")
    arrow(draw, (195, 385), (195, 510), RED, 12, 25)
    cross(draw, (195, 545), RED, 45, 12)
    text(draw, (195, 625), "士先实际阵亡", 30, RED)
    panel(draw, (450, 60, 750, 740), "2 · 随机候选")
    piece(draw, (535, 285), "车", "red", 31)
    piece(draw, (665, 285), "马", "red", 31)
    piece(draw, (535, 445), "士", "red", 31)
    piece(draw, (665, 445), "帅", "red", 31)
    cross(draw, (535, 445), RED, 40, 10)
    cross(draw, (665, 445), RED, 40, 10)
    text(draw, (600, 570), "排除士与将帅", 29, RED)
    badge(draw, (600, 650), "?", AMBER, 34)
    panel(draw, (855, 60, 1155, 740), "3 · 随机复活")
    p = grid(draw, (915, 190, 1095, 510), 3, 3, PALE_GREEN)
    piece(draw, p(1, 1), "车", "red", 34)
    check(draw, (1005, 600), GREEN, 38, 12)
    text(draw, (1005, 665), "随机空点复活", 29, GREEN)
    arrow(draw, (365, 400), (430, 400), INK, 11, 22)
    arrow(draw, (770, 400), (835, 400), INK, 11, 22)


def wall_zone(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], invaders: int, breached: bool) -> None:
    x1, y1, x2, y2 = box
    h = y2 - y1
    battle_y = y1 + h * 0.22
    wall_y = y1 + h * 0.62
    draw.rectangle((x1, y1, x2, battle_y), fill=PALE_BLUE)
    draw.rectangle((x1, battle_y, x2, wall_y), fill=PALE_AMBER)
    draw.rectangle((x1, wall_y, x2, y2), fill=PALE_RED)
    text(draw, (x1 + 20, y1 + 25), "战区", 26, BLUE, "la")
    text(draw, (x1 + 20, battle_y + 25), "缓冲区", 26, AMBER, "la")
    text(draw, (x1 + 20, wall_y + 35), "敌方大本营", 26, RED, "la")
    if breached:
        draw.line((x1, wall_y, x1 + (x2 - x1) * 0.38, wall_y), fill=RED, width=18)
        draw.line((x1 + (x2 - x1) * 0.62, wall_y, x2, wall_y), fill=RED, width=18)
        cross(draw, ((x1 + x2) / 2, wall_y), RED, 32, 11)
    else:
        draw.line((x1, wall_y, x2, wall_y), fill=RED, width=18)
    for index in range(invaders):
        px = x1 + (index + 1) * (x2 - x1) / (invaders + 1)
        piece(draw, (px, battle_y + (wall_y - battle_y) * 0.56), "兵", "red", 31)


def page_11(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (50, 55, 770, 745), "三枚入侵棋在缓冲区 → 城墙立即倒塌")
    wall_zone(draw, (105, 145, 715, 665), 3, True)
    badge(draw, (690, 255), "3", RED, 29)
    panel(draw, (815, 55, 1150, 745), "进营必须再行动一次")
    draw.rectangle((865, 175, 1100, 385), fill=PALE_AMBER, outline=AMBER, width=5)
    draw.rectangle((865, 455, 1100, 665), fill=PALE_RED, outline=RED, width=5)
    text(draw, (982, 205), "缓冲区", 27, AMBER)
    text(draw, (982, 485), "大本营", 27, RED)
    piece(draw, (982, 315), "兵", "red", 34)
    arrow(draw, (982, 365), (982, 545), GREEN, 13, 27)
    draw.rounded_rectangle((850, 390, 950, 450), radius=20, fill=GREEN)
    text(draw, (900, 420), "下一次", 23, WHITE)


def page_12(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 55, 385, 745), "修复启动")
    draw.rounded_rectangle((95, 155, 335, 315), radius=24, fill=PALE_AMBER, outline=AMBER, width=6)
    piece(draw, (165, 235), "兵", "red", 28)
    piece(draw, (265, 235), "兵", "red", 28)
    text(draw, (215, 365), "入侵棋 < 3", 34, AMBER)
    text(draw, (215, 430), "触发这次行动", 28, INK)
    draw.rounded_rectangle((100, 470, 330, 585), radius=24, fill=PALE_FOG, outline=FOG, width=5)
    text(draw, (215, 515), "不计入等待", 29, FOG)
    text(draw, (215, 555), "窗口", 29, FOG)
    arrow(draw, (400, 400), (465, 400), INK, 11, 22)
    panel(draw, (480, 55, 830, 745), "之后双方各行动一次")
    draw.rounded_rectangle((545, 190, 765, 310), radius=25, fill=PALE_RED, outline=RED, width=6)
    badge(draw, (575, 250), "1", RED, 25)
    text(draw, (665, 250), "赤方行动", 31, RED)
    arrow(draw, (655, 335), (655, 415), INK, 10, 22)
    draw.rounded_rectangle((545, 440, 765, 560), radius=25, fill=PALE_BLUE, outline=BLUE, width=6)
    badge(draw, (575, 500), "2", BLUE, 25)
    text(draw, (665, 500), "玄方行动", 31, BLUE)
    text(draw, (655, 635), "期间仍须 < 3", 29, AMBER)
    arrow(draw, (845, 400), (910, 400), INK, 11, 22)
    panel(draw, (925, 55, 1155, 745), "恢复完整")
    draw.line((970, 360, 1110, 360), fill=RED, width=22)
    check(draw, (1040, 485), GREEN, 50, 14)
    text(draw, (1040, 585), "城墙恢复", 31, GREEN)


def capture_stage(draw: ImageDraw.ImageDraw, center: tuple[int, int], progress: int, completed: bool = False) -> None:
    x, y = center
    color = GREEN if completed else GOLD
    draw.ellipse((x - 95, y - 95, x + 95, y + 95), fill=WHITE, outline="#D9DDE2", width=8)
    for index in range(3):
        start = -90 + index * 120
        fill = color if index < progress else "#D9DDE2"
        draw.arc((x - 105, y - 105, x + 105, y + 105), start=start + 7, end=start + 110, fill=fill, width=17)
    flag(draw, (x - 38, y), "neutral", 0.52)
    piece(draw, (x + 38, y + 12), "兵", "red", 29)
    badge(draw, (x, y + 142), f"{progress}/3", color, 32)


def page_13(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 55, 1155, 745), "占领进度绑定同一枚棋子")
    centers = ((245, 360), (600, 360), (955, 360))
    for index, center in enumerate(centers, start=1):
        capture_stage(draw, center, index, index == 3)
        badge(draw, (center[0] + 90, center[1] - 120), "A", RED, 26)
    arrow(draw, (370, 360), (475, 360), INK, 11, 23)
    arrow(draw, (725, 360), (830, 360), INK, 11, 23)
    text(draw, (600, 635), "A 离开 / 阵亡 / 被撤回 → 未完成进度清零", 31, RED)


def page_14(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 55, 1145, 745), "反占期间：原所有权保留，三旗即时胜利冻结")
    draw.rounded_rectangle((105, 170, 450, 620), radius=28, fill=PALE_RED, outline=RED, width=7)
    text(draw, (277, 215), "开始反占", 31, RED)
    flag(draw, (245, 365), "red", 1.05)
    piece(draw, (330, 400), "卒", "blue", 36)
    draw.rounded_rectangle((145, 500, 410, 590), radius=22, fill=PALE_AMBER, outline=AMBER, width=5)
    text(draw, (277, 530), "争夺中", 25, AMBER)
    text(draw, (277, 565), "所有权仍为赤", 25, AMBER)
    arrow(draw, (480, 395), (650, 395), AMBER, 14, 28)
    badge(draw, (565, 335), "1/3…", AMBER, 38)
    draw.rounded_rectangle((680, 170, 1085, 620), radius=28, fill=PALE_BLUE, outline=BLUE, width=7)
    text(draw, (882, 215), "完成 3/3 后", 31, BLUE)
    flag(draw, (850, 365), "blue", 1.05)
    piece(draw, (935, 400), "卒", "blue", 36)
    check(draw, (882, 545), GREEN, 35, 11)
    text(draw, (882, 595), "所有权正式翻转", 29, GREEN)


def page_15(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 55, 565, 510), "立即胜利 · 斩将")
    piece(draw, (230, 280), "将", "blue", 52)
    cross(draw, (230, 280), RED, 62, 15)
    arrow(draw, (330, 280), (440, 280), INK, 12, 26)
    draw.polygon(((455, 235), (475, 270), (515, 278), (485, 305), (495, 348), (455, 325), (415, 348), (425, 305), (395, 278), (435, 270)), fill=GOLD)
    text(draw, (305, 430), "将帅实际阵亡", 31, RED)
    panel(draw, (635, 55, 1155, 510), "立即胜利 · 三面非争夺旗")
    for x in (755, 895, 1035):
        flag(draw, (x, 285), "red", 0.78)
        check(draw, (x, 405), GREEN, 22, 8)
    text(draw, (895, 455), "3 面均非 contested", 29, GREEN)
    panel(draw, (180, 545, 1020, 745), "同一炮击窗口双方将帅都阵亡 → 平局")
    piece(draw, (380, 645), "帅", "red", 39)
    piece(draw, (820, 645), "将", "blue", 39)
    cross(draw, (380, 645), RED, 48, 11)
    cross(draw, (820, 645), RED, 48, 11)
    badge(draw, (600, 645), "和", FOG, 48)
    draw.line((470, 645, 730, 645), fill=AMBER, width=10)


def page_16(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (40, 55, 340, 745), "公开阵亡记录")
    text(draw, (190, 150), "双方可见", 29, MUTED)
    for y, glyph, side in ((250, "车", "red"), (365, "马", "blue"), (480, "士", "red")):
        piece(draw, (140, y), glyph, side, 31)
        draw.line((205, y, 285, y), fill=GRID, width=6)
    text(draw, (190, 625), "记录 ≠ 复活候选池", 27, RED)
    arrow(draw, (355, 400), (420, 400), INK, 11, 22)
    panel(draw, (435, 55, 775, 745), "大本营没有空点")
    p = grid(draw, (500, 165, 710, 515), 3, 3, PALE_RED)
    glyphs = ("车", "马", "相", "士", "帅", "炮", "兵", "兵", "兵")
    for index, glyph in enumerate(glyphs):
        piece(draw, p(index % 3, index // 3), glyph, "red", 24)
    cross(draw, (605, 600), RED, 38, 11)
    text(draw, (605, 665), "回营棋进入后备", 28, RED)
    arrow(draw, (790, 400), (855, 400), INK, 11, 22)
    panel(draw, (870, 55, 1160, 745), "行动开始自动部署")
    for index, glyph in enumerate(("车", "马"), start=1):
        draw.rounded_rectangle((920, 170 + (index - 1) * 130, 1110, 265 + (index - 1) * 130), radius=22, fill=PALE_BLUE, outline=BLUE, width=5)
        badge(draw, (950, 218 + (index - 1) * 130), str(index), BLUE, 23)
        piece(draw, (1045, 218 + (index - 1) * 130), glyph, "red", 27)
    arrow(draw, (1015, 445), (1015, 545), GREEN, 12, 25)
    draw.ellipse((965, 555, 1065, 655), fill=PALE_GREEN, outline=GREEN, width=7)
    text(draw, (1015, 605), "空位", 27, GREEN)


def page_17(draw: ImageDraw.ImageDraw) -> None:
    panel(draw, (45, 55, 1155, 745), "行动预览只解释当前可见信息")
    cards = (
        (95, GOLD, "金色", "可直接提交", "✓"),
        (425, AMBER, "琥珀", "公开可知的风险", "!"),
        (755, RED, "红色", "当前已知不可行", "×"),
    )
    for x, color, name, label, symbol in cards:
        draw.rounded_rectangle((x, 155, x + 280, 500), radius=32, fill=WHITE, outline=color, width=9)
        draw.ellipse((x + 75, 230, x + 205, 360), fill=color)
        text(draw, (x + 140, 295), symbol, 64, WHITE)
        text(draw, (x + 140, 410), name, 34, color)
        text(draw, (x + 140, 460), label, 27, INK)
    draw.rounded_rectangle((210, 560, 990, 680), radius=28, fill=PALE_FOG, outline=FOG, width=6)
    eye_slash(draw, (320, 620), 0.55)
    text(draw, (650, 600), "不能靠悬停或试点推断隐藏棋与未知旗位", 29, FOG)
    text(draw, (650, 645), "公开信息相同 → 预览必须相同", 31, INK)


PAGE_DRAWERS = (
    page_00,
    page_01,
    page_02,
    page_03,
    page_04,
    page_05,
    page_06,
    page_07,
    page_08,
    page_09,
    page_10,
    page_11,
    page_12,
    page_13,
    page_14,
    page_15,
    page_16,
    page_17,
)


def render_all(output_dir: Path) -> dict[str, object]:
    if not FONT_PATH.is_file():
        raise FileNotFoundError(f"missing tutorial diagram font: {FONT_PATH}")
    output_dir.mkdir(parents=True, exist_ok=True)
    pages: list[dict[str, object]] = []
    for index, (filename, drawer, rule_ref) in enumerate(zip(PAGE_FILES, PAGE_DRAWERS, RULE_REFS, strict=True)):
        image, draw = page_base()
        drawer(draw)
        path = output_dir / filename
        image.save(path, "PNG", optimize=True, compress_level=9)
        data = path.read_bytes()
        pages.append(
            {
                "index": index,
                "file": filename,
                "size": [WIDTH, HEIGHT],
                "sha256": hashlib.sha256(data).hexdigest(),
                "rule_ref": rule_ref,
            }
        )
    manifest = {
        "schema_version": "veilfront_tutorial_diagram_manifest_v1",
        "generator": "tools/art/build_tutorial_diagrams_v3.py",
        "source_rule": "docs/prototype/rules-spec-v1.md owner-freeze revision 5",
        "visual_policy": "deterministic_accuracy_first",
        "page_count": len(pages),
        "pages": pages,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    return manifest


def check_existing(output_dir: Path) -> list[str]:
    errors: list[str] = []
    manifest_path = output_dir / "manifest.json"
    if not manifest_path.is_file():
        return [f"missing manifest: {manifest_path}"]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("page_count") != 18:
        errors.append("manifest page_count must be 18")
    pages = manifest.get("pages", [])
    if not isinstance(pages, list) or len(pages) != 18:
        errors.append("manifest pages must contain 18 entries")
        return errors
    for index, filename in enumerate(PAGE_FILES):
        path = output_dir / filename
        if not path.is_file():
            errors.append(f"missing page: {filename}")
            continue
        with Image.open(path) as image:
            if image.size != (WIDTH, HEIGHT):
                errors.append(f"wrong dimensions: {filename} {image.size}")
            if image.mode != "RGB":
                errors.append(f"wrong color mode: {filename} {image.mode}")
        entry = pages[index]
        if entry.get("file") != filename or entry.get("index") != index:
            errors.append(f"manifest ordering mismatch: {filename}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if entry.get("sha256") != digest:
            errors.append(f"digest mismatch: {filename}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate the committed v3 diagram set")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    if args.check:
        errors = check_existing(output_dir)
        if errors:
            for error in errors:
                print(f"TUTORIAL_DIAGRAM_V3_ERROR {error}")
            return 1
        print("TUTORIAL_DIAGRAM_V3_CHECK_PASS pages=18 size=1200x800 policy=deterministic_accuracy_first")
        return 0
    manifest = render_all(output_dir)
    print(f"TUTORIAL_DIAGRAM_V3_BUILD_PASS pages={manifest['page_count']} output={output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
