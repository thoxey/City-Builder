# Tasks: Traffic Flow Coherence

**Input**: Design artifacts in `specs/010-traffic-flow-coherence/`

**Tests**: Required. Every behaviour phase begins with a failing unit, contract, or
integration test and records the red/green evidence before its implementation task is
checked complete.

**Authority boundary**: Community remains authoritative for civilian assignments and
outcomes. RoadNetwork remains authoritative for access, stops, canonical routes,
distance, and route revision. CarManager and People remain transient presentation
consumers. No public playtest command or runtime art/audio change is permitted.

## Phase 1: Baseline and test seams

**Purpose**: Freeze the pre-change state and establish deterministic fixture seams.

- [x] T001 Record baseline focused-suite results and the tracked runtime-media digest in `specs/010-traffic-flow-coherence/validation/baseline.md`
- [x] T002 [P] Extend deterministic CarManager road/pool fixtures in `test/unit/traffic/car_manager_test_fixtures.gd`
- [x] T003 [P] Add reusable fixed-step traffic-flow fixtures in `test/integration/traffic_flow/traffic_flow_fixtures.gd`

**Checkpoint**: Baseline and isolated deterministic stepping are reproducible.

---

## Phase 2: Pending departure admission (User Story 1, P1)

**Goal**: Valid resolved car requests become non-physical FIFO pending departures and
are admitted only when both origin capacity and render-pool capacity exist.

**Independent Test**: Submit four same-origin requests, step once, observe two active
and two pending, then release one claim and observe exactly one FIFO admission.

### Tests first

- [x] T004 [US1] Add failing pending-first, two-active/two-pending, FIFO, direction-aware origin, and pool/road waiting-reason tests in `test/unit/traffic/test_car_manager_admission.gd`
- [x] T005 [US1] Add failing deferred `journey_started`, visible waiting resident, cancellation, and stale-signal tests in `test/unit/people/test_people_car_lifecycle.gd`

### Implementation

- [x] T006 [US1] Add transient pending/admission fields to `plugins/traffic/car_slot.gd` and `plugins/traffic/car_manager_plugin.gd`
- [x] T007 [US1] Implement stable pending request validation, identity allocation, per-origin FIFO admission, render-slot allocation, and `journey_started` emission in `plugins/traffic/car_manager_plugin.gd`
- [x] T008 [US1] Implement pending-aware People handoff, visibility, cancellation, and lifecycle reconciliation in `plugins/people/people_plugin.gd` and `plugins/people/person_slot.gd`
- [x] T009 [US1] Run focused traffic and People tests, record red/green evidence in `specs/010-traffic-flow-coherence/validation/admission.md`, then check the phase contract

**Checkpoint**: Pending requests are non-physical, FIFO, cancellable, and never hide a
resident before deferred admission.

---

## Phase 3: Two-phase capacity and bounded queues (User Story 2, P1)

**Goal**: Visible cars hold at most two total claims per tile, reserve the next tile
before crossing, retain the current claim during crossing, and wait forever on their
canonical route while it remains valid.

**Independent Test**: Fill a straight route and sample starts, crossings, blockage,
opposing travel, turns, cancellation, and a long gridlock at fixed deltas.

### Tests first

- [x] T010 [US2] Add failing total-capacity, opposing-direction, two-phase-claim, bounded-position, stable-promotion, and large-delta tests in `test/unit/traffic/test_car_manager_capacity.gd`
- [x] T011 [US2] Add failing canonical-route gridlock, no-reroute/no-completion, and targeted invalidation tests in `test/unit/traffic/test_car_manager_canonical_waiting.gd`
- [x] T012 [US2] Add failing same-origin and backed-up-route contract tests in `test/integration/traffic_flow/test_vehicle_flow.gd`

### Implementation

- [x] T013 [US2] Replace directional conflict capacity with hard two-total tile claims and deterministic claim ordering in `plugins/traffic/car_manager_plugin.gd`
- [x] T014 [US2] Implement current/next two-phase crossing, one-boundary-per-step movement, stable release/promotion, and canonical-route waiting in `plugins/traffic/car_manager_plugin.gd` and `plugins/traffic/car_slot.gd`
- [x] T015 [US2] Implement bounded direction-aware lane and front/rear display anchors with turn interpolation in `plugins/traffic/car_manager_plugin.gd`
- [x] T016 [US2] Run focused vehicle unit/integration tests and record red/green evidence in `specs/010-traffic-flow-coherence/validation/vehicle-flow.md`

**Checkpoint**: Cars queue on-road without overlap, capacity bypass, congestion reroute,
silent completion, teleport, or route mutation.

---

## Phase 4: Pedestrian separation (User Story 3, P2)

**Goal**: Walkers sharing a directed segment receive deterministic, bounded,
presentation-only lateral/following separation.

**Independent Test**: Replay grouped walkers at matching fixed steps and compare order,
offsets, transforms, assignments, destinations, and outcomes.

### Tests first

- [x] T017 [US3] Add failing deterministic bounded-offset, following-gap, opposite-direction, and no-authority-mutation tests in `test/unit/people/test_people_spacing.gd`
- [x] T018 [US3] Add failing grouped-walker replay contract test in `test/integration/traffic_flow/test_pedestrian_flow.gd`

### Implementation

