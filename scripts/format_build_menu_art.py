#!/usr/bin/env python3
"""Build deterministic derivatives, proofs, manifest, and validation for build-menu art."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/ui/build-menu"
SPRITES = ROOT / "sprites/ui/build-menu"
PROOFS = ART / "proofs"
INK = (23, 23, 19, 255)
PAPER = (231, 211, 173, 255)
BG = (43, 41, 35, 255)
FONT = ImageFont.load_default()

CATEGORIES = {
    "roads-and-paths": ("Roads & Paths", "curving road junction with directional branch", ["capacity", "civic", "ink", "paper"]),
    "homes": ("Homes", "welcoming detached house", ["residential", "ink", "paper"]),
    "commerce": ("Commerce", "jaunty shopfront and awning", ["commercial", "active", "ink", "paper"]),
    "industry": ("Industry", "sawtooth factory and purposeful gear", ["industrial", "civic", "ink", "paper"]),
    "nature": ("Nature", "wind-leaning tree joined to ground", ["building", "civic", "ink", "paper"]),
    "leisure-civic": ("Leisure & Civic", "civic pavilion with activity pennant", ["civic", "active", "ink", "paper"]),
    "landmarks-story": ("Landmarks & Story", "distinctive landmark with discovery rays", ["building", "active", "ink", "paper"]),
}

ENTRY_LABELS = {
    "road": "Road", "pavement": "Pavement", "house": "House", "tower-block": "Tower Block",
    "shop": "Shop", "supermarket": "Supermarket", "workshop": "Workshop", "city-hall": "City Hall",
    "grass": "Grass", "duck-pond": "Duck Pond", "nature-patch": "Nature Patch", "crazy-golf": "Crazy Golf",
    "lumber-mill": "Lumber Mill", "private-members-club": "Private Members’ Club", "nightclub": "Nightclub",
    "pipe-factory": "Pipe Factory", "pirate-radio-station": "Pirate Radio Station",
    "postwar-mid-block": "Postwar Mid-Block", "postwar-terrace": "Postwar Terrace",
    "postwar-tower-block": "Postwar Tower Block", "pub": "Pub", "restaurant": "Restaurant",
    "theatre": "Theatre", "windmill": "Windmill",
}

ENTRY_MOTIFS = {
    "road": "single curving road with directional branch", "pavement": "angled paving slabs and curb",
    "house": "squat detached pitched-roof home", "tower-block": "simple tall narrow slab tower",
    "shop": "narrow commercial shop and awning", "supermarket": "broad low commercial store and trolley",
    "workshop": "squat industrial shed and gear", "city-hall": "civic hall, steps, cupola and clock",
    "grass": "low turf mound and three grass blades", "duck-pond": "duck on irregular pond",
    "nature-patch": "joined tree, bushes and ground", "crazy-golf": "putting hill, flag and windmill obstacle",
    "lumber-mill": "industrial mill, logs and circular saw", "private-members-club": "exclusive townhouse and barrier",
    "nightclub": "venue canopy, star light and rhythm marks", "pipe-factory": "industrial shed and pipe elbows",
    "pirate-radio-station": "studio shack and leaning broadcast mast", "postwar-mid-block": "wide medium-height residential block",
    "postwar-terrace": "long low joined residential terrace", "postwar-tower-block": "offset brutalist residential slabs",
    "pub": "commercial corner pub and hanging sign", "restaurant": "commercial frontage, canopy and tables",
    "theatre": "stepped marquee and curtain doorway", "windmill": "landmark windmill with four large sails",
}

CONTROL_LABELS = {
    "open-build": "Open Build", "bulldoze": "Bulldoze", "rotate": "Rotate", "place-confirm": "Place/confirm",
    "cancel": "Cancel", "back": "Back", "close": "Close", "next-page": "Next page",
    "previous-page": "Previous page", "locked": "Locked", "unavailable-blocked": "Unavailable/blocked",
    "missing-artwork": "Missing artwork fallback",
}

COMPONENTS = {
    "top-status-bar-frame": {"label": "Top status bar frame", "size": (512, 128), "slice": [96, 64, 96, 48], "content": [104, 68, 104, 52], "minimum": [224, 128]},
    "bottom-tool-dock-frame": {"label": "Bottom tool dock frame", "size": (512, 160), "slice": [96, 80, 96, 64], "content": [104, 84, 104, 68], "minimum": [224, 160]},
    "tooltip-detail-card-frame": {"label": "Tooltip/detail card frame", "size": (384, 256), "slice": [96, 88, 72, 80], "content": [104, 96, 80, 88], "minimum": [192, 184]},
    "button-tab-base": {"label": "Button/tab base", "size": (384, 96), "slice": [56, 44, 56, 36], "content": [64, 48, 64, 40], "minimum": [128, 88]},
}


def rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def save_rgba(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True, compress_level=9)


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    fit = ImageOps.contain(image, size, Image.Resampling.LANCZOS)
    out.alpha_composite(fit, ((size[0] - fit.width) // 2, (size[1] - fit.height) // 2))
    return out


def mirror_tile(source: Image.Image, half: int) -> Image.Image:
    base = source.resize((half, half), Image.Resampling.LANCZOS)
    row = Image.new("RGBA", (half * 2, half))
    row.alpha_composite(base, (0, 0))
    row.alpha_composite(ImageOps.mirror(base), (half, 0))
    tile = Image.new("RGBA", (half * 2, half * 2))
    tile.alpha_composite(row, (0, 0))
    tile.alpha_composite(ImageOps.flip(row), (0, half))
    return tile


def nine_slice(source: Image.Image, margins: list[int], target: tuple[int, int]) -> Image.Image:
    l, t, r, b = margins
    sw, sh = source.size
    tw, th = target
    out = Image.new("RGBA", target, (0, 0, 0, 0))
    xs = [(0, l), (l, sw - r), (sw - r, sw)]
    ys = [(0, t), (t, sh - b), (sh - b, sh)]
    dx = [(0, l), (l, tw - r), (tw - r, tw)]
    dy = [(0, t), (t, th - b), (th - b, th)]
    for yi in range(3):
        for xi in range(3):
            piece = source.crop((xs[xi][0], ys[yi][0], xs[xi][1], ys[yi][1]))
            size = (max(1, dx[xi][1] - dx[xi][0]), max(1, dy[yi][1] - dy[yi][0]))
            if piece.size != size:
                piece = piece.resize(size, Image.Resampling.LANCZOS)
            out.alpha_composite(piece, (dx[xi][0], dy[yi][0]))
    return out


def labelled_grid(items: list[tuple[str, Image.Image]], cell: int, cols: int, title: str, bg=BG) -> Image.Image:
    label_h, title_h = 30, 44
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, title_h + rows * (cell + label_h)), bg)
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 14), title, font=FONT, fill=PAPER)
    for i, (label, icon) in enumerate(items):
        x, y = (i % cols) * cell, title_h + (i // cols) * (cell + label_h)
        fit = contain(icon, (cell - 20, cell - 20))
        sheet.alpha_composite(fit, (x + 10, y + 10))
        draw.text((x + 8, y + cell + 7), label, font=FONT, fill=PAPER)
    return sheet


def icon_items(size: int) -> list[tuple[str, Image.Image]]:
    result = []
    for folder, mapping in (("categories", CATEGORIES), ("entries", ENTRY_LABELS), ("controls", CONTROL_LABELS)):
        for slug, meta in mapping.items():
            label = meta[0] if folder == "categories" else meta
            result.append((label, rgba(SPRITES / folder / f"{slug}.png").resize((size, size), Image.Resampling.LANCZOS)))
    return result


def component_derivatives() -> None:
    for slug, data in COMPONENTS.items():
        source = rgba(ART / "masters/components" / f"{slug}.png")
        bounds = source.getbbox()
        if bounds:
            source = source.crop(bounds)
        source = source.resize(tuple(data["size"]), Image.Resampling.LANCZOS)
        save_rgba(source, SPRITES / "components" / f"{slug}.png")
    save_rgba(rgba(ART / "masters/components/focus-overlay.png").resize((128, 128), Image.Resampling.LANCZOS), SPRITES / "components/focus-overlay.png")
    save_rgba(rgba(ART / "masters/components/destructive-warning-overlay.png").resize((128, 128), Image.Resampling.LANCZOS), SPRITES / "components/destructive-warning-overlay.png")
    save_rgba(mirror_tile(rgba(ART / "masters/components/disabled-hatch-overlay.png"), 64), SPRITES / "components/disabled-hatch-overlay.png")
    save_rgba(mirror_tile(rgba(ART / "masters/components/parchment-print-grain.png"), 128), SPRITES / "components/parchment-print-grain.png")


def make_proofs() -> None:
    items = icon_items(180)
    contact = labelled_grid(items, 190, 7, "Approved radial build UI icon family")
    save_rgba(contact, PROOFS / "family-contact-sheet.png")
    save_rgba(ImageOps.grayscale(contact).convert("RGBA"), PROOFS / "grayscale-proof.png")
    for size in (24, 32, 56, 72):
        small = icon_items(size)
        cell = max(92, size + 44)
        save_rgba(labelled_grid(small, cell, 8, f"Actual-size proof — {size} px", PAPER), PROOFS / f"actual-size-{size}px.png")

    shot = Image.open(ROOT / "specs/003-community-ui/validation/screenshots/overview.png").convert("RGBA")
    icons = icon_items(56)
    for i, (_, icon) in enumerate(icons):
        x = 24 + (i % 15) * 82
        y = 462 + (i // 15) * 82
        shot.alpha_composite(icon, (x, y))
    save_rgba(shot, PROOFS / "context-gameplay-56px.png")

    tile = rgba(SPRITES / "components/parchment-print-grain.png")
    repeat = Image.new("RGBA", (tile.width * 3, tile.height * 3))
    for y in range(3):
        for x in range(3):
            repeat.alpha_composite(tile, (x * tile.width, y * tile.height))
    save_rgba(repeat, PROOFS / "parchment-repeat-3x3.png")

    frames = []
    for slug, data in COMPONENTS.items():
        source = rgba(SPRITES / "components" / f"{slug}.png")
        minimum = tuple(data["minimum"])
        targets = (("minimum", minimum), ("wide", (max(560, minimum[0] * 2), minimum[1])), ("tall", (minimum[0], max(480, minimum[1] * 2))))
        for label, target in targets:
            frames.append((f"{data['label']} — {label}", nine_slice(source, data["slice"], target)))
    save_rgba(labelled_grid(frames, 360, 3, "Nine-slice minimum / wide / tall proofs"), PROOFS / "nine-slice-proofs.png")

    base = rgba(SPRITES / "components/button-tab-base.png")
    base = nine_slice(base, COMPONENTS["button-tab-base"]["slice"], (220, 88))
    focus = rgba(SPRITES / "components/focus-overlay.png").resize((96, 96), Image.Resampling.LANCZOS)
    hatch = rgba(SPRITES / "components/disabled-hatch-overlay.png")
    danger = rgba(SPRITES / "components/destructive-warning-overlay.png").resize((88, 88), Image.Resampling.LANCZOS)
    states = []
    states.append(("normal", base))
    states.append(("hover — lifted", ImageEnhance.Brightness(base).enhance(1.08)))
    pressed = Image.new("RGBA", base.size); pressed.alpha_composite(ImageEnhance.Brightness(base).enhance(.88), (0, 4)); states.append(("pressed — lowered", pressed))
    focused = base.copy(); focused.alpha_composite(focus, ((base.width-focus.width)//2, -4)); states.append(("focused — brackets", focused))
    selected = ImageOps.expand(base, border=5, fill=(211,165,38,255)).resize(base.size, Image.Resampling.LANCZOS); states.append(("selected — heavy edge", selected))
    disabled = ImageEnhance.Color(base).enhance(.15); pattern = Image.new("RGBA", base.size); 
    for y in range(0, base.height, hatch.height):
        for x in range(0, base.width, hatch.width): pattern.alpha_composite(hatch, (x, y))
    disabled.alpha_composite(pattern); states.append(("disabled — hatch", disabled))
    destructive = base.copy(); destructive.alpha_composite(danger, (base.width-danger.width, base.height-danger.height)); states.append(("destructive — fracture", destructive))
    save_rgba(labelled_grid(states, 250, 4, "Interaction state matrix"), PROOFS / "state-matrix.png")


def manifest_record(slug: str, label: str, family: str, role: str, motif: str, palette: list[str], runtime_size: list[int], display: list[int], extra=None):
    source = ART / "masters" / family / f"{slug}.png"
    runtime = SPRITES / family / f"{slug}.png"
    record = {
        "id": f"build-{slug}", "label": label, "family": "build-menu", "role": role, "motif": motif,
        "source_path": str(source.relative_to(ROOT)), "source_dimensions": list(rgba(source).size),
        "runtime": [{"path": str(runtime.relative_to(ROOT)), "dimensions": runtime_size}],
        "display_size_range": display, "colour_mode": "RGBA", "colour_space": "sRGB", "alpha": "straight",
        "background_rule": "rimless rough parchment medallion with transparent exterior" if family != "components" else "component-specific",
        "palette_roles": palette, "accessibility_label": label, "approval": "approved",
        "prompt_version": "build-menu-c-zoning-v2", "reference_ids": ["community-icon-wall", "exploration-direction-c"],
        "tool": "built-in image generation plus deterministic Pillow/ImageMagick formatting",
    }
    if extra: record.update(extra)
    return record


def write_manifest() -> None:
    assets = []
    for slug, (label, motif, palette) in CATEGORIES.items():
        assets.append(manifest_record(slug, label, "categories", "category-icon", motif, palette, [256,256], [56,72]))
    for slug, label in ENTRY_LABELS.items():
        if slug in {"house", "tower-block", "postwar-mid-block", "postwar-terrace", "postwar-tower-block"}: palette = ["residential", "ink", "paper"]
        elif slug in {"shop", "supermarket", "private-members-club", "nightclub", "pub", "restaurant", "theatre", "pirate-radio-station"}: palette = ["commercial", "ink", "paper"]
        elif slug in {"workshop", "lumber-mill", "pipe-factory"}: palette = ["industrial", "ink", "paper"]
        else: palette = ["semantic-mixed", "ink", "paper"]
        assets.append(manifest_record(slug, label, "entries", "build-entry-icon", ENTRY_MOTIFS[slug], palette, [256,256], [24,72]))
    for slug, label in CONTROL_LABELS.items():
        extra = {"fallback_state": "normal"}
        if slug == "missing-artwork": extra["fallback_for"] = "missing or failed icon resource"
        assets.append(manifest_record(slug, label, "controls", "control-icon", label.lower(), ["semantic-mixed","ink","paper"], [128,128], [16,32], extra))
    for slug, data in COMPONENTS.items():
        source = ART / "masters/components" / f"{slug}.png"; runtime = SPRITES / "components" / f"{slug}.png"
        assets.append({
            "id": slug, "label": data["label"], "family": "build-menu", "role": "nine-slice-component",
            "motif": "quiet parchment frame with restrained corner character", "source_path": str(source.relative_to(ROOT)),
            "source_dimensions": list(rgba(source).size), "runtime": [{"path": str(runtime.relative_to(ROOT)), "dimensions": list(rgba(runtime).size)}],
            "display_size_range": data["minimum"], "colour_mode": "RGBA", "colour_space": "sRGB", "alpha": "straight",
            "background_rule": "transparent exterior; quiet opaque parchment centre", "palette_roles": ["paper","ink","active","civic"],
            "accessibility_label": data["label"], "approval": "approved", "slice_margins": data["slice"], "content_margins": data["content"],
            "minimum_dimensions": data["minimum"], "horizontal_mode": "stretch", "vertical_mode": "stretch", "draw_center": True,
        })
    overlays = [
        ("focus-overlay", "Focus overlay", "state-overlay", [128,128], {"state":"focused","fallback_state":"normal"}),
        ("disabled-hatch-overlay", "Disabled hatch overlay", "tileable-state-overlay", [128,128], {"state":"disabled","tile_axes":["x","y"],"tile_dimensions":[128,128],"repeat_mode":"repeat"}),
        ("destructive-warning-overlay", "Destructive warning overlay", "state-overlay", [128,128], {"state":"destructive","fallback_state":"normal"}),
        ("parchment-print-grain", "Parchment print grain", "tileable-texture", [256,256], {"tile_axes":["x","y"],"tile_dimensions":[256,256],"repeat_mode":"repeat","seam_proof":"art/ui/build-menu/proofs/parchment-repeat-3x3.png"}),
    ]
    for slug,label,role,dims,extra in overlays:
        source=ART/"masters/components"/f"{slug}.png"; runtime=SPRITES/"components"/f"{slug}.png"
        rec={"id":slug,"label":label,"family":"build-menu","role":role,"motif":label.lower(),"source_path":str(source.relative_to(ROOT)),"source_dimensions":list(rgba(source).size),"runtime":[{"path":str(runtime.relative_to(ROOT)),"dimensions":dims}],"display_size_range":[16,512],"colour_mode":"RGBA","colour_space":"sRGB","alpha":"straight","background_rule":"transparent overlay" if "overlay" in role else "opaque repeat tile","palette_roles":["ink","paper","active","danger","neutral"],"accessibility_label":label,"approval":"approved"};rec.update(extra);assets.append(rec)
    payload = {
        "family": "build-menu", "version": 1, "direction": "exploration C",
        "zoning_palette": {"residential":"#58705A","commercial":"#2E8290","industrial":"#C9743F"},
        "alpha_policy":"straight RGBA", "colour_space":"sRGB", "mipmaps":False,
        "proofs": sorted(str(p.relative_to(ROOT)) for p in PROOFS.glob("*.png")), "assets": assets,
    }
    (ART / "manifest.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def validate() -> None:
    expected = 7 + 24 + 12 + 8
    report = {"expected_assets": expected, "manifest_assets": 0, "errors": [], "warnings": []}
    data = json.loads((ART / "manifest.json").read_text())
    report["manifest_assets"] = len(data["assets"])
    for record in data["assets"]:
        src = ROOT / record["source_path"]
        if not src.is_file(): report["errors"].append(f"missing source: {src}")
        for runtime in record["runtime"]:
            path = ROOT / runtime["path"]
            if not path.is_file(): report["errors"].append(f"missing runtime: {path}"); continue
            image = rgba(path)
            if list(image.size) != runtime["dimensions"]: report["errors"].append(f"wrong size: {path}")
            if image.mode != "RGBA": report["errors"].append(f"not RGBA: {path}")
    if report["manifest_assets"] != expected: report["errors"].append("asset count mismatch")
    report["status"] = "pass" if not report["errors"] else "fail"
    (PROOFS / "validation-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    component_derivatives()
    make_proofs()
    write_manifest()
    validate()


if __name__ == "__main__":
    main()
