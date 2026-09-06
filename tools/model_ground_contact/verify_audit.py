#!/usr/bin/env python3
"""Read-only integrity checks for the feature 020 ground-contact audit."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ALLOWED_DECISIONS = ("pass", "grass_underlay", "transform", "mesh_repair")
EXPECTED_ROTATIONS = {0, 90, 180, 270}
EXPECTED_ROTATION_ORDER = [0, 90, 180, 270]
STABLE_FIELDS = (
    "footprint_cells",
    "model_path",
    "model_scale",
    "model_offset",
    "model_rotation_y",
)
FROZEN_CATALOGUE_FIELDS = (
    *STABLE_FIELDS,
    "category",
    "pool_id",
    "cash_cost",
    "community_role",
    "palette_excluded",
    "tags",
    "profiles",
    "ui_group",
    "ui_order",
    "ui_icon",
)
VALID_UI_GROUPS = {
    "roads",
    "homes",
    "commerce",
    "industry",
    "nature",
    "civic",
    "landmarks",
}
UI_GROUP_FALLBACK = "landmarks"
UI_ICON_FALLBACK = "missing-artwork"
GROUND_TREATMENT_REPLACE = "replace"
GROUND_TREATMENT_GRASS_UNDERLAY = "grass_underlay"
HASH_LENGTH = 64
CAPTURE_FLOAT_TOLERANCE = 1e-9


class Verifier:
    def __init__(self, root: Path) -> None:
        self.root = root.resolve()
        self.errors: list[str] = []
        self._hashes: dict[Path, str] = {}

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def load_object(self, path: Path, label: str) -> dict[str, Any]:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            self.errors.append(f"{label}: cannot read valid JSON from {path}: {exc}")
            return {}
        if not isinstance(value, dict):
            self.errors.append(f"{label}: root must be an object")
            return {}
        return value

    def index_rows(self, value: Any, label: str) -> dict[str, dict[str, Any]]:
        if not isinstance(value, list):
            self.errors.append(f"{label}: rows must be an array")
            return {}
        indexed: dict[str, dict[str, Any]] = {}
        for index, row in enumerate(value):
            if not isinstance(row, dict):
                self.errors.append(f"{label}: row {index} must be an object")
                continue
            building_id = row.get("building_id")
            if not isinstance(building_id, str) or not building_id:
                self.errors.append(f"{label}: row {index} has no stable building_id")
                continue
            if building_id in indexed:
                self.errors.append(f"{label}: duplicate building_id {building_id!r}")
                continue
            indexed[building_id] = row
        return indexed

    def resolve_repo_path(self, value: Any, label: str) -> Path | None:
        if not isinstance(value, str) or not value:
            self.errors.append(f"{label}: path is missing")
            return None
        relative = value.removeprefix("res://")
        candidate = (self.root / relative).resolve()
        try:
            candidate.relative_to(self.root)
        except ValueError:
            self.errors.append(f"{label}: path escapes repository root: {value}")
            return None
        return candidate

    def sha256(self, path: Path, label: str) -> str:
        if path in self._hashes:
            return self._hashes[path]
        try:
            digest = hashlib.sha256()
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
        except OSError as exc:
            self.errors.append(f"{label}: cannot hash {path}: {exc}")
            return ""
        value = digest.hexdigest()
        self._hashes[path] = value
        return value

    def require_hash(self, value: Any, label: str) -> str:
        valid = (
            isinstance(value, str)
            and len(value) == HASH_LENGTH
            and all(character in "0123456789abcdef" for character in value)
        )
        self.require(valid, f"{label}: expected a lowercase SHA-256 digest")
        return value if isinstance(value, str) else ""

    def require_vector3(self, value: Any, label: str) -> None:
        valid = (
            isinstance(value, list)
            and len(value) == 3
            and all(
                isinstance(component, (int, float))
                and not isinstance(component, bool)
                and math.isfinite(component)
                for component in value
            )
        )
        self.require(valid, f"{label}: expected three finite numbers")

    def require_bounds(self, value: Any, label: str, near_ground: bool) -> None:
        if not isinstance(value, dict):
            self.errors.append(f"{label}: bounds must be an object")
            return
        for key in ("min", "max", "extent"):
            self.require_vector3(value.get(key), f"{label}.{key}")
        extent = value.get("extent")
        if isinstance(extent, list) and len(extent) == 3:
            self.require(
                all(isinstance(component, (int, float)) and component >= 0 for component in extent),
                f"{label}.extent: components must be non-negative",
            )
            self.require(
                isinstance(extent[0], (int, float)) and extent[0] > 0
                and isinstance(extent[2], (int, float)) and extent[2] > 0,
                f"{label}.extent: horizontal bounds must be non-empty",
            )
        if near_ground:
            point_count = value.get("point_count")
            self.require(
                isinstance(point_count, int) and not isinstance(point_count, bool) and point_count > 0,
                f"{label}.point_count: expected a positive integer",
            )
            band_max_y = value.get("band_max_y")
            self.require(
                isinstance(band_max_y, (int, float))
                and not isinstance(band_max_y, bool)
                and math.isfinite(band_max_y),
                f"{label}.band_max_y: expected a finite number",
            )


def _same_ids(verifier: Verifier, expected: set[str], actual: set[str], label: str) -> None:
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    verifier.require(not missing, f"{label}: missing IDs: {', '.join(missing)}")
    verifier.require(not extra, f"{label}: unexpected IDs: {', '.join(extra)}")


def _stable_value_equal(current: Any, frozen: Any) -> bool:
    """Compare authored values to Godot-captured floats without hiding real drift."""
    if (
        isinstance(current, (int, float))
        and not isinstance(current, bool)
        and isinstance(frozen, (int, float))
        and not isinstance(frozen, bool)
    ):
        return math.isclose(
            float(current),
            float(frozen),
            rel_tol=0.0,
            abs_tol=CAPTURE_FLOAT_TOLERANCE,
        )
    if isinstance(current, list) and isinstance(frozen, list):
        return len(current) == len(frozen) and all(
            _stable_value_equal(current_value, frozen_value)
            for current_value, frozen_value in zip(current, frozen)
        )
    if isinstance(current, dict) and isinstance(frozen, dict):
        return current.keys() == frozen.keys() and all(
            _stable_value_equal(current[key], frozen[key]) for key in current
        )
    return current == frozen


def _valid_godot_filename(value: Any) -> bool:
    """Mirror the filename restrictions used by String.is_valid_filename()."""
    return (
        isinstance(value, str)
        and bool(value)
        and not any(character in value for character in ':\\/?*"|%<>')
    )


def _catalogue_int(value: Any, default: int) -> Any:
    """Apply the catalogue's numeric coercion without hiding malformed values."""
    if isinstance(value, (int, float)):
        return int(value)
    return default if value is None else value


