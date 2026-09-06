# Tasks: Opening Playtest Polish

**Input**: Design documents from `specs/019-opening-playtest-polish/`

**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`,
`contracts/opening-polish-contracts.md`

**Tests**: Required by the specification and project constitution. Write or update the
focused assertions before each implementation slice and confirm the intended failures.

## Phase 1: Baseline and guardrails

- [x] T001 Record the same-seed pre-change opening trace and current panel/pool fixtures
  in `specs/019-opening-playtest-polish/validation/`.
- [x] T002 [P] Add failing filtered-row fixtures to
  `test/unit/placement_consequences/test_consequence_panel.gd` for unchanged, changed,
  invalid, replacement, failed-access, and uncertain quotes.
- [x] T003 [P] Add failing road/copy/adjacency/legacy-receipt assertions under
  `test/unit/opening_tutorial/` and first-shop handoff assertions under the existing
  opening tutorial integration tests.
- [x] T004 [P] Add failing Dashboard priority fixtures to
  `test/unit/dashboard/test_dashboard.gd` for active tutorial, first-quest handoff, and
  the unarrived 100-demand character fallback.
- [x] T005 [P] Add failing 39/40 and 14/15 boundary assertions to the existing demand,
  UniqueRegistry, StatusBar, and opening-balance tests.
- [x] T006 [P] Add failing catalogue/palette/seeded-selection and legacy grass-load
  assertions under `test/unit/palette/`, `test/unit/player_ui/`, and the relevant save/load
  integration suite.

## Phase 2: User Story 1 - Useful location changes (P1)

**Goal**: The existing location panel shows only changed or actionable consequences.

**Independent Test**: Run T002 fixtures and render unchanged/changed/warning quotes.

- [x] T007 [US1] Filter routine valid access, zero deltas, zero affected evidence, and
  empty reach in `plugins/player_ui/placement_consequences_panel.gd` without changing the
  quote contract.
- [x] T008 [US1] Hide the panel for an empty filtered model and size it from retained rows
  in `plugins/player_ui/placement_consequences_panel.gd`.
- [x] T009 [US1] Verify compact panel behavior at 1280×720 and 1920×1080 and record
  screenshots/notes in `specs/019-opening-playtest-polish/validation/visual-qa.md`.

## Phase 3: User Story 2 - Opening tutorial pacing and handoff (P1)

**Goal**: Ten rooted roads precede housing, any observed adjacent pair can teach the
lesson truthfully, and one rooted shop ends the tutorial before the first quest.

**Independent Test**: Run fresh, legacy, out-of-order, and save/load opening fixtures.

- [x] T010 [US2] Change the incomplete/new-game rooted-road gate and projection to 10
  while honoring existing receipts in
  `plugins/opening_tutorial/opening_tutorial_plugin.gd`.
- [x] T011 [US2] Generalize stable adjacent-home pair selection and persisted evidence in
  `plugins/opening_tutorial/opening_tutorial_plugin.gd` without weakening causal/baseline
  diagnostics.
- [x] T012 [US2] Update B02/B08 purpose text and the matching beat descriptions in
  `plugins/opening_tutorial/opening_tutorial_plugin.gd` and
  `specs/012-first-tutorial-mini-quest/dialogue-workshop.md` to say ten roads and another
  home; do not author unrelated final dialogue.
- [x] T013 [US2] Project OpeningTutorial/first-quest phase into Dashboard's direction
  inputs and apply the priority contract in `plugins/dashboard/dashboard_plugin.gd`.
- [x] T014 [US2] Prove the first rooted shop still writes one completion receipt and
  exactly one handoff, with no 100-demand tutorial projection, in opening tutorial and
  Dashboard tests.

## Phase 4: User Story 3 - Early unique timing (P1)

**Goal**: Postwar Terrace unlocks at lifetime Homes 40 and Pub at lifetime Shops 15.

**Independent Test**: Exercise exact lifetime-demand boundaries independently of current
and fulfilled demand.

- [x] T015 [P] [US3] Set Postwar Terrace `prerequisite_threshold` to 40 in
  `data/buildings/unique/building_postwar_terrace.json`.
- [x] T016 [P] [US3] Set Pub `prerequisite_threshold` to 15 in
  `data/buildings/unique/building_pub.json`.
- [x] T017 [US3] Update data-driven status/progression/opening fixtures that intentionally
  encode the old 25/10 values without hard-coding a second runtime authority.

## Phase 5: User Story 4 - Curated Grass pool (P2)

**Goal**: Plain grass remains save-compatible but cannot be chosen from the Grass pool.

**Independent Test**: Catalogue lookup succeeds, Palette membership excludes grass, and
seeded preview/commit reaches both retained variants but never plain grass.

- [x] T018 [US4] Add `palette_excluded` with a false default to BuildingCatalog summary
  loading in `plugins/building_catalog/building_catalog_plugin.gd` and preserve it through
  the data-editor/manifest schema under `tools/data_editor/src/`.
- [x] T019 [US4] Filter excluded structures before solo/pool entry construction in
  `plugins/palette/palette_plugin.gd`, including the all-members-excluded case.
- [x] T020 [US4] Mark plain grass excluded in `data/buildings/nature/grass.json` while
  retaining the file, stable ID, model, metadata, and pool ID.
- [x] T021 [US4] Update seeded pool expectations and prove old maps containing plain grass
  still load, inspect, and demolish it.

## Phase 6: Cross-feature verification

- [x] T022 Run the focused Godot suites from `quickstart.md` with writable `user://` and
  record results in `specs/019-opening-playtest-polish/validation/test-results.md`.
- [x] T023 Run data-editor/manifest validation and audit the exported content for the two
  thresholds and `palette_excluded` field.
- [x] T024 Run the same-seed post-change opening scenario, compare it with T001, and record
  only the declared intentional differences in
  `specs/019-opening-playtest-polish/validation/balance-before-after.md`.
- [x] T025 Run the full Godot suite, deterministic replay, and one full automated
  city-building scenario; record hashes, failures, and environment.
- [x] T026 Complete normal-renderer playthrough review at 1280×720 and 1920×1080,
  including panel footprint, ten-road pacing, adjacency wording, first-shop handoff, and
  grass variants.
- [x] T027 Re-check the four explicit exclusions and confirm no model asset, world-space
  capsule, broad progression/service, or bottom-bar redesign file entered the diff.

## Dependencies and execution order

- T001–T006 establish the baseline and failing assertions.
- T007–T009, T010–T014, T015–T017, and T018–T021 are independently implementable after
  their corresponding baseline test.
- T013 depends on the existing OpeningTutorial projection and first-quest seam, but not on
  T010–T012's new values.
- T019 depends on T018's summary field; T020 may be authored in parallel but remains
  ineffective until both land.
- T022–T027 follow all selected implementation slices.

## Implementation strategy

Deliver the P1 slices first: panel filtering, tutorial pacing/handoff, then threshold
tuning. Validate each independently. The Grass pool is a separate P2 slice and can be
deferred without weakening the P1 behavior. Stop before any excluded feature expands the
pass.
