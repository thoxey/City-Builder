# Tasks: Connected First-Town Loop

**Input**: Design documents from `specs/006-connected-first-town-loop/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, and
`contracts/`

## Phase 1: Baseline and setup

- [ ] T001 Freeze unchanged roadless and connected 48-hour traces in `specs/006-connected-first-town-loop/validation/baseline-before.md`.
- [x] T002 [P] Inventory starter T1/T2 and nature Community roles in `specs/006-connected-first-town-loop/validation/starter-content-inventory.md`.
- [x] T003 [P] Record current nuisance/local radii and Attractiveness-to-demand path in `specs/006-connected-first-town-loop/validation/spatial-inventory.md`.
- [x] T004 Add first-town integration coverage under `test/integration/first_town_loop/` and loader-compatible scenario fixtures under `test/scenarios/`.

## Phase 2: Canonical connectivity foundation

**Goal**: One orientation-aware, footprint-complete decision surface.

- [x] T005 [P] Add failing component/access/route unit fixtures in `test/unit/traffic/test_road_network_connectivity.gd`.
- [x] T006 [P] Add multi-cell, radius-boundary, stable-route, and bridge-removal coverage in `test/unit/traffic/`, `test/unit/community/`, and the full-stack scenario.
- [x] T007 Add revisioned components and stable component IDs to `plugins/traffic/road_network_plugin.gd`.
- [x] T008 Add building access projection across every registry footprint cell to `plugins/traffic/road_network_plugin.gd`.
- [x] T009 Add deterministic shortest-route and route-distance queries to `plugins/traffic/road_network_plugin.gd`.
- [x] T010 Expose detached sorted connectivity snapshots and stable reasons from `plugins/traffic/road_network_plugin.gd`.
- [x] T011 Verify road place/demolish/replace/load/clear invalidation in `test/unit/traffic/`.

## Phase 3: User Story 1 — Build a town whose roads matter (P1)

**Independent test**: Roadless work produces zero assignments/output/income;
connecting the same buildings makes all three positive; bridge removal clears
them at the next exact hour.

- [x] T012 [P] Add deterministic work-allocation tests in `test/unit/community/test_reachable_assignments.gd`.
- [x] T013 Add `work_assignment` serialization and detached records to `scripts/community/community_resident.gd`.
- [x] T014 Add cached hourly work-before-activity allocation to `plugins/community/community_plugin.gd` using RoadNetwork routes.
- [x] T015 Add fulfilled workplace/activity and complete assignment projections to `plugins/community/community_plugin.gd`.
- [x] T016 Make `plugins/workplace/workplace_plugin.gd` request only its canonical reachable work count.
- [x] T017 Make `plugins/commercial/commercial_plugin.gd` request only its canonical reachable activity count.
- [x] T018 Add operational state, reason ordering, output, and contribution projections to workplace/commercial owners.
- [x] T019 Add roadless/connected/bridge integration coverage in `test/integration/first_town_loop/test_connected_operation.gd`.

## Phase 4: User Story 2 — Make meaningful opening trade-offs (P1)

**Independent test**: T1 is useful at hour zero, T2 is locked; a connected mixed
town earns T2 and stays cash-positive while additional roads consume cash.

- [x] T020 [P] Add hour-zero choice and T2-boundary tests in `test/unit/demand/test_first_town_balance.gd`.
- [x] T021 Add data-authored starter demand/tier/tax/amenity/road tuning in `data/buildings/`, `data/community/`, and existing balance fields.
- [x] T022 Add one-time road cash spend tracking through `plugins/economy/economy_plugin.gd` and `plugins/playtest/playtest_plugin.gd`.
- [x] T023 Replace raw city-wide nature-driven housing growth in `plugins/demand/demand_plugin.gd` with resident-served Community evidence.
- [x] T024 Add single-purpose and mixed-opening scenario fixtures under `test/scenarios/first_town/`.
- [x] T025 Capture same-seed before/after balance evidence in `specs/006-connected-first-town-loop/validation/balance-comparison.md`.

## Phase 5: User Story 3 — Residents experience connected places (P1)

**Independent test**: Only assigned reachable residents receive work/activity
effects; local and resident effects retain spatial behavior when disconnected.

- [x] T026 [P] Add participant/local/resident scope tests in `test/unit/community/test_connected_effect_scopes.gd`.
- [x] T027 Correct finite positive stacking and add ordinal/evidence fields in `scripts/community/community_effect_evaluator.gd`.
- [x] T028 Extend Community snapshots with full exposure and coverage evidence in `plugins/community/community_plugin.gd`.
- [x] T029 Add resident-serving nature and candidate-home service projections in `plugins/community/community_plugin.gd`.
- [x] T030 Add amenity-supported versus nuisance/isolated seven-day scenario in `test/scenarios/first_town/`.

## Phase 6: User Stories 4–5 — Spatial and Community-shaped towns (P1)

**Independent test**: Admissible compact/spread and served/unserved pairs prove
exposure, coverage, route, road/land cost, cohort reversal, and anti-spam gates.

- [x] T031 [P] Add radius, same-box, duplicate-stack, and cohort-order unit tests in `test/unit/community/`.
- [x] T032 Add explicit Community/cosmetic roles and missing effects to all starter JSON in `data/buildings/`.
- [x] T033 Extend data-editor validation for roles/effect completeness in `tools/data_editor/src/buildings/validation.ts` and tests.
- [x] T034 Add matched pair manifest schema and validator in `scripts/first_town_layout_comparator.gd`.
- [x] T035 Add compact/spread, clustered/distributed, served/unserved, mix/spam, built/nature, blank-sprawl, same-box, cohort, and nature-only fixtures under `test/scenarios/first_town/`.
- [x] T036 Add admissibility and comparison integration tests in `test/integration/first_town_loop/test_layout_comparison.gd`.
- [x] T037 Run bounded exploit search and freeze any dominant exploit as a named regression fixture.

## Phase 7: User Story 6 — Diagnose why a building is idle (P2)

**Independent test**: HUD, place inspection, radial details, and playtest snapshot
agree on access, schedule, operation, contribution, and reason order.

- [x] T038 [P] Add operation parity tests in `test/unit/community_ui/` and full-stack playtest evidence coverage.
- [x] T039 Project canonical operation into `plugins/community/community_inspector.gd` and the existing place-inspection view.
- [x] T040 Add access/coverage preview fields to `plugins/palette/palette_plugin.gd` and radial detail surfaces.
- [x] T041 Remove duplicate Satisfaction presentation from `plugins/hud/hud_plugin.gd` while preserving internal compatibility.
- [x] T042 Extend `plugins/playtest/playtest_plugin.gd` with connectivity, operation, assignment, spatial, land, and spend fields.

## Phase 8: User Story 7 — Evidence-backed comparison (P2)

**Independent test**: Same-seed repeats match, invalid pairs are rejected, and
milestone 005 remains reachable.

- [x] T043 Add balance-relevant first-town state hash fields and normalization in `plugins/playtest/playtest_plugin.gd`.
- [x] T044 Add ten-repeat deterministic replay driver/report under `scripts/` and `specs/006-connected-first-town-loop/validation/`.
- [x] T045 Run every automated matrix row and preserve trace/comparison evidence.
- [x] T046 Run the milestone-005 canonical patron scenario and record the post-balance regression result.
- [x] T047 Run full Godot, TypeScript, content-validation, and performance gates.
- [x] T048 Capture normal-renderer UI and matched-layout screenshots with the frozen camera rule.

## Phase 9: Human and visual release evidence

**These tasks cannot be completed by automated implementation.**

- [ ] T049 Pilot the neutral brief with three non-acceptance players and freeze telemetry, rubric, seeds, camera, and moderator rules.
- [ ] T050 Run two formative waves of four fresh players, changing at most one mechanic family between waves.
- [ ] T051 Complete the frozen 12-player acceptance cohort and preserve anonymised behavior records.
- [ ] T052 Complete independent three-reviewer blind visual scoring and pairwise baseline comparison.
- [ ] T053 Complete four one-hour durability continuations and preserve evidence.
- [ ] T054 Record the release decision against every SC-021–SC-025 threshold.

## Dependencies and execution order

- Phase 2 blocks all runtime stories.
- Phase 3 blocks economy, demand, participant, and explanation integration.
- Phases 4 and 5 can proceed independently after Phase 3.
- Phase 6 requires Community exposure/coverage and balance tuning.
- Phase 7 consumes all canonical projections.
- Phase 8 is the automated release gate; Phase 9 is the separate human gate.
- T049–T054 must remain unchecked until real participants/reviewers complete the
  frozen protocol; automated evidence cannot waive them.

## Phase 10: Mini-goal — Town Hall-rooted cadence rebalance

- [x] T055 Add `FR-042`–`FR-049`, `SC-026`–`SC-032`, rooted-town entities, and explicit meaningful-placement counting rules.
- [x] T056 Author the free 2×2 Town Hall content and first-choice presentation.
- [x] T057 Add canonical Town Hall identity, rooted components, route bands, and candidate-placement decisions to RoadNetwork.
- [x] T058 Gate Builder and Palette through canonical rooted-placement decisions with stable reasons and protected Town Hall demolition.
- [x] T059 Add exact road-distance shop activity/income bonuses and housing Liveability penalties with detached evidence.
- [x] T060 Add boundary, disconnection, atomic rejection, save/load, and UI/playtest parity tests.
- [x] T061 Rebalance starting land, demand consumption/growth, costs, and capacities for three meaningful placements per minute.
- [x] T062 Add deterministic 5/10/20-minute cadence fixtures and a runner that excludes roads, cosmetics, replacements, and rejections.
- [x] T063 Prove 15/30/60 checkpoint counts, 90% success, non-negative cash, useful choice availability, rooted access, operation, and mixed Community outcomes.
- [x] T064 Capture a normal-renderer 60+ structure mid-game town and preserve exact manifest counts.
- [x] T065 Rerun milestone 005/006 regressions, full Godot/TypeScript/content gates, and reconcile evidence.