def _catalogue_float(value: Any, default: float) -> Any:
    """Apply the catalogue's float projection while retaining invalid authored data."""
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    return default if value is None else value


def _catalogue_vector3(value: Any) -> Any:
    """Mirror BuildingCatalog._to_vec3 for JSON-safe authored values."""
    if not isinstance(value, list) or len(value) < 3:
        return [0.0, 0.0, 0.0]
    if not all(
        isinstance(component, (int, float)) and not isinstance(component, bool)
        for component in value[:3]
    ):
        return value
    return [float(component) for component in value[:3]]


def _catalogue_footprint(value: Any) -> Any:
    """Mirror BuildingCatalog._to_cell_offsets for JSON-safe authored values."""
    if not isinstance(value, list):
        return [[0, 0]]
    cells: list[Any] = []
    for item in value:
        if not isinstance(item, list) or len(item) < 2:
            cells.append([0, 0])
            continue
        if not all(
            isinstance(component, (int, float)) and not isinstance(component, bool)
            for component in item[:2]
        ):
            cells.append(item)
            continue
        cells.append([int(item[0]), int(item[1])])
    return cells or [[0, 0]]


def _normalised_catalogue_row(payload: dict[str, Any]) -> dict[str, Any]:
    """Project authored JSON through the defaults captured by BuildingCatalog."""
    ui_group = payload.get("ui_group", "")
    if ui_group not in VALID_UI_GROUPS:
        ui_group = UI_GROUP_FALLBACK

    ui_order_raw = payload.get("ui_order", 1000)
    ui_order = (
        int(ui_order_raw)
        if isinstance(ui_order_raw, (int, float)) and not isinstance(ui_order_raw, bool)
        else 1000
    )

    ui_icon = payload.get("ui_icon", "")
    if not _valid_godot_filename(ui_icon):
        ui_icon = UI_ICON_FALLBACK

    return {
        "footprint_cells": _catalogue_footprint(payload.get("footprint", [[0, 0]])),
        "model_path": payload.get("model_path", ""),
        "model_scale": _catalogue_float(payload.get("model_scale", 1.0), 1.0),
        "model_offset": _catalogue_vector3(payload.get("model_offset", [0, 0, 0])),
        "model_rotation_y": _catalogue_float(payload.get("model_rotation_y", 0.0), 0.0),
        "category": payload.get("category", ""),
        "pool_id": payload.get("pool_id", ""),
        "cash_cost": _catalogue_int(payload.get("cash_cost", 0), 0),
        "community_role": payload.get("community_role", ""),
        "palette_excluded": bool(payload.get("palette_excluded", False)),
        "tags": payload.get("tags", []),
        "profiles": payload.get("profiles", []),
        "ui_group": ui_group,
        "ui_order": ui_order,
        "ui_icon": ui_icon,
    }


