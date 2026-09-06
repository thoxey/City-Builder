# Tasks: Coherent Civilian Simulation

**Input**: Design documents from `specs/008-civilian-simulation-coherence/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/`, and `quickstart.md`

**Tests**: Required by FR-024 and the acceptance scenarios. Add each focused test
before its implementation and verify that it fails for the intended contradiction.

**Format**: `[ID] [P?] [Story] Description with exact file path`

## Phase 1: Baseline and Test Setup

**Purpose**: Preserve current behaviour and create reusable seams without changing
runtime outcomes.

- [x] T001 Run the four focused baseline suites from `specs/008-civilian-simulation-coherence/quickstart.md` and record commands, versions, totals, and known full-suite `user://` limitations in `specs/008-civilian-simulation-coherence/validation/baseline-before.md`.
- [x] T002 [P] Create deterministic resident, intent, building, clock, and route doubles for People tests in `test/unit/people/people_test_fixtures.gd`.
- [x] T003 [P] Create deterministic route, pool, and resolved-journey doubles for CarManager tests in `test/unit/traffic/car_manager_test_fixtures.gd`.
- [x] T004 [P] Add loader-compatible connected, disconnected, and edit-interruption fixtures in `test/scenarios/civilian_simulation/connected_day.json`, `test/scenarios/civilian_simulation/disconnected_day.json`, and `test/scenarios/civilian_simulation/edit_continuity.json`.
- [x] T005 [P] Record the current Community/BuildingProfile role, schedule, capacity, and effect data for Pub, Restaurant, Private Members' Club, Crazy Golf, Town Hall, Pirate Radio, and Theatre in `specs/008-civilian-simulation-coherence/validation/venue-inventory-before.md`.
- [x] T006 [P] Freeze a path-and-digest inventory of current person, car, road, venue, UI, and audio assets in `specs/008-civilian-simulation-coherence/validation/runtime-assets-before.txt` for the no-new-assets gate.

**Checkpoint**: Existing contradictory behaviour and the original asset/content state
are reproducible before implementation begins.

---

## Phase 2: Foundational Observability and Identity

**Purpose**: Add the shared diagnostic and identity seams required by every user
story. These tasks block all later phases.

> Write T007-T010 first and confirm their assertions fail for the missing contracts.

- [x] T007 [P] Add failing detached-order, purpose-precedence, and same-hour revision tests for the Community civilian-intent contract in `test/unit/community/test_civilian_intents.gd`.
- [x] T008 [P] Add failing binding, count, stable-order, and violation-projection tests for People in `test/unit/people/test_people_snapshot.gd`.
- [x] T009 [P] Add failing resident binding, route revision, active/waiting count, and detached-copy tests for CarManager in `test/unit/traffic/test_car_manager_snapshot.gd`.
- [x] T010 [P] Add failing after-hash, compact-omission, and no-seventh-command tests in `test/unit/playtest/test_playtest_civilians.gd`.
- [x] T011 Implement monotonic assignment invalidation plus stable `get_civilian_intent()`, `get_civilian_intents()`, and `get_assignment_revision()` reads in `plugins/community/community_plugin.gd` to satisfy `contracts/civilian-projection.md`.
- [x] T012 [P] Extend `plugins/people/person_slot.gd` with resident ID/seed, immutable home, current place, intent revision, journey revision, mode, purpose, blocked reason, and transient plan fields from `data-model.md`.
- [x] T013 Implement resident-indexed, stably ordered `get_civilian_snapshot()` output and machine-checkable alignment violations in `plugins/people/people_plugin.gd`.
- [x] T014 [P] Implement detached `get_civilian_snapshot()` output for active and waiting journeys in `plugins/traffic/car_manager_plugin.gd`.
- [x] T015 Inject People and CarManager into the existing debug Playtest plugin and append non-compact `civilian_simulation` only after `state_hash` calculation in `plugins/playtest/playtest_plugin.gd`.
- [x] T016 Add fixed-delta People/CarManager stepping and normalised diagnostic capture helpers in `test/integration/civilian_simulation/civilian_simulation_fixtures.gd` without adding a public playtest command.

**Checkpoint**: The current system's contradictions can be inspected by resident ID,
and visual-only changes provably do not affect gameplay hashes.

---

## Phase 3: User Story 1 — Residents Live Their Assigned Day (P1) 🎯 MVP

