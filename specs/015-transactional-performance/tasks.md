# Tasks: Transactional Performance Architecture

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Required by the specification and constitution. Contract/focused tests precede each story’s runtime migration; parity, replay, full-suite, and scenario gates follow it.

## Phase 1: Setup and Frozen Evidence

**Purpose**: Make the current behavior, workload, and measurement method reproducible before architectural work.

- [ ] T001 Record commit/worktree, machine, Godot build mode, seed, hashes, sample counts, and raw command metadata in `specs/015-transactional-performance/validation/baseline.md`
- [ ] T002 [P] Add the 135-building reference workload fixture and identity metadata in `test/fixtures/performance/transactional_reference_town.json`
- [ ] T003 [P] Add shared percentile, workload-count, and hash assertions in `test/helpers/performance_assertions.gd`
- [ ] T004 Capture three untouched headless runs plus one rendered run in `specs/015-transactional-performance/validation/baseline-before.json`

---

## Phase 2: Foundational Contracts and Value Types

**Purpose**: Establish immutable records, canonical vocabularies, state versioning, and injection points used by every story.

**⚠️ CRITICAL**: Complete before story implementation.

- [ ] T005 [P] Add validated immutable HourContext value semantics in `scripts/simulation/hour_context.gd`
- [ ] T006 [P] Add SimulationIntent schema, stable identity, and canonical ordering tuple in `scripts/simulation/simulation_intent.gd`
- [ ] T007 [P] Add TransactionLedgerEntry dispositions and reason codes in `scripts/simulation/transaction_ledger_entry.gd`
- [ ] T008 [P] Add immutable AuthoritativeChangeSet schema and canonical domain/entity ordering in `scripts/simulation/authoritative_change_set.gd`
- [ ] T009 [P] Define the finite invalidation vocabulary and source-domain mapping helpers in `scripts/presentation/invalidation_domains.gd`
- [ ] T010 [P] Add PresenterRegistration dirty/visibility/version state in `scripts/presentation/presenter_registration.gd`
- [ ] T011 Add authoritative StateVersion lifecycle and reset/load rules in `scripts/game_state.gd`
- [ ] T012 Add SimulationTransaction, PresentationScheduler, and PerformanceMonitor registrations/dependencies in `scripts/plugin_manager.gd`
- [ ] T013 [P] Add schema/immutability/order contract tests in `test/contract/simulation/test_transaction_value_contracts.gd`
- [ ] T014 [P] Add invalidation vocabulary and presenter registration contract tests in `test/contract/presentation/test_presentation_value_contracts.gd`
- [ ] T015 Verify the foundational types are absent from saves and canonical hashes in `test/integration/simulation/test_non_authoritative_records.gd`

**Checkpoint**: Contracts compile, value records are detached, and StateVersion is the only new value attached to gameplay authority.

---

## Phase 3: User Story 1 — Atomic, Explainable Hourly Simulation (P1)

**Goal**: Replace hidden hourly signal ordering with one deterministic collect/validate/reduce/commit boundary and independent ledger records.

**Independent Test**: Fixed-seed runs with normal and reversed contributor registration produce identical hashes/ledgers; invalid intents preserve pre-state/version.

### Tests

- [ ] T016 [P] [US1] Add contributor registration, duplicate ID, and unregistration contract tests in `test/contract/simulation/test_contributor_contract.gd`
- [ ] T017 [P] [US1] Add collection purity, stale context, conflict, re-entry, and atomic rejection tests in `test/unit/simulation/test_transaction_coordinator.gd`
- [ ] T018 [P] [US1] Add resource reducer allocation, combination, and tie-break tests in `test/unit/simulation/test_resource_reducer.gd`
- [ ] T019 [P] [US1] Add reversed-registration deterministic ledger/replay coverage in `test/integration/simulation/test_hourly_transaction_determinism.gd`
- [ ] T020 [P] [US1] Add legacy hourly signal and state-hash parity coverage in `test/integration/simulation/test_hourly_compatibility.gd`

### Implementation

