from __future__ import annotations

import math
from pathlib import Path
from typing import Callable, Iterable

from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Flowable,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "output" / "pdf" / "veilfront-beginner-rulebook-v1.pdf"
FONT = ROOT / "assets" / "fonts" / "noto_sans_sc" / "NotoSansSC-VariableFont_wght.ttf"

PAGE_W, PAGE_H = A4
MARGIN_X = 16 * mm
MARGIN_TOP = 17 * mm
MARGIN_BOTTOM = 16 * mm
CONTENT_W = PAGE_W - 2 * MARGIN_X

INK = HexColor("#28231F")
MUTED = HexColor("#6E655B")
PAPER = HexColor("#F7F0E1")
PANEL = HexColor("#FFFDF7")
RED = HexColor("#A53D35")
RED_LIGHT = HexColor("#E8C4B8")
BLUE = HexColor("#3E7D8E")
BLUE_LIGHT = HexColor("#C7DEE2")
GOLD = HexColor("#BD8B32")
GOLD_LIGHT = HexColor("#F1DFC0")
GREEN = HexColor("#5D7B55")
GREEN_LIGHT = HexColor("#D8E3CC")
FOG = HexColor("#777A7E")
FOG_LIGHT = HexColor("#D8D8D4")
GRID = HexColor("#8B8175")
BLACK_PIECE = HexColor("#364149")


def register_fonts() -> None:
    pdfmetrics.registerFont(TTFont("NotoSansSC", str(FONT)))
    pdfmetrics.registerFontFamily(
        "NotoSansSC",
        normal="NotoSansSC",
        bold="NotoSansSC",
        italic="NotoSansSC",
        boldItalic="NotoSansSC",
    )


register_fonts()


STYLES = getSampleStyleSheet()
TITLE = ParagraphStyle(
    "TitleCN", parent=STYLES["Title"], fontName="NotoSansSC", fontSize=27,
    leading=36, textColor=INK, alignment=TA_LEFT, spaceAfter=8,
)
SUBTITLE = ParagraphStyle(
    "SubtitleCN", parent=STYLES["Normal"], fontName="NotoSansSC", fontSize=12,
    leading=19, textColor=MUTED, spaceAfter=10,
)
H1 = ParagraphStyle(
    "H1CN", parent=STYLES["Heading1"], fontName="NotoSansSC", fontSize=19,
    leading=25, textColor=RED, spaceBefore=3, spaceAfter=9, keepWithNext=True,
)
H2 = ParagraphStyle(
    "H2CN", parent=STYLES["Heading2"], fontName="NotoSansSC", fontSize=13,
    leading=19, textColor=INK, spaceBefore=6, spaceAfter=5, keepWithNext=True,
)
BODY = ParagraphStyle(
    "BodyCN", parent=STYLES["BodyText"], fontName="NotoSansSC", fontSize=9.3,
    leading=15, textColor=INK, spaceAfter=5,
)
SMALL = ParagraphStyle(
    "SmallCN", parent=BODY, fontSize=7.7, leading=12, textColor=MUTED,
)
CAPTION = ParagraphStyle(
    "CaptionCN", parent=SMALL, alignment=TA_CENTER, fontSize=7.4, leading=10,
    spaceBefore=3, spaceAfter=0,
)
TABLE_HEAD = ParagraphStyle(
    "TableHeadCN", parent=BODY, fontSize=8.5, leading=12, textColor=colors.white,
    alignment=TA_CENTER,
)
TABLE_BODY = ParagraphStyle(
    "TableBodyCN", parent=BODY, fontSize=8.0, leading=12, spaceAfter=0,
)
COVER_NOTE = ParagraphStyle(
    "CoverNoteCN", parent=BODY, fontSize=10, leading=17, textColor=INK,
    alignment=TA_CENTER,
)


def P(text: str, style: ParagraphStyle = BODY) -> Paragraph:
    return Paragraph(text, style)


def bullets(items: Iterable[str], level: int = 0) -> list[Paragraph]:
    style = ParagraphStyle(
        f"Bullet{level}", parent=BODY, leftIndent=11 + level * 10,
        firstLineIndent=-7, bulletIndent=2 + level * 10, spaceAfter=3,
    )
    return [Paragraph(f"• {item}", style) for item in items]


def callout(title: str, text: str, tone: str = "gold") -> Table:
    palette = {
        "gold": (GOLD_LIGHT, GOLD),
        "red": (RED_LIGHT, RED),
        "blue": (BLUE_LIGHT, BLUE),
        "green": (GREEN_LIGHT, GREEN),
        "gray": (FOG_LIGHT, FOG),
    }
    bg, edge = palette[tone]
    data = [[P(f"<b>{title}</b>", TABLE_BODY), P(text, TABLE_BODY)]]
    table = Table(data, colWidths=[34 * mm, CONTENT_W - 34 * mm])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("BOX", (0, 0), (-1, -1), 0.8, edge),
        ("LINEAFTER", (0, 0), (0, -1), 0.8, edge),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return table


def rule_table(headers: list[str], rows: list[list[str]], widths: list[float]) -> Table:
    data = [[P(h, TABLE_HEAD) for h in headers]]
    data += [[P(cell, TABLE_BODY) for cell in row] for row in rows]
    table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), INK),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("GRID", (0, 0), (-1, -1), 0.45, HexColor("#C8BDAF")),
        ("BACKGROUND", (0, 1), (-1, -1), PANEL),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [PANEL, HexColor("#F4EBDD")]),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return table


def arrow(c, x1, y1, x2, y2, color=RED, width=1.6, head=5) -> None:
    c.saveState()
    c.setStrokeColor(color)
    c.setFillColor(color)
    c.setLineWidth(width)
    c.line(x1, y1, x2, y2)
    angle = math.atan2(y2 - y1, x2 - x1)
    pts = []
    for delta in (2.55, -2.55):
        pts.append((x2 + head * math.cos(angle + delta), y2 + head * math.sin(angle + delta)))
    path = c.beginPath()
    path.moveTo(x2, y2)
    path.lineTo(*pts[0])
    path.lineTo(*pts[1])
    path.close()
    c.drawPath(path, stroke=0, fill=1)
    c.restoreState()


def piece(c, x, y, label, side="red", radius=10, dashed=False) -> None:
    c.saveState()
    color = RED if side == "red" else BLACK_PIECE
    c.setFillColor(PAPER if not dashed else colors.white)
    c.setStrokeColor(color)
    c.setLineWidth(1.5)
    if dashed:
        c.setDash(3, 2)
    c.circle(x, y, radius, fill=1, stroke=1)
    c.setDash()
    c.setFillColor(color)
    c.setFont("NotoSansSC", max(5.5, radius * 0.82))
    c.drawCentredString(x, y - radius * 0.32, label)
    c.restoreState()


def point(c, x, y, fill=GOLD, radius=3.2, stroke=None) -> None:
    c.saveState()
    c.setFillColor(fill)
    c.setStrokeColor(stroke or fill)
    c.circle(x, y, radius, fill=1, stroke=1)
    c.restoreState()


