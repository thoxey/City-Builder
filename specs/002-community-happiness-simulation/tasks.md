# Tasks: Community Happiness Simulation

**Input**: Design documents from `specs/002-community-happiness-simulation/`

**Prerequisites**: `plan.md`, `spec.md`

**Tests**: Required by section 10 of `spec.md`. Test tasks precede the behavior
they specify and must be observed failing for the intended reason before the
corresponding implementation task begins.

**Organization**: Tasks are grouped by user story so each gameplay capability
can be implemented and verified as an increment. User Story 1 is the MVP.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with adjacent tasks because it touches different files and does not depend on their incomplete work
- **[Story]**: User story from `spec.md`
- Every task names its exact target file or directory

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the community domain, authored-data, test, scenario, and
validation locations without changing live gameplay.

- [x] T001 Create community source and test directory skeletons at `scripts/community/`, `plugins/community/`, and `test/unit/community/`
- [x] T002 [P] Add schema-versioned default thresholds, smoothing, candidate batch, sensitivity bounds, relocation grace, and snapshot limits in `data/community/balance.json`
- [x] T003 [P] Add initial moderate-general, Identity-heavy, Freedom-heavy, and Care-heavy prototype records in `data/community/cohorts.json`
- [x] T004 [P] Add deterministic scenario fixture shells in `test/scenarios/community_personality_contrast.json`, `test/scenarios/community_park_and_noise.json`, `test/scenarios/community_migration_week.json`, and `test/scenarios/community_retention_failure.json`

**Checkpoint**: Authored files parse as JSON and the new directories introduce
no runtime behavior.

---

## Phase 2: Foundational (Blocking Domain and Persistence Seams)

**Purpose**: Define the common save-safe model, authored-profile loader, event
boundary, and plugin lifecycle required by every user story.

**⚠️ CRITICAL**: No user-story implementation starts until this phase passes.

- [x] T005 [P] Write failing resident normalization, JSON-safety, four-decimal snapshot, and round-trip tests in `test/unit/community/test_community_models.gd`
- [x] T006 [P] Write failing catalog tests for valid effects/programmes and rejected quality, manifestation, scope, radius, schedule, capacity, sensitivity, and duplicate-effect data in `test/unit/building_catalog/test_building_catalog.gd`
- [x] T007 Implement quality/lens enums, canonical ordering, vector normalization, clamping, stable sorting, and four-decimal helpers in `scripts/community/community_constants.gd`
- [x] T008 Implement the persistent `CommunityResident` record, defaults, validation, JSON-safe serialization, and schema migration entry point in `scripts/community/community_resident.gd`
- [x] T009 Implement `CommunityEffectProfile` effect/programme validation and immutable normalized effect records in `scripts/community/community_effect_profile.gd`
- [x] T010 Extend catalog profile parsing and summaries for `CommunityEffectProfile` without building-ID conditionals in `plugins/building_catalog/building_catalog_plugin.gd`
- [x] T011 Add resident records, next resident ID, generation schema/state, migration counters, and selected programme persistence fields in `scripts/data_map.gd`
- [x] T012 Add community population, qualities, migration, departure, home, and programme-change signals to `scripts/game_events.gd`
- [x] T013 Create the Community plugin dependency declaration, authored-data loading, canonical event subscriptions, and empty lifecycle state in `plugins/community/community_plugin.gd`
- [x] T014 Register Community before its compatibility consumers and inject it without coupling Builder to community logic in `scripts/plugin_manager.gd`
- [x] T015 Implement map reconciliation and complete scenario reset of residents, counters, programme selections, IDs, and deterministic RNG state in `plugins/community/community_plugin.gd`
- [x] T016 Add foundational plugin tests for registration, dependency injection, old-map defaults, map reconciliation, and clean reset in `test/unit/community/test_community_plugin.gd`
- [x] T017 Add Community fixture factories for residents, buildings, effects, homes, clocks, and deterministic RNGs in `test/unit/community/community_test_fixtures.gd`
- [x] T018 Run the foundational catalog/model/plugin tests and record their command and passing totals in `specs/002-community-happiness-simulation/validation/test-results.md`

**Checkpoint**: Community loads safely on new and old maps, authored profiles
are validated, and reset/load paths cannot leak resident or RNG state.

