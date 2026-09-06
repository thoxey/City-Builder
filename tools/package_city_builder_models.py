#!/usr/bin/env python3
"""Package approved Meshy remeshes as self-contained, Godot-ready GLBs."""

from __future__ import annotations

import io
import json
import struct
from pathlib import Path

from PIL import Image

from meshy_production import ROOT, read_glb
from meshy_runtime_remesh import TARGET_POLYCOUNT


SOURCE = ROOT / "artifacts/building-concepts/meshy-production/runtime-v1"
DESTINATION = ROOT / "models/city-builder"
GRASS_TEXTURES = ROOT / "artifacts/building-concepts/meshy-production/textured-v1/ground-materials/grass"
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def align4(data: bytes, padding: bytes = b"\0") -> bytes:
    return data + padding * ((4 - len(data) % 4) % 4)


def write_glb(path: Path, document: dict, binary: bytes) -> None:
    encoded = align4(json.dumps(document, separators=(",", ":")).encode(), b" ")
    binary = align4(binary)
    body = (
        struct.pack("<II", len(encoded), JSON_CHUNK) + encoded
        + struct.pack("<II", len(binary), BIN_CHUNK) + binary
    )
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, 12 + len(body)) + body)


def resized_image(data: bytes, mime: str, size: int) -> tuple[bytes, list[int]]:
    with Image.open(io.BytesIO(data)) as source:
        source.load()
        if max(source.size) > size:
            source.thumbnail((size, size), Image.Resampling.LANCZOS)
        output = io.BytesIO()
        if mime == "image/jpeg":
            source.convert("RGB").save(output, "JPEG", quality=90, optimize=True)
        else:
            source.save(output, "PNG", optimize=True)
        return output.getvalue(), list(source.size)


def package_meshy_glb(source: Path, destination: Path, texture_size: int = 2048) -> dict:
    document, chunks, _ = read_glb(source)
    binary = next(data for kind, data in chunks if kind == BIN_CHUNK)
    replacements: dict[int, bytes] = {}
    dimensions = []
    for image in document.get("images", []):
        view_index = image.get("bufferView")
        if view_index is None:
            continue
        view = document["bufferViews"][view_index]
        start = view.get("byteOffset", 0)
        data = binary[start:start + view["byteLength"]]
        replacements[view_index], image_size = resized_image(
            data, image.get("mimeType", "image/png"), texture_size
        )
        dimensions.append(image_size)

    rebuilt = bytearray()
    for index, view in enumerate(document.get("bufferViews", [])):
        while len(rebuilt) % 4:
            rebuilt.append(0)
        start = view.get("byteOffset", 0)
        data = replacements.get(index, binary[start:start + view["byteLength"]])
        view["buffer"] = 0
        view["byteOffset"] = len(rebuilt)
        view["byteLength"] = len(data)
        rebuilt.extend(data)
    document["buffers"] = [{"byteLength": len(rebuilt)}]
    write_glb(destination, document, bytes(rebuilt))
    return {
        "source_bytes": source.stat().st_size,
        "runtime_bytes": destination.stat().st_size,
        "texture_dimensions": dimensions,
    }


def add_view(document: dict, binary: bytearray, data: bytes, target: int | None = None) -> int:
    while len(binary) % 4:
        binary.append(0)
    view = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(data)}
    if target is not None:
        view["target"] = target
    document.setdefault("bufferViews", []).append(view)
    binary.extend(data)
    return len(document["bufferViews"]) - 1