- [ ] T021 [US1] Implement contributor/reducer registries and coordinator state machine in `plugins/simulation/simulation_transaction_plugin.gd`
- [ ] T022 [US1] Implement preflight validation, canonical sort, atomic commit, rejection, and bounded ledger in `plugins/simulation/simulation_transaction_plugin.gd`
- [ ] T023 [US1] Implement declarative supply/demand/fulfillment/satisfaction reduction in `plugins/city_stats/city_stats_plugin.gd`
- [ ] T024 [US1] Convert Economy hourly mutation to economic intents plus post-commit compatibility publication in `plugins/economy/economy_plugin.gd`
- [ ] T025 [P] [US1] Convert Demand hourly work to independent intents in `plugins/demand/demand_plugin.gd`
- [ ] T026 [P] [US1] Convert Community hourly work to independent aggregate/resident intents in `plugins/community/community_plugin.gd`
- [ ] T027 [P] [US1] Convert People hourly schedule transitions to independent intents in `plugins/people/people_plugin.gd`
- [ ] T028 [US1] Make DayNight depend on and delegate each crossed hour to SimulationTransaction, advance the clock only on commit, and emit legacy `hour_changed` afterward in `plugins/day_night/day_night_plugin.gd`
- [ ] T029 [US1] Emit `stats_ticked`, cash, demand, and community compatibility signals only from post-commit adapters in `plugins/city_stats/city_stats_plugin.gd`, `plugins/economy/economy_plugin.gd`, `plugins/demand/demand_plugin.gd`, and `plugins/community/community_plugin.gd`
- [ ] T030 [US1] Audit every direct `hour_changed` consumer and record zero remaining legacy-signal gameplay mutations in `specs/015-transactional-performance/validation/hourly-listener-inventory.md`
- [ ] T031 [US1] Run focused, replay, and full-city parity gates and record results in `specs/015-transactional-performance/validation/parity-us1.json`

**Checkpoint**: P1 is a viable architectural MVP; one committed hour and its ledger are independently testable with legacy consumers still supported.

---

## Phase 4: User Story 2 — Coordinated, Decoupled Presentation (P2)

**Goal**: Coalesce committed invalidations and refresh independent visible presenters once at a consistent state version.

**Independent Test**: Several changes dirty only subscribed presenters; visible presenters run once, hidden presenters do no projection work, and re-entrant dirtying waits.

### Tests

- [ ] T032 [P] [US2] Add coalescing, visibility, catch-up, re-entrant invalidation, and error-isolation tests in `test/unit/presentation/test_presentation_scheduler.gd`
- [ ] T033 [P] [US2] Add presenter independence and consistent-version contract tests in `test/contract/presentation/test_presenter_contract.gd`
- [ ] T034 [P] [US2] Add real Dashboard/Community/HUD simultaneous-flush integration coverage in `test/integration/presentation/test_core_presenters.gd`
- [ ] T035 [P] [US2] Add GameEvents-to-change-set adapter parity coverage in `test/integration/presentation/test_game_events_adapter.gd`

### Implementation

- [ ] T036 [US2] Implement domain dirtying, one deferred flush, next-flush re-entry, and reports in `plugins/presentation/presentation_scheduler_plugin.gd`
- [ ] T037 [US2] Translate hourly and non-hourly compatibility events into canonical change sets in `plugins/presentation/presentation_scheduler_plugin.gd`
- [ ] T038 [P] [US2] Register Dashboard dependencies/visibility and replace synchronous `_refresh` fan-out in `plugins/dashboard/dashboard_plugin.gd`
- [ ] T039 [P] [US2] Register Community panel/overlay dependencies/visibility in `plugins/community/community_panel.gd`
- [ ] T040 [P] [US2] Register top HUD dependencies/visibility and coalesce value changes in `plugins/hud/hud_plugin.gd`
- [ ] T041 [US2] Register non-core change-driven presenters without cross-presenter references in `plugins/player_ui/player_ui_plugin.gd`, `plugins/nameplate/nameplate_plugin.gd`, `plugins/palette/palette_plugin.gd`, and `plugins/buildable_area/buildable_area_plugin.gd`
- [ ] T042 [US2] Record projection/refresh invocation counts and parity evidence in `specs/015-transactional-performance/validation/parity-us2.json`

