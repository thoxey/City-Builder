# Feature Specification: Building Ground Contact

**Feature Branch**: `020-building-ground-contact`

**Created**: 2026-09-06

**Status**: Draft

**Input**: Audit and repair the live building models whose bases do not fill their
declared tiles. Add grass beneath incomplete bases, adjust authored scale/offset where an
entire asset is genuinely undersized, and treat the Town Hall as the highest-priority
failure.

## Scope and boundaries

This feature makes every currently live placeable model sit convincingly on its declared
footprint. It audits the complete BuildingCatalog, assigns an explicit repair decision to
every failing asset, and applies the smallest safe treatment:

1. retain a footprint-matched grass underlay when the building is correctly sized but its
   decorative base is incomplete;
2. adjust the existing authored scale/offset when the whole asset is uniformly undersized
   or misaligned; or
3. repair source geometry through the existing model-production pipeline only when an
   underlay or transform cannot produce a correct result.

The Town Hall must be fixed even if no other asset fails the final visual audit.

This feature does not change building footprints, placement rules, costs, demand,
progression, simulation effects, categories, UI, camera behavior, or create new buildings.
It does not remodel architecture, repaint textures, add decorative props, or optimize the
general rendering pipeline. The plain-grass Palette decision belongs to feature 019 and
is independent of using grass as a non-selectable foundation material here.

## User Scenarios & Testing

### User Story 1 - Buildings Meet the Ground Cleanly (Priority: P1)

As a player, I can place and rotate any live building without seeing a void, clipped
ground, or obviously unfinished tile beneath or around its base.

**Why this priority**: Broken ground contact makes finished models look temporary and is
most conspicuous around the Town Hall, the opening's visual anchor.

**Independent Test**: Render every placeable BuildingCatalog entry on a contrasting
checkerboard at normal play zoom in all four rotations, with its declared footprint
outlined, and compare the result with the approved audit decision.

**Acceptance Scenarios**:

1. **Given** the Town Hall occupies a 2×2 footprint, **When** it is previewed, committed,
   rotated, loaded, or revealed after demolition of a neighbour, **Then** all four occupied
   cells have continuous intentional ground treatment to their outer edges.
2. **Given** a correctly sized building has an incomplete decorative base, **When** it is
   placed, **Then** matching grass fills the exposed footprint without covering roads,
   pavement, water, hardstanding, or architectural details.
3. **Given** an asset is uniformly undersized or off-centre, **When** its authored
   transform is corrected, **Then** it reads at the intended tile scale without changing
   its logical footprint or visibly colliding with ordinary neighbouring placements.
4. **Given** any repaired model is rotated through 0°, 90°, 180°, and 270°, **When** viewed
   at normal minimum and maximum gameplay zoom, **Then** no rotation exposes an untreated
   strip or causes its base to cross an unintended footprint edge.

---

### User Story 2 - Ground Treatment Survives Every Placement Lifecycle (Priority: P1)

As a player, I see the same repaired ground contact during preview, after placement,
after save/load, after replacement, and after demolition.

**Why this priority**: A visual fix that only works on initial placement will regress in
ordinary city editing and saved games.

**Independent Test**: For each ground-treatment mode, exercise preview, commit, rotation,
replacement, demolition, save, clear, and load while asserting both logical occupancy and
the derived GroundMap cells.

**Acceptance Scenarios**:

1. **Given** a building authored for grass underlay, **When** it is committed or rebuilt
   from a save, **Then** every occupied footprint cell receives the underlay treatment.
2. **Given** a road, pavement, water feature, or other asset authored to replace ground,
   **When** it is committed or loaded, **Then** grass does not bleed through its surface.
3. **Given** either treatment is demolished or replaced, **When** the transaction
   completes, **Then** the resulting GroundMap matches the new occupant or restores normal
   grass exactly once.
4. **Given** an old save has no ground-treatment field, **When** it loads against current
   catalogue data, **Then** the current authored treatment is derived from the stable
   building ID; no save migration or duplicate visual state is required.

---

### User Story 3 - Model Repairs Remain Reproducible (Priority: P2)

As a developer, I can identify why each asset was changed and regenerate every repaired
runtime GLB or transform without relying on an opaque one-off manual edit.

**Why this priority**: Runtime models are packaged derivatives. Direct binary edits would
be silently lost the next time the model pipeline runs.