def grid(c, x, y, cols, rows, cell, stroke=GRID, width=0.55) -> None:
    c.saveState()
    c.setStrokeColor(stroke)
    c.setLineWidth(width)
    for col in range(cols):
        c.line(x + col * cell, y, x + col * cell, y + (rows - 1) * cell)
    for row in range(rows):
        c.line(x, y + row * cell, x + (cols - 1) * cell, y + row * cell)
    c.restoreState()


class Diagram(Flowable):
    def __init__(self, title: str, caption: str, height: float,
                 draw_fn: Callable, width: float = CONTENT_W):
        super().__init__()
        self.title = title
        self.caption = caption
        self.width = width
        self.height = height
        self.draw_fn = draw_fn

    def wrap(self, availWidth, availHeight):
        return min(self.width, availWidth), self.height

    def draw(self):
        c = self.canv
        w = self.width
        h = self.height
        c.saveState()
        c.setFillColor(PANEL)
        c.setStrokeColor(HexColor("#D4C8B8"))
        c.setLineWidth(0.8)
        c.roundRect(0, 0, w, h, 7, fill=1, stroke=1)
        c.setFillColor(INK)
        c.setFont("NotoSansSC", 9.4)
        c.drawString(9, h - 15, self.title)
        self.draw_fn(c, 9, 20, w - 18, h - 42)
        c.setFillColor(MUTED)
        c.setFont("NotoSansSC", 6.7)
        c.drawCentredString(w / 2, 7, self.caption)
        c.restoreState()


def diagram_pair(left: Diagram, right: Diagram) -> Table:
    gap = 5 * mm
    table = Table([[left, right]], colWidths=[(CONTENT_W - gap) / 2] * 2)
    table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (0, -1), gap / 2),
        ("LEFTPADDING", (1, 0), (1, -1), gap / 2),
        ("RIGHTPADDING", (1, 0), (-1, -1), 0),
    ]))
    return table


def movement_draw(destinations: list[tuple[int, int]], origin=(3, 3),
                  blocker=None, blocked_targets=None, label="棋", side="red"):
    def _draw(c, x, y, w, h):
        cell = min(19, (w - 15) / 6, (h - 10) / 6)
        gx = x + (w - 6 * cell) / 2
        gy = y + (h - 6 * cell) / 2
        grid(c, gx, gy, 7, 7, cell)
        ox, oy = gx + origin[0] * cell, gy + origin[1] * cell
        for col, row in destinations:
            dx, dy = gx + col * cell, gy + row * cell
            arrow(c, ox, oy, dx, dy, BLUE, 1.0, 4)
            point(c, dx, dy, BLUE, 3)
        if blocker:
            bx, by = gx + blocker[0] * cell, gy + blocker[1] * cell
            piece(c, bx, by, "挡", "black", radius=6)
        for col, row in blocked_targets or []:
            dx, dy = gx + col * cell, gy + row * cell
            c.saveState()
            c.setStrokeColor(RED)
            c.setLineWidth(1.5)
            c.line(dx - 5, dy - 5, dx + 5, dy + 5)
            c.line(dx - 5, dy + 5, dx + 5, dy - 5)
            c.restoreState()
        piece(c, ox, oy, label, side, radius=9)
    return _draw


def draw_regions(c, x, y, w, h):
    cell = min(8.0, h / 23)
    board_w = 8 * cell
    board_h = 23 * cell
    bx = x + 32
    by = y + (h - board_h) / 2
    bands = [
        (0, 2, RED_LIGHT, "红方大本营  Y=1..3"),
        (3, 7, GOLD_LIGHT, "红方缓冲区  Y=4..8"),
        (8, 15, GREEN_LIGHT, "中央战区  Y=9..16"),
        (16, 20, BLUE_LIGHT, "黑方缓冲区  Y=17..21"),
        (21, 23, FOG_LIGHT, "黑方大本营  Y=22..24"),
    ]
    for lo, hi, col, _ in bands:
        c.setFillColor(col)
        c.rect(bx, by + lo * cell, board_w, (hi - lo) * cell, fill=1, stroke=0)
    grid(c, bx, by, 9, 24, cell)
    c.setStrokeColor(RED)
    c.setLineWidth(2)
    c.line(bx, by + 3 * cell, bx + board_w, by + 3 * cell)
    c.setStrokeColor(BLACK_PIECE)
    c.line(bx, by + 20 * cell, bx + board_w, by + 20 * cell)
    c.setFont("NotoSansSC", 7)
    c.setFillColor(INK)
    for lo, hi, _, label in bands:
        c.drawString(bx + board_w + 15, by + ((lo + hi) / 2) * cell - 2, label)
    c.setFillColor(RED)
    c.drawString(bx + board_w + 15, by + 3 * cell - 2, "红墙 Y=4")
    c.setFillColor(BLACK_PIECE)
    c.drawString(bx + board_w + 15, by + 20 * cell - 2, "黑墙 Y=21")
    c.setFillColor(MUTED)
    c.drawString(bx, by - 12, "红方前进方向  +Y ↑")


def draw_initial(c, x, y, w, h):
    labels_red = ["车", "马", "相", "士", "帅", "士", "相", "马", "车"]
    labels_black = ["车", "马", "象", "士", "将", "士", "象", "马", "车"]
    cell = min(19, (w / 2 - 30) / 8)
    for index, (side, labels, ox) in enumerate([
        ("red", labels_red, x + 8),
        ("black", labels_black, x + w / 2 + 10),
    ]):
        oy = y + 16
        grid(c, ox, oy, 9, 4, cell)
        home_row = 0 if side == "red" else 3
        cannon_row = 2 if side == "red" else 1
        wall_row = 3 if side == "red" else 0
        for col, label in enumerate(labels):
            piece(c, ox + col * cell, oy + home_row * cell, label, side, radius=cell * 0.38)
        for col in (1, 7):
            piece(c, ox + col * cell, oy + cannon_row * cell, "炮", side, radius=cell * 0.38)
        for col in (0, 2, 4, 6, 8):
            piece(c, ox + col * cell, oy + wall_row * cell, "兵" if side == "red" else "卒", side, radius=cell * 0.38)
        c.setFillColor(RED if side == "red" else BLACK_PIECE)
        c.setFont("NotoSansSC", 7.5)
        c.drawCentredString(ox + 4 * cell, oy + 3 * cell + 13, "红方" if side == "red" else "黑方（显示时旋转到底部）")


def draw_cannon(c, x, y, w, h):
    cell = min(26, (w - 40) / 6)
    gx = x + (w - 6 * cell) / 2
    gy = y + h / 2
    grid(c, gx, gy, 7, 1, cell)
    piece(c, gx, gy, "炮", "red", 9)
    piece(c, gx + 3 * cell, gy, "架", "red", 8)
    piece(c, gx + 6 * cell, gy, "车", "black", 9)
    arrow(c, gx + 10, gy + 12, gx + 6 * cell - 10, gy + 12, RED)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 7)
    c.drawCentredString(gx + 3 * cell, gy - 20, "吃子时中间恰好一枚炮架")


