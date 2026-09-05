#!/usr/bin/env python3
"""Resolve and compile South West building prompts without external dependencies."""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
from pathlib import Path


PRESETS = {
    "victorian_industrial": {
        "density": ["medium", "high"],
        "street_type": ["residential_street", "urban_street"],
        "era_character": ["victorian_industrial"],
        "typology": ["terrace"],
        "attachment": ["terrace"],
        "storeys": [2, 2, 3],
        "bay_count": [2, 2, 3],
        "massing": ["single_volume", "main_plus_rear_projection"],
        "setback": ["none", "very_shallow_threshold"],
        "building_line": ["continuous"],
        "roof_family": ["gable"],
        "roof_orientation": ["ridge_parallel_to_street"],
        "roof_articulation": ["plain", "paired_chimneys", "individual_chimneys"],
        "facade_rhythm": ["2_bay", "2_bay", "3_bay"],
        "vertical_organisation": ["uniform"],
        "opening_character": ["tall_narrow"],
        "opening_density": ["moderate"],
        "alignment": ["regular_vertical"],
        "symmetry": ["restrained", "near_symmetric"],
        "ground_condition": ["direct_to_pavement", "very_shallow_threshold"],
        "sky_condition": ["chimney_rhythm", "exposed_pitched_roof"],
        "primary_material": ["red_brick", "red_brick", "brown_brick", "local_stone", "painted_render"],
        "secondary_material": ["stone_lintels_and_sills", "brick_lintels"],
        "roof_material": ["dark_slate"],
        "window_family": ["timber_sash", "simple_vertical_casement"],
        "door_family": ["painted_timber_panelled"],
        "decoration_level": ["low", "low", "moderate"],
        "detail_density": ["controlled"],
        "weathering": ["light", "moderate"],
        "boundary_treatment": ["none"],
    },
    "georgian_formal": {
        "density": ["medium", "high"],
        "street_type": ["urban_street", "square"],
        "era_character": ["georgian_formal"],
        "typology": ["townhouse", "terrace"],
        "attachment": ["terrace", "continuous_block"],
        "storeys": [3],
        "bay_count": [2, 3, 3],
        "massing": ["single_volume"],
        "setback": ["none", "lightwell_depth"],
        "building_line": ["continuous"],
        "roof_family": ["gable", "parapet"],
        "roof_orientation": ["ridge_parallel_to_street"],
        "roof_articulation": ["plain", "restrained_dormers", "concealed_behind_parapet"],
        "facade_rhythm": ["2_bay", "3_bay"],
        "vertical_organisation": ["decreasing_floor_height", "base_body_top"],
        "opening_character": ["tall_narrow"],
        "opening_density": ["moderate"],
        "alignment": ["strict_vertical"],
        "symmetry": ["symmetric", "disciplined_terrace_rhythm"],
        "ground_condition": ["direct_to_pavement", "railings_and_lightwell"],
        "sky_condition": ["parapet", "exposed_pitched_roof", "restrained_dormers"],
        "primary_material": ["limestone", "pale_painted_render", "warm_brick"],
        "secondary_material": ["stone_door_surrounds"],
        "roof_material": ["dark_slate"],
        "window_family": ["timber_sash"],
        "door_family": ["painted_timber_panelled_with_fanlight"],
        "decoration_level": ["low", "moderate"],
        "detail_density": ["controlled"],
        "weathering": ["light"],
        "boundary_treatment": ["none", "simple_railings"],
    },
    "high_street": {
        "density": ["high"],
        "street_type": ["high_street"],
        "era_character": ["victorian_to_early_20c"],
        "typology": ["shop_and_upper"],
        "attachment": ["continuous_block"],
        "storeys": [2, 3, 3],
        "bay_count": [1, 2, 3],
        "massing": ["single_volume", "main_plus_rear_projection"],
        "setback": ["none"],
        "building_line": ["continuous"],
        "roof_family": ["gable", "parapet"],
        "roof_orientation": ["ridge_parallel_to_street"],
        "roof_articulation": ["plain", "paired_chimneys"],
        "facade_rhythm": ["shopfront_module"],
        "vertical_organisation": ["expressed_ground_floor", "base_body_top"],
        "opening_character": ["large_shopfront_below_tall_narrow_above"],
        "opening_density": ["active_ground_moderate_upper"],
        "alignment": ["shopfront_with_aligned_upper_bays"],
        "symmetry": ["restrained", "asymmetric_entrance"],
        "ground_condition": ["shopfront"],
        "sky_condition": ["exposed_pitched_roof", "parapet", "chimney_rhythm"],
        "primary_material": ["red_brick", "brown_brick", "painted_render", "limestone"],
        "secondary_material": ["painted_timber_shopfront", "stone_lintels_and_sills"],
        "roof_material": ["dark_slate"],
        "window_family": ["timber_sash", "simple_vertical_casement"],
        "door_family": ["separate_upper_floor_door"],
        "decoration_level": ["low", "moderate"],
        "detail_density": ["controlled"],
        "weathering": ["light", "moderate"],
        "boundary_treatment": ["none"],
        "signage_policy": ["blank_or_generic"],
    },
    "victorian_suburb": {
        "density": ["low", "medium"],
        "street_type": ["residential_street"],
        "era_character": ["late_victorian_suburban"],
        "typology": ["semi_detached", "detached_villa", "short_terrace"],
        "attachment": ["semi_detached", "detached", "terrace"],
        "storeys": [2],
        "bay_count": [2, 3],
        "massing": ["single_volume", "main_plus_rear_projection"],
        "setback": ["shallow_front_garden"],
        "building_line": ["consistent_setback"],
        "roof_family": ["gable", "hipped", "complex_victorian"],
        "roof_orientation": ["ridge_parallel_to_street", "gable_to_street"],
        "roof_articulation": ["plain", "cross_gable", "paired_chimneys"],
        "facade_rhythm": ["2_bay", "3_bay", "paired_bays"],
        "vertical_organisation": ["uniform"],
        "opening_character": ["tall_narrow", "modest_bay_window"],
        "opening_density": ["moderate"],
        "alignment": ["regular_vertical"],
        "symmetry": ["paired_symmetry", "near_symmetric"],
        "ground_condition": ["shallow_front_garden"],
        "sky_condition": ["gabled", "chimney_rhythm"],
        "primary_material": ["red_brick", "local_stone", "painted_render"],
        "secondary_material": ["stone_lintels_and_sills", "restrained_brick_detail"],
        "roof_material": ["dark_slate", "restrained_clay_tile"],
        "window_family": ["timber_sash", "simple_vertical_casement"],
        "door_family": ["painted_timber_panelled"],
        "decoration_level": ["low", "moderate"],
        "detail_density": ["controlled"],
        "weathering": ["light"],
        "boundary_treatment": ["low_stone_wall", "low_hedge", "short_front_path"],
    },
}