**Independent Test**: Start from the declared upstream model inputs, run the documented
repair/package commands, and compare repair manifests, model identities, transforms,
materials, texture references, mesh readability, and generated runtime hashes.

**Acceptance Scenarios**:

1. **Given** the audit is complete, **When** its manifest is reviewed, **Then** every live
   placeable building has one status: `pass`, `grass_underlay`, `transform`, or
   `mesh_repair`, plus evidence and rationale.
2. **Given** a transform-only repair, **When** model wiring is regenerated, **Then** the
   value comes from the model-production transform source and is not overwritten by the
   existing wiring script.
3. **Given** a mesh repair is unavoidable, **When** the runtime model is regenerated,
   **Then** the repair is represented by a checked-in source/recipe upstream of
   `models/city-builder/`, preserves the original materials, and exports a mesh readable
   by Builder's current first-mesh contract.
4. **Given** no Blender MCP connection is available, **When** a mesh repair is required,
   **Then** the same documented result can be produced with the installed Blender CLI;
   the feature is not blocked on a particular control surface.

### Edge Cases

- A model's overall bounding box fills a tile but its lowest surface has holes, rounded
  corners, or an intentional path cut-out; bounds are evidence, not an automatic pass.
- Roofs, trees, blades, signs, and other elevated details overhang a footprint while the
  ground base remains inset; ground coverage is assessed near ground height.
- A non-square model cannot be safely fixed with uniform scale because one axis already
  fills the footprint, as with the preliminary Town Hall measurement.
- A two-cell or 2×2 footprint is rotated and its visual centre must continue to match
  Builder's footprint auto-centring.
- Grass underlay shares nearly the same plane as an imported base and creates z-fighting;
  the underlay uses one measured depth bias rather than per-frame offsets.
- Grass beneath transparent, cut-out, or water surfaces becomes visible where it should
  not; those assets retain ground replacement or require a mesh repair.
- An asset already uses an intentional full hardstanding slab; adding grass would be a
  regression even if the building itself is narrow.
- A source GLB contains several mesh objects, while Builder currently consumes the first
  MeshInstance3D only; any repaired export must preserve the runtime-readable contract.
- A model-packaging rerun changes embedded texture encoding or binary hashes without a
  visual geometry change; validation separates expected packaging drift from repairs.
- Feature 019 is implemented concurrently and edits building JSON or catalogue loading;
  this feature must merge its authored fields without overwriting those changes.

## Requirements

### Functional Requirements

- **FR-001**: The feature MUST inventory every building definition loaded by the live
  BuildingCatalog and record an explicit ground-contact decision for each.
- **FR-002**: The audit MUST combine programmatic footprint/bounds evidence with
  normal-renderer review; bounds alone MUST NOT approve an asset.
- **FR-003**: `building_town_hall` MUST receive a passing repair for its full 2×2 declared
  footprint and is the first implementation/visual checkpoint.
- **FR-004**: The repair decision order MUST be grass underlay, then authored transform,
  then source mesh repair, choosing the least invasive treatment that satisfies the
  visual contract.
- **FR-005**: A grass underlay MUST cover exactly the canonical occupied footprint cells
  and use the existing packaged British grass material/mesh family.
- **FR-006**: Underlay depth bias MUST be stable, deterministic, and sufficient to prevent
  z-fighting at supported cameras without creating a visible floating gap at tile edges.
- **FR-007**: Assets that replace the ground, including road and pavement surfaces, MUST
  continue to clear grass unless the audit explicitly proves another treatment.
- **FR-008**: Ground treatment MUST be authored per building with a backward-compatible
  default and projected through BuildingCatalog; Builder MUST NOT hard-code building IDs.
- **FR-009**: Builder MUST apply the same authored ground treatment on commit and map load,
  and MUST reconcile it correctly on replacement, demolition, clear, and reset.
- **FR-010**: Ground treatment MUST remain derived presentation state and MUST NOT alter
  `GameState.cell_to_building`, building registry records, footprints, affordability,
  access, simulation, or deterministic gameplay hashes.
- **FR-011**: Transform repairs MUST use existing `model_scale`, `model_offset`, and
  `model_rotation_y` fields and MUST preserve footprint auto-centring in preview and
  MeshLibrary placement.