def draw_pawn(c, x, y, w, h):
    cell = 26
    gx = x + (w - 4 * cell) / 2
    gy = y + 12
    grid(c, gx, gy, 5, 5, cell)
    ox, oy = gx + 2 * cell, gy + 2 * cell
    for dx, dy in ((0, 1), (-1, 0), (1, 0)):
        arrow(c, ox, oy, ox + dx * cell, oy + dy * cell, BLUE)
        point(c, ox + dx * cell, oy + dy * cell, BLUE)
    c.setStrokeColor(RED)
    c.setLineWidth(1.4)
    c.line(ox - 5, oy - cell - 5, ox + 5, oy - cell + 5)
    c.line(ox - 5, oy - cell + 5, ox + 5, oy - cell - 5)
    piece(c, ox, oy, "兵", "red", 9)
    c.setFont("NotoSansSC", 7)
    c.setFillColor(MUTED)
    c.drawCentredString(ox, gy + 4 * cell + 10, "前")


def draw_palace(c, x, y, w, h):
    cell = 36
    gx = x + (w - 2 * cell) / 2
    gy = y + 12
    grid(c, gx, gy, 3, 3, cell)
    c.setStrokeColor(GRID)
    c.line(gx, gy, gx + 2 * cell, gy + 2 * cell)
    c.line(gx + 2 * cell, gy, gx, gy + 2 * cell)
    piece(c, gx + cell, gy + cell, "士", "red", 10)
    for col, row in ((0, 0), (2, 0), (0, 2), (2, 2)):
        point(c, gx + col * cell, gy + row * cell, GOLD)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 7)
    c.drawCentredString(gx + cell, gy - 14, "士斜走；将帅直走；都不能离开九宫")


def draw_general(c, x, y, w, h):
    cell = 34
    gx = x + (w - 2 * cell) / 2
    gy = y + 14
    grid(c, gx, gy, 3, 3, cell)
    ox, oy = gx + cell, gy + cell
    for dx, dy in ((0, 1), (0, -1), (-1, 0), (1, 0)):
        arrow(c, ox, oy, ox + dx * cell, oy + dy * cell, BLUE, 1.1, 4)
    piece(c, ox, oy, "帅", "red", 10)


def draw_special_pawn(c, x, y, w, h):
    cell = min(24, (w - 40) / 6)
    gx = x + (w - 6 * cell) / 2
    gy = y + h / 2
    grid(c, gx, gy, 7, 1, cell)
    piece(c, gx, gy, "兵", "red", 9)
    piece(c, gx + 2 * cell, gy, "敌", "black", 7)
    piece(c, gx + 4 * cell, gy, "敌", "black", 7)
    point(c, gx + 6 * cell, gy, GREEN, 4)
    arrow(c, gx + 10, gy + 13, gx + 6 * cell - 6, gy + 13, GREEN, 1.7, 5)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 7)
    c.drawCentredString(gx + 3 * cell, gy - 19, "直线 2-5 点；可穿敌不伤；终点必须为空")


def draw_special_rook(c, x, y, w, h):
    cell = min(22, (w - 30) / 7)
    gx = x + (w - 7 * cell) / 2
    gy = y + h / 2
    grid(c, gx, gy, 8, 1, cell)
    piece(c, gx, gy, "车", "red", 9)
    piece(c, gx + 2 * cell, gy, "卒", "black", 7)
    piece(c, gx + 4 * cell, gy, "炮", "black", 7)
    piece(c, gx + 6 * cell, gy, "马", "black", 7, dashed=True)
    point(c, gx + 7 * cell, gy, BLUE, 3)
    arrow(c, gx + 10, gy + 13, gx + 7 * cell - 4, gy + 13, BLUE)
    c.setStrokeColor(BLUE)
    c.setLineWidth(2.2)
    c.line(gx, gy - 14, gx + 6 * cell, gy - 14)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 6.8)
    c.drawCentredString(gx + 3.5 * cell, gy - 25, "按路径顺序处理敌棋；首次接触未显形马时吃马并停点")


def draw_elephant_vision(c, x, y, w, h):
    cell = min(22, (w - 20) / 6, (h - 20) / 6)
    gx = x + (w - 6 * cell) / 2
    gy = y + (h - 6 * cell) / 2
    grid(c, gx, gy, 7, 7, cell)
    start = (2, 2)
    dest = (4, 4)
    for cx, cy in [(a, b) for a in range(1, 4) for b in range(1, 4)]:
        c.setFillColor(colors.Color(62/255, 125/255, 142/255, alpha=0.16))
        c.rect(gx + cx * cell - cell/2, gy + cy * cell - cell/2, cell, cell, fill=1, stroke=0)
    for cx, cy in [(a, b) for a in range(2, 5) for b in range(2, 5)]:
        c.setFillColor(colors.Color(189/255, 139/255, 50/255, alpha=0.20))
        c.rect(gx + cx * cell - cell/2, gy + cy * cell - cell/2, cell, cell, fill=1, stroke=0)
    for cx, cy in [(a, b) for a in range(3, 6) for b in range(3, 6)]:
        c.setFillColor(colors.Color(93/255, 123/255, 85/255, alpha=0.16))
        c.rect(gx + cx * cell - cell/2, gy + cy * cell - cell/2, cell, cell, fill=1, stroke=0)
    grid(c, gx, gy, 7, 7, cell)
    piece(c, gx + start[0]*cell, gy + start[1]*cell, "相", "red", 8)
    piece(c, gx + dest[0]*cell, gy + dest[1]*cell, "终", "red", 8)
    c.setStrokeColor(GOLD)
    c.setLineWidth(1.8)
    c.rect(gx + 1.5*cell, gy + 1.5*cell, 3*cell, 3*cell, fill=0, stroke=1)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 6.6)
    c.drawString(gx, gy - 12, "蓝：起点 3x3   金：田字九点（显形/阻挡）   绿：终点 3x3")


def draw_bombard(c, x, y, w, h):
    cell = min(32, (h - 12) / 2)
    gx = x + (w - 2 * cell) / 2
    gy = y + 6
    c.setFillColor(RED_LIGHT)
    c.rect(gx - cell/2, gy - cell/2, 3*cell, 3*cell, fill=1, stroke=0)
    grid(c, gx, gy, 3, 3, cell)
    for col, row in ((0, 2), (1, 0), (2, 1)):
        c.setFillColor(RED)
        c.circle(gx + col*cell, gy + row*cell, 7, fill=1, stroke=0)
        c.setFillColor(colors.white)
        c.setFont("NotoSansSC", 6.5)
        c.drawCentredString(gx + col*cell, gy + row*cell - 2.3, "命中")
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 7)
    c.drawCentredString(gx + cell, gy + 2*cell + 14, "预览只显示 3x3 风险区；确认后随机三处不同落点")


def draw_sacrifice(c, x, y, w, h):
    cy = y + h / 2
    xs = [x + 22, x + w*0.34, x + w*0.64, x + w - 24]
    labels = [("士", "red"), ("阵亡", "black"), ("筛选", "red"), ("复活", "red")]
    for index, (label, side) in enumerate(labels):
        piece(c, xs[index], cy, label, side, 11)
        if index < len(labels) - 1:
            arrow(c, xs[index] + 13, cy, xs[index+1] - 13, cy, GOLD, 1.4, 4)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 6.7)
    c.drawCentredString(xs[1], cy - 22, "士先进入公开阵亡记录")
    c.drawCentredString(xs[2], cy - 22, "排除士与将帅")
    c.drawCentredString(xs[3], cy - 22, "随机己方大本营空点")