COMMON = {
    "region": "south_west_england_fictional_city",
    "prominence": "background",
    "use": "residential",
    "street_role": "mid_terrace",
    "occupancy_expression": "use_neutral",
    "clutter_level": "low_controlled",
    "signage_policy": "none",
    "occlusion_budget": "none",
    "thin_detail_budget": "very_low",
    "component_separation": "strong",
    "camera": "orthographic_isometric_front_three_quarter_elevated",
    "lighting": "sunny_clear_daylight_soft_readable_shadows_fixed_direction",
    "background": "plain_warm_neutral",
    "framing": "entire_building_and_roof_visible_with_clear_margin",
    "mesh_profile": "strict",
    "geometry_reuse_allowed": False,
}


def infer_request(text: str) -> dict:
    low = text.lower()
    if "georgian" in low:
        family = "georgian_formal"
    elif "high street" in low or "mixed-use" in low or "mixed use" in low:
        family = "high_street"
    elif "suburb" in low:
        family = "victorian_suburb"
    else:
        family = "victorian_industrial"
    use = "mixed_use" if "mixed" in low or "shop" in low else "residential"
    prominence = next((p for p in ("landmark", "accent", "background") if p in low), "background")
    return {"neighbourhood_family": family, "use": use, "prominence": prominence}


