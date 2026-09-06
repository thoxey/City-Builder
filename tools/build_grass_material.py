#!/usr/bin/env python3
"""Derive a compact PBR helper set from the approved grass albedo master."""

from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/building-concepts/meshy-production/textured-v1/ground-materials/grass"


def main() -> None:
    source = Image.open(OUT / "grass_albedo_master.png").convert("RGB")
    albedo = source.resize((2048, 2048), Image.Resampling.LANCZOS)
    albedo.save(OUT / "grass_albedo_2k.png", optimize=True)

    luminance = albedo.convert("L")
    blurred = luminance.filter(ImageFilter.GaussianBlur(7))
    high_pass = ImageChops.subtract(luminance, blurred, scale=1.5, offset=128)
    height = ImageEnhance.Contrast(high_pass).enhance(1.35)
    height.save(OUT / "grass_height_2k.png", optimize=True)

    left = ImageChops.offset(height, -2, 0)
    right = ImageChops.offset(height, 2, 0)
    up = ImageChops.offset(height, 0, -2)
    down = ImageChops.offset(height, 0, 2)
    nx = ImageChops.subtract(left, right, scale=2.2, offset=128)
    ny = ImageChops.subtract(up, down, scale=2.2, offset=128)
    normal = Image.merge("RGB", (nx, ny, Image.new("L", height.size, 246)))
    normal.save(OUT / "grass_normal_2k.png", optimize=True)

    roughness = ImageOps.autocontrast(blurred, cutoff=2).point(lambda value: 190 + value * 50 // 255)
    roughness.save(OUT / "grass_roughness_2k.png", optimize=True)
    Image.new("L", (2048, 2048), 0).save(OUT / "grass_metallic_2k.png", optimize=True)

    tile = albedo.resize((768, 768), Image.Resampling.LANCZOS)
    preview = Image.new("RGB", (1536, 1536))
    for y in (0, 768):
        for x in (0, 768):
            preview.paste(tile, (x, y))
    preview.save(OUT / "grass_tiling_preview_2x2.png", optimize=True)


if __name__ == "__main__":
    main()
