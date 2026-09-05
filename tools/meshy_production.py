#!/usr/bin/env python3
"""Generate canonical city-builder assets through Meshy without persisting API keys."""

from __future__ import annotations

import argparse
import base64
import csv
import getpass
import json
import math
import os
import struct
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / "artifacts/building-concepts/final-catalogue"
MANIFEST = CATALOGUE / "manifest.csv"
OUTPUT = ROOT / "artifacts/building-concepts/meshy-production"
API = "https://api.meshy.ai/openapi/v1"

PILOT_IDS = {
    "building_small_a",
    "building_lumber_mill",
    "grass_trees_tall",
}

TEXTURE_PROMPT = (
    "High-end animated-feature stylized realism matching the reference: believable "
    "British brick, stone, slate, painted render, timber, corrugated metal, foliage "
    "and glass; restrained natural variation, softened bevels and clear material "
    "separation. Preserve the reference palette. Neutral PBR albedo without baked "
    "dramatic lighting. Avoid photoreal noise, low-poly faceting, toy-plastic surfaces, "
    "readable text and invented branding."
)


def request_json(method: str, path: str, key: str, payload=None, timeout=90):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": "uk-city-builder-meshy-production/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"Meshy HTTP {exc.code}: {body[:1000]}") from exc


def download(url: str, path: Path):
    request = urllib.request.Request(url, headers={"User-Agent": "uk-city-builder/1.0"})
    with urllib.request.urlopen(request, timeout=180) as response:
        path.write_bytes(response.read())


def image_data_uri(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def parse_footprint(value: str):
    cells = value.split(" tile", 1)[0]
    width_cells, depth_cells = (int(part) for part in cells.split("x"))
    return width_cells * 10.0, depth_cells * 10.0


def load_assets(mode: str):
    rows = list(csv.DictReader(MANIFEST.open(newline="", encoding="utf-8")))
    if mode == "pilot":
        rows = [row for row in rows if row["asset_id"] in PILOT_IDS]
    elif mode == "remaining":
        rows = [row for row in rows if row["asset_id"] not in PILOT_IDS]
    for row in rows:
        row["image_path"] = CATALOGUE / "images" / row["canonical_filename"]
        row["target_width"], row["target_depth"] = parse_footprint(row["footprint_suggestion"])
    return rows


def submit(asset, key, with_texture: bool):
    payload = {
        "image_url": image_data_uri(asset["image_path"]),
        "model_type": "standard",
        "ai_model": "meshy-7",
        "ultra_mode": True,
        "should_texture": with_texture,
        "should_remesh": False,
        "image_enhancement": False,
        "target_formats": ["glb"],
        "auto_size": False,
        "alpha_thumbnail": True,
    }
    if with_texture:
        payload.update({
            "enable_pbr": True,
            "texture_resolution": "4k",
            "texture_prompt": TEXTURE_PROMPT,
        })
    created = request_json("POST", "/image-to-3d", key, payload, timeout=180)
    return created["result"], payload


def poll(task_id: str, key: str):
    while True:
        result = request_json("GET", f"/image-to-3d/{task_id}", key)
        status = result.get("status")
        print(f"{task_id[:8]}  {status:>11}  {result.get('progress', 0):3}%", flush=True)
        if status in {"SUCCEEDED", "FAILED", "CANCELED"}:
            return result
        time.sleep(8)


def identity():
    return [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]]


def matmul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def transform(m, p):
    v = [p[0], p[1], p[2], 1.0]
    result = [sum(m[r][c] * v[c] for c in range(4)) for r in range(4)]
    return result[:3]