def load_spec(raw: str) -> dict:
    if raw.startswith("@"):
        return json.loads(Path(raw[1:]).read_text())
    return json.loads(raw)


def choose(options, rng: random.Random, deterministic: bool):
    return options[0] if deterministic else rng.choice(options)


def resolve(base: dict, mode: str, seed: int, index: int = 0) -> dict:
    rng = random.Random(seed + index * 9973)
    out = dict(COMMON)
    out.update(base)
    family = out.get("neighbourhood_family", "victorian_industrial")
    preset = PRESETS.get(family, PRESETS["victorian_industrial"])
    deterministic = mode == "deterministic"
    for key, options in preset.items():
        if key not in out:
            out[key] = choose(options, rng, deterministic)
    if isinstance(out.get("bay_count"), int):
        out["facade_rhythm"] = f"{out['bay_count']}_bay"
    if out.get("roof_family") == "parapet":
        out["roof_articulation"] = "concealed_behind_parapet"
        out["sky_condition"] = "parapet"
    elif out.get("sky_condition") == "parapet":
        out["sky_condition"] = "exposed_pitched_roof"
    if out.get("typology") == "semi_detached":
        out["attachment"] = "semi_detached"
        out["street_role"] = "detached_in_plot"
    elif out.get("typology") == "detached_villa":
        out["attachment"] = "detached"
        out["street_role"] = "detached_in_plot"
    elif out.get("typology") == "shop_and_upper":
        out["occupancy_expression"] = choose(
            ["small_shop_plus_flat", "cafe_plus_flats", "office_plus_flats", "vacant_shop_plus_flats"], rng, deterministic
        )
        out["street_role"] = choose(["mid_terrace", "mid_terrace", "end_terrace", "corner"], rng, deterministic)
    out["mode"] = mode
    out["seed"] = seed
    if "model_id" not in out:
        family_slug = re.sub(r"[^a-z0-9]+", "_", family.lower()).strip("_")
        typology_slug = re.sub(r"[^a-z0-9]+", "_", str(out["typology"]).lower()).strip("_")
        out["model_id"] = f"{family_slug}_{typology_slug}_{seed:04d}_{index + 1:02d}"
    out["geometry_signature"] = "unique_geometry_required_before_catalogue_acceptance"
    return out


def validate(spec: dict) -> dict:
    errors, corrections, warnings = [], [], []
    typology = spec.get("typology")
    if typology == "terrace" and spec.get("attachment") in {"detached", "pavilion_in_plot"}:
        errors.append("Terrace typology conflicts with detached/pavilion attachment.")
    if typology in {"mansion_block", "slab_block", "point_block"} and int(spec.get("storeys", 0)) < 3:
        errors.append(f"{typology} requires at least 3 storeys.")
    if spec.get("neighbourhood_family") == "high_street" and spec.get("use") in {"retail", "mixed_use", "hospitality"}:
        if spec.get("ground_condition") != "shopfront":
            errors.append("High-street commercial/mixed use requires an active shopfront ground condition.")
        if spec.get("door_family") != "separate_upper_floor_door":
            errors.append("High-street mixed use requires independent upper-floor access.")
    if spec.get("prominence") == "background" and spec.get("sky_condition") in {"tower", "cupola", "turret"}:
        spec["sky_condition"] = "exposed_pitched_roof"
        corrections.append("Suppressed landmark skyline element for background prominence.")
    if spec.get("neighbourhood_family") == "georgian_formal" and spec.get("alignment") in {"chaotic", "unaligned"}:
        errors.append("Georgian formal expression requires disciplined opening alignment.")
    expected_rhythm = f"{spec.get('bay_count')}_bay"
    if isinstance(spec.get("bay_count"), int) and spec.get("facade_rhythm") != expected_rhythm:
        errors.append("Numeric bay_count must agree with facade_rhythm.")
    if spec.get("roof_family") == "parapet" and spec.get("sky_condition") != "parapet":
        errors.append("Parapet roof family requires a parapet sky condition.")
    if spec.get("occlusion_budget") not in {"none", "very_low"}:
        warnings.append("Mesh profile is strict; reduce façade and silhouette occlusion.")
    if spec.get("geometry_reuse_allowed") is not False:
        errors.append("Catalogue assets must use unique geometry; shared geometry means a missing model.")
    if not spec.get("model_id"):
        errors.append("Every model candidate requires a unique model_id.")
    return {"valid": not errors, "errors": errors, "corrections": corrections, "warnings": warnings}