def _current_definitions(verifier: Verifier) -> dict[str, tuple[Path, dict[str, Any]]]:
    definitions: dict[str, tuple[Path, dict[str, Any]]] = {}
    data_root = verifier.root / "data" / "buildings"
    for path in sorted(data_root.rglob("*.json")):
        payload = verifier.load_object(path, f"catalogue definition {path.relative_to(verifier.root)}")
        building_id = payload.get("building_id")
        if not isinstance(building_id, str) or not building_id:
            continue
        if building_id in definitions:
            prior = definitions[building_id][0].relative_to(verifier.root)
            verifier.errors.append(
                f"current catalogue: duplicate {building_id!r} in {prior} and {path.relative_to(verifier.root)}"
            )
            continue
        definitions[building_id] = (path.resolve(), payload)
    return definitions


def _verify_evidence(verifier: Verifier, row: dict[str, Any], building_id: str, phase: str) -> None:
    before = row.get("before_evidence")
    verifier.require(
        isinstance(before, list) and bool(before),
        f"{building_id}: before_evidence must contain at least one capture",
    )
    evidence_values: list[Any] = list(before) if isinstance(before, list) else []
    after = row.get("after_evidence")
    verifier.require(isinstance(after, list), f"{building_id}: after_evidence must be an array")
    if isinstance(after, list):
        evidence_values.extend(after)
        if phase == "after" and row.get("status") != "pass":
            verifier.require(bool(after), f"{building_id}: repaired row lacks after evidence")
    for index, value in enumerate(evidence_values):
        path = verifier.resolve_repo_path(value, f"{building_id}.evidence[{index}]")
        if path is not None:
            verifier.require(path.is_file(), f"{building_id}: evidence file is missing: {value}")

    rotations = row.get("rotation_results")
    if not isinstance(rotations, list):
        verifier.errors.append(f"{building_id}: rotation_results must be an array")
        return
    verifier.require(len(rotations) == 4, f"{building_id}: expected exactly four rotation results")
    degrees: set[int] = set()
    quadrants: set[int] = set()
    for index, rotation in enumerate(rotations):
        if not isinstance(rotation, dict):
            verifier.errors.append(f"{building_id}: rotation result {index} must be an object")
            continue
        degrees_value = rotation.get("degrees")
        quadrant = rotation.get("quadrant")
        if isinstance(degrees_value, int) and not isinstance(degrees_value, bool):
            degrees.add(degrees_value)
        if isinstance(quadrant, int) and not isinstance(quadrant, bool):
            quadrants.add(quadrant)
        verifier.require(
            rotation.get("verdict") in {"pass", "fail"},
            f"{building_id}: rotation {index} lacks a frozen pass/fail verdict",
        )
        if phase == "after":
            verifier.require(
                rotation.get("verdict") == "pass",
                f"{building_id}: final after-phase rotation {degrees_value!r} is not approved as pass",
            )
        evidence = rotation.get("evidence")
        verifier.require(
            isinstance(evidence, str) and evidence in evidence_values,
            f"{building_id}: rotation {index} does not reference recorded evidence",
        )
    verifier.require(degrees == EXPECTED_ROTATIONS, f"{building_id}: rotation degrees are incomplete")
    verifier.require(quadrants == {0, 1, 2, 3}, f"{building_id}: rotation quadrants are incomplete")


