# Research: Building Ground Contact

## Finding 1: Builder deliberately removes the grass layer beneath every placement

`Builder._commit_build` and `_apply_map` clear `ground_gridmap` for all occupied footprint
cells. Demolition restores grass. A building whose imported mesh does not contain a
complete ground surface therefore exposes an empty or visibly unfinished footprint.

**Decision**: Add an authored ground-treatment policy and centralize GroundMap updates
across commit/load/replacement/demolition/reset.

## Finding 2: Town Hall cannot be repaired safely by uniform scale

The Town Hall declares a 2×2 footprint. A Blender 3.4.1 import scan, after applying its
authored scale, found an approximate near-ground/overall horizontal envelope of 2.0×1.1.
Scaling the short axis to 2.0 would expand the already full axis to roughly 3.6 cells.

**Decision**: The Town Hall's default repair is a full 2×2 grass underlay. Scaling is not
an acceptable primary fix unless later source inspection disproves the preliminary
measurement.

## Finding 3: Bounds identify candidates, not holes

The same scan found several narrow envelopes, including approximately:

| Building | Footprint | Imported horizontal envelope |
|---|---:|---:|
| Town Hall | 2×2 | 2.000×1.100 |
| Theatre | 1×1 | 0.645×1.000 |
| Nightclub | 1×1 | 1.000×0.625 |
| Postwar Mid-Block | 1×1 | 0.762×1.000 |
| Postwar Tower Block | 1×1 | 1.000×0.829 |
| Grass Trees Tall | 1×1 | 1.000×0.822 |
| Tower Residence C | 2×2 | 2.000×1.757 |

Other candidates sit around 0.84–0.91 on one axis. However, roofs/props can determine an
overall bound while the actual ground plane remains smaller, and an intentional inset can
still look correct over grass.

**Decision**: Render every live model with a visible footprint guide. Programmatic bounds
prioritize review and catch gross regressions but cannot approve ground contact alone.

## Finding 4: Runtime GLBs are generated derivatives

`tools/package_city_builder_models.py` reads remeshed GLBs from
`artifacts/building-concepts/meshy-production/runtime-v1/models`, repackages embedded
textures, and writes `models/city-builder`. `tools/wire_city_builder_models.py` rewrites
building transform fields from the upstream `runtime-v1/results.json` records.

**Decision**: Transform changes belong in the upstream game-transform record. Any mesh
repair needs an upstream source/recipe integrated before packaging. Runtime-only GLB or
building-JSON tweaks are not reproducible.

## Finding 5: Builder consumes the first imported mesh

`Builder.get_mesh` walks a PackedScene and returns the first `MeshInstance3D` mesh. A
Blender repair exported as a separate foundation object may be ignored.

**Decision**: Any unavoidable mesh-level foundation must export within the first runtime
mesh (multiple material surfaces are acceptable) or deliberately revise and test the
extraction contract. Changing extraction is not the default plan.

## Finding 6: The existing grass asset is the right underlay source

The packaging script creates a one-cell grass GLB with the existing British grass
albedo, normal, and packed material textures. GroundMap already uses this asset for empty
terrain.

**Decision**: Reuse the grass mesh/material through a second depth-biased MeshLibrary item
rather than create new art or duplicate textures per building.

## Alternatives rejected

- Keep grass beneath every structure: risks grass bleeding through roads, pavement,
  water, and full hardstanding surfaces.
- Uniformly enlarge every narrow asset: distorts correctly sized architecture and makes
  non-square models overflow neighbouring tiles.
- Add a grass mesh to every runtime GLB: duplicates geometry/material setup, increases
  binary churn, and can be discarded by the first-mesh loader.
- Edit `models/city-builder/*.glb` directly: regeneration would overwrite the work.
- Change logical footprints to fit visuals: alters gameplay, adjacency, access, and save
  behavior outside this visual repair.