def human(value) -> str:
    return str(value).replace("_", " ")


def compile_prompt(spec: dict) -> str:
    return " ".join(
        [
            f"Create one {human(spec['prominence'])} {human(spec['typology'])} for a fictional South West England {human(spec['neighbourhood_family'])}.",
            f"Use: {human(spec['use'])}; occupancy: {human(spec['occupancy_expression'])}.",
            f"Model identity: {spec['model_id']}; create unique geometry for this catalogue asset and do not reuse or retexture another model.",
            f"Geometry: {spec['storeys']} storeys, {human(spec['bay_count'])} bays, {human(spec['attachment'])}, {human(spec['massing'])}, {human(spec['street_role'])}, {human(spec['building_line'])} building line, {human(spec['setback'])} setback.",
            f"Roof: {human(spec['roof_family'])}, {human(spec['roof_orientation'])}, {human(spec['roof_articulation'])}, {human(spec['roof_material'])}; sky condition {human(spec['sky_condition'])}.",
            f"Façade: {human(spec['facade_rhythm'])} rhythm, {human(spec['vertical_organisation'])}, {human(spec['opening_character'])} openings, {human(spec['alignment'])} alignment, {human(spec['symmetry'])} symmetry.",
            f"Materials: {human(spec['primary_material'])}, {human(spec['secondary_material'])}; {human(spec['window_family'])} windows and {human(spec['door_family'])} doors.",
            f"Ground: {human(spec['ground_condition'])}; boundary {human(spec['boundary_treatment'])}.",
            f"Expression: {human(spec['decoration_level'])} decoration, {human(spec['detail_density'])} detail, {human(spec['weathering'])} weathering, believable but consolidated gutters and downpipes.",
            "Render as a clean stylised architectural asset in sunny clear daylight, with soft readable shadows in one fixed direction.",
            "Use an orthographic front three-quarter elevated isometric view with minimal perspective; show the entire unobscured building and roof with clear margin on a plain warm-neutral background.",
            "Optimise for image-to-mesh reconstruction: strong component separation, clearly recessed windows and doors, simple readable roof geometry, no people, cars, legible brand text, street clutter, foreground vegetation, depth of field, dramatic perspective, or ambiguous overlapping geometry; avoid thin railings, wires, dense pipes and ivy.",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("request", nargs="?", default="Victorian industrial residential background building")
    parser.add_argument("--spec", help="JSON object or @path to JSON")
    parser.add_argument("--mode", choices=("deterministic", "generative"), default="generative")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--family-size", type=int, default=1)
    args = parser.parse_args()
    base = load_spec(args.spec) if args.spec else infer_request(args.request)
    results = []
    for i in range(args.family_size):
        spec = resolve(base, args.mode, args.seed, i)
        check = validate(spec)
        results.append({"variant": i + 1, "resolved_specification": spec, "validation": check, "canonical_image_prompt": compile_prompt(spec)})
    print(json.dumps({"request": args.request, "family_size": args.family_size, "variants": results}, indent=2))
    return 0 if all(item["validation"]["valid"] for item in results) else 2


if __name__ == "__main__":
    sys.exit(main())
