#!/usr/bin/env python3
"""Create a print-ready QR card for the research code appendix."""

from __future__ import annotations

import argparse
import sys
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def _load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/calibrib.ttf" if bold else "C:/Windows/Fonts/calibri.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def _wrap_text(text: str, font: ImageFont.ImageFont, max_width: int, draw: ImageDraw.ImageDraw) -> list[str]:
    lines: list[str] = []
    for paragraph in text.splitlines() or [""]:
        words = paragraph.split()
        current = ""
        for word in words:
            trial = f"{current} {word}".strip()
            if draw.textbbox((0, 0), trial, font=font)[2] <= max_width:
                current = trial
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
    return lines


def _draw_centered(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    y: int,
    font: ImageFont.ImageFont,
    fill: str,
    canvas_width: int,
    line_gap: int,
) -> int:
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        x = (canvas_width - (bbox[2] - bbox[0])) // 2
        draw.text((x, y), line, font=font, fill=fill)
        y += (bbox[3] - bbox[1]) + line_gap
    return y


def make_qr_card(url: str, title: str, caption: str, output: Path) -> None:
    try:
        import qrcode
        from qrcode.constants import ERROR_CORRECT_Q
    except ImportError as exc:
        raise SystemExit(
            "Missing dependency: qrcode. Install it with:\n"
            "  python -m pip install qrcode[pil]"
        ) from exc

    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_Q,
        box_size=16,
        border=3,
    )
    qr.add_data(url)
    qr.make(fit=True)
    qr_image = qr.make_image(fill_color="#111111", back_color="#ffffff").convert("RGB")
    qr_image = qr_image.resize((720, 720), Image.Resampling.NEAREST)

    width = 1100
    height = 1420
    margin = 82
    bg = "#ffffff"
    ink = "#111111"
    muted = "#555555"
    accent = "#1f6feb"

    card = Image.new("RGB", (width, height), bg)
    draw = ImageDraw.Draw(card)
    title_font = _load_font(54, bold=True)
    caption_font = _load_font(30)
    url_font = _load_font(24)
    label_font = _load_font(26, bold=True)

    draw.rounded_rectangle((28, 28, width - 28, height - 28), radius=32, outline="#d7dde8", width=4)
    draw.rectangle((28, 28, width - 28, 46), fill=accent)

    y = 92
    title_lines = _wrap_text(title, title_font, width - margin * 2, draw)
    y = _draw_centered(draw, title_lines, y, title_font, ink, width, 16)
    y += 26

    qr_x = (width - qr_image.width) // 2
    card.paste(qr_image, (qr_x, y))
    y += qr_image.height + 42

    caption_lines = _wrap_text(caption, caption_font, width - margin * 2, draw)
    y = _draw_centered(draw, caption_lines, y, caption_font, muted, width, 12)
    y += 28

    draw.text((margin, y), "Direct link:", font=label_font, fill=ink)
    y += 42
    wrapped_url = textwrap.wrap(url, width=58, break_long_words=True, break_on_hyphens=False)
    _draw_centered(draw, wrapped_url, y, url_font, accent, width, 8)

    output.parent.mkdir(parents=True, exist_ok=True)
    card.save(output, "PNG", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="Public URL to the Rmd/HTML code appendix.")
    parser.add_argument(
        "--title",
        default="Research Code Appendix",
        help="Title printed above the QR code.",
    )
    parser.add_argument(
        "--caption",
        default="Scan this QR code to view the complete R Markdown code, outputs, and figures used in the analysis.",
        help="Caption printed below the QR code.",
    )
    parser.add_argument(
        "--output",
        default="output/figures/code_appendix_qr.png",
        help="PNG output path.",
    )
    args = parser.parse_args()

    make_qr_card(args.url, args.title, args.caption, Path(args.output))
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
