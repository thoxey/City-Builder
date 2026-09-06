#!/usr/bin/env python3
"""Point building definitions at their distinct packaged runtime models."""

from __future__ import annotations

import json
import re
from pathlib import Path

from meshy_production import ROOT
from meshy_runtime_remesh import TARGET_POLYCOUNT


RESULTS = ROOT / "artifacts/building-concepts/meshy-production/runtime-v1/results.json"
DATA = ROOT / "data/buildings"
MODEL_FIELDS = re.compile(
    r'^  "model_path":.*?\n'
    r'^  "model_scale":.*?\n'
    r'^  "model_offset": \[.*?\],\n'
    r'^  "model_rotation_y":.*?$',
    re.MULTILINE | re.DOTALL,
)


def fields(asset_id: str, transform: dict) -> str:
    scale = float(transform["model_scale"])
    offset = [float(value) for value in transform["model_offset"]]
    return (
        f'  "model_path": "res://models/city-builder/{asset_id}.glb",\n'
        f'  "model_scale": {scale:.9g},\n'
        '  "model_offset": [\n'
        f'    {offset[0]:.9g},\n'
        f'    {offset[1]:.9g},\n'
        f'    {offset[2]:.9g}\n'
        '  ],\n'
        f'  "model_rotation_y": {float(transform["model_rotation_y"]):.1f},'
    )


def main() -> None:
    records = {
        row["asset_id"]: row
        for row in json.loads(RESULTS.read_text())["records"]
        if row.get("status") == "SUCCEEDED"
    }
    records["grass"] = {
        "asset_id": "grass",
        "game_transform": {"model_scale": 1.0, "model_offset": [0, 0, 0], "model_rotation_y": 0.0},
    }
    expected = set(TARGET_POLYCOUNT) | {"grass"}
    missing_runtime = sorted(expected - set(records))
    if missing_runtime:
        raise SystemExit(f"Runtime models incomplete: {', '.join(missing_runtime)}")
    definitions = {}
    for path in DATA.rglob("*.json"):
        payload = json.loads(path.read_text())
        if "building_id" in payload:
            definitions[payload["building_id"]] = path

    missing = sorted(set(records) - set(definitions))
    if missing:
        raise SystemExit(f"No building definition for: {', '.join(missing)}")
    for asset_id, record in sorted(records.items()):
        path = definitions[asset_id]
        original = path.read_text()
        updated, count = MODEL_FIELDS.subn(fields(asset_id, record["game_transform"]), original, count=1)
        if count != 1:
            raise SystemExit(f"Could not safely replace model fields in {path}")
        path.write_text(updated)
        print(f"{asset_id}: {path.relative_to(ROOT)}")

    paths = [f"res://models/city-builder/{asset_id}.glb" for asset_id in records]
    if len(paths) != len(set(paths)):
        raise SystemExit("Runtime model paths are not unique")
    print(f"Wired {len(records)} distinct non-road models")


if __name__ == "__main__":
    main()