def _verify_mesh_facts(verifier: Verifier, row: dict[str, Any], building_id: str) -> None:
    verifier.require(row.get("first_mesh_readable") is True, f"{building_id}: first mesh is not readable")
    first_mesh = row.get("first_mesh")
    if not isinstance(first_mesh, dict):
        verifier.errors.append(f"{building_id}: first_mesh facts are missing")
        return
    verifier.require(first_mesh.get("readable") is True, f"{building_id}: first_mesh.readable is not true")
    verifier.require(
        isinstance(first_mesh.get("resource_name"), str) and bool(first_mesh.get("resource_name")),
        f"{building_id}: first mesh resource name is missing",
    )
    resource_path = first_mesh.get("resource_path")
    verifier.require(
        isinstance(resource_path, str) and resource_path.startswith(str(row.get("model_path", "")) + "::"),
        f"{building_id}: first mesh resource path is not tied to the stable model path",
    )
    vertex_count = first_mesh.get("vertex_count")
    surface_count = first_mesh.get("surface_count")
    verifier.require(
        isinstance(vertex_count, int) and not isinstance(vertex_count, bool) and vertex_count > 0,
        f"{building_id}: first mesh vertex_count must be positive",
    )
    verifier.require(
        isinstance(surface_count, int) and not isinstance(surface_count, bool) and surface_count > 0,
        f"{building_id}: first mesh surface_count must be positive",
    )

    materials = row.get("materials")
    textures = row.get("texture_bindings")
    verifier.require(isinstance(materials, list) and bool(materials), f"{building_id}: materials are not recorded")
    verifier.require(isinstance(textures, list) and bool(textures), f"{building_id}: textures are not recorded")
    verifier.require(first_mesh.get("materials") == materials, f"{building_id}: first-mesh material facts disagree")
    verifier.require(first_mesh.get("texture_bindings") == textures, f"{building_id}: first-mesh texture facts disagree")

    if isinstance(materials, list):
        for index, material in enumerate(materials):
            valid = (
                isinstance(material, dict)
                and isinstance(material.get("class"), str)
                and bool(material.get("class"))
                and isinstance(material.get("surface"), int)
                and material.get("surface") >= 0
            )
            verifier.require(valid, f"{building_id}: material {index} lacks import facts")
    if isinstance(textures, list):
        for index, texture in enumerate(textures):
            valid = (
                isinstance(texture, dict)
                and isinstance(texture.get("slot"), str)
                and bool(texture.get("slot"))
                and isinstance(texture.get("resource_path"), str)
                and bool(texture.get("resource_path"))
                and isinstance(texture.get("width"), int)
                and texture.get("width") > 0
                and isinstance(texture.get("height"), int)
                and texture.get("height") > 0
            )
            verifier.require(valid, f"{building_id}: texture binding {index} lacks import facts")
            if valid:
                texture_path = verifier.resolve_repo_path(
                    texture["resource_path"], f"{building_id}.texture_bindings[{index}]"
                )
                if texture_path is not None:
                    verifier.require(
                        texture_path.is_file(),
                        f"{building_id}: recorded texture is missing: {texture['resource_path']}",
                    )

    verifier.require_bounds(row.get("overall_bounds"), f"{building_id}.overall_bounds", False)
    verifier.require_bounds(row.get("near_ground_bounds"), f"{building_id}.near_ground_bounds", True)