- [x] T019 [US3] Add transient display/segment spacing fields in `plugins/people/person_slot.gd`
- [x] T020 [US3] Implement stable directed-segment grouping, bounded pavement offsets, following limits, and detached spacing projection in `plugins/people/people_plugin.gd`
- [x] T021 [US3] Run focused People/integration tests and record red/green evidence in `specs/010-traffic-flow-coherence/validation/pedestrian-flow.md`

**Checkpoint**: Covered walkers remain visually distinct and deterministic without
changing canonical waypoints, Community intent, or outcomes.

---

## Phase 5: Diagnostics and reconstruction (User Story 4, P3)

**Goal**: Expose detached, stably ordered traffic state and fault codes after gameplay
hashing, with transient state cleared and reconstructible on full map load.

**Independent Test**: Compare clean and fault-injected projections, mutate returned
copies, compare hashes/saves, and reconstruct twice from identical authority.

### Tests first

- [x] T022 [US4] Add failing projection, stable-order, detached-copy, and all required vehicle-fault tests in `test/unit/traffic/test_car_manager_traffic_diagnostics.gd`
- [x] T023 [US4] Add failing pedestrian-overlap diagnostic and reconstruction tests in `test/unit/people/test_people_spacing_diagnostics.gd`
- [x] T024 [US4] Add failing post-hash `traffic_flow` projection and no-new-command tests in `test/unit/playtest/test_playtest_traffic_flow.gd`
- [x] T025 [US4] Add failing clean/fault-injected diagnostic contract tests in `test/integration/traffic_flow/test_traffic_diagnostics.gd`

### Implementation

- [x] T026 [US4] Implement detached pending/active/occupancy projection and stable vehicle diagnostics in `plugins/traffic/car_manager_plugin.gd`
- [x] T027 [US4] Implement pedestrian spacing diagnostics and deterministic transient reset/reconstruction in `plugins/people/people_plugin.gd`
- [x] T028 [US4] Compose `civilian_simulation.traffic_flow` only after gameplay hash calculation in `plugins/playtest/playtest_plugin.gd`
- [x] T029 [US4] Run focused diagnostic, hashing, persistence-adjacent, and reconstruction tests and record evidence in `specs/010-traffic-flow-coherence/validation/diagnostics.md`

**Checkpoint**: Diagnostics explain traffic without mutating or hashing presentation
state, and map load clears every transient claim and pending record.

---

## Phase 6: Deterministic scenario and release evidence

**Purpose**: Prove the complete contract and preserve every established regression.

- [x] T030 Add internal fixed-step ten-replay/fault-injection runner in `scripts/run_traffic_flow_scenario.gd` and traffic fixtures under `test/scenarios/traffic_flow/` without adding a public playtest operation
- [x] T031 Run the deterministic traffic runner and store machine-readable evidence in `specs/010-traffic-flow-coherence/validation/last-run.json`
- [x] T032 Run focused traffic, People, Playtest, and traffic-flow integration suites; record results in `specs/010-traffic-flow-coherence/validation/automated-gates.md`
- [x] T033 Run the full unit suite, civilian deterministic scenario, and first-town loop; record hashes/results and all warnings in `specs/010-traffic-flow-coherence/validation/automated-gates.md`
- [x] T034 Run the 512-proxy/traffic performance gate with diagnostics measured separately and record timings in `specs/010-traffic-flow-coherence/validation/performance.md`
- [x] T035 Compare tracked runtime art/audio inventory against baseline and record zero feature-attributable changes in `specs/010-traffic-flow-coherence/validation/assets.md`
- [x] T036 Review implementation against all three contracts, authority boundaries, and task dependency/test-first ordering; record the audit in `specs/010-traffic-flow-coherence/validation/contract-audit.md`
- [ ] T037 Leave the 1920x1080 normal-renderer observation open in `specs/010-traffic-flow-coherence/validation/manual-renderer.md` unless it is genuinely observed and documented

---

## Dependencies and execution order

- Phase 1 blocks all behaviour phases because it freezes the baseline and creates the
  fixture seams.
- Phase 2 blocks Phase 3: current/next claims apply only to admitted active cars.
- Phase 3 blocks Phase 4 integration assertions and Phase 5 occupancy diagnostics.
- Phase 4 blocks pedestrian diagnostics in Phase 5.
- Phase 5 blocks the scenario runner and release evidence in Phase 6.
- Within every behaviour phase, all listed test tasks precede implementation tasks;
  implementation is not checked complete until the corresponding tests have been seen
  failing for the missing behaviour and passing after the change.
- T031 depends on T030. T032 depends on T029. T033 depends on T032. T034 depends on
  T033 so performance is measured on the regression-clean implementation. T035 may run
  after implementation settles. T036 depends on T031–T035. T037 is an explicit manual
  evidence gate and does not block feasible automated completion.

## Parallel opportunities

- T002 and T003 touch different fixture files.
- Test authoring tasks within a phase may be prepared independently, but all must fail
  for the intended reason before implementation begins.
- Evidence-only T035 can run independently after runtime edits are complete.

## Test-first coverage audit

| Contract area | Failing tests before implementation | Implementation |
|---|---|---|
| Pending admission and People handoff | T004–T005 | T006–T008 |
| Capacity, claims, transforms, canonical waiting | T010–T012 | T013–T015 |
| Pedestrian separation | T017–T018 | T019–T020 |
| Diagnostics, hashes, reconstruction | T022–T025 | T026–T028 |
| Deterministic replay and release gates | T030–T035 | Verification only |

The ordering contains no implementation-before-test edge and no task requires a new
route authority, gameplay outcome owner, persistent traffic record, public playtest
operation, or runtime media asset.