**Goal**: Every visible resident follows the exact Community work/activity/home
intent, with stable variation and assignment-length dwell.

**Independent test**: In a simple connected home/work/activity town, each visible
resident's purpose and destination match Community through work, leisure, and return
home; same-seed runs produce the same trace.

### Tests for User Story 1

- [x] T017 [P] [US1] Add failing exact work/activity/home intent and immutable-home tests in `test/unit/people/test_people_intent_reconciliation.gd`.
- [x] T018 [P] [US1] Add failing seeded spawn-offset, departure-order, and same-seed trace tests in `test/unit/people/test_people_determinism.gd`.
- [x] T019 [P] [US1] Add a failing full-day binding, commute, dwell, activity, and return-home integration test in `test/integration/civilian_simulation/test_assigned_day.gd` using `test/scenarios/civilian_simulation/connected_day.json`.

### Implementation for User Story 1

- [x] T020 [US1] Change Community-backed spawning in `plugins/people/people_plugin.gd` to bind the stable `resident_id`, seed, and authoritative home into `PersonSlot`, preserving stable cap selection.
- [x] T021 [US1] Replace hour-8/category/random destination selection and 4-10-second roaming in `plugins/people/people_plugin.gd` with reconciliation against the exact Community CivilianIntent.
- [x] T022 [US1] Replace global visual randomness in `plugins/people/people_plugin.gd` with resident-seed plus absolute-hour/purpose derivation for spawn offset and bounded departure staggering only.
- [x] T023 [US1] Implement explicit at-home, travelling, at-destination, blocked, and unhoused semantics in `plugins/people/person_slot.gd` and `plugins/people/people_plugin.gd`, keeping current place separate from immutable home.
- [x] T024 [US1] Reconcile intents on exact hour and assignment-revision changes in `plugins/people/people_plugin.gd`; keep arrived residents dwelling until intent end/change rather than resetting a real-time idle timer.
- [x] T025 [US1] Run T017-T019 and record the independently passing assigned-day checkpoint in `specs/008-civilian-simulation-coherence/validation/us1-assigned-day.md`.

**Checkpoint**: User Story 1 works with a simple reachable path even before the full
canonical walk/car policy is introduced.

---

## Phase 4: User Story 2 — Journeys Respect the Built Town (P1)

**Goal**: Walking and driving consume the same canonical route that made an
assignment reachable; disconnected or capacity-blocked travel never invents a path.

**Independent test**: Matched connected/disconnected layouts produce respectively a
canonical journey and an explained stationary resident, with walk/car boundaries
based on route distance.

### Tests for User Story 2

- [x] T026 [P] [US2] Add failing resolved-stop, stable equal-cost tie, route-distance, and detached-route tests in `test/unit/traffic/test_road_network_civilian_routes.gd`.
- [x] T027 [P] [US2] Add failing resolved-path execution, resident identity, pool-full waiting, and stale-completion tests in `test/unit/traffic/test_car_manager_resolved_journeys.gd`.
- [x] T028 [P] [US2] Add failing walk-threshold, valid waypoint, and no-direct-fallback tests in `test/unit/people/test_people_journey_policy.gd`.
- [x] T029 [P] [US2] Add a failing matched connected/disconnected integration test in `test/integration/civilian_simulation/test_honest_journeys.gd` using both day fixtures.

### Implementation for User Story 2

- [x] T030 [US2] Extend `plugins/traffic/road_network_plugin.gd` with a detached civilian route projection containing chosen origin/destination stops, ordered road cells, route distance, revision, and stable failure reason.
- [x] T031 [US2] Build and cache the transient JourneyPlan from the RoadNetwork projection in `plugins/people/people_plugin.gd`, selecting walk/car only from authored route-distance threshold data in `data/community/balance.json`.
- [x] T032 [US2] Replace pedestrian path fallback and anchor-distance mode choice in `plugins/people/people_plugin.gd` with canonical road/edge waypoint generation and an explicit blocked state on route failure.
- [x] T033 [US2] Add `request_resolved_journey()` to `plugins/traffic/car_manager_plugin.gd` and resident/plan/revision metadata to `plugins/traffic/car_slot.gd`, copying the supplied stops/path before movement.
- [x] T034 [US2] Update People-to-car handoff and completion handling in `plugins/people/people_plugin.gd` to preserve resident/plan identity and reject completion from a superseded JourneyPlan.
- [x] T035 [US2] Implement deterministic `WAITING_FOR_CAR` retry order in `plugins/people/people_plugin.gd`; pool exhaustion must never fall back to unsupported walking.
- [x] T036 [US2] Run T026-T029 and record connected/disconnected routes, threshold boundaries, pool behaviour, and zero invalid waypoints in `specs/008-civilian-simulation-coherence/validation/us2-honest-journeys.md`.