def create_grass_glb(destination: Path) -> dict:
    binary = bytearray()
    positions = struct.pack("<12f", -.5, 0, -.5, .5, 0, -.5, .5, 0, .5, -.5, 0, .5)
    normals = struct.pack("<12f", 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0)
    uvs = struct.pack("<8f", 0, 0, 1, 0, 1, 1, 0, 1)
    indices = struct.pack("<6H", 0, 2, 1, 0, 3, 2)
    document: dict = {
        "asset": {"version": "2.0", "generator": "city-builder-runtime-packager"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Grass", "mesh": 0}],
        "bufferViews": [],
        "accessors": [],
        "images": [],
        "textures": [],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
    }
    pos_view = add_view(document, binary, positions, 34962)
    normal_view = add_view(document, binary, normals, 34962)
    uv_view = add_view(document, binary, uvs, 34962)
    index_view = add_view(document, binary, indices, 34963)
    document["accessors"] = [
        {"bufferView": pos_view, "componentType": 5126, "count": 4, "type": "VEC3", "min": [-.5, 0, -.5], "max": [.5, 0, .5]},
        {"bufferView": normal_view, "componentType": 5126, "count": 4, "type": "VEC3"},
        {"bufferView": uv_view, "componentType": 5126, "count": 4, "type": "VEC2"},
        {"bufferView": index_view, "componentType": 5123, "count": 6, "type": "SCALAR"},
    ]

    albedo = Image.open(GRASS_TEXTURES / "grass_albedo_2k.png").convert("RGB")
    normal = Image.open(GRASS_TEXTURES / "grass_normal_2k.png").convert("RGB")
    roughness = Image.open(GRASS_TEXTURES / "grass_roughness_2k.png").convert("L")
    metallic = Image.open(GRASS_TEXTURES / "grass_metallic_2k.png").convert("L")
    packed = Image.merge("RGB", (Image.new("L", roughness.size, 0), roughness, metallic))
    for name, image in (("Grass Albedo", albedo), ("Grass Normal", normal), ("Grass ORM", packed)):
        stream = io.BytesIO()
        image.save(stream, "PNG", optimize=True)
        view = add_view(document, binary, stream.getvalue())
        document["images"].append({"name": name, "bufferView": view, "mimeType": "image/png"})
        document["textures"].append({"sampler": 0, "source": len(document["images"]) - 1})
    document["materials"] = [{
        "name": "British Grass",
        "pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0},
            "metallicRoughnessTexture": {"index": 2},
            "metallicFactor": 1.0,
            "roughnessFactor": 1.0,
        },
        "normalTexture": {"index": 1, "scale": .65},
        "doubleSided": True,
    }]
    document["meshes"] = [{"name": "Grass Tile", "primitives": [{
        "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
        "indices": 3,
        "material": 0,
    }]}]
    document["buffers"] = [{"byteLength": len(binary)}]
    write_glb(destination, document, bytes(binary))
    return {"runtime_bytes": destination.stat().st_size, "triangles": 2, "texture_dimensions": [[2048, 2048]] * 3}


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    results = json.loads((SOURCE / "results.json").read_text())
    succeeded = {row["asset_id"] for row in results["records"] if row.get("status") == "SUCCEEDED"}
    missing = sorted(set(TARGET_POLYCOUNT) - succeeded)
    if missing:
        raise SystemExit(f"Runtime remeshes incomplete: {', '.join(missing)}")
    records = []
    for record in results["records"]:
        if record.get("status") != "SUCCEEDED":
            continue
        asset_id = record["asset_id"]
        source = SOURCE / "models" / f"{asset_id}.glb"
        destination = DESTINATION / f"{asset_id}.glb"
        stats = package_meshy_glb(source, destination, 2048)
        records.append({"asset_id": asset_id, "model_path": f"res://models/city-builder/{asset_id}.glb", **stats})
        print(f"{asset_id}: {stats['source_bytes']/1048576:.1f} -> {stats['runtime_bytes']/1048576:.1f} MiB")
    records.append({"asset_id": "grass", "model_path": "res://models/city-builder/grass.glb", **create_grass_glb(DESTINATION / "grass.glb")})
    report = {"policy": "distinct per-asset 2K runtime GLBs; 4K masters retained under artifacts", "records": records}
    (SOURCE / "game-build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Wrote {len(records)} models and {SOURCE / 'game-build-report.json'}")


if __name__ == "__main__":
    main()
