# Tasks: Building Ground Contact

**Input**: Design documents from `specs/020-building-ground-contact/`

**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`,
`contracts/ground-contact-contract.md`

**Tests**: Required. Ground-contact correctness is primarily visual but must also have
catalogue, lifecycle, import, determinism, and performance assertions.

## Phase 1: Freeze the audit and baselines

- [x] T001 Inventory every live BuildingCatalog definition, stable ID, model path,
  footprint, transform source, source/runtime hash, first mesh, materials, and textures in
  `specs/020-building-ground-contact/validation/model-audit.json`.
- [x] T002 Create `scripts/capture_model_ground_contact_validation.gd` to render every
  placeable model at four rotations over a contrasting canonical footprint guide.
- [x] T003 Record pre-change contact sheets and one explicit `pass`, `grass_underlay`,
  `transform`, or `mesh_repair` decision per model in
  `specs/020-building-ground-contact/validation/model-audit.md`.
- [x] T004 Freeze Builder lifecycle state, full deterministic gameplay hashes, model
  import results, and reference-town load/placement/frame timings before implementation.
- [x] T005 [P] Add failing BuildingCatalog parsing/default/invalid-value tests for
  `ground_treatment` under `test/unit/building_catalog/`.
- [x] T006 [P] Add failing Builder ground-cell lifecycle tests for `replace` and
  `grass_underlay` under `test/unit/builder/` and `test/integration/builder/`.

## Phase 2: User Story 1 - Town Hall repair checkpoint (P1)

**Goal**: The Town Hall's full 2×2 footprint has clean ground contact.

**Independent Test**: Preview, place, rotate, load, replace beside, and demolish the Town
Hall while reviewing dedicated close/town-context captures.

- [x] T007 [US1] Add normalized `ground_treatment` loading/projection in
  `plugins/building_catalog/building_catalog_plugin.gd` and preserve concurrent feature
  019 fields.
- [x] T008 [US1] Add a depth-biased underlay grass MeshLibrary item and one centralized
  occupant-to-ground sync helper in `scripts/builder.gd`.
- [x] T009 [US1] Route commit, load, replacement, demolition, clear, and reset through the
  helper in `scripts/builder.gd` without changing occupancy or save state.
- [x] T010 [US1] Author `building_town_hall` for `grass_underlay` in
  `data/buildings/unique/building_town_hall.json`.
- [x] T011 [US1] Complete Town Hall tests and 0°/90° before-after visual checkpoint; tune
  one underlay depth bias until no z-fighting, bleed, or floating seam remains.

## Phase 3: User Story 1 - Remaining audited repairs (P1)

**Goal**: Every audit failure receives its approved least-invasive repair.

**Independent Test**: Re-run the catalogue-wide four-rotation contact sheet and approve
every formerly failing row.

- [x] T012 [US1] Apply `grass_underlay` only to audit rows classified for incomplete
  bases in their existing `data/buildings/**/*.json` definitions.
- [x] T013 [US1] **Not applicable — the frozen audit has zero `transform` rows.** Apply approved transform repairs in the upstream game-transform records
  under `artifacts/building-concepts/meshy-production/runtime-v1/` and regenerate only the
  intended model fields with `tools/wire_city_builder_models.py`.
- [x] T014 [US1] Verify repaired models remain aligned with canonical footprint
  auto-centring in preview and all four committed rotations.
- [x] T015 [US1] Re-run contact sheets and record per-asset before/after verdicts; any
  remaining failure proceeds to Phase 5 rather than receiving an ad hoc scale.

## Phase 4: User Story 2 - Lifecycle parity (P1)

**Goal**: Derived ground treatment is correct and idempotent across all map mutations.

**Independent Test**: Run the lifecycle matrix for both treatment modes and compare
GroundMap plus unchanged logical state.

- [x] T016 [US2] Complete commit/load/replacement/demolition/clear/reset tests, including
  multi-cell and rotated footprints.
- [x] T017 [US2] Add legacy-save coverage proving ground treatment derives from current
  catalogue data without a save migration.
- [x] T018 [US2] Add road, pavement, water/cut-out, and hardstanding regression fixtures
  proving grass does not bleed through `replace` assets.
- [x] T019 [US2] Compare preview, commit, and post-load transforms for every repaired
  asset and fail on visible alignment drift.

## Phase 5: User Story 3 - Reproducible mesh repairs, only if required (P2)

**Goal**: Any defect unsolved by underlay/transform has a reproducible upstream Blender
repair instead of a one-off runtime binary edit.

**Independent Test**: Regenerate repaired GLBs from expected source hashes and validate
first mesh, materials, textures, transforms, and visual evidence.

- [x] T020 [US3] **Not applicable — the frozen and final audits have zero `mesh_repair` rows.** If the audit contains `mesh_repair`, create a checked-in repair manifest
  and deterministic Blender-compatible script/source under
  `tools/model_ground_contact/` and the established upstream artifact area.
- [x] T021 [US3] **Not applicable — no repaired upstream output exists.** Integrate repaired upstream outputs with
  `tools/package_city_builder_models.py` without changing stable runtime paths.
- [x] T022 [US3] **Not applicable to a repair; the read-only audit verifier checks all unchanged GLBs.** Add source-hash guards and GLB import/material/texture/first-mesh
  validation for every mesh repair.
- [x] T023 [US3] If no audit row requires mesh repair, record that Phase 5 is not
  applicable with the underlay/transform evidence that avoided it.

## Phase 6: Release verification

- [x] T024 Run focused catalogue/Builder/save tests with writable `user://` and record
  results in `specs/020-building-ground-contact/validation/test-results.md`.
- [x] T025 Re-run the full Godot suite and deterministic city replay; verify logical
  snapshots, footprints, balance metadata, and hashes are unchanged.
- [x] T026 Regenerate the final model audit and confirm every live catalogue entry has a
  passing decision and valid first mesh/material/texture state.
- [x] T027 Record Town Hall and all repaired-asset normal-renderer evidence at 1280×720
  and 1920×1080, four rotations, and camera zoom extremes.
- [x] T028 Measure reference-town load, placement, frame time, and visible/draw instance
  behavior; investigate any median regression greater than 5%.
- [x] T029 Audit the final diff for concurrent feature 019 preservation and confirm no
  footprint, balance, progression, simulation, UI, narrative, or unrelated model change.

## Dependencies and execution order

- T001–T006 freeze evidence and failing contracts before any repair.
- T007–T011 are the mandatory Town Hall checkpoint and establish the reusable underlay
  path.
- T012–T015 apply only decisions approved by the audit.
- T016–T019 validate all lifecycle paths after the reusable seam exists.
- T020–T023 are conditional and run only for remaining `mesh_repair` rows.
- T024–T029 follow all applicable repairs.

## Implementation strategy

Finish and visually approve the Town Hall slice first. Then batch the remaining explicit
underlay decisions, apply transform decisions one at a time from upstream data, and
regenerate evidence after each class. Do not begin Blender mesh repair until the audit
records why both simpler treatments fail.
