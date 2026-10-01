#!/usr/bin/env python3
"""Crop design-system figures to 16:10 previews for the README grid."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / "docs" / "design"
OUT = DESIGN / "previews"
WIDTH = 1200
HEIGHT = 750
SOURCES = [
    "1-principles/do-and-dont.png",
    "2-foundations/color.png",
    "3-chart-grammar/always-never.png",
    "4-components/c02-kpi-tile.png",
    "5-page-templates/shared-rules.png",
    "6-applied-screens/t1-executive.png",
]


def frame(image: Image.Image) -> Image.Image:
    """Keep the top of the figure at 16:10, including its existing margin."""
    width, height = image.size
    crop_height = round(width * HEIGHT / WIDTH)
    if crop_height <= height:
        return image.crop((0, 0, width, crop_height))
    # Shorter than 16:10. Extend the white canvas instead of cutting the sides.
    canvas = Image.new(image.mode, (width, crop_height), "white")
    canvas.paste(image, (0, 0))
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for source in SOURCES:
        path = DESIGN / source
        with Image.open(path) as image:
            preview = frame(image).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
            preview.save(OUT / path.name, optimize=True)


if __name__ == "__main__":
    main()
