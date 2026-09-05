#!/usr/bin/env python3
"""Retexture approved Meshy geometry masters without altering their topology."""

from __future__ import annotations

import argparse
import csv
import getpass
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from meshy_production import ROOT, CATALOGUE, MANIFEST, OUTPUT, download, image_data_uri, normalize_glb, parse_footprint, request_json


RUN_DIR = OUTPUT / "textured-v1"
RESULTS = RUN_DIR / "results.json"
SAMPLE_IDS = {
    "building_small_a",
    "building_postwar_midblock",
    "building_lumber_mill",
    "grass_trees_tall",
}
IMAGE_STYLE_IDS = {
    "road_straight",
    "road_corner",
    "road_split",
    "road_intersection",
    "building_duck_pond",
    "building_crazy_golf",
}

COMMON = (
    "Restrained British city-builder stylized realism. Natural low-saturation albedo, "
    "believable matte PBR materials, gentle age and subtle local variation, clean readable "
    "material separation. Overcast-neutral colour balance with no baked shadows or highlights. "
    "Avoid vivid primary colours, neon, candy colours, toy-plastic gloss, excessive contrast, "
    "photoreal grime, text, logos and invented branding. "
)

MATERIALS = {
    "road_straight": "Dark weathered asphalt, pale grey kerbs, restrained off-white road markings and muted ochre-yellow edge lines.",
    "road_corner": "Dark weathered asphalt, pale grey kerbs, restrained off-white UK junction markings and muted ochre-yellow edge lines.",
    "road_split": "Dark weathered asphalt, pale grey kerbs, off-white UK give-way double dashed markings and muted ochre-yellow edge lines.",
    "road_intersection": "Dark weathered asphalt, pale grey kerbs, restrained off-white UK crossroads markings and muted ochre-yellow edge lines.",
    "road_straight_lightposts": "Dark weathered asphalt and pale grey kerbs; galvanised charcoal-grey lampposts on footways; restrained off-white markings and muted ochre-yellow edge lines.",
    "pavement": "British town-centre paving: weathered mid-grey concrete flags with restrained red-brown brick edging, matte and subtly varied.",
    "pavement_fountain": "Weathered pale limestone fountain, mid-grey concrete flags with restrained red-brown brick details, dull blue-grey water without tropical turquoise.",
    "building_small_a": "Muted warm red-brown brick house, charcoal-grey slate roof, soft off-white painted timber, dark brown door, subdued dusty-green British garden planting.",
    "building_small_d": "Warm grey-beige local stone cottage, weathered charcoal slate, muted cream frames, faded sage door, restrained native British garden greens.",
    "building_small_c": "Warm grey concrete tower, brown-red brick infill panels, aged off-white frames, charcoal metalwork and restrained communal landscaping.",
    "building_postwar_terrace": "Post-war British buff and muted red-brown brick, warm grey concrete lintels, aged off-white frames, charcoal roofing and subdued garden greens.",
    "building_postwar_midblock": "Post-war British brown-buff brick, weathered cream render panels, warm grey concrete, aged off-white frames and charcoal shopfront details.",
    "building_postwar_tower_block": "Weathered warm-grey concrete, muted brown brick infill, aged cream panels, charcoal metalwork and restrained dark glazing.",
    "building_small_b": "Muted red-brown brick high-street shop, warm cream trim, bottle-green canvas awning, dark timber shopfront and blank aged signboard.",
    "building_pub": "Deep weathered red-brown brick, warm cream stone trim, charcoal slate, dark timber, muted burgundy and bottle-green accents; blank pub signboards.",
    "building_restaurant": "Contemporary warm off-white mineral render, charcoal zinc and aluminium, natural weathered oak, dark neutral glazing and restrained sage planting.",
    "building_members_club": "Warm pale limestone and muted cream render, charcoal slate, black iron railings, dark green door and subdued formal grounds.",
    "building_garage": "Weathered galvanised corrugated steel in mid-grey, muted concrete block, dark asphalt, faded industrial blue-grey doors and small rust-brown details.",
    "building_windmill": "British rural windmill with warm off-white limewash over stone, weathered dark timber cap and sails, charcoal ironwork and muted meadow greens.",
    "building_lumber_mill": "Modern British industrial shed: weathered mid-grey corrugated steel, muted red-brown brick, aged concrete, natural sawn timber and dark asphalt.",
    "building_pipe_factory": "Post-war factory in muted brown-red brick, warm-grey concrete, weathered galvanised corrugated steel, charcoal doors and restrained rust staining.",
    "grass": "The entire top surface must be deep muted British lawn in olive, moss and sage green, with subtle darker natural variation and brown soil sides; matte, never lime, yellow, fluorescent or artificial turf.",
    "grass_trees": "Native British deciduous trees and groundcover: restrained oak, birch and field-maple greens, brown-grey bark, muted grass and soil.",
    "grass_trees_tall": "Tall native British deciduous trees: restrained oak, birch and field-maple greens, brown-grey bark, muted grass, moss and soil.",
    "building_nature_patch": "Native British scrub and wild planting in muted olive, sage and moss greens, brown-grey branches, dull stone and dark natural soil.",
    "building_duck_pond": "Dull blue-green British pond water, muddy brown banks, muted reeds and native grass, weathered grey stone and timber; no tropical colour.",
    "building_town_hall": "Warm honey-grey limestone civic building, charcoal slate, aged bronze and black ironwork, dark neutral glazing and restrained stone weathering.",
    "building_crazy_golf": "Restrained British seaside crazy golf: weathered cream concrete, faded sage, dusty blue and muted terracotta accents, dark artificial turf and dull stone.",
    "building_nightclub": "Post-war urban nightclub in deep brown-red brick and warm-grey concrete, charcoal metalwork, smoked glazing, restrained burgundy and desaturated teal accents; no neon wash.",
    "building_pirate_radio": "Weathered warm-grey concrete and muted red-brown brick, charcoal steel, galvanised aerial structures, aged cream panels and restrained rust.",
    "building_theatre": "Warm pale limestone and muted red-brown brick, charcoal slate, aged bronze, dark timber doors and restrained burgundy accents; blank signage panels.",
}