def draw_fog(c, x, y, w, h):
    cell = min(28, (h - 16) / 4)
    gx = x + 25
    gy = y + 8
    for col in range(5):
        for row in range(5):
            visible = 1 <= col <= 3 and 1 <= row <= 3
            c.setFillColor(PANEL if visible else FOG_LIGHT)
            c.rect(gx + col*cell - cell/2, gy + row*cell - cell/2, cell, cell, fill=1, stroke=0)
    grid(c, gx, gy, 5, 5, cell)
    piece(c, gx + 2*cell, gy + 2*cell, "兵", "red", 9)
    c.setFillColor(INK)
    c.setFont("NotoSansSC", 7)
    c.drawString(gx + 5*cell + 18, gy + 3*cell, "普通棋子提供当前位置周围 3x3 视野")
    c.drawString(gx + 5*cell + 18, gy + 2*cell, "移动后旧视野撤除，无其他来源就重新入雾")
    c.drawString(gx + 5*cell + 18, gy + cell, "旗帜发现记忆会保留；普通地形视野不会保留")


def draw_wall(c, x, y, w, h):
    left = x + 12
    right = x + w - 12
    cy = y + h/2
    sections = [
        (left, left + (right-left)*0.28, GREEN_LIGHT, "战区"),
        (left + (right-left)*0.28, left + (right-left)*0.62, GOLD_LIGHT, "守方缓冲区"),
        (left + (right-left)*0.62, right, BLUE_LIGHT, "守方大本营"),
    ]
    for x1, x2, col, label in sections:
        c.setFillColor(col)
        c.rect(x1, cy-34, x2-x1, 68, fill=1, stroke=0)
        c.setFillColor(INK)
        c.setFont("NotoSansSC", 7)
        c.drawCentredString((x1+x2)/2, cy+42, label)
    wall_x = sections[1][1]
    c.setStrokeColor(BLACK_PIECE)
    c.setLineWidth(4)
    c.line(wall_x, cy-36, wall_x, cy+36)
    for i in range(3):
        piece(c, sections[1][0] + 25 + i*28, cy, "红", "red", 8)
    c.setFillColor(RED)
    c.setFont("NotoSansSC", 7)
    c.drawCentredString((sections[1][0]+sections[1][1])/2, cy-49, "缓冲区同时有 3 枚入侵棋：城墙倒塌")
    arrow(c, sections[0][0]+18, cy+18, sections[1][0]+18, cy+18, BLUE, 1.2, 4)
    arrow(c, sections[1][0]+18, cy-18, sections[2][0]+18, cy-18, BLUE, 1.2, 4)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 6.6)
    c.drawString(sections[0][0]+6, cy+27, "第 1 次行动")
    c.drawString(sections[1][0]+6, cy-29, "第 2 次行动")


def draw_wall_cycle(c, x, y, w, h):
    cy = y + h/2
    xs = [x + 48, x + w/2, x + w - 52]
    labels = [("完整", GREEN), ("倒塌", RED), ("修复中", GOLD)]
    for i, (label, col) in enumerate(labels):
        c.setFillColor(colors.white)
        c.setStrokeColor(col)
        c.setLineWidth(2)
        c.circle(xs[i], cy, 25, fill=1, stroke=1)
        c.setFillColor(col)
        c.setFont("NotoSansSC", 8.5)
        c.drawCentredString(xs[i], cy-3, label)
    arrow(c, xs[0]+27, cy+8, xs[1]-27, cy+8, RED, 1.4, 5)
    arrow(c, xs[1]+27, cy+8, xs[2]-27, cy+8, GOLD, 1.4, 5)
    arrow(c, xs[2]-10, cy-28, xs[0]+10, cy-28, GREEN, 1.4, 5)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 6.6)
    c.drawCentredString((xs[0]+xs[1])/2, cy+23, "缓冲区 3 敌棋")
    c.drawCentredString((xs[1]+xs[2])/2, cy+23, "守区入侵数 < 3")
    c.drawCentredString((xs[2]+xs[0])/2, cy-42, "启动后双方各行动一次且未被打断")


def draw_flag(c, x, y, w, h):
    cy = y + h*0.62
    xs = [x+30, x+w*0.29, x+w*0.52, x+w*0.74, x+w-30]
    labels = ["迷雾", "发现", "1/3", "2/3", "3/3"]
    cols = [FOG, BLUE, GOLD, GOLD, GREEN]
    for i, label in enumerate(labels):
        c.setFillColor(cols[i])
        c.circle(xs[i], cy, 14, fill=1, stroke=0)
        c.setFillColor(colors.white)
        c.setFont("NotoSansSC", 6.6)
        c.drawCentredString(xs[i], cy-2.3, label)
        if i < len(labels)-1:
            arrow(c, xs[i]+16, cy, xs[i+1]-16, cy, INK, 1.0, 4)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 6.6)
    c.drawCentredString((xs[0]+xs[1])/2, cy-25, "进入己方视野")
    c.drawCentredString((xs[2]+xs[4])/2, cy-25, "占领者不离开；对方每完成一次行动推进 1")
    c.setFillColor(RED_LIGHT)
    c.roundRect(x+30, y+4, w-60, 24, 5, fill=1, stroke=0)
    c.setFillColor(RED)
    c.drawCentredString(x+w/2, y+13, "离开、死亡、献祭、复活或强制撤回：占领进度立即清零")


def draw_preview(c, x, y, w, h):
    entries = [
        ("确定合法", GREEN, "可见信息足以证明合法"),
        ("存在风险", GOLD, "迷雾可能影响真实结果，可提交"),
        ("确定非法", RED, "仅凭可见信息已能判定，不可提交"),
    ]
    row_h = h / 3
    for i, (name, col, desc) in enumerate(entries):
        yy = y + h - (i+0.5)*row_h
        c.setFillColor(col)
        c.roundRect(x+8, yy-10, 54, 20, 5, fill=1, stroke=0)
        c.setFillColor(colors.white)
        c.setFont("NotoSansSC", 7)
        c.drawCentredString(x+35, yy-2.5, name)
        c.setFillColor(INK)
        c.drawString(x+72, yy-2.5, desc)


def draw_reserve(c, x, y, w, h):
    cy = y + h/2
    labels = ["撤回/复活", "己方营空点", "后备队列", "行动开始部署"]
    xs = [x+28, x+w*0.34, x+w*0.62, x+w-34]
    for i, label in enumerate(labels):
        c.setFillColor(PANEL)
        c.setStrokeColor([BLUE, GREEN, GOLD, RED][i])
        c.roundRect(xs[i]-24, cy-14, 48, 28, 6, fill=1, stroke=1)
        c.setFillColor(INK)
        c.setFont("NotoSansSC", 6.5)
        c.drawCentredString(xs[i], cy-2, label)
        if i < 3:
            arrow(c, xs[i]+26, cy, xs[i+1]-26, cy, MUTED, 1.0, 4)
    c.setFillColor(MUTED)
    c.setFont("NotoSansSC", 6.5)
    c.drawCentredString(x+w/2, y+5, "无空位才入队；后备棋不在场、不提供视野、不充当炮架；部署不消耗行动")


