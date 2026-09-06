# Tasks: Performance and Regression Foundation

**Input**: Design documents from `/specs/009-performance-foundation/`

**Tests**: Required by the feature request and constitution. Tests are written before or beside each implementation slice and must demonstrate deterministic outcomes.

## Phase 1: Setup and Baseline

**Purpose**: Preserve the starting point and establish comparable evidence.

- [X] T001 Commit the verified pre-existing civilian simulation, production assets and UI work
- [X] T002 Record the reference command, seed, total runtime, 06:00 symptom and final hash in `specs/009-performance-foundation/validation/baseline-before.md`
- [X] T003 Complete requirements self-review in `specs/009-performance-foundation/checklists/requirements.md`

---

## Phase 2: Foundational Contracts

**Purpose**: Lock the observable performance seams before optimization.

- [X] T004 [P] Add route-cache hit, copy-safety and rebuild-invalidation tests in `test/unit/traffic/test_road_network_route_cache.gd`
- [X] T005 [P] Add migration source-catalogue reuse and lightweight summary tests in `test/unit/community/test_community_performance.gd`
- [X] T006 [P] Add per-hour timing contract tests in `test/unit/day_night/test_day_night_performance.gd`
- [X] T007 [P] Add Playtest snapshot-mode and action timing contract tests in `test/unit/playtest/test_playtest_performance.gd`

**Checkpoint**: Tests describe the cache, timing and compatibility contract and fail only where the new behavior is absent.

---

## Phase 3: User Story 1 - Smooth Daily Simulation Boundary (P1)

**Goal**: Eliminate repeated synchronous work at 06:00 while preserving exact gameplay outcomes.

**Independent Test**: The canonical 240-hour town completes under the threshold and keeps the baseline hash.

- [X] T008 [US1] Add revision-scoped route and anchor caches in `plugins/traffic/road_network_plugin.gd`
- [X] T009 [US1] Return detached cached route results and expose non-authoritative diagnostics in `plugins/traffic/road_network_plugin.gd`
- [X] T010 [US1] Hoist the 24-hour source catalogue out of the candidate loop in `plugins/community/community_plugin.gd`
- [X] T011 [US1] Replace hourly full community snapshots with direct average-quality aggregation in `plugins/community/community_plugin.gd`
- [X] T012 [US1] Run focused Community, RoadNetwork, civilian and deterministic replay suites

**Checkpoint**: All optimization behavior is transparent and deterministic.

---

## Phase 4: User Story 2 - Fast, Observable AI Playtesting (P2)

**Goal**: Make long agent playthroughs cheap enough to run repeatedly and precise enough to diagnose tick spikes.

**Independent Test**: Action responses honor all snapshot modes and a profiled advance produces ordered samples without changing hashes.

- [X] T013 [US2] Add opt-in per-hour profiling to `plugins/day_night/day_night_plugin.gd`
- [X] T014 [US2] Add compatible `full`, `compact` and `none` action snapshot modes to `plugins/playtest/playtest_plugin.gd`
- [X] T015 [US2] Add separate command/snapshot action timings to `plugins/playtest/playtest_plugin.gd`
- [X] T016 [US2] Adapt `scripts/run_town_rebalance.gd` to use low-overhead actions and collect timing samples
- [X] T017 [US2] Add `scripts/run_performance_playthroughs.gd` to execute at least three complete legal, varied runs
- [X] T018 [US2] Persist machine-readable scenario evidence in `specs/009-performance-foundation/validation/playthrough-report.json`

**Checkpoint**: The AI harness can choose observability cost and pin an individual slow hour.

---

## Phase 5: User Story 3 - Simulation Regression Safety Net (P3)

**Goal**: Protect the current deterministic city loop before progression work begins.

**Independent Test**: Focused and complete test suites plus repeated scenario replay all pass.

- [X] T019 [P] [US3] Extend replay assertions for profiled/non-profiled equivalence in `test/unit/playtest/test_playtest_replay.gd`
- [X] T020 [P] [US3] Cover full-capacity and large-free-capacity migration boundaries in `test/unit/community/test_community_performance.gd`
- [X] T021 [P] [US3] Add a realistic 05:00-to-06:00 integration performance test under `test/integration/performance/`
- [X] T022 [US3] Run all unit and integration suites and record results in `specs/009-performance-foundation/validation/test-results.md`
- [X] T023 [US3] Compare final state hash and outcomes against the seed-6066 baseline in `specs/009-performance-foundation/validation/benchmark-after.md`

**Checkpoint**: Existing gameplay, persistence, civilian and UI behavior remains green.

---

## Phase 6: User Story 4 - Stable Core HUD Controls (P4)

**Goal**: Protect only the radial, top-bar and bottom-bar interfaces used by the core build loop.

**Independent Test**: Core-HUD focused GUT tests pass without adding or modifying side-panel assertions.

- [X] T024 [P] [US4] Strengthen radial navigation and availability coverage in `test/unit/player_ui/`
- [X] T025 [P] [US4] Strengthen top status-bar canonical update coverage in `test/unit/player_ui/test_status_bar.gd`
- [X] T026 [P] [US4] Add bottom tool-bar mode, signal and cancellation coverage in `test/unit/player_ui/test_tool_dock.gd`
- [X] T027 [US4] Run focused radial/top/bottom unit and player-UI integration suites

---

## Phase 7: Polish and Delivery

**Purpose**: Finish evidence, documentation and repository hygiene.

- [X] T028 Run the same performance scenario three times and enforce the 45-second total and 500-millisecond hourly gates
- [X] T029 Run Godot import validation, the complete GUT suite and `git diff --check`
- [X] T030 Update all task checkboxes and validation documents with actual results
- [X] T031 Commit the Spec Kit documents, implementation, tests and evidence with a clean working tree
- [X] T032 Deliver the morning manual smoke-test checklist from `specs/009-performance-foundation/quickstart.md`

## Dependencies and Execution Order

- Setup and baseline (Phase 1) precede every code change.
- Foundational contract tests (Phase 2) precede their matching implementations.
- Route/migration optimization (Phase 3) precedes final performance gating.
- Profiling/harness work (Phase 4) is required to generate Phase 5 evidence.
- Core HUD tests (Phase 6) are independent of simulation optimization after Phase 2.
- Delivery (Phase 7) depends on all user stories.

## Parallel Opportunities

- T004-T007 target independent plugins and test files.
- T019-T021 target independent replay, community and integration layers.
- T024-T026 target separate approved HUD components.
- Automated test suites can run concurrently when they use separate log files.