---

## Phase 3: User Story 1 - Different People Experience the Same Place Differently (Priority: P1) 🎯 MVP

**Goal**: Deterministically generate residents whose per-quality lenses interpret
the same tagged and neutral effects differently, with exact explanations.

**Independent Test**: Create residents with equal Belonging importance and
opposite Identity/Freedom weights, apply plays and rock effects, and verify
opposite ranked Belonging targets while an equal neutral nuisance remains equal
before sensitivity.

### Tests for User Story 1

- [x] T019 [P] [US1] Write failing same-seed, different-seed, cohort-selection, vector-normalization, sensitivity-bound, persistent-ID, and generation-version tests in `test/unit/community/test_personality_generator.gd`
- [x] T020 [P] [US1] Write failing exact tests for tagged/neutral preference multipliers, sensitivity, smoothing, clamping, composite weighting, and source-preserving AppliedEffects in `test/unit/community/test_effect_evaluator.gd`
- [x] T021 [US1] Write the failing plays-versus-rock resident contrast integration test, including simultaneous attendance benefit and neutral noise harm, in `test/unit/community/test_community_plugin.gd`

### Implementation for User Story 1

- [x] T022 [US1] Implement versioned cohort selection, deterministic perturbation/renormalization, bounded sensitivities, and resident ID allocation in `scripts/community/community_personality_generator.gd`
- [x] T023 [US1] Implement the pure tagged/neutral formula, quality target calculation, hourly smoothing, composite happiness, and AppliedEffect explanation construction in `scripts/community/community_effect_evaluator.gd`
- [x] T024 [US1] Implement deterministic resident creation and per-hour quality state updates using the pure helpers in `plugins/community/community_plugin.gd`
- [x] T025 [P] [US1] Author the `plays`, `rock_nights`, and `community_use` theatre programme fixtures with concise reasons in `data/buildings/unique/building_theatre.json`
- [x] T026 [P] [US1] Author Freedom participant benefits and scheduled neutral local noise for the night venue in `data/buildings/unique/building_nightclub.json`
- [x] T027 [US1] Complete the declared fixed-resident action/effect sequence and expected ranked outcomes in `test/scenarios/community_personality_contrast.json`
- [x] T028 [US1] Run `community_personality_contrast` twice with one seed and record resident-level effects, quality targets, and equivalence evidence in `specs/002-community-happiness-simulation/validation/personality-contrast.md`

**Checkpoint**: One resident can simultaneously explain “I love this venue” and
“I cannot sleep beside it,” and lens differences change tagged contributions
without becoming extra happiness bars.

---

## Phase 4: User Story 2 - Buildings Create a Complex but Explainable Happiness Web (Priority: P1)

**Goal**: Evaluate spatial, scheduled, capacity-limited, and participant effects
in stable order and expose legible four-quality explanations.

**Independent Test**: Place a park and night venue beside occupied housing,
advance through day and night, and verify radius, programme participation,
schedule, stacking, and source breakdowns for all four qualities.

### Tests for User Story 2

- [x] T029 [P] [US2] Write failing radius, local/resident/city/participant scope, inclusive-start/exclusive-end schedule, and active-building tests in `test/unit/community/test_effect_evaluator.gd`
- [x] T030 [P] [US2] Write failing deterministic stacking-order and `1.0/0.5/0.25` diminishing-multiplier tests, including positive/negative group separation, in `test/unit/community/test_effect_evaluator.gd`
- [x] T031 [P] [US2] Write failing activity retention, predicted-benefit ranking, travel tie-break, stable resident order, and capacity-limit tests in `test/unit/community/test_community_plugin.gd`
- [x] T032 [P] [US2] Write failing integration coverage for separate park Liveability/Beauty effects and attendee benefit plus nearby non-attendee noise in `test/unit/community/test_community_plugin.gd`
- [x] T033 [P] [US2] Write failing bounded full/compact community snapshot and source-breakdown contract tests in `test/unit/playtest/test_playtest_plugin.gd` and `server/src/tools/playtest-tools.test.ts`

### Implementation for User Story 2