def node_matrix(node):
    if "matrix" in node:
        values = node["matrix"]
        return [[values[c * 4 + r] for c in range(4)] for r in range(4)]
    tx, ty, tz = node.get("translation", [0.0, 0.0, 0.0])
    sx, sy, sz = node.get("scale", [1.0, 1.0, 1.0])
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    rotation = [
        [1 - 2*y*y - 2*z*z, 2*x*y - 2*z*w, 2*x*z + 2*y*w, 0.0],
        [2*x*y + 2*z*w, 1 - 2*x*x - 2*z*z, 2*y*z - 2*x*w, 0.0],
        [2*x*z - 2*y*w, 2*y*z + 2*x*w, 1 - 2*x*x - 2*y*y, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    scale = identity()
    scale[0][0], scale[1][1], scale[2][2] = sx, sy, sz
    translation = identity()
    translation[0][3], translation[1][3], translation[2][3] = tx, ty, tz
    return matmul(translation, matmul(rotation, scale))


def read_glb(path: Path):
    raw = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", raw, 0)
    if magic != b"glTF" or version != 2 or total != len(raw):
        raise ValueError(f"Invalid GLB: {path}")
    chunks = []
    offset = 12
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        chunks.append((kind, raw[offset:offset + length]))
        offset += length
    json_index = next(i for i, (kind, _) in enumerate(chunks) if kind == 0x4E4F534A)
    document = json.loads(chunks[json_index][1].rstrip(b" \t\r\n\0"))
    return document, chunks, json_index


def document_bounds(document):
    minima = [math.inf, math.inf, math.inf]
    maxima = [-math.inf, -math.inf, -math.inf]
    nodes = document.get("nodes", [])
    meshes = document.get("meshes", [])
    accessors = document.get("accessors", [])
    scene_index = document.get("scene", 0)
    roots = document.get("scenes", [{}])[scene_index].get("nodes", [])

    def visit(index, parent):
        node = nodes[index]
        world = matmul(parent, node_matrix(node))
        if "mesh" in node:
            for primitive in meshes[node["mesh"]].get("primitives", []):
                position_index = primitive.get("attributes", {}).get("POSITION")
                if position_index is None:
                    continue
                accessor = accessors[position_index]
                if "min" not in accessor or "max" not in accessor:
                    raise ValueError("POSITION accessor lacks min/max bounds")
                lo, hi = accessor["min"], accessor["max"]
                for x in (lo[0], hi[0]):
                    for y in (lo[1], hi[1]):
                        for z in (lo[2], hi[2]):
                            point = transform(world, (x, y, z))
                            for axis in range(3):
                                minima[axis] = min(minima[axis], point[axis])
                                maxima[axis] = max(maxima[axis], point[axis])
        for child in node.get("children", []):
            visit(child, world)

    for root in roots:
        visit(root, identity())
    if any(math.isinf(value) for value in minima + maxima):
        raise ValueError("No mesh position bounds found")
    return minima, maxima, roots


def write_glb(path: Path, document, chunks, json_index):
    encoded = json.dumps(document, separators=(",", ":")).encode("utf-8")
    encoded += b" " * ((4 - len(encoded) % 4) % 4)
    chunks = list(chunks)
    chunks[json_index] = (0x4E4F534A, encoded)
    body = b"".join(struct.pack("<II", len(data), kind) + data for kind, data in chunks)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, 12 + len(body)) + body)


def normalize_glb(source: Path, destination: Path, target_width: float, target_depth: float):
    document, chunks, json_index = read_glb(source)
    minima, maxima, roots = document_bounds(document)
    extent = [maxima[i] - minima[i] for i in range(3)]
    if extent[0] <= 0 or extent[2] <= 0:
        raise ValueError(f"Degenerate horizontal bounds: {extent}")
    scale = min(target_width / extent[0], target_depth / extent[2])
    centre_x = (minima[0] + maxima[0]) / 2.0
    centre_z = (minima[2] + maxima[2]) / 2.0
    wrapper = {
        "name": "CityBuilder_FootprintNormalizer",
        "children": list(roots),
        "translation": [-centre_x * scale, -minima[1] * scale, -centre_z * scale],
        "scale": [scale, scale, scale],
        "extras": {
            "target_width_m": target_width,
            "target_depth_m": target_depth,
            "uniform_scale": scale,
        },
    }
    document.setdefault("nodes", []).append(wrapper)
    wrapper_index = len(document["nodes"]) - 1
    scene_index = document.get("scene", 0)
    document["scenes"][scene_index]["nodes"] = [wrapper_index]
    write_glb(destination, document, chunks, json_index)
    normalized_extent = [value * scale for value in extent]
    return {
        "source_min": minima,
        "source_max": maxima,
        "source_extent": extent,
        "uniform_scale": scale,
        "normalized_extent": normalized_extent,
        "target_envelope": [target_width, target_depth],
        "fits_envelope": normalized_extent[0] <= target_width + 1e-5 and normalized_extent[2] <= target_depth + 1e-5,
    }


