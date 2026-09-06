#!/usr/bin/env python3
"""Create game-ready remesh derivatives from approved textured Meshy masters."""

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

from meshy_production import ROOT, MANIFEST, OUTPUT, document_bounds, download, read_glb, request_json


RUN_DIR = OUTPUT / "runtime-v1"
RESULTS = RUN_DIR / "results.json"
TEXTURE_RESULTS = OUTPUT / "textured-v1/results.json"
SAMPLE_IDS = {"building_small_a", "building_lumber_mill", "building_town_hall", "grass_trees_tall", "pavement_fountain"}

TARGET_POLYCOUNT = {
    "pavement": 5_000,
    "pavement_fountain": 40_000,
    "building_small_a": 40_000,
    "building_small_d": 40_000,
    "building_small_c": 50_000,
    "building_postwar_terrace": 40_000,
    "building_postwar_midblock": 40_000,
    "building_postwar_tower_block": 40_000,
    "building_small_b": 40_000,
    "building_pub": 60_000,
    "building_restaurant": 45_000,
    "building_members_club": 50_000,
    "building_garage": 35_000,
    "building_windmill": 60_000,
    "building_lumber_mill": 40_000,
    "building_pipe_factory": 40_000,
    "grass_trees": 75_000,
    "grass_trees_tall": 75_000,
    "building_nature_patch": 50_000,
    "building_duck_pond": 40_000,
    "building_town_hall": 75_000,
    "building_crazy_golf": 50_000,
    "building_nightclub": 50_000,
    "building_pirate_radio": 60_000,
    "building_theatre": 75_000,
}


def load_assets() -> list[dict]:
    with MANIFEST.open(newline="", encoding="utf-8") as handle:
        manifest = list(csv.DictReader(handle))
    texture_records = {
        record["asset_id"]: record
        for record in json.loads(TEXTURE_RESULTS.read_text())["records"]
    }
    assets = []
    for row in manifest:
        asset_id = row["asset_id"]
        if asset_id not in TARGET_POLYCOUNT:
            continue
        cells = row["footprint_suggestion"].split(" tile", 1)[0]
        cell_width, cell_depth = (int(value) for value in cells.split("x"))
        assets.append({
            **row,
            "source_task_id": texture_records[asset_id]["task_id"],
            "target_polycount": TARGET_POLYCOUNT[asset_id],
            "cell_width": cell_width,
            "cell_depth": cell_depth,
        })
    return assets


def poll(task_id: str, key: str) -> dict:
    while True:
        result = request_json("GET", f"/remesh/{task_id}", key)
        status = result.get("status")
        print(f"{task_id[:8]}  {status:>11}  {result.get('progress', 0):3}%", flush=True)
        if status in {"SUCCEEDED", "FAILED", "CANCELED"}:
            return result
        time.sleep(8)


def mesh_stats(path: Path) -> tuple[list[float], list[float], int, int]:
    document, _, _ = read_glb(path)
    minima, maxima, _ = document_bounds(document)
    triangles = 0
    vertices = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            position = document["accessors"][primitive["attributes"]["POSITION"]]
            vertices += position["count"]
            if "indices" in primitive:
                triangles += document["accessors"][primitive["indices"]]["count"] // 3
            else:
                triangles += position["count"] // 3
    return minima, maxima, triangles, vertices


def process(asset: dict, key: str) -> dict:
    asset_id = asset["asset_id"]
    payload = {
        "input_task_id": asset["source_task_id"],
        "target_formats": ["glb"],
        "topology": "triangle",
        "target_polycount": asset["target_polycount"],
        "alpha_thumbnail": True,
    }
    print(f"Submitting {asset_id} ({asset['target_polycount']:,})", flush=True)
    task_id = request_json("POST", "/remesh", key, payload, timeout=180)["result"]
    result = poll(task_id, key)
    record = {
        "asset_id": asset_id,
        "source_task_id": asset["source_task_id"],
        "task_id": task_id,
        "status": result.get("status"),
        "request": payload,
        "consumed_credits": result.get("consumed_credits"),
        "task_error": result.get("task_error"),
    }
    if result.get("status") != "SUCCEEDED":
        return record

    model_dir = RUN_DIR / "models"
    preview_dir = RUN_DIR / "previews"
    model_dir.mkdir(parents=True, exist_ok=True)
    preview_dir.mkdir(parents=True, exist_ok=True)
    model_path = model_dir / f"{asset_id}.glb"
    preview_path = preview_dir / f"{asset_id}.png"
    download(result["model_urls"]["glb"], model_path)
    preview_url = result.get("alpha_thumbnail_url") or result.get("thumbnail_url")
    if preview_url:
        download(preview_url, preview_path)

    minima, maxima, triangles, vertices = mesh_stats(model_path)
    extent = [maxima[i] - minima[i] for i in range(3)]
    scale = min(asset["cell_width"] / extent[0], asset["cell_depth"] / extent[2])
    center_x = (minima[0] + maxima[0]) / 2.0
    center_z = (minima[2] + maxima[2]) / 2.0
    record.update({
        "model_path": str(model_path.relative_to(ROOT)),
        "preview_path": str(preview_path.relative_to(ROOT)),
        "triangles": triangles,
        "vertices": vertices,
        "source_bounds": {"min": minima, "max": maxima, "extent": extent},
        "game_transform": {
            "model_scale": scale,
            "model_offset": [-center_x * scale, 0.0, -center_z * scale],
            "model_rotation_y": 0.0,
            "result_extent_grid_units": [extent[0] * scale, extent[1] * scale, extent[2] * scale],
            "footprint_cells": [asset["cell_width"], asset["cell_depth"]],
        },
    })
    return record


def checkpoint(records: dict[str, dict]) -> None:
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "policy": "triangle runtime derivatives; full textured masters retained separately",
        "records": sorted(records.values(), key=lambda row: row["asset_id"]),
    }
    temporary = RESULTS.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n")
    temporary.replace(RESULTS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("sample", "all"))
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--force", action="store_true")
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
    if not args.force:
        assets = [asset for asset in assets if existing.get(asset["asset_id"], {}).get("status") != "SUCCEEDED"]

    balance = request_json("GET", "/balance", key).get("balance")
    expected = len(assets) * 5
    print(f"Balance: {balance}; selected: {len(assets)}; estimated cost: {expected}", flush=True)
    if balance is not None and balance < expected:
        raise SystemExit("Insufficient Meshy API credit balance")
    if not assets:
        print("Nothing to do.")
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