- **FR-012**: Transform source values MUST be updated upstream in the existing model
  production results/manifest so `tools/wire_city_builder_models.py` reproduces them.
- **FR-013**: Uniform scale MUST NOT be used when it fixes one ground axis by materially
  overflowing another or distorts a model whose architecture is already correctly sized.
- **FR-014**: A mesh repair MUST be used only when the audit demonstrates that underlay
  and transform treatments cannot satisfy ground contact without a visible regression.
- **FR-015**: Mesh repairs MUST be stored or generated upstream of runtime derivatives and
  integrated with `tools/package_city_builder_models.py`; direct unrecorded edits to
  `models/city-builder/*.glb` are forbidden.
- **FR-016**: Any repaired runtime GLB MUST retain stable building/model paths, readable
  geometry, required materials and textures, correct axes/origin, and compatibility with
  Builder's current mesh extraction.
- **FR-017**: The repair pass MUST NOT change logical footprints or any balance, category,
  progression, simulation, UI, or narrative data.
- **FR-018**: Preview and committed placement MUST remain visually aligned for every
  repaired asset and every supported rotation.
- **FR-019**: Automated lifecycle tests MUST cover both ground-treatment modes across
  commit, load, replacement, demolition, clear, and reset.
- **FR-020**: Model validation MUST reject missing/non-finite meshes, empty first-mesh
  exports, lost materials/textures, unintended footprint changes, and unrecorded runtime
  binary edits.
- **FR-021**: Visual QA MUST include a before/after contact sheet for every failing asset
  at normal play zoom, plus dedicated close and wide shots of the Town Hall at 0° and 90°.
- **FR-022**: Performance verification MUST show no material regression in normal map
  load, placement, frame time, or draw-call/visible-instance behavior for the reference
  town.

### Key Entities

- **Model Ground-Contact Audit Row**: Stable building ID, model path, footprint, projected
  bounds, four-rotation visual result, chosen treatment, rationale, evidence paths, and
  approval status.
- **Ground Treatment**: Authored per-building presentation policy selecting normal ground
  replacement or a footprint grass underlay.
- **Transform Repair**: Reproducible scale/offset/rotation change stored in the existing
  upstream game-transform record.
- **Mesh Repair Recipe**: Last-resort Blender-compatible source or deterministic operation
  that produces a packageable, first-mesh-compatible GLB.
- **Visual Contact Sheet**: Repeatable pre/post rendered evidence with the declared
  footprint and tile edges visible.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% of live BuildingCatalog entries have a completed audit row and 100% of
  rows marked failing before implementation pass the post-change visual review.
- **SC-002**: The Town Hall shows continuous intentional ground across all four cells at
  0° and 90°, with no exposed void, grass bleed over hard surfaces, z-fighting, or change
  to its 2×2 logical footprint.
- **SC-003**: Every repaired asset passes preview/commit comparison at four rotations and
  at normal minimum and maximum gameplay zoom.
- **SC-004**: Commit, load, replacement, demolition, clear, and reset tests produce the
  expected GroundMap item for every occupied/restored cell in both treatment modes.
- **SC-005**: Re-running the declared transform/mesh packaging path reproduces the repair
  manifest and runtime asset set with zero missing models, materials, or texture bindings.
- **SC-006**: Stable building IDs, model paths, footprints, costs, demand, unlocks,
  simulation metadata, and normalized gameplay hashes are unchanged by the pass.
- **SC-007**: A reference-town comparison shows no greater than 5% regression in median
  map-load time, placement time, or steady rendered frame time, with environment and raw
  measurements recorded.
- **SC-008**: Focused Builder/catalog/model tests, full Godot tests, save/load replay, and
  normal-renderer visual QA pass with no unclassified ground-contact defect remaining.

## Assumptions

- The user's “grass tiles underneath” means a visual grass underlay derived from current
  building data, not a new player-selectable grass building or a logical occupant.
- The underlay can reuse the existing packaged grass mesh/material with a small stable
  depth bias; no new texture art is expected.
- The preliminary bounds scan identifies candidates but does not decide final failures.
- Existing runtime GLBs are derivatives of the pipeline under
  `artifacts/building-concepts/meshy-production/`; reproducible fixes belong upstream or
  in the packaging path.
- Blender CLI is installed and sufficient for any unavoidable mesh repair. A future
  Blender MCP connection may improve interaction but is not a dependency.