def draw_settlement(c, x, y, w, h):
    steps = [
        ("确认", BLUE), ("位移", BLUE), ("伤亡/复活", RED),
        ("将帅终局", RED), ("临时状态", GOLD), ("城墙", GOLD),
        ("旗帜", GREEN), ("轮上限", GREEN), ("投影换手", INK),
    ]
    cols = 5
    box_w = (w - 4*10) / cols
    box_h = 28
    positions = []
    for i in range(len(steps)):
        row = 1 if i >= cols else 0
        col = i-cols if row else i
        if row == 0:
            px = x + col*(box_w+10)
            py = y + h - box_h - 6
        else:
            px = x + (cols-2-col)*(box_w+10)
            py = y + 7
        positions.append((px, py))
    for i, ((label, col), (px, py)) in enumerate(zip(steps, positions)):
        c.setFillColor(colors.white)
        c.setStrokeColor(col)
        c.setLineWidth(1.2)
        c.roundRect(px, py, box_w, box_h, 5, fill=1, stroke=1)
        c.setFillColor(INK)
        c.setFont("NotoSansSC", 6.6)
        c.drawCentredString(px+box_w/2, py+box_h/2-2, label)
        if i < len(steps)-1:
            nx, ny = positions[i+1]
            if abs(ny-py) < 2:
                if nx > px:
                    arrow(c, px+box_w+2, py+box_h/2, nx-2, ny+box_h/2, MUTED, 0.9, 3)
                else:
                    arrow(c, px-2, py+box_h/2, nx+box_w+2, ny+box_h/2, MUTED, 0.9, 3)
            else:
                arrow(c, px+box_w/2, py-2, nx+box_w/2, ny+box_h+2, MUTED, 0.9, 3)