**Checkpoint**: UI modules remain separately owned but present coherently once per frame.

---

## Phase 5: User Story 3 — Bounded Operational Queries and Placement (P3)

**Goal**: Prevent routine UI reads and building mutations from rebuilding unrelated diagnostic or city-wide state.

**Independent Test**: Named operational projections avoid diagnostic builders, and place/replace/demolish update only affected indexes with no partial failure.

### Tests

- [ ] T043 [P] [US3] Add projection dependency, cache-version, copy-safety, and diagnostic-separation tests in `test/unit/presentation/test_projection_registry.gd`
- [ ] T044 [P] [US3] Add Dashboard and Community operational projection cost/invocation tests in `test/unit/dashboard/test_operational_projections.gd`
- [ ] T045 [P] [US3] Add building change-set domain/entity mapping contract tests in `test/contract/simulation/test_building_change_set.gd`
- [ ] T046 [P] [US3] Add place/replace/demolish/load/clear incremental-index parity tests in `test/integration/simulation/test_building_index_updates.gd`
- [ ] T047 [P] [US3] Add rejected-placement authority/index-version invariants in `test/integration/simulation/test_building_mutation_atomicity.gd`

### Implementation

- [ ] T048 [US3] Implement named versioned operational projection registration and detached caching in `plugins/presentation/projection_registry.gd`
- [ ] T049 [US3] Split Community operational summaries from full resident/spatial diagnostics in `plugins/community/community_inspector.gd`
- [ ] T050 [US3] Replace Dashboard universal snapshot refresh with named bounded selectors in `plugins/dashboard/dashboard_plugin.gd`
- [ ] T051 [US3] Publish one precise post-commit change set for place/replace/demolish in `scripts/builder.gd`
- [ ] T052 [P] [US3] Update topology and building-anchor indexes from affected cells/revisions in `plugins/traffic/road_network_plugin.gd`
- [ ] T053 [P] [US3] Update Community occupancy/programme/spatial indexes from change sets in `plugins/community/community_plugin.gd`
- [ ] T054 [P] [US3] Update attractiveness and operation projections from affected structures in `plugins/attractiveness/attractiveness_plugin.gd`
- [ ] T055 [US3] Make map load/clear reset transient projections and rebuild each derived index exactly once in `plugins/presentation/projection_registry.gd`
- [ ] T056 [US3] Run placement/projection parity and timing evidence in `specs/015-transactional-performance/validation/parity-us3.json`

**Checkpoint**: Routine presentation and building commands are bounded by explicit dependencies.

---

## Phase 6: User Story 4 — Scalable Migration, People, and Traffic (P4)

**Goal**: Reuse migration facts and remove full-collection copy/sort work from normal people and traffic frames while preserving deterministic decisions.

**Independent Test**: Fixed-seed migration, 512-person, and 256-car workloads preserve decisions/order and meet their isolated budgets.

### Tests

- [ ] T057 [P] [US4] Add migration dependency-revision reuse and selective invalidation tests in `test/unit/community/test_migration_batch_context.gd`
- [ ] T058 [P] [US4] Add candidate attribution and fixed-seed decision parity tests in `test/integration/simulation/test_migration_transaction_parity.gd`
- [ ] T059 [P] [US4] Add per-origin FIFO fairness, cursor, cancellation, and topology-reset tests in `test/unit/traffic/test_stable_admission_queue.gd`
- [ ] T060 [P] [US4] Add maintained resident order and active/relevant-set parity tests in `test/unit/people/test_people_processing_order.gd`
- [ ] T061 [P] [US4] Add combined 512-person/256-car performance fixture in `test/integration/performance/test_entity_loop_budget.gd`

### Implementation