def process_asset(asset, key, raw_dir, normalized_dir, preview_dir, with_texture):
    asset_id = asset["asset_id"]
    print(f"Submitting {asset_id}", flush=True)
    task_id, payload = submit(asset, key, with_texture)
    result = poll(task_id, key)
    record = {
        "asset_id": asset_id,
        "canonical_image": str(asset["image_path"].relative_to(ROOT)),
        "task_id": task_id,
        "status": result.get("status"),
        "request": {key: value for key, value in payload.items() if key != "image_url"},
        "consumed_credits": result.get("consumed_credits"),
        "task_error": result.get("task_error"),
    }
    if result.get("status") != "SUCCEEDED":
        return record
    raw_path = raw_dir / f"{asset_id}.glb"
    normalized_path = normalized_dir / f"{asset_id}.glb"
    download(result["model_urls"]["glb"], raw_path)
    preview_url = result.get("alpha_thumbnail_url") or result.get("thumbnail_url")
    if preview_url:
        download(preview_url, preview_dir / f"{asset_id}.png")
    record["raw_glb"] = str(raw_path.relative_to(ROOT))
    record["normalized_glb"] = str(normalized_path.relative_to(ROOT))
    record["bounds"] = normalize_glb(
        raw_path, normalized_path, asset["target_width"], asset["target_depth"]
    )
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("pilot", "remaining", "all"))
    parser.add_argument("--workers", type=int, default=3)
    args = parser.parse_args()

    key = os.environ.get("MESHY_API_KEY") or getpass.getpass("Meshy API key: ")
    if not key:
        raise SystemExit("No Meshy API key supplied")
    balance = request_json("GET", "/balance", key).get("balance")
    assets = load_assets(args.mode)
    with_texture = args.mode == "pilot"
    expected_per_asset = 35 if with_texture else 25
    expected = len(assets) * expected_per_asset
    print(f"Balance: {balance} credits; selected: {len(assets)} assets; estimated generation cost: {expected}", flush=True)
    if balance is not None and balance < expected:
        raise SystemExit("Insufficient Meshy API credit balance")

    run_dir = OUTPUT / args.mode
    raw_dir = run_dir / "raw-masters"
    normalized_dir = run_dir / "normalized"
    preview_dir = run_dir / "previews"
    for directory in (raw_dir, normalized_dir, preview_dir):
        directory.mkdir(parents=True, exist_ok=True)

    records = []
    with ThreadPoolExecutor(max_workers=min(args.workers, len(assets))) as executor:
        jobs = {
            executor.submit(process_asset, asset, key, raw_dir, normalized_dir, preview_dir, with_texture): asset
            for asset in assets
        }
        for future in as_completed(jobs):
            asset = jobs[future]
            try:
                records.append(future.result())
            except Exception as exc:
                records.append({"asset_id": asset["asset_id"], "status": "LOCAL_FAILURE", "error": str(exc)})
                print(f"FAILED {asset['asset_id']}: {exc}", file=sys.stderr, flush=True)

    records.sort(key=lambda item: item["asset_id"])
    report = {
        "mode": args.mode,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "style": "high-end animated-feature stylized realism",
        "geometry_master": "Meshy 7 Standard Ultra; remesh disabled",
        "textured": with_texture,
        "records": records,
    }
    report_path = run_dir / "results.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    failed = [record for record in records if record.get("status") != "SUCCEEDED"]
    print(f"Wrote {report_path}; succeeded={len(records)-len(failed)} failed={len(failed)}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