- [x] T034 [US2] Extend the pure evaluator with grid radius, all four scopes, schedule windows across midnight, active-building gates, and deterministic stacking in `scripts/community/community_effect_evaluator.gd`
- [x] T035 [US2] Implement stable hourly programme/activity assignment with capacity, current-assignment retention, predicted benefit, travel distance, and canonical tie-breaking in `plugins/community/community_plugin.gd`
- [x] T036 [US2] Bind Community to DayNight’s single exact `hour_changed` boundary and canonical placement/demolition/map events in `plugins/community/community_plugin.gd`
- [x] T037 [P] [US2] Author accessible recreation, shared greenery, landscape identity, and optional meeting-place effects in `data/buildings/nature/building_duck_pond.json` and `data/buildings/nature/building_nature_patch.json`
- [x] T038 [P] [US2] Author participant employment plus local pollution/noise and Beauty nuisance effects in `data/buildings/generic/building_garage.json` and `data/buildings/unique/building_pipe_factory.json`
- [x] T039 [US2] Add player-facing four-quality averages and resident top-positive/top-negative inspection without exposing lenses as bars in `plugins/community/community_inspector.gd` and `plugins/dashboard/dashboard_plugin.gd`
- [x] T040 [US2] Extend existing full and compact Playtest snapshots with bounded `community` aggregates, residents, migration, distributions, and effect summaries in `plugins/playtest/playtest_plugin.gd`
- [x] T041 [US2] Complete and run `community_park_and_noise`, then record day/night boundaries and simultaneous signed explanations in `test/scenarios/community_park_and_noise.json` and `specs/002-community-happiness-simulation/validation/park-and-noise.md`

**Checkpoint**: Radius, participation, schedules, and stacking are deterministic;
the dashboard and Playtest snapshot explain the largest positive and negative
contributors to each of the four qualities.

---

## Phase 5: User Story 3 - Happiness Grows or Shrinks Population (Priority: P1)

**Goal**: Make persistent resident count authoritative, attract compatible
candidates into legal housing, relocate homeless residents, and remove only
after sustained severe unhappiness or expired relocation grace.

**Independent Test**: Run identical candidate streams against matched and
nuisance-heavy towns for seven days; verify capacity, best-home choice,
thresholds, 24-hour grace, departures, and higher population in the matched town.

### Tests for User Story 3

- [x] T042 [P] [US3] Write failing non-mutating quote tests for every free slot, local/access/participant prediction, best-home canonical tie-breaks, no capacity, and below-threshold rejection in `test/unit/community/test_community_migration.gd`
- [x] T043 [P] [US3] Write failing daily candidate-batch, threshold arrival, slot occupancy, persistent ID, and identical-stream determinism tests in `test/unit/community/test_community_migration.gd`
- [x] T044 [P] [US3] Write failing one-bad-hour, 24-consecutive-hour departure, recovery reset, demolition homelessness, relocation, and relocation-grace tests in `test/unit/community/test_community_migration.gd`
- [x] T045 [P] [US3] Write failing save/load, old-save resident migration, programme persistence, ID/RNG continuation, and scenario-reset tests in `test/unit/community/test_community_persistence.gd`
- [x] T046 [P] [US3] Write failing population-authority and compatibility tests spanning Residential, Satisfaction, People, Workplace, Demand, and CityStats in `test/unit/community/test_community_plugin.gd`

### Implementation for User Story 3