- [ ] T062 [US4] Build/reuse immutable migration batch facts keyed by explicit dependency revisions in `plugins/community/community_plugin.gd`
- [ ] T063 [US4] Emit independently attributable candidate migration intents from the shared batch context in `plugins/community/community_plugin.gd`
- [ ] T064 [US4] Replace pending-origin discovery, full sorting, and duplicated scans with stable origin queues/cursor in `plugins/traffic/car_manager_plugin.gd`
- [ ] T065 [US4] Maintain people resident order and active/relevant processing sets on lifecycle changes in `plugins/people/people_plugin.gd`
- [ ] T066 [P] [US4] Move people diagnostic copies/sorts out of normal `_process` in `plugins/people/people_plugin.gd`
- [ ] T067 [P] [US4] Move traffic diagnostic copies/sorts out of normal `_process` in `plugins/traffic/car_manager_plugin.gd`
- [ ] T068 [US4] Add visibility/update-frequency tiers without changing simulation schedules or routes in `plugins/people/people_plugin.gd`
- [ ] T069 [US4] Run migration/entity deterministic parity and timing evidence in `specs/015-transactional-performance/validation/parity-us4.json`

**Checkpoint**: Domain hot loops scale with changed/active work rather than total diagnostic population.

---

## Phase 7: User Story 5 — Enforced Performance Budgets (P5)

**Goal**: Attribute costs to stable boundaries and enforce reproducible headless and rendered budgets.

**Independent Test**: Three-run reports include every required field, detect an injected breach at the correct boundary, and pass all reference budgets without hash drift.

### Tests

- [ ] T070 [P] [US5] Add PerformanceSample/Budget schema, percentile, nesting, and exclusion contract tests in `test/contract/performance/test_performance_evidence_contract.gd`
- [ ] T071 [P] [US5] Add disabled/aggregate release behavior and non-authoritative hash tests in `test/unit/performance/test_performance_monitor.gd`
- [ ] T072 [P] [US5] Add deliberately exceeded boundary attribution/gate failure test in `test/integration/performance/test_budget_failure_reporting.gd`
- [ ] T073 [P] [US5] Add rendered workload identity, warm-up, UI/entity, and frame-attribution checks in `test/integration/performance/test_rendered_profile_contract.gd`

### Implementation

- [ ] T074 [P] [US5] Implement PerformanceSample and PerformanceBudget value objects in `scripts/performance/performance_sample.gd` and `scripts/performance/performance_budget.gd`
- [ ] T075 [US5] Implement nested boundary sampling, workload counts, aggregation, and JSON reports in `plugins/performance/performance_monitor_plugin.gd`
- [ ] T076 [US5] Instrument hourly collection/validation/commit/notify boundaries in `plugins/simulation/simulation_transaction_plugin.gd`
- [ ] T077 [P] [US5] Instrument projection/presentation/diagnostic boundaries in `plugins/presentation/presentation_scheduler_plugin.gd`
- [ ] T078 [P] [US5] Instrument building command and incremental-index boundaries in `scripts/builder.gd`
- [ ] T079 [P] [US5] Instrument migration context and candidate boundaries in `plugins/community/community_plugin.gd`
- [ ] T080 [P] [US5] Instrument people processing and relevance workloads in `plugins/people/people_plugin.gd`
- [ ] T081 [P] [US5] Instrument traffic admission, processing, and submission workloads in `plugins/traffic/car_manager_plugin.gd`
- [ ] T082 [US5] Extend three-run headless reporting and budget enforcement in `scripts/run_performance_playthroughs.gd`
- [ ] T083 [US5] Add rendered reference-town runner with warm-up/exclusion and engine-unattributed accounting in `scripts/run_rendered_performance_profile.gd`
- [ ] T084 [US5] Gate or aggregate hot-path debug output in `plugins/economy/economy_plugin.gd`, `plugins/city_stats/city_stats_plugin.gd`, and `plugins/dashboard/dashboard_plugin.gd`
- [ ] T085 [US5] Produce final headless/rendered reports in `specs/015-transactional-performance/validation/benchmark-after.json`

**Checkpoint**: Every performance claim is attributable, reproducible, and enforced.

---

## Phase 8: Cross-Cutting Rollout and Completion

**Purpose**: Prove whole-game compatibility and remove temporary paths safely.