def prompt_for(asset_id: str) -> str:
    prompt = COMMON + MATERIALS[asset_id]
    if len(prompt) > 800:
        raise ValueError(f"Prompt exceeds Meshy limit for {asset_id}: {len(prompt)}")
    return prompt


def load_assets() -> list[dict]:
    with MANIFEST.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    source_records = {}
    for batch in ("pilot", "remaining"):
        report = json.loads((OUTPUT / batch / "results.json").read_text())
        for record in report["records"]:
            source_records[record["asset_id"]] = record
    for row in rows:
        row["source"] = source_records[row["asset_id"]]
        row["target_width"], row["target_depth"] = parse_footprint(row["footprint_suggestion"])
        row["texture_prompt"] = prompt_for(row["asset_id"])
        row["image_path"] = CATALOGUE / "images" / row["canonical_filename"]
    return rows


def poll(task_id: str, key: str) -> dict:
    while True:
        result = request_json("GET", f"/retexture/{task_id}", key)
        status = result.get("status")
        print(f"{task_id[:8]}  {status:>11}  {result.get('progress', 0):3}%", flush=True)
        if status in {"SUCCEEDED", "FAILED", "CANCELED"}:
            return result
        time.sleep(8)


def submit(asset: dict, key: str) -> tuple[str, dict]:
    payload = {
        "input_task_id": asset["source"]["task_id"],
        "ai_model": "meshy-7",
        "enable_original_uv": True,
        "enable_pbr": True,
        "texture_resolution": "4k",
        "target_formats": ["glb"],
        "alpha_thumbnail": True,
    }
    if asset["asset_id"] in IMAGE_STYLE_IDS:
        payload["image_style_url"] = image_data_uri(asset["image_path"])
    else:
        payload["text_style_prompt"] = asset["texture_prompt"]
    response = request_json("POST", "/retexture", key, payload, timeout=180)
    return response["result"], payload