- [x] T047 [US3] Replace capacity-scaled population sources with stable housing-slot enumeration and Community-delegated current population in `plugins/residential/residential_plugin.gd`
- [x] T048 [US3] Implement non-mutating candidate-versus-home prediction across every free housing slot with canonical best-home selection in `plugins/community/community_plugin.gd`
- [x] T049 [US3] Implement fixed-hour daily candidate generation, migration threshold enforcement, bounded batches, arrivals, home occupancy, and migration counters in `plugins/community/community_plugin.gd`
- [x] T050 [US3] Implement hourly departure counters, recovery reset, home demolition to homelessness, deterministic relocation, 24-hour housed/unhoused grace rules, and slot release in `plugins/community/community_plugin.gd`
- [x] T051 [US3] Persist residents, counters, home/programme assignments, generation version/state, and next ID on every authoritative mutation in `plugins/community/community_plugin.gd` and `scripts/data_map.gd`
- [x] T052 [US3] Migrate older capacity-based saves deterministically and guarantee complete community reset from Playtest fresh-map startup in `plugins/community/community_plugin.gd` and `plugins/playtest/playtest_plugin.gd`
- [x] T053 [P] [US3] Delegate legacy normalized satisfaction to average community composite happiness in `plugins/satisfaction/satisfaction_plugin.gd`
- [x] T054 [P] [US3] Feed persistent community population into existing employment, demand, and population stat consumers in `plugins/workplace/workplace_plugin.gd`, `plugins/demand/demand_plugin.gd`, and `plugins/city_stats/city_stats_plugin.gd`
- [x] T055 [US3] Render persistent resident records or a deterministic bounded subset rather than full housing capacity in `plugins/people/people_plugin.gd`
- [x] T056 [US3] Remove double-counting by translating or suppressing legacy Attractiveness contributions where Community Beauty/Liveability effects are authoritative in `plugins/attractiveness/attractiveness_plugin.gd` and affected `data/buildings/**/*.json`
- [x] T057 [US3] Extend Playtest population and satisfaction compatibility fields to agree with authoritative community records in `plugins/playtest/playtest_plugin.gd`
- [x] T058 [US3] Complete and run migration-week and retention-failure scenarios, recording hourly aggregates, arrivals, departures, capacity, reasons, and final populations in `test/scenarios/community_migration_week.json`, `test/scenarios/community_retention_failure.json`, `specs/002-community-happiness-simulation/validation/migration-week.md`, and `specs/002-community-happiness-simulation/validation/retention-failure.md`

**Checkpoint**: Housing supplies slots rather than people; every resident is a
persistent record; migration and departure obey deterministic thresholds and
grace periods; all legacy population consumers agree.

---

## Phase 6: User Story 4 - Population Composition Emerges Without Faction Mechanics (Priority: P2)

**Goal**: Generate broad individual variation around weighted cohort prototypes
and expose neighbourhood composition without cohort approval or forced diversity.

**Independent Test**: Offer Identity-heavy and Freedom-heavy neighbourhoods to
one deterministic candidate stream for seven days and verify measurably different
resident lens distributions while nuisances and participation still override
prototype affinity.

### Tests for User Story 4

- [x] T059 [P] [US4] Write failing cohort-weight, prototype-extreme, within-cohort variation, and broad-general-distribution tests in `test/unit/community/test_community_composition.gd`
- [x] T060 [P] [US4] Write failing tests proving cohort IDs never produce approval scores, diversity bonuses, monoculture penalties, or overrides of personal exposure in `test/unit/community/test_community_composition.gd`

### Implementation for User Story 4

- [x] T061 [US4] Finalize cohort centres, variation, and candidate weights against deterministic fixture expectations in `data/community/cohorts.json`
- [x] T062 [US4] Implement weighted cohort candidate streams and preserve individual perturbation/sensitivity authority in `scripts/community/community_personality_generator.gd`
- [x] T063 [US4] Implement city and neighbourhood personality-distribution aggregation with stable buckets and four-decimal output in `plugins/community/community_plugin.gd`
- [x] T064 [US4] Add the same-stream Identity-versus-Freedom neighbourhood comparison and specialisation assertion to `test/scenarios/community_migration_week.json`
- [x] T065 [US4] Run the seven-day composition comparison and append distribution deltas, override examples, and no-faction/no-diversity-score evidence to `specs/002-community-happiness-simulation/validation/migration-week.md`

**Checkpoint**: Development choices influence who arrives, but every result is
owned by individual residents and no faction or ideology approval system exists.

---

## Phase 7: Polish & Cross-Cutting Verification

**Purpose**: Prove parity, replay determinism, performance, bounded output,
persistence safety, and regression compatibility across all stories.