**Checkpoint**: User Stories 1 and 2 tell one coherent assignment and route story.

---

## Phase 5: User Story 3 — Town Edits Preserve Daily Life (P2)

**Goal**: Ordinary placement, demolition, resident, and road events update only
affected bindings/journeys; map load remains the deliberate full-rebuild boundary.

**Independent test**: Unrelated construction changes zero proxy positions, plan keys,
or car IDs, while removing a used route affects only dependent residents.

### Tests for User Story 3

- [x] T037 [P] [US3] Add failing unrelated-placement, dependent-road-removal, and stale-route-revision tests in `test/unit/people/test_people_reconciliation.gd`.
- [x] T038 [P] [US3] Add failing resident arrival, departure, rehome, cap transition, and map-load reconstruction tests in `test/unit/people/test_people_roster_events.gd`.
- [x] T039 [P] [US3] Add failing targeted cancellation and unaffected-reservation-preservation tests in `test/unit/traffic/test_car_manager_invalidation.gd`.
- [x] T040 [P] [US3] Add a failing edit-continuity integration test in `test/integration/civilian_simulation/test_edit_continuity.gd` using `test/scenarios/civilian_simulation/edit_continuity.json`.

### Implementation for User Story 3

- [x] T041 [US3] Add resident-ID-to-slot indexing and targeted add/remove/rehome reconciliation in `plugins/people/people_plugin.gd`, replacing roster-event calls to `_rebuild()`.
- [x] T042 [US3] Replace ordinary structure-event `_rebuild()` calls in `plugins/people/people_plugin.gd` with endpoint/path dependency checks against RoadNetwork revision, preserving still-valid plan keys and progress.
- [x] T043 [US3] Replace ordinary structure-event `_cancel_all()` calls in `plugins/traffic/car_manager_plugin.gd` with targeted path/endpoint invalidation while retaining full cancellation for `map_loaded`.
- [x] T044 [US3] Implement safe segment interruption and last-valid-place recovery in `plugins/people/people_plugin.gd`, including stale car completion, destination demolition, disconnection, and rehome while travelling.
- [x] T045 [US3] Reconstruct transient bindings and current intents after map load in `plugins/people/people_plugin.gd` without persisting transforms, waypoint progress, car IDs, or lane reservations.
- [x] T046 [US3] Run T037-T040 and record unchanged and affected resident/car identities before and after each edit in `specs/008-civilian-simulation-coherence/validation/us3-continuity.md`.

**Checkpoint**: Building remains visually compatible with an already-living town.

---

## Phase 6: User Story 4 — Existing Venues Create Daily Rhythms (P2)

**Goal**: Suitable existing buildings become deterministic scheduled participant
destinations through data only; unsuitable buildings retain explicit non-attendance
roles.

**Independent test**: Connected eligible venues receive no more than authored
capacity during active hours, disconnected or closed venues receive none, and
programme changes reconcile in the same hour.

### Tests for User Story 4

- [x] T047 [P] [US4] Add failing role, capacity, schedule, and overnight-range authored-data tests in `tools/data_editor/src/buildings/civilian-participation.test.ts`.
- [x] T048 [P] [US4] Add failing connected/disconnected allocation and same-hour programme-invalidation tests in `test/unit/community/test_civilian_venue_assignments.gd`.
- [x] T049 [P] [US4] Add a failing scheduled venue visit integration test in `test/integration/civilian_simulation/test_existing_venue_rhythm.gd`.

### Implementation for User Story 4

