from __future__ import annotations

from io import BytesIO
from pathlib import Path

from PIL import Image
from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets" / "art" / "tutorial" / "diagram_v3"
OUTPUT_PATH = ROOT / "output" / "pdf" / "veilfront-illustrated-tutorial-v3.pdf"


PAGE_FILES = [
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
]


def build_pdf() -> None:
    missing = [name for name in PAGE_FILES if not (SOURCE_DIR / name).is_file()]
    if missing:
        raise FileNotFoundError(f"Missing comic pages: {missing}")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    page_width, page_height = A4
    margin_x = 10 * mm
    margin_top = 8 * mm
    margin_bottom = 12 * mm
    usable_width = page_width - 2 * margin_x
    usable_height = page_height - margin_top - margin_bottom

    pdf = canvas.Canvas(str(OUTPUT_PATH), pagesize=A4, pageCompression=1)
    pdf.setTitle("Veilfront Xiangqi Siege - Illustrated Tutorial v3")
    pdf.setAuthor("Veilfront Xiangqi Siege Project")
    pdf.setSubject("Accuracy-first illustrated tutorial")

    for index, filename in enumerate(PAGE_FILES, start=1):
        path = SOURCE_DIR / filename
        with Image.open(path) as image:
            image_width, image_height = image.size
            flattened = Image.new("RGB", image.size, "#090807")
            if image.mode in ("RGBA", "LA"):
                flattened.paste(image.convert("RGBA"), mask=image.convert("RGBA").getchannel("A"))
            else:
                flattened.paste(image.convert("RGB"))
            encoded = BytesIO()
            flattened.save(encoded, format="JPEG", quality=90, optimize=True, progressive=True)
            encoded.seek(0)

        scale = min(usable_width / image_width, usable_height / image_height)
        draw_width = image_width * scale
        draw_height = image_height * scale
        x = (page_width - draw_width) / 2
        y = margin_bottom + (usable_height - draw_height) / 2

        pdf.setFillColor(HexColor("#090807"))
        pdf.rect(0, 0, page_width, page_height, stroke=0, fill=1)
        pdf.drawImage(
            ImageReader(encoded),
            x,
            y,
            width=draw_width,
            height=draw_height,
            preserveAspectRatio=True,
            mask="auto",
        )
        pdf.setFillColor(HexColor("#A9874A"))
        pdf.setFont("Helvetica", 7)
        pdf.drawCentredString(page_width / 2, 5 * mm, f"{index:02d} / {len(PAGE_FILES):02d}")
        pdf.showPage()

    pdf.save()
    print(OUTPUT_PATH)


if __name__ == "__main__":
    build_pdf()
