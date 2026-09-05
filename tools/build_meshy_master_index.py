#!/usr/bin/env python3
"""Build a unified index and labelled preview sheet for Meshy master outputs."""

from __future__ import annotations

import csv
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / "artifacts/building-concepts/final-catalogue/manifest.csv"
PRODUCTION = ROOT / "artifacts/building-concepts/meshy-production"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/SFNS.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main() -> None:
    with CATALOGUE.open(newline="", encoding="utf-8-sig") as handle:
        catalogue = list(csv.DictReader(handle))

    generated: dict[str, dict] = {}
    for batch in ("pilot", "remaining"):
        data = json.loads((PRODUCTION / batch / "results.json").read_text())
        for record in data["records"]:
            generated[record["asset_id"]] = {**record, "batch": batch}

    rows = []
    for item in catalogue:
        record = generated[item["asset_id"]]
        preview = PRODUCTION / record["batch"] / "previews" / f'{item["asset_id"]}.png'
        row = {
            "group": item["group"],
            "menu_choice": item["menu_choice"],
            "asset_id": item["asset_id"],
            "friendly_label": item["friendly_label"],
            "footprint_suggestion": item["footprint_suggestion"],
            "batch": record["batch"],
            "textured": record["request"]["should_texture"],
            "status": record["status"],
            "task_id": record["task_id"],
            "credits": record["consumed_credits"],
            "raw_master_glb": str((ROOT / record["raw_glb"]).resolve()),
            "normalized_glb": str((ROOT / record["normalized_glb"]).resolve()),
            "preview_png": str(preview.resolve()),
            "fits_footprint": record["bounds"]["fits_envelope"],
            "normalized_width": round(record["bounds"]["normalized_extent"][0], 6),
            "normalized_height": round(record["bounds"]["normalized_extent"][1], 6),
            "normalized_depth": round(record["bounds"]["normalized_extent"][2], 6),
        }
        rows.append(row)

    csv_path = PRODUCTION / "master-index.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    json_path = PRODUCTION / "master-index.json"
    json_path.write_text(json.dumps(rows, indent=2) + "\n")

    columns = 4
    card_w, card_h = 420, 490
    image_box = (390, 390)
    sheet = Image.new("RGB", (columns * card_w, ((len(rows) + columns - 1) // columns) * card_h), "#d7d5cf")
    title_font = font(22, bold=True)
    meta_font = font(16)

    for index, row in enumerate(rows):
        x = (index % columns) * card_w
        y = (index // columns) * card_h
        card = Image.new("RGB", (card_w - 12, card_h - 12), "#f5f3ee")
        preview = Image.open(row["preview_png"]).convert("RGBA")
        background = Image.new("RGBA", preview.size, "#eceae4")
        background.alpha_composite(preview)
        preview = ImageOps.contain(background.convert("RGB"), image_box, Image.Resampling.LANCZOS)
        px = (card.width - preview.width) // 2
        card.paste(preview, (px, 10))
        draw = ImageDraw.Draw(card)
        draw.text((14, 408), row["friendly_label"], fill="#161616", font=title_font)
        state = "textured pilot" if row["textured"] else "untextured Ultra master"
        draw.text((14, 440), f'{row["asset_id"]}  |  {state}', fill="#535353", font=meta_font)
        draw.text((14, 462), row["footprint_suggestion"], fill="#535353", font=meta_font)
        sheet.paste(card, (x + 6, y + 6))

    sheet_path = PRODUCTION / "meshy-master-previews-contact-sheet.png"
    sheet.save(sheet_path, optimize=True)
    print(f"Wrote {csv_path}")
    print(f"Wrote {json_path}")
    print(f"Wrote {sheet_path}")


if __name__ == "__main__":
    main()
