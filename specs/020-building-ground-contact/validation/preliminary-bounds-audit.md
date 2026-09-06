# Preliminary Bounds Audit

**Date**: 2026-09-06

**Tool**: Blender 3.4.1 background import with authored `model_scale` applied

**Purpose**: Prioritize the full visual audit. These measurements are not repair
decisions because bounding rectangles cannot reveal holes, rounded bases, transparent
surfaces, or intentional insets.

## Highest-priority candidates

| Building | Declared footprint | Approximate horizontal envelope | Observation |
|---|---:|---:|---|
| Town Hall | 2×2 | 2.000×1.100 | Mandatory; one axis covers only 55% of footprint depth |
| Theatre | 1×1 | 0.645×1.000 | Very narrow on one axis |
| Nightclub | 1×1 | 1.000×0.625 | Very narrow on one axis |
| Postwar Mid-Block | 1×1 | 0.762×1.000 | Narrow on one axis |
| Grass Trees Tall | 1×1 | 1.000×0.822 | Narrow ground envelope |
| Postwar Tower Block | 1×1 | 1.000×0.829 | Narrow on one axis |
| Tower Residence C | 2×2 | 2.000×1.757 | Partial 2×2 depth; visual review required |

## Secondary candidates

The scan also found one-axis coverage around 0.84–0.91 for Building Small A, Building
Small D, Garage, Lumber Mill, Pub near ground level, Restaurant, Pirate Radio, and
Windmill. These require visual review but must not be automatically scaled.

## Apparent full-footprint references

Road variants, pavement, plain grass, Duck Pond, Nature Patch, Crazy Golf, Members Club,
Pipe Factory, Postwar Terrace, and several generic buildings measured close to their
declared footprint envelope. They remain in the visual audit because full bounds do not
prove a complete opaque base.

## Pipeline observations

- Runtime assets under `models/city-builder/` are packaged derivatives.
- Non-road source/remesh assets and transforms live under
  `artifacts/building-concepts/meshy-production/`.
- `tools/wire_city_builder_models.py` can overwrite local building transform edits from
  upstream `game_transform` records.
- Builder clears background grass under all occupied cells and consumes the first
  imported MeshInstance3D mesh.