- [x] T066 [P] Add UI-placement versus Playtest-placement community parity tests, including programme effects and identical hour advancement, in `test/unit/community/test_community_plugin.gd`
- [x] T067 [P] Add resident/effect/history bounds and malformed authored-data hardening tests in `test/unit/community/test_community_models.gd` and `server/src/tools/playtest-tools.test.ts`
- [x] T068 Run every community scenario 10 times per declared seed and record exact resident/snapshot equivalence plus any intentionally ignored volatile fields in `specs/002-community-happiness-simulation/validation/deterministic-replay.md`
- [x] T069 Measure and optimize 500 residents over 168 exact hours to the under-10-second target, recording machine, command, timings, and snapshot sizes in `specs/002-community-happiness-simulation/validation/performance.md`
- [x] T070 Run recursive GUT and all Vitest suites with writable `user://`, then record versions, commands, totals, failures, and SC-008 six-tool contract status in `specs/002-community-happiness-simulation/validation/test-results.md`
- [x] T071 Run matched-seed before/after traces for all changed effect values and record the evidence-led tuning deltas in `specs/002-community-happiness-simulation/validation/migration-week.md` and `specs/002-community-happiness-simulation/validation/park-and-noise.md`
- [x] T072 Add verified setup, authored-effect examples, scenario commands, snapshot interpretation, and balance-trace workflow to `specs/002-community-happiness-simulation/quickstart.md`

**Final checkpoint**: SC-001 through SC-008 have recorded evidence; the same
inputs replay identically; performance and collection bounds pass; existing
city-building and six-tool Playtest contracts remain green.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 - Setup**: No dependencies.
- **Phase 2 - Foundation**: Depends on Phase 1 and blocks every user story.
- **Phase 3 - US1**: Depends on Foundation and is the smallest useful MVP.
- **Phase 4 - US2**: Depends on US1's resident interpretation and pure evaluator.
- **Phase 5 - US3**: Depends on US1 personality/happiness and US2 spatial/participation predictions.
- **Phase 6 - US4**: Depends on US3 candidate migration and distribution snapshots.
- **Phase 7 - Polish**: Depends on all selected stories.

### User Story Dependency Graph

```text
Setup → Foundation → US1 personality interpretation (MVP)
                           ↓
                  US2 effect web/explanations
                           ↓
                  US3 migration/retention
                           ↓
                  US4 emergent composition
                           ↓
                  cross-cutting verification
```

### Within Each User Story

- Write the listed tests first and observe the intended failure.
- Implement pure data/math helpers before plugin lifecycle behavior.
- Implement plugin authority before compatibility facades or presentation.
- Pass isolated unit tests before deterministic and live scenarios.
- Record checkpoint evidence before starting a dependent story.

## Parallel Opportunities

### Setup and Foundation

- T002, T003, and T004 author independent data/scenario files.
- T005 and T006 specify independent model and catalog seams.
- T017 can prepare test fixtures while T007-T010 implement production helpers.

### User Story 1

```text
T019: personality generation specification
T020: effect math specification
T025-T026: independent theatre and night-venue content
```

After T022 and T023 stabilize, T024 can integrate both while content fixtures are
authored independently.

### User Story 2

```text
T029-T030: pure evaluator scope/schedule/stacking tests
T031-T032: assignment and building integration tests
T033: Playtest snapshot contract tests
T037-T038: independent park and industrial authored content
```

### User Story 3

```text
T042-T046: migration, persistence, and compatibility specifications
T053: Satisfaction compatibility facade
T054: Workplace/Demand/CityStats population consumers
```

### User Story 4

T059 and T060 can specify statistical generation and forbidden faction/diversity
behavior independently before T061-T063 implement them.

## Implementation Strategy

### MVP First

1. Complete Setup and Foundation.
2. Complete User Story 1 through T028.
3. Stop and validate deterministic plays-versus-rock personality contrast.
4. Demo four qualities plus simultaneous positive/negative explanations before
   adding migration complexity.

### Incremental Delivery

1. **US1**: residents interpret tagged and neutral effects.
2. **US2**: places form a spatial, scheduled, participant-aware effect web.
3. **US3**: happiness becomes persistent population growth and retention.
4. **US4**: candidate compatibility produces emergent neighbourhood character.
5. **Polish**: lock replay, performance, contracts, and balance traces.

## Notes

- `[P]` means different files or truly independent preparation, not merely tasks
  that could be assigned simultaneously after hidden dependencies.
- Cohort data never grants a resident a shared approval value.
- No task adds a seventh Playtest MCP tool.
- Exact balance values are accepted only with matched-seed before/after traces.
- Git staging, commits, branches, merges, and pushes require a separate explicit request.