- [x] T050 [US4] Add conservative participant effects/capacities aligned to existing opening hours in `data/buildings/unique/building_pub.json`, `data/buildings/unique/building_restaurant.json`, and `data/buildings/unique/building_members_club.json`.
- [x] T051 [US4] Add an explicit scheduled participant profile for Crazy Golf in `data/buildings/unique/building_crazy_golf.json` using its existing identity and asset.
- [x] T052 [US4] Record Town Hall as local-only, Pirate Radio as productive/cosmetic non-attendance, and Theatre as the existing programme-driven participant reference in `specs/008-civilian-simulation-coherence/validation/venue-role-decisions.md`; add only validator-required role metadata to `data/buildings/unique/building_town_hall.json`, `data/buildings/unique/building_pirate_radio.json`, and `data/buildings/unique/building_theatre.json`.
- [x] T053 [US4] Extend existing building validation in `tools/data_editor/src/buildings/validation.ts` to reject participant profiles with missing/invalid capacity, schedule, scope, or stable IDs while permitting explicit non-participant roles.
- [x] T054 [US4] Invalidate Community's assignment revision and cached same-hour intents inside `plugins/community/community_plugin.gd` whenever `set_programme()` succeeds.
- [x] T055 [US4] Run connected/disconnected and before/after venue traces, tune only authored effect values if required, and record capacity, quality, demand, economy, and first-town deltas in `specs/008-civilian-simulation-coherence/validation/venue-balance-comparison.md`.
- [x] T056 [US4] Run T047-T049 plus the data-editor suite and record the independently passing venue-rhythm checkpoint in `specs/008-civilian-simulation-coherence/validation/us4-venue-rhythm.md`.

**Checkpoint**: Existing assets produce a legible work/leisure/home rhythm without
inventing attendance at every landmark.

---

## Phase 7: User Story 5 — Civilian Contradictions Are Automatically Detectable (P3)

**Goal**: Existing AI/playtest state and internal headless scenarios expose and fail
every specified visible/authoritative contradiction without changing gameplay state.

**Independent test**: A fixed-step full-day run has zero violations and repeats
identically; deliberately injected mismatches each produce their expected reason.

### Tests for User Story 5

- [x] T057 [P] [US5] Extend `test/unit/playtest/test_playtest_civilians.gd` with duplicate binding, destination mismatch, unreachable journey, invalid waypoint, stale route, missing car, unexpected reset, and unexpected cancellation fault cases.
- [x] T058 [P] [US5] Add gameplay-hash and save-payload exclusion coverage for all transient civilian fields in `test/unit/playtest/test_playtest_civilian_hashing.gd` and `test/unit/community/test_community_persistence.gd`.
- [x] T059 [P] [US5] Add fixed-step full-day, disconnect, unrelated-edit, and programme-change scenario assertions in `test/integration/civilian_simulation/test_civilian_diagnostics.gd`.

### Implementation for User Story 5

- [x] T060 [US5] Complete stable aggregate counts, blocked reasons, resident records, and violation ordering across `plugins/people/people_plugin.gd`, `plugins/traffic/car_manager_plugin.gd`, and `plugins/playtest/playtest_plugin.gd` to match `contracts/civilian-projection.md`.
- [x] T061 [US5] Implement the headless fixed-step canonical runner in `scripts/run_civilian_simulation_scenario.gd` using only existing playtest actions plus internal deterministic visual stepping.
- [x] T062 [US5] Add normalisation, ten-run trace comparison, and fault-injection modes to `scripts/run_civilian_simulation_scenario.gd`, excluding only explicitly volatile wall-clock/log fields.
- [x] T063 [US5] Run T057-T059, prove each injected fault is detected, then run ten clean same-seed replays and store their summary plus canonical trace in `specs/008-civilian-simulation-coherence/validation/deterministic-civilian-replay.md` and `specs/008-civilian-simulation-coherence/validation/last-run.json`.

**Checkpoint**: All five stories are observable and deterministically testable through
the existing public playtest surface.

---

## Phase 8: Performance, Regression, Visual, and Scope Gates

**Purpose**: Prove the complete feature meets its quantitative and no-new-assets
constraints.