def verify(root: Path) -> tuple[list[str], Counter[str], int]:
    verifier = Verifier(root)
    validation = verifier.root / "specs" / "020-building-ground-contact" / "validation"
    audit = verifier.load_object(validation / "model-audit.json", "model audit")
    baseline = verifier.load_object(validation / "catalogue-baseline.json", "catalogue baseline")
    decisions = verifier.load_object(validation / "audit-decisions.json", "audit decisions")

    audit_rows = verifier.index_rows(audit.get("rows"), "model audit")
    baseline_rows = verifier.index_rows(baseline.get("rows"), "catalogue baseline")
    current = _current_definitions(verifier)
    decision_rows_raw = decisions.get("rows")
    if not isinstance(decision_rows_raw, dict):
        verifier.errors.append("audit decisions: rows must be an object keyed by stable building ID")
        decision_rows: dict[str, Any] = {}
    else:
        decision_rows = decision_rows_raw

    after_review = decisions.get("after_review")
    if not isinstance(after_review, dict):
        verifier.errors.append(
            "audit decisions: after_review must be an explicit object"
        )
        after_review = {}

    verifier.require(
        decisions.get("classification_order") == list(ALLOWED_DECISIONS),
        "audit decisions: classification_order does not match the mandated treatment order",
    )
    verifier.require(audit.get("catalogue_source") == "BuildingCatalog.get_summary()", "model audit: wrong catalogue source")
    verifier.require(
        baseline.get("catalogue_source") == "BuildingCatalog.get_summary()",
        "catalogue baseline: wrong catalogue source",
    )
    verifier.require(audit.get("catalogue_count") == len(audit_rows), "model audit: catalogue_count mismatch")
    verifier.require(audit.get("captured_count") == len(audit_rows), "model audit: captured_count mismatch")
    verifier.require(
        baseline.get("catalogue_count") == len(baseline_rows),
        "catalogue baseline: catalogue_count mismatch",
    )

    expected_ids = set(baseline_rows)
    _same_ids(verifier, expected_ids, set(audit_rows), "model audit coverage")
    _same_ids(verifier, expected_ids, set(current), "current catalogue coverage")
    _same_ids(verifier, expected_ids, set(decision_rows), "decision coverage")
    reviewed_ids_raw = after_review.get("building_ids")
    if not isinstance(reviewed_ids_raw, list) or not all(
        isinstance(building_id, str) and bool(building_id) for building_id in reviewed_ids_raw
    ):
        verifier.errors.append(
            "audit decisions: after_review.building_ids must be an array of stable building IDs"
        )
        reviewed_ids: list[str] = []
    else:
        reviewed_ids = reviewed_ids_raw
        verifier.require(
            len(reviewed_ids) == len(set(reviewed_ids)),
            "audit decisions: after_review.building_ids contains duplicate IDs",
        )
    _same_ids(verifier, expected_ids, set(reviewed_ids), "after-review coverage")
    verifier.require(
        after_review.get("reviewed_rotation_degrees") == EXPECTED_ROTATION_ORDER,
        f"audit decisions: after_review must explicitly cover rotations {EXPECTED_ROTATION_ORDER}",
    )
    verifier.require(
        after_review.get("verdict") == "pass",
        "audit decisions: after_review verdict must be pass",
    )

    phase = str(audit.get("phase", ""))
    verifier.require(phase in {"before", "after"}, "model audit: phase must be before or after")
    statuses: Counter[str] = Counter()

    for building_id in sorted(expected_ids & set(audit_rows) & set(current)):
        row = audit_rows[building_id]
        frozen = baseline_rows[building_id]
        definition_path, payload = current[building_id]
        current_catalogue_row = _normalised_catalogue_row(payload)
        decision = decision_rows.get(building_id)
        status = row.get("status")
        if isinstance(status, str):
            statuses[status] += 1
        verifier.require(status in ALLOWED_DECISIONS, f"{building_id}: invalid audit decision {status!r}")
        verifier.require(row.get("approved") is True, f"{building_id}: audit decision is not approved")
        verifier.require(
            isinstance(row.get("rationale"), str) and bool(row.get("rationale", "").strip()),
            f"{building_id}: rationale is missing",
        )
        if isinstance(decision, dict):
            verifier.require(decision.get("status") in ALLOWED_DECISIONS, f"{building_id}: invalid frozen decision")
            verifier.require(decision.get("status") == status, f"{building_id}: audit and frozen decision disagree")
            verifier.require(decision.get("rationale") == row.get("rationale"), f"{building_id}: frozen rationale drifted")
        else:
            verifier.errors.append(f"{building_id}: frozen decision must be an object")

        for field in STABLE_FIELDS:
            verifier.require(
                row.get(field) == frozen.get(field),
                f"{building_id}: audit {field} drifted from catalogue baseline",
            )
        for field in FROZEN_CATALOGUE_FIELDS:
            verifier.require(
                field in frozen,
                f"{building_id}: catalogue baseline is missing frozen field {field}",
            )
            verifier.require(
                _stable_value_equal(current_catalogue_row.get(field), frozen.get(field)),
                f"{building_id}: current catalogue field {field} changed",
            )

        expected_treatment = (
            GROUND_TREATMENT_GRASS_UNDERLAY
            if status == GROUND_TREATMENT_GRASS_UNDERLAY
            else GROUND_TREATMENT_REPLACE
        )
        current_treatment = payload.get("ground_treatment", GROUND_TREATMENT_REPLACE)
        verifier.require(
            current_treatment == expected_treatment,
            f"{building_id}: decision {status!r} requires authored ground_treatment "
            f"{expected_treatment!r}, found {current_treatment!r}",
        )

        expected_definition = "res://" + definition_path.relative_to(verifier.root).as_posix()
        verifier.require(
            row.get("definition_path") == expected_definition,
            f"{building_id}: definition path drifted ({row.get('definition_path')!r})",
        )
        transform_source = verifier.resolve_repo_path(row.get("transform_source"), f"{building_id}.transform_source")
        if transform_source is not None:
            verifier.require(transform_source.is_file(), f"{building_id}: transform source is missing")

        model_path = verifier.resolve_repo_path(row.get("model_path"), f"{building_id}.model_path")
        model_hash_before = verifier.require_hash(row.get("model_hash_before"), f"{building_id}.model_hash_before")
        model_hash_after_raw = row.get("model_hash_after")
        if model_hash_after_raw not in (None, ""):
            model_hash_after = verifier.require_hash(model_hash_after_raw, f"{building_id}.model_hash_after")
            verifier.require(
                model_hash_after == model_hash_before,
                f"{building_id}: model binary changed despite an underlay/pass-only audit",
            )
        else:
            model_hash_after = model_hash_before
        if model_path is not None:
            verifier.require(model_path.is_file(), f"{building_id}: stable model path is missing")
            if model_path.is_file():
                verifier.require(
                    verifier.sha256(model_path, f"{building_id}.model_path") == model_hash_after,
                    f"{building_id}: runtime model hash drifted from the frozen audit",
                )

        source_path = verifier.resolve_repo_path(row.get("source_model_path"), f"{building_id}.source_model_path")
        source_hash_before = verifier.require_hash(
            row.get("source_hash_before"), f"{building_id}.source_hash_before"
        )
        source_hash_after = verifier.require_hash(
            row.get("source_hash_after"), f"{building_id}.source_hash_after"
        )
        if status in {"pass", "grass_underlay"} and source_hash_before and source_hash_after:
            verifier.require(
                source_hash_after == source_hash_before,
                f"{building_id}: upstream source changed despite an underlay/pass-only audit",
            )
        if source_path is not None:
            verifier.require(source_path.is_file(), f"{building_id}: recorded upstream source is missing")
            if source_path.is_file() and source_hash_after:
                verifier.require(
                    verifier.sha256(source_path, f"{building_id}.source_model_path") == source_hash_after,
                    f"{building_id}: upstream source hash drifted from the final audit",
                )

        _verify_mesh_facts(verifier, row, building_id)
        _verify_evidence(verifier, row, building_id, phase)

    forbidden = statuses["transform"] + statuses["mesh_repair"]
    verifier.require(
        forbidden == 0,
        "Phase 5 gate failed: transform and mesh_repair decisions must both be zero",
    )
    return verifier.errors, statuses, len(expected_ids)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="repository root (defaults to the root containing this script)",
    )
    args = parser.parse_args()
    errors, statuses, count = verify(args.root)
    if errors:
        print(f"GROUND_CONTACT_AUDIT_VERIFY success=false errors={len(errors)}", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(
        "GROUND_CONTACT_AUDIT_VERIFY success=true "
        f"catalogue={count} pass={statuses['pass']} grass_underlay={statuses['grass_underlay']} "
        f"transform={statuses['transform']} mesh_repair={statuses['mesh_repair']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