def process(asset: dict, key: str) -> dict:
    asset_id = asset["asset_id"]
    print(f"Submitting {asset_id}", flush=True)
    task_id, payload = submit(asset, key)
    result = poll(task_id, key)
    record = {
        "asset_id": asset_id,
        "source_task_id": asset["source"]["task_id"],
        "task_id": task_id,
        "status": result.get("status"),
        "request": payload,
        "consumed_credits": result.get("consumed_credits"),
        "task_error": result.get("task_error"),
    }
    if result.get("status") != "SUCCEEDED":
        return record

    raw_dir = RUN_DIR / "raw-textured-masters"
    normalized_dir = RUN_DIR / "normalized"
    preview_dir = RUN_DIR / "previews"
    maps_dir = RUN_DIR / "texture-maps" / asset_id
    for directory in (raw_dir, normalized_dir, preview_dir, maps_dir):
        directory.mkdir(parents=True, exist_ok=True)

    raw_path = raw_dir / f"{asset_id}.glb"
    normalized_path = normalized_dir / f"{asset_id}.glb"
    preview_path = preview_dir / f"{asset_id}.png"
    download(result["model_urls"]["glb"], raw_path)
    preview_url = result.get("alpha_thumbnail_url") or result.get("thumbnail_url")
    if preview_url:
        download(preview_url, preview_path)

    downloaded_maps = {}
    for map_index, urls in enumerate(result.get("texture_urls", [])):
        for map_name, url in urls.items():
            map_path = maps_dir / f"texture_{map_index}_{map_name}.png"
            download(url, map_path)
            downloaded_maps[f"{map_index}:{map_name}"] = str(map_path.relative_to(ROOT))

    record.update({
        "raw_textured_glb": str(raw_path.relative_to(ROOT)),
        "normalized_glb": str(normalized_path.relative_to(ROOT)),
        "preview_png": str(preview_path.relative_to(ROOT)),
        "texture_maps": downloaded_maps,
        "bounds": normalize_glb(raw_path, normalized_path, asset["target_width"], asset["target_depth"]),
    })
    return record


def checkpoint(records: dict[str, dict]) -> None:
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    report = {
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "style": "restrained low-saturation British stylized realism",
        "geometry_policy": "approved Meshy Ultra geometry retained; original UV enabled; no remesh",
        "records": sorted(records.values(), key=lambda item: item["asset_id"]),
    }
    temporary = RESULTS.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    temporary.replace(RESULTS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("sample", "all"))
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--ids", help="Comma-separated asset IDs to select")
    args = parser.parse_args()

    key = os.environ.get("MESHY_API_KEY") or getpass.getpass("Meshy API key: ")
    if not key:
        raise SystemExit("No Meshy API key supplied")

    existing = {}
    if RESULTS.exists():
        existing = {row["asset_id"]: row for row in json.loads(RESULTS.read_text())["records"]}
    assets = load_assets()
    if args.mode == "sample":
        assets = [asset for asset in assets if asset["asset_id"] in SAMPLE_IDS]
    if args.ids:
        selected_ids = {value.strip() for value in args.ids.split(",") if value.strip()}
        unknown = selected_ids - {asset["asset_id"] for asset in assets}
        if unknown:
            raise SystemExit(f"Unknown asset IDs: {', '.join(sorted(unknown))}")
        assets = [asset for asset in assets if asset["asset_id"] in selected_ids]
    if not args.force:
        assets = [asset for asset in assets if existing.get(asset["asset_id"], {}).get("status") != "SUCCEEDED"]

    balance = request_json("GET", "/balance", key).get("balance")
    expected = len(assets) * 10
    print(f"Balance: {balance} credits; selected: {len(assets)} assets; estimated cost: {expected}", flush=True)
    if balance is not None and balance < expected:
        raise SystemExit("Insufficient Meshy API credit balance")
    if not assets:
        print("Nothing to do; every selected asset already succeeded.", flush=True)
        return 0

    failed = []
    with ThreadPoolExecutor(max_workers=min(args.workers, len(assets))) as executor:
        jobs = {executor.submit(process, asset, key): asset for asset in assets}
        for future in as_completed(jobs):
            asset = jobs[future]
            try:
                record = future.result()
            except Exception as exc:
                record = {"asset_id": asset["asset_id"], "status": "LOCAL_FAILURE", "error": str(exc)}
                print(f"FAILED {asset['asset_id']}: {exc}", file=sys.stderr, flush=True)
            existing[asset["asset_id"]] = record
            checkpoint(existing)
            if record.get("status") != "SUCCEEDED":
                failed.append(record)

    print(f"Wrote {RESULTS}; succeeded={len(assets)-len(failed)} failed={len(failed)}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