- [ ] T086 Audit legacy hourly and UI compatibility consumers in `specs/015-transactional-performance/validation/adapter-inventory.md`
- [ ] T087 Remove only adapters with zero remaining consumers in `plugins/simulation/simulation_transaction_plugin.gd`
- [ ] T088 Run all focused contract/unit/integration suites and record commands/results in `specs/015-transactional-performance/validation/test-results.md`
- [ ] T089 Run deterministic replay with normal/reversed registration and record state/ledger hashes in `specs/015-transactional-performance/validation/parity-report.json`
- [ ] T090 Run the complete GUT suite and canonical full-city scenario in `specs/015-transactional-performance/validation/test-results.md`
- [ ] T091 Compare all SC-001–SC-011 thresholds against before/after evidence in `specs/015-transactional-performance/validation/acceptance-report.md`
- [ ] T092 Update architecture and validation commands to match delivered contracts in `specs/015-transactional-performance/quickstart.md`

---

## Dependencies

- Phase 1 precedes all implementation so comparisons remain trustworthy.
- Phase 2 blocks every user story.
- **US1 (P1)** is the architectural MVP and blocks committed change-driven invalidation.
- **US2 (P2)** depends on the US1 change-set publication contract.
- **US3 (P3)** depends on US2 projection/presentation registries; building change sets can begin after Phase 2.
- **US4 (P4)** migration work depends on US1; people/traffic maintained-order work can begin after Phase 2 and integrate after US2.
- **US5 (P5)** value/test scaffolding may start after Phase 2, but final instrumentation and gates depend on US1–US4.
- Phase 8 depends on all stories; adapters are never removed earlier.

## Parallel Execution Examples

- **Foundational**: T005–T010, T013–T014 are separate files and can proceed in parallel before T011–T012 integration.
- **US1**: T016–T020 can be authored in parallel; T025–T027 can migrate independent contributors after T021–T022 stabilize.
- **US2**: T032–T035 are parallel; T038–T040 migrate independent presenters after T036.
- **US3**: T043–T047 are parallel; T052–T054 update separate domain indexes after T051.
- **US4**: T057–T061 are parallel; traffic T064/T067 and people T065/T066 can proceed independently of migration T062/T063.
- **US5**: T070–T074 can proceed in parallel; T076–T081 instrument separate owners after T075.

## Implementation Strategy

1. Deliver **US1 only** as the MVP behind legacy post-commit adapters.
2. Add US2 without changing presenter ownership.
3. Add US3 and the independent migration/people/traffic parts of US4 in small parity-protected changes.
4. Enforce US5 budgets only after attribution shows which boundary owns time.
5. Remove adapters last, one consumer inventory at a time.

## Requirement Traceability

| Requirement group | Covered by tasks |
|---|---|
| FR-001–FR-010 hourly boundary, IoC, atomicity, ledger, deterministic order | T005–T008, T011, T016–T031 |
| FR-011 compatibility | T020, T029–T031, T086–T091 |
| FR-012–FR-017 invalidation and independent presentation | T009–T010, T014, T032–T042 |
| FR-018–FR-021 projections and atomic building indexes | T043–T056 |
| FR-022–FR-023 migration reuse and attribution | T057–T058, T062–T063, T069, T079 |
| FR-024 traffic fairness/order | T059, T061, T064, T067, T069, T081 |
| FR-025 people/traffic relevance | T060–T061, T065–T068, T080–T081 |
| FR-026–FR-029 performance attribution, evidence, non-authority, logging | T003–T004, T070–T085 |
| FR-030 adapter rollout | T020, T029–T031, T035, T086–T090 |
| SC-001–SC-003 deterministic transaction and presentation outcomes | T019–T020, T031–T035, T042, T089 |
| SC-004–SC-009 wall-clock and rendered budgets | T004, T044, T056, T061, T069–T085, T091 |
| SC-010 layered quality gates | T013–T020, T031–T035, T042–T047, T056–T061, T069–T073, T086–T091 |
| SC-011 timing attribution | T070–T085, T091 |

## Format Validation

All tasks use the required checkbox, sequential ID, optional `[P]`, required user-story label within story phases, actionable description, and explicit file path.
