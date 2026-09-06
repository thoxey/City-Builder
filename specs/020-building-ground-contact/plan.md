# Implementation Plan: Building Ground Contact

**Branch**: `020-building-ground-contact` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/020-building-ground-contact/spec.md`

## Summary

Create a reproducible catalogue-wide ground-contact audit, then repair each confirmed
failure using the smallest safe treatment. Add a data-driven `ground_treatment` projection
and a depth-biased grass underlay item to Builder for incomplete bases, correct upstream
game transforms for uniformly undersized/misaligned models, and use recorded Blender
source repairs only as a last resort. The Town Hall is the first mandatory slice.

## Technical Context

**Language/Version**: GDScript 4.x, Python 3 model tooling, optional Blender Python on
Blender 3.4.1, JSON-authored building/model metadata

**Primary Dependencies**: Godot 4.6.x, BuildingCatalog, Builder/GridMap/MeshLibrary,
existing grass GLB, model production and packaging scripts

**Storage**: Building JSON plus upstream model-production manifests/assets under
`artifacts/building-concepts/meshy-production/`; no new save fields

**Testing**: GUT unit/integration tests, headless model import audit, deterministic
placement/save-load replay, Blender/package integrity checks, normal-renderer contact
sheets

**Target Platform**: Local desktop game at supported gameplay camera/zoom and 1280×720,
1920×1080 rendering

**Project Type**: Godot plugin-oriented desktop game with generated GLB assets

**Performance Goals**: No per-frame repair work; no more than 5% median regression in
reference map load, placement, or steady rendered frame time

**Constraints**: Stable IDs/paths/footprints, first-mesh runtime contract, embedded
materials/textures, deterministic lifecycle, concurrent feature 019 edits

**Scale/Scope**: All live BuildingCatalog entries audited; Town Hall plus every confirmed
failure repaired; no architectural redesign or new content

## Constitution Check

### Pre-design gate

- **One Gameplay Truth — PASS**: Footprints and occupancy remain Builder-owned. Ground
  treatment is derived visual state applied from the same commit/load lifecycle.
- **Deterministic, Controllable Simulation — PASS**: Repairs do not enter simulation or
  gameplay hashes. Audit/export inputs and decisions use stable building IDs.
- **Observable and Explainable State — PASS**: Every catalogue item receives an audit row
  and every changed asset has pre/post visual and machine-readable evidence.
- **Data-Driven Balance, Narrative Separation — PASS**: Per-building treatment and
  transforms are authored data; no balance or narrative value changes.
- **Small Interfaces and Layered Verification — PASS**: One catalogue field and one
  Builder ground-sync helper cover every lifecycle instead of adding a parallel placement
  path. Visual evidence supplements state/import assertions.

### Post-design gate

PASS. The feature introduces no gameplay authority or material architectural exception.

## Project Structure

### Documentation (this feature)

```text
specs/020-building-ground-contact/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── ground-contact-contract.md
├── checklists/
│   └── requirements.md
├── validation/
│   └── preliminary-bounds-audit.md
└── tasks.md
```

### Source and tooling (repository root)

```text
data/buildings/**/*.json
plugins/building_catalog/building_catalog_plugin.gd
scripts/builder.gd
scripts/capture_model_ground_contact_validation.gd
tools/package_city_builder_models.py
tools/wire_city_builder_models.py
tools/model_ground_contact/
artifacts/building-concepts/meshy-production/
models/city-builder/*.glb
test/unit/building_catalog/
test/unit/builder/
test/integration/builder/
test/integration/save/
```

**Structure Decision**: Extend the existing catalogue, Builder ground layer, model
pipeline, and test layout. Add a focused model-audit tool directory only if the existing
packaging helpers cannot host the reusable checks cleanly.

## Design

### 1. Freeze an audit, not a guessed repair list

Enumerate BuildingCatalog definitions and capture projected overall/near-ground bounds,
footprints, transform sources, model hashes, materials, and first-mesh readability. Render
each asset against a high-contrast footprint guide at four rotations. Record one explicit
decision per stable building ID: `pass`, `grass_underlay`, `transform`, or `mesh_repair`.

The preliminary scan makes Town Hall, Theatre, Nightclub, Postwar Mid-Block, Postwar Tower
Block, Grass Trees Tall, and other narrow candidates mandatory visual-review items, but it
does not classify them automatically.

### 2. Add one authored ground-treatment seam

Add `ground_treatment` to building definitions and BuildingCatalog summaries:

- `replace` (default): current behavior; clear GroundMap beneath occupied cells.
- `grass_underlay`: use the existing grass mesh through a separate underlay MeshLibrary
  item with one tested negative vertical bias.

Centralize commit/load/replacement/demolition/reset behavior in a Builder helper that sets
the derived ground cell from the current occupant's authored treatment. Ground treatment
never enters save records because stable building IDs already determine it.

### 3. Keep transforms reproducible upstream

For audit rows classified `transform`, adjust `game_transform` in the existing
`runtime-v1/results.json` source (or its owning generation input), regenerate building
JSON with `tools/wire_city_builder_models.py`, and verify the diff is restricted to the
intended model fields. Do not scale a non-square asset when one axis already reaches its
footprint; use an underlay instead.

### 4. Make Blender a last-resort pipeline step

If a confirmed defect cannot be solved by underlay or transform, add a stable repair
manifest/recipe upstream of `models/city-builder/`. Use Blender CLI or an available MCP
to apply the same operation, preserve materials/textures and axis/origin, join required
foundation geometry into the first runtime mesh, and then run the existing packaging
script. Never hand-edit only the packaged derivative.

### 5. Verify lifecycle, appearance, and cost

Unit-test catalogue parsing and Builder ground-cell policy. Integration-test commit,
rotation, replacement, demolition, clear, and load. Re-run model import/package checks,
full gameplay tests, deterministic hashes, reference-town timings, and the pre/post visual
contact sheet. No asset is complete without a human-readable before/after verdict.

## Test Seams

- Pure parsing/default tests for `ground_treatment`.
- Builder ground-sync tests over `replace` and `grass_underlay` for every lifecycle.
- Headless GLB import checks for first mesh, finite bounds, materials, textures, path, and
  stable footprint/metadata.
- Upstream transform/package regeneration diff and hash report.
- Full deterministic gameplay replay proving unchanged normalized simulation state.
- Normal-renderer four-rotation contact sheet for each audit failure.
- Reference-town map load, placement, steady frame, draw/instance comparison.

## Risks and Mitigations

- **Z-fighting**: Use a separate underlay item with one measured negative height bias and
  validate at camera extremes.
- **Grass bleed through hard surfaces**: Keep `replace` as the default and opt assets into
  underlay only after visual review.
- **Pipeline overwrite**: Change upstream transform/repair inputs and prove regeneration;
  never rely on runtime-only binary edits.
- **First-mesh loss**: Import/export validation asserts the repaired visible mesh remains
  the first mesh Builder consumes.
- **Concurrent feature 019 work**: Preserve its catalogue/data fields and avoid changing
  `.specify/feature.json` while that pass is active.

## Complexity Tracking

No constitution violation is required. Any asset that unexpectedly needs architectural
remodelling rather than ground-contact repair must be removed from this feature and
specified separately.