- [x] T064 [P] Add a 512-visible-proxy, diagnostics-off performance case in `test/unit/people/test_people_performance.gd` and record average/maximum People plus CarManager update cost separately from snapshot cost in `specs/008-civilian-simulation-coherence/validation/performance.md`.
- [x] T065 Run all focused Community, People, traffic, day/night, playtest, persistence, and civilian integration suites from `specs/008-civilian-simulation-coherence/quickstart.md` and record totals in `specs/008-civilian-simulation-coherence/validation/test-results.md`.
- [x] T066 Run the complete GUT unit suite with a writable Godot user-data directory and record every failure or warning disposition in `specs/008-civilian-simulation-coherence/validation/test-results.md`.
- [x] T067 Run the data-editor build/tests and `scripts/run_first_town_loop.gd`, then record content validation and first-town regression hashes in `specs/008-civilian-simulation-coherence/validation/test-results.md`.
- [ ] T068 Run one normal-renderer full-day scenario with current assets, inspect work/leisure/home dwell, connected routes, construction continuity, and car handoffs, and record observations/screenshots in `specs/008-civilian-simulation-coherence/validation/visual-observation.md`.
- [x] T069 Compare the implementation asset inventory with `validation/runtime-assets-before.txt`; record zero feature-attributable runtime art/audio additions or modifications in `specs/008-civilian-simulation-coherence/validation/asset-scope-gate.md`.
- [x] T070 Re-run every command in `specs/008-civilian-simulation-coherence/quickstart.md`, reconcile SC-001-SC-009 evidence, and update only the evidence gates in `specs/008-civilian-simulation-coherence/checklists/requirements.md` that are genuinely satisfied.

## Dependencies and Execution Order

### Phase dependencies

- Phase 1 has no dependencies and freezes the baseline.
- Phase 2 depends on Phase 1 and blocks all user-story implementation.
- Phase 3 (US1) depends on Phase 2 and is the minimum coherent-resident slice.
- Phase 4 (US2) depends on Phase 2 and integrates with US1 for the full P1 slice; its
  route execution can be tested independently with injected CivilianIntent fixtures.
- Phase 5 (US3) depends on US1 and US2 because continuity preserves their bindings and
  JourneyPlans.
- Phase 6 (US4) depends on US1 for visible intent consumption; Community-only venue
  allocation tests can start after Phase 2.
- Phase 7 (US5) depends on the diagnostics foundation and consumes all completed story
  states for the canonical trace.
- Phase 8 depends on all selected story phases.

### User-story dependencies

```text
Phase 1 baseline
       ↓
Phase 2 diagnostics/identity foundation
       ├───────────────┐
       ↓               ↓
US1 assigned day     US2 route policy (fixture-driven)
       └───────┬───────┘
               ↓
       US3 edit continuity
               ↑
       US4 venue rhythm (requires US1)
               ↓
       US5 deterministic detection
               ↓
       Cross-cutting gates
```

### Parallel opportunities

- T002-T006 touch independent fixture/evidence paths and may run together.
- T007-T010 are independent failing contract suites.
- T012 and T014 touch different runtime files once their tests exist.
- T017-T019, T026-T029, T037-T040, and T047-T049 are parallel test-writing groups.
- Community-only T048/T054 work can proceed alongside US2/US3 once Phase 2 is green.
- T064 and the documentation preparation for T068/T069 may proceed after story code
  freezes, but final evidence waits for all regressions.

## Implementation Strategy

### MVP slice

1. Complete Phases 1 and 2.
2. Complete US1 through T025.
3. Demonstrate a named resident following the exact work/activity/home intent on a
   simple connected layout.
4. Continue into US2 before calling the overall feature shippable; the MVP proves
   assignment coherence but not yet every route failure.

### Recommended delivery increments

1. **Inspectable baseline**: T001-T016.
2. **One resident, one assigned day**: T017-T025.
3. **Honest walking and driving**: T026-T036.
4. **Continuity during building**: T037-T046.
5. **Existing-venue rhythm**: T047-T056.
6. **AI-verifiable full-day story**: T057-T063.
7. **Release evidence**: T064-T070.

## Requirement Coverage

| Requirements | Tasks |
|--------------|-------|
| FR-001-FR-007 | T007, T012, T017-T025 |
| FR-008-FR-013 | T026-T036 |
| FR-014-FR-016 | T037-T046 |
| FR-017-FR-019 | T005, T047-T056 |
| FR-020-FR-024 | T008-T016, T057-T063 |
| FR-025 | T058, T063, T065-T067 |
| FR-026 | T006, T068-T070 |

## Notes

- `[P]` means the task touches a different file and has no unmet dependency on another
  task in the same group.
- Tests must demonstrate the intended failure before implementation begins.
- Do not mark visual arrival, traffic congestion, proxy availability, or render-frame
  time as authoritative for Community, output, economy, demand, or happiness.
- Do not add a seventh public playtest command.
- Do not add or modify runtime art/audio assets for this feature.
- Preserve unrelated user changes in the existing dirty worktree.
