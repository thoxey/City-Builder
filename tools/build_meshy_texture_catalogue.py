#!/usr/bin/env python3
"""Create a review sheet and CSV index for the completed texture pass."""

from __future__ import annotations

import csv
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / "artifacts/building-concepts/final-catalogue/manifest.csv"
RUN_DIR = ROOT / "artifacts/building-concepts/meshy-production/textured-v1"


def font(size: int, bold: bool = False):
    path = "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf"
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def main() -> None:
    with CATALOGUE.open(newline="", encoding="utf-8-sig") as handle:
        catalogue = list(csv.DictReader(handle))
    report = json.loads((RUN_DIR / "results.json").read_text())
    records = {record["asset_id"]: record for record in report["records"]}

    rows = []
    for item in catalogue:
        record = records[item["asset_id"]]
        rows.append({
            "group": item["group"],
            "menu_choice": item["menu_choice"],
            "asset_id": item["asset_id"],
            "friendly_label": item["friendly_label"],
            "footprint_suggestion": item["footprint_suggestion"],
            "status": record["status"],
            "task_id": record["task_id"],
            "credits": record["consumed_credits"],
            "texture_prompt": record["request"].get("text_style_prompt", "[canonical image style reference]"),
            "raw_textured_glb": str((ROOT / record["raw_textured_glb"]).resolve()),
            "normalized_glb": str((ROOT / record["normalized_glb"]).resolve()),
            "preview_png": str((ROOT / record["preview_png"]).resolve()),
            "texture_maps_directory": str((RUN_DIR / "texture-maps" / item["asset_id"]).resolve()),
            "fits_footprint": record["bounds"]["fits_envelope"],
        })

    index_path = RUN_DIR / "texture-index.csv"
    with index_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    def write_sheet(sheet_rows, sheet_path):
        columns, card_w, card_h = 4, 420, 470
        sheet = Image.new("RGB", (columns * card_w, ((len(sheet_rows) + columns - 1) // columns) * card_h), "#c9c7c1")
        title_font, meta_font = font(22, True), font(16)
        for index, row in enumerate(sheet_rows):
            x, y = (index % columns) * card_w, (index // columns) * card_h
            card = Image.new("RGB", (card_w - 12, card_h - 12), "#efede8")
            preview = Image.open(row["preview_png"]).convert("RGBA")
            backdrop = Image.new("RGBA", preview.size, "#17191b")
            backdrop.alpha_composite(preview)
            preview = ImageOps.contain(backdrop.convert("RGB"), (390, 390), Image.Resampling.LANCZOS)
            card.paste(preview, ((card.width - preview.width) // 2, 10))
            draw = ImageDraw.Draw(card)
            draw.text((14, 407), row["friendly_label"], fill="#161616", font=title_font)
            draw.text((14, 438), f'{row["asset_id"]}  |  4K PBR', fill="#555555", font=meta_font)
            sheet.paste(card, (x + 6, y + 6))
        sheet.save(sheet_path, optimize=True)

    sheet_path = RUN_DIR / "textured-contact-sheet.png"
    write_sheet(rows, sheet_path)
    no_roads_path = RUN_DIR / "textured-contact-sheet-no-roads.png"
    write_sheet([row for row in rows if row["group"] != "Roads"], no_roads_path)
    print(f"Wrote {index_path}")
    print(f"Wrote {sheet_path}")
    print(f"Wrote {no_roads_path}")


if __name__ == "__main__":
    main()