def cover_page(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(PAPER)
    canvas.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    canvas.setStrokeColor(RED)
    canvas.setLineWidth(2.2)
    canvas.line(MARGIN_X, PAGE_H-20*mm, PAGE_W-MARGIN_X, PAGE_H-20*mm)
    canvas.setStrokeColor(GOLD)
    canvas.setLineWidth(0.8)
    canvas.line(MARGIN_X, 18*mm, PAGE_W-MARGIN_X, 18*mm)
    canvas.setFillColor(MUTED)
    canvas.setFont("NotoSansSC", 7.2)
    canvas.drawCentredString(PAGE_W/2, 10*mm, "玩家规则教学手册 v1 | owner-freeze revision 5 | 2026-08")
    canvas.restoreState()


def later_page(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(PAPER)
    canvas.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    canvas.setStrokeColor(HexColor("#D1C5B4"))
    canvas.setLineWidth(0.5)
    canvas.line(MARGIN_X, PAGE_H-12*mm, PAGE_W-MARGIN_X, PAGE_H-12*mm)
    canvas.line(MARGIN_X, 11*mm, PAGE_W-MARGIN_X, 11*mm)
    canvas.setFillColor(MUTED)
    canvas.setFont("NotoSansSC", 7.2)
    canvas.drawString(MARGIN_X, PAGE_H-9*mm, "《雾疆：九路烽棋》玩家规则教学手册")
    canvas.drawRightString(PAGE_W-MARGIN_X, 7*mm, f"{doc.page}")
    canvas.restoreState()


def page_title(number: str, title: str, lead: str | None = None):
    result = [P(f"{number}  {title}", H1)]
    if lead:
        result.append(P(lead, SUBTITLE))
    return result


def build_story():
    story = []

    # Cover
    story += [
        Spacer(1, 27*mm),
        P("雾疆：九路烽棋", TITLE),
        P("新手规则教学手册", ParagraphStyle(
            "CoverSub", parent=TITLE, fontSize=22, leading=30, textColor=RED,
        )),
        P("从第一步走法，到迷雾、破墙与夺旗", SUBTITLE),
        Spacer(1, 6*mm),
        Diagram("九路入雾", "九路交点战场，红黑双方都从自己的大本营向中央战区推进。", 100*mm, draw_regions),
        Spacer(1, 8*mm),
        callout("本手册适合谁", "没玩过象棋的玩家可以从头阅读；会象棋的玩家可先看第 2 页的差异清单，再跳到特殊能力部分。", "blue"),
        Spacer(1, 5*mm),
        P("本手册只使用玩家可以获得的信息解释规则。未发现的旗位、迷雾内敌棋和未公开随机结果不会被提前展示。", COVER_NOTE),
        PageBreak(),
    ]

    # 1 quick start
    story += page_title("01", "一分钟认识这局棋", "先理解你要做什么，再学习每枚棋子怎么走。")
    story += bullets([
        "棋盘有 <b>9 路、24 线</b>，棋子落在横线与竖线的交点上。",
        "红方固定先手。双方轮流完成一次行动；红黑各完成一次行动记为一个完整轮。主动跳过、超时跳过、无合法行动跳过也算一次行动。",
        "开局除己方大本营外，大部分棋盘被战争迷雾覆盖。移动棋子可以建立视野。",
        "中央战区随机放置三面旗。发现、占领并守住旗帜，是本作最重要的目标。",
        "获得三面非争夺状态的旗，或者实际吃掉敌方将帅，都可以立即结束对局。",
    ])
    story.append(Spacer(1, 3*mm))
    story.append(rule_table(
        ["如果你会传统象棋", "《雾疆》的关键变化"],
        [
            ["将军、应将、照面、飞将", "全部取消。将帅进入攻击范围不会自动失败，只有实际被吃掉才失败。"],
            ["兵卒过河", "不存在河界。兵卒始终可以向前、向左、向右一步，不可后退。"],
            ["马与相的活动范围", "马、相/象可以在全棋盘活动；满足特殊资格时还能无视马腿或象眼。"],
            ["胜负", "除实际吃将外，还可以通过三面战旗获胜。"],
            ["信息", "行动提示只基于你看得见的内容；迷雾中的未知阻挡可能让一次行动失败并消耗机会。"],
        ],
        [54*mm, CONTENT_W-54*mm],
    ))
    story.append(Spacer(1, 4*mm))
    story.append(callout("牢记一句话", "先侦察，再判断；先进入缓冲区，再攻大本营；旗要由同一枚棋子守到 3/3。", "gold"))
    story.append(PageBreak())

    # 2 board
    story += page_title("02", "棋盘、区域与初始阵型", "底层坐标永远以红方为准；黑方界面只做 180° 显示旋转。")
    story.append(Diagram("五个战场区域", "红方朝 +Y 前进，黑方朝 -Y 前进；Y=12/13 只是几何中线，不是河界。", 90*mm, draw_regions))
    story.append(Spacer(1, 3*mm))
    story.append(Diagram("双方初始阵型", "车马相士帅士相马车居底线，双炮居第三线，五兵/卒就在各自城墙线上。", 57*mm, draw_initial))
    story += bullets([
        "红方大本营 Y=1..3；红方缓冲区 Y=4..8；中央战区 Y=9..16。",
        "黑方缓冲区 Y=17..21；黑方大本营 Y=22..24。红墙在 Y=4，黑墙在 Y=21。",
        "红方九宫为 X=4..6、Y=1..3；黑方九宫为 X=4..6、Y=22..24。",
        "一个交点最多容纳一枚棋子；后备或阵亡棋子不占棋盘交点。",
    ])
    story.append(PageBreak())

    # 3 ordinary line pieces
    story += page_title("03", "普通走法：兵、车、炮", "先看本作始终有效的普通行动，再看后面的特殊能力。")
    half = (CONTENT_W - 5*mm)/2
    story.append(diagram_pair(
        Diagram("兵 / 卒", "前、左、右一步；可吃终点敌棋；不可后退。", 57*mm, draw_pawn, half),
        Diagram("车", "沿横线或竖线移动。普通状态下不能穿过任何棋子。", 57*mm,
                movement_draw([(3,0),(3,1),(3,2),(3,4),(3,5),(3,6),(0,3),(1,3),(2,3),(4,3),(5,3),(6,3)], label="车"), half),
    ))
    story.append(Spacer(1, 4*mm))
    story.append(Diagram("炮的普通移动与吃子", "炮像车一样移动；移动到空点不需要炮架，吃子时中间必须恰好一枚炮架。", 49*mm, draw_cannon))
    story.append(Spacer(1, 3*mm))
    story.append(callout("常见误解", "炮架可以是任意阵营的棋子。已知超过一枚炮架时确定非法；迷雾可能隐藏炮架时，精确吃子只会显示为存在风险。", "red"))
    story += bullets([
        "普通兵卒只有一步，但本作从开局起就能横走，不需要先过河。",
        "普通车不能穿过友军，也不能穿过敌军；特殊车满足资格后才会改成路径歼灭。",
        "炮精确吃子的目标必须当前可见并与炮同线；轰炸是另一种特殊行动。",
    ])
    story.append(PageBreak())

    # 4 ordinary leapers and palace
    story += page_title("04", "普通走法：马、相、士、将帅", "马与相可以跨全盘活动；士与将帅始终留在九宫。")
    story.append(diagram_pair(
        Diagram("马走日", "先沿横或竖方向走一格，再斜向走一格；默认状态会被马腿阻挡。", 59*mm,
                movement_draw([(1,2),(1,4),(2,1),(4,1),(5,2),(5,4),(2,5),(4,5)], blocker=(3,2), blocked_targets=[(2,1),(4,1)], label="马"), half),
        Diagram("相 / 象走田", "沿对角方向走两格；默认状态会被中心象眼阻挡。没有河界。", 59*mm,
                movement_draw([(1,1),(1,5),(5,1),(5,5)], blocker=(4,4), blocked_targets=[(5,5)], label="相"), half),
    ))
    story.append(Spacer(1, 4*mm))
    story.append(diagram_pair(
        Diagram("士", "在己方九宫内斜走一格。", 50*mm, draw_palace, half),
        Diagram("将 / 帅", "在己方九宫内横走或直走一格。", 50*mm, draw_general, half),
    ))
    story.append(Spacer(1, 3*mm))
    story.append(callout("本作没有将军", "将帅可以主动走进敌方攻击范围。没有应将、将死、照面或飞将检查；只有将帅实际死亡才触发最高优先级终局。", "red"))
    story.append(PageBreak())

    # 5 special eligibility
    story += page_title("05", "什么时候可以使用特殊行动", "马、相、车、兵的特殊能力共享一组资格；炮击单独判断。")
    story.append(callout("马 / 相 / 车 / 兵的共同资格", "敌方城墙必须完整，而且起点、路径上的每个交点、终点都必须位于 Y=4..21。任一条件不满足，只能生成普通行动。", "blue"))
    story.append(Spacer(1, 4*mm))
    story.append(rule_table(
        ["棋子", "满足资格后的变化", "敌墙倒塌时"],
        [
            ["马", "无视蹩马腿，落点后隐身。", "特殊能力立即失效；隐身仍按公开显形原因处理。"],
            ["相 / 象", "无视象眼，建立扩展视野、显形区和敌车/兵阻挡区。", "旧视野和阻挡源立即清除。"],
            ["车", "可穿敌并按路径顺序处理；完整路径提供视野。", "后续只按普通车行动；旧特殊路径能力不恢复。"],
            ["兵 / 卒", "横向或纵向移动 2-5 点，可穿敌不伤。", "后续只能普通一步。"],
            ["炮击", "敌墙完整、炮在己方大本营、该炮有弹药。", "不能轰炸；墙恢复后重新按三项资格判断。"],
        ],
        [21*mm, 87*mm, CONTENT_W-108*mm],
    ))
    story.append(Spacer(1, 4*mm))
    story.append(callout("永久资源", "每门炮初始有 2 发轰炸弹药，只减不增。没有阵营共享冷却，也不需要等待轮数。", "gold"))
    story.append(PageBreak())

    # 6 horse elephant
    story += page_title("06", "特殊马与特殊相", "一枚负责潜行，一枚负责侦察、显形和封路。")
    story.append(diagram_pair(
        Diagram("特殊马：越腿入雾", "满足资格时无视马腿；移动完成后隐身。虚线棋子表示对敌方不可见。", 62*mm,
                movement_draw([(4,1)], blocker=(3,2), label="马"), half),
        Diagram("特殊相：三段视野", "视野为起点 3x3、田字九点、终点 3x3 的并集。", 62*mm, draw_elephant_vision, half),
    ))
    story += bullets([
        "隐身马只有进入有效相/象田字显形区，或出现其他公开显形原因时，才向对方显示。",
        "城墙倒塌提供的是区域视野，不等于反隐；即使整片区域可见，隐身马仍可能不显示。",
        "相的黄色田字九点会截停从区域外进入或穿过的敌方车与兵/卒，到路径首个交点为止。",
        "田字区不阻挡己方车和兵/卒；已经在田字区内的敌棋可以正常离开。",
        "每枚相最多保留一个自己的视野源；下次移动开始、死亡、回营、入后备或敌墙倒塌时清除。多个相的有效区域取并集。",
    ])
    story.append(callout("看图时要分清", "蓝色和绿色区域都能侦察；只有黄色田字九点负责显形与截停。不要把整片扩展视野都当作阻挡区。", "gold"))
    story.append(PageBreak())

    # 7 rook pawn
    story += page_title("07", "特殊车与特殊兵", "车用路径制造压制，兵用穿阵获得长距离机动。")
    story.append(diagram_pair(
        Diagram("特殊车：蓝线开路", "沿路径依次处理敌棋；不能穿友军；路径视野持续到该车下次移动开始。", 58*mm, draw_special_rook, half),
        Diagram("特殊兵：穿阵不伤", "直线移动 2-5 点；可以穿过多枚敌棋，但不能穿友军。", 58*mm, draw_special_pawn, half),
    ))
    story += bullets([
        "特殊车按起点到终点的顺序处理敌棋。每枚实际死亡的棋先进入公开阵亡记录，再检查是否为将帅。",
        "若路径目标是将帅，将帅死亡后立即终局，车不再继续处理后面的目标。",
        "普通车路径中首次接触未显形敌马时，会在接触点吃掉该马并停下，不会形成无反馈失败。",
        "特殊兵的终点必须为空；穿越不吃沿途敌棋，也不提供路径视野。",
        "特殊兵终点若被迷雾中的敌棋占用，行动会按未知接触失败并消耗机会。",
    ])
    story.append(callout("一句话区别", "车的特殊路径会处理沿途敌棋；兵的特殊路径只穿过敌棋，沿途不造成伤害。", "blue"))
    story.append(PageBreak())

    # 8 cannon advisor
    story += page_title("08", "区域轰炸与士献祭", "两种行动都必须先预览、再确认；取消不会消费行动或随机数。")
    story.append(diagram_pair(
        Diagram("炮击：3x3 风险区", "炮不移动。九个交点中随机抽取三个不同伤害点，允许友军伤害。", 59*mm, draw_bombard, half),
        Diagram("士献祭：以身换援", "士先阵亡，再从合资格阵亡棋中随机选择一枚复活。", 59*mm, draw_sacrifice, half),
    ))
    story.append(rule_table(
        ["行动", "确认条件", "结算要点"],
        [
            ["区域轰炸", "敌墙完整；炮在己方大本营；该炮至少 1 发；中心完整 3x3 全在 Y=4..21。", "确认时消耗 1 发并锁定三个不同落点；三个格逻辑同时受击。"],
            ["士献祭复活", "士存活在场；公开阵亡记录存在非士、非将帅候选；士牺牲后己方大本营仍有真实空点。", "士先进入公开阵亡记录；候选随机、复活空点随机；不恢复弹药等永久资源。"],
        ],
        [28*mm, 78*mm, CONTENT_W-106*mm],
    ))
    story += bullets([
        "炮击预览不会提前显示三个命中点，也不会预演随机数。",
        "轰炸动画可以依次播放，但逻辑按同一快照同时受击；同一窗口双方将帅都死亡则平局。",
        "阵亡士与将帅会出现在公开阵亡记录中，但永远不进入士复活候选池。",
        "炮击和主动献祭不会留下阵亡虚影，也不会触发任何被动士替死。",
    ])
    story.append(PageBreak())

    # 9 fog
    story += page_title("09", "战争迷雾与视野", "你只能根据自己的 PlayerView 做判断；小地图与主棋盘遵守同一信息边界。")
    story.append(Diagram("普通 3x3 动态视野", "己方大本营始终可见；普通棋子提供当前位置周围 3x3；车、相和破墙区域会叠加额外视野。", 60*mm, draw_fog))
    story += bullets([
        "开局除己方大本营外均受迷雾。敌棋只有位于可见交点且没有隐身时才会显示。",
        "普通棋子移动后，旧 3x3 视野立即撤除；若没有其他来源覆盖，交点重新入雾。",
        "车的特殊路径视野持续到该车下次移动开始；相的扩展视野按自己的生命周期清除。",
        "敌墙倒塌或修复中时，你会看见守方缓冲区与大本营全部交点；墙恢复后该额外视野立即消失。",
        "旗帜是例外：一旦由你发现，即使该点重新入雾，地图仍保留旗帜记忆图标。另一方不会因此获得坐标。",
        "不可见的敌方相田、车路径、炮架、未来随机结果和规则种子都必须隐藏。",
    ])
    story.append(callout("没有免费侦察按钮", "接触情报只能来自已经提交并消耗行动的尝试、实际命中，或马/相/车等正式侦察能力。", "gray"))
    story.append(PageBreak())

    # 10 previews
    story += page_title("10", "行动提示与迷雾风险", "高亮不是完整世界真相，它只表示你当前能判断到什么程度。")
    story.append(Diagram("三种行动提示", "界面不得用按钮、颜色、排序或鼠标形状提前泄露隐藏阻挡。", 55*mm, draw_preview))
    story.append(rule_table(
        ["情况", "结果", "公开反馈"],
        [
            ["确定非法", "不能提交，不消耗行动。", "直接说明仅凭可见信息可确认的原因。"],
            ["风险行动被隐藏路径或马腿/象眼阻挡", "棋子原地不动，但消耗一次行动。", "只提示路线受到未知阻挡，不公开坐标、类型或数量。"],
            ["可吃子行动落到隐藏敌棋所在终点", "执行盲吃并进入目标交点。", "命中后公开被吃棋身份。"],
            ["不能吃子的移动落到隐藏敌棋终点", "失败并消耗行动。", "记录一次最后已知接触；若目标是隐身马，同时发生接触显形。"],
            ["炮精确吃子", "目标必须可见；FullState 中恰好一枚炮架才成功。", "失败只提示炮路不成立。"],
        ],
        [45*mm, 48*mm, CONTENT_W-93*mm],
    ))
    story.append(Spacer(1, 3*mm))
    story.append(callout("风险不是 bug", "迷雾中的行动允许存在不确定性。你提交的是行动意图，不是“保证合法”的命令；真正结果由权威局面解析。", "gold"))
    story.append(PageBreak())

    # 11 walls
    story += page_title("11", "城墙、破墙与进攻大本营", "两面城墙独立运作。完整墙挡住墙线，但不会阻止敌人先进入外侧缓冲区。")
    story.append(Diagram("三子破墙与两段进营", "缓冲区同时有至少三枚敌棋时破墙；即使墙已破，也必须先停入守方缓冲区，下一次行动才可进入大本营。", 60*mm, draw_wall))
    story.append(Diagram("城墙状态循环", "修复中仍按倒塌墙处理；若入侵数重新达到三枚，立刻退回倒塌并清零修复进度。", 48*mm, draw_wall_cycle))
    story += bullets([
        "完整墙阻止敌棋踏上或跨过墙线。进攻红方时最深只能到 Y=5；进攻黑方时最深只能到 Y=20。",
        "守方缓冲区内同时有至少三枚敌棋，城墙立即倒塌。",
        "缓冲区与大本营内敌棋总数少于三枚时，在该行动结算后进入修复中；触发修复的行动本身不计修复进度。",
        "进入修复中后，红黑双方各再完成一次行动且条件持续成立，城墙恢复完整。",
        "城墙恢复时，只撤回守方大本营内的入侵棋；仍在缓冲区的敌棋不撤回。",
        "撤回棋随机放回各自大本营；没有空点的进入后备队列。",
        "倒塌和修复中会开放守方缓冲区与大本营视野，但不会自动看见隐身马。",
    ])
    story.append(PageBreak())

    # 12 flags
    story += page_title("12", "旗帜：发现、占领与争夺", "三面旗随机位于中央战区的不同交点，开局都受迷雾保护。")
    story.append(Diagram("从发现到 3/3", "棋子停在中立旗或敌方旗上开始 1/3；之后对方每完成一次行动机会，占领推进一次。", 58*mm, draw_flag))
    story += bullets([
        "旗位进入你的视野后，会永久写入你的发现记忆；离开视野后仍显示记忆图标。",
        "占领进度绑定具体棋子，不能换另一枚棋继承。",
        "占领者离开、死亡、主动献祭、复活、强制撤回或棋子实例改变，进度立即清零。",
        "占领完成后，旗的所有权永久保留，原占领者可以离开。",
        "敌方开始重占时，原所有权暂时保留，但旗进入争夺状态。争夺中的旗不计入三旗即时胜利。",
        "争夺中断后，原所有权安全保留；达到完整轮上限时，争夺旗仍计给原所有者。",
        "占领进度消息只公开阵营和 n/3，不会把尚未发现的旗坐标告诉另一方。",
    ])
    story.append(callout("三旗胜利", "同一阵营拥有三面旗，而且三面旗都不处于争夺状态时，立即获胜。", "green"))
    story.append(PageBreak())

    # 13 casualties/reserve
    story += page_title("13", "阵亡记录、虚影、复活与后备", "公开阵亡记录和士复活候选池不是同一个集合。")
    story.append(Diagram("没有空位时进入后备队列", "后备棋按 FIFO 排队，在本方行动开始、生成可选行动之前尝试自动部署。", 52*mm, draw_reserve))
    story.append(rule_table(
        ["对象", "规则"],
        [
            ["公开阵亡记录", "所有原因造成的实际死亡都会登记，双方都能看到；复活后立即移出。"],
            ["士复活候选池", "只从发动方当前阵亡记录筛选非士、非将帅棋子。"],
            ["阵亡虚影", "普通吃子或车路径吃子后，只向阵亡方在原交点显示，持续到对方下一次行动完成。"],
            ["不生成虚影", "炮击和主动献祭不会生成阵亡虚影。"],
            ["后备棋", "不视为死亡；不在棋盘、不可行动或被攻击、不提供视野、不充当炮架或阻挡、不计入墙与旗。"],
            ["自动部署", "己方大本营出现空点时，行动开始按 FIFO 随机部署；不消耗行动，刚部署棋可立即被选择。"],
        ],
        [39*mm, CONTENT_W-39*mm],
    ))
    story.append(Spacer(1, 3*mm))
    story.append(callout("永久消耗不会恢复", "复活、撤回或后备部署不会恢复炮弹、技能次数或其他永久资源。临时隐身、占旗进度和临时视野会被清除。", "red"))
    story.append(PageBreak())

    # 14 settlement / victory
    story += page_title("14", "胜负与行动结算顺序", "看似同时发生的事情也有明确先后；最高优先级是将帅实际死亡。")
    story.append(Diagram("一次行动的核心结算顺序", "终局一旦在将帅阶段成立，后续临时状态、城墙、旗帜和轮上限不再处理。", 54*mm, draw_settlement))
    story.append(rule_table(
        ["优先级", "检查内容", "结果"],
        [
            ["1", "将帅实际死亡", "仅一方死亡则该方失败；同一炮击窗口双方都死亡则平局。"],
            ["2", "城墙与临时状态", "更新隐身、相田、车路径、虚影、墙状态和撤回。"],
            ["3", "三面非争夺旗", "满足时立即获胜。"],
            ["4", "完整轮上限", "仅在完整轮边界检查；按旗所有权数量判胜，同数平局。"],
            ["5", "投影与换手", "生成观察者安全信息后切换行动方；终局不换手。"],
        ],
        [18*mm, 56*mm, CONTENT_W-74*mm],
    ))
    story += bullets([
        "车路径逐个处理目标：每次死亡先登记，再检查是否为将帅；吃到将帅就立刻截断后续路径。",
        "炮击确认时锁定三个不同落点和开始前快照；三个格同步受击，动画顺序不改变逻辑。",
        "旗帜进度增加前，会先处理占领者死亡、离开、献祭、复活或撤回。",
        "主动跳过、超时跳过或无合法行动被迫跳过，会直接进入城墙/旗帜阶段并消耗一次行动机会。",
    ])
    story.append(callout("尚未冻结的规则", "单局完整轮上限仍是开放项。实际对局应显示当前运行配置；不要把测试使用的 50 或 100 轮当作最终批准规则。", "gray"))
    story.append(PageBreak())

    # 15 quick reference
    story += page_title("15", "快速查阅卡", "开局前看一遍，遇到疑问时再返回对应章节。")
    story.append(rule_table(
        ["棋子 / 系统", "普通规则", "特殊或关键规则"],
        [
            ["兵 / 卒", "前、左、右一步；不可后退。", "直线 2-5 点；穿敌不伤；不能穿友军；终点为空。"],
            ["车", "直线移动，不能穿子。", "穿敌顺序处理；路径视野；首次接触隐身马时吃马停点。"],
            ["炮", "直线移动；隔恰好一架吃子。", "大本营 3x3 轰炸；随机三点；每炮 2 发；无冷却。"],
            ["马", "走日；默认受马腿阻挡。", "特殊资格下无视马腿，落点后隐身。"],
            ["相 / 象", "走田；默认受象眼阻挡；可跨全盘。", "三段视野；田字九点显形并截停敌车与兵。"],
            ["士", "九宫内斜走。", "主动献祭；先取消也不消耗行动；排除士与将帅候选。"],
            ["将 / 帅", "九宫内直走。", "无将军/飞将；只有实际死亡才失败。"],
            ["城墙", "完整墙挡住墙线。", "缓冲区 3 敌棋破墙；少于 3 启动修复；进营必须两段。"],
            ["旗帜", "进入视野后永久记忆。", "同一棋子守到 3/3；三面非争夺旗即时胜利。"],
            ["迷雾", "普通棋子当前位置 3x3 视野。", "提示分确定合法、存在风险、确定非法；风险失败可能消耗行动。"],
        ],
        [29*mm, 66*mm, CONTENT_W-95*mm],
    ))
    story.append(Spacer(1, 3*mm))
    story.append(callout("最容易记错的四条", "1. 本作没有将军。2. 兵卒始终能横走。3. 破墙后仍要先停进缓冲区。4. 区域视野不等于看见隐身马。", "red"))
    story.append(Spacer(1, 3*mm))
    story += bullets([
        "规则基线：docs/prototype/rules-spec-v1.md，owner-freeze revision 5。",
        "结算顺序：docs/prototype/settlement-order-v1.md。",
        "迷雾与提示：docs/prototype/information-boundary-v1.md。",
        "本手册是玩家教学版整理；若与后续项目所有者批准的规则修订冲突，以最新确认规则为准。",
    ])
    story.append(Spacer(1, 5*mm))
    story.append(P("愿你在雾中看清道路，在烽火中守住第一面战旗。", ParagraphStyle(
        "End", parent=SUBTITLE, alignment=TA_CENTER, textColor=RED, fontSize=12,
    )))
    return story


def build_pdf() -> Path:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUTPUT), pagesize=A4,
        rightMargin=MARGIN_X, leftMargin=MARGIN_X,
        topMargin=MARGIN_TOP, bottomMargin=MARGIN_BOTTOM,
        title="《雾疆：九路烽棋》新手规则教学手册 v1",
        author="Veilfront Xiangqi Siege Project",
        subject="玩家规则、棋子走法、特殊能力、迷雾、城墙、旗帜与结算顺序",
    )
    doc.build(build_story(), onFirstPage=cover_page, onLaterPages=later_page)
    return OUTPUT


if __name__ == "__main__":
    result = build_pdf()
    print(result)
