# Tasks: Reachable First-Patron Progression

**Input**: Design documents from `specs/005-reachable-first-patron/`

**Tests**: Required by the feature specification and constitution. Test tasks
precede the implementation they constrain.

## Phase 1: Setup and Baseline

**Purpose**: Freeze the current failure and create reusable progression fixtures.

- [X] T001 Record the unchanged reachability calculation, current gate values, and failing route boundary in `specs/005-reachable-first-patron/validation/baseline-before.md`
- [X] T002 [P] Add stable in-memory character, patron, unique, and bucket fixtures in `test/unit/progression/progression_test_fixtures.gd`
- [X] T003 [P] Add the versioned first-patron scenario skeleton and ordered action schema in `test/scenarios/first_patron_reachable.json`

---

## Phase 2: Foundational Progression Contracts

**Purpose**: Add shared state fields, reason vocabulary, and dependency direction required by every story.

**Critical**: Complete before user-story implementation.

- [X] T004 Add `demand_totals`, `pending_dialogue_event_ids`, and `patron_donations_applied` defaults to `scripts/data_map.gd`
- [X] T005 Add stable progression and dialogue rejection reason constants to `scripts/playtest_action_result.gd`
- [X] T006 Retain authored source paths in catalog summaries and character/patron definitions in `plugins/building_catalog/building_catalog_plugin.gd`, `plugins/character_system/character_system_plugin.gd`, and `plugins/patron_system/patron_system_plugin.gd`
- [X] T007 Restructure CharacterSystem, PatronSystem, UniqueRegistry, and BuildableArea dependency declarations without cycles in `plugins/character_system/character_system_plugin.gd`, `plugins/patron_system/patron_system_plugin.gd`, `plugins/unique_registry/unique_registry_plugin.gd`, and `plugins/buildable_area/buildable_area_plugin.gd`

**Checkpoint**: PluginManager starts with a deterministic acyclic progression order.

---

## Phase 3: User Story 1 — Complete the First Patron (Priority: P1) 🎯 MVP

**Goal**: A fresh legal scenario completes all three requests, the Theatre, and the 192-cell donation.

**Independent Test**: Run `scripts/run_first_patron_scenario.gd` from a fresh map; every action is accepted through public gameplay commands and final patron/land assertions pass.

### Tests for User Story 1

- [X] T008 [P] [US1] Add placed-bucket tier and stable evidence tests in `test/unit/building_catalog/test_building_catalog.gd`
- [X] T009 [P] [US1] Replace the ARRIVED satisfaction expectation and add dual-condition, sorted-arrival, monotonicity, and reveal reconciliation tests in `test/unit/character_system/test_character_system.gd`
- [X] T010 [P] [US1] Add story-lock reason and refresh-transition tests in `test/unit/unique_registry/test_unique_registry.gd`
- [X] T011 [P] [US1] Add synchronous donation receipt, overlap, completion, and duplicate-reconciliation tests in `test/unit/buildable_area/test_buildable_area.gd` and `test/unit/patron_system/test_patron_system.gd`
- [X] T012 [P] [US1] Add visible/headless dialogue resolution parity and pending acknowledgement tests in `test/unit/dialogue/test_dialogue.gd` and `test/unit/inbox/test_inbox.gd`
- [X] T013 [P] [US1] Add resolve-dialogue, progression snapshot, milestone, and hash tests in `test/unit/playtest/test_playtest_plugin.gd` and `test/unit/playtest/test_playtest_replay.gd`

### Implementation for User Story 1

- [X] T014 [US1] Implement canonical placed-bucket tier projection in `plugins/building_catalog/building_catalog_plugin.gd`
- [X] T015 [US1] Implement character dual-gate evaluation, stable ordering, forward-only transitions, and request reconciliation in `plugins/character_system/character_system_plugin.gd`
- [X] T016 [US1] Compose character and patron story gates into the canonical unique decision and refresh it on progression changes in `plugins/unique_registry/unique_registry_plugin.gd`
- [X] T017 [US1] Implement idempotent `apply_donation` with receipts in `plugins/buildable_area/buildable_area_plugin.gd`
- [X] T018 [US1] Implement patron availability/completion reconciliation and synchronous donation application in `plugins/patron_system/patron_system_plugin.gd`
- [X] T019 [US1] Persist pending dialogue IDs and expose deterministic authored-event lookup/acknowledgement in `plugins/event_system/event_system_plugin.gd` and `plugins/inbox/inbox_plugin.gd`
- [X] T020 [US1] Refactor visible and headless event completion through one semantic resolver in `plugins/dialogue/dialogue_plugin.gd`
- [X] T021 [US1] Add the semantic `resolve_dialogue` action, complete progression snapshot, and ordered milestone records in `plugins/playtest/playtest_plugin.gd`
- [X] T022 [US1] Apply the trace-backed reachability corrections in `data/characters/aristocrat_industrial.json`, `data/community/balance.json`, and `plugins/demand/demand_plugin.gd`, then synchronize `data/events/_manifest.json`
- [X] T023 [US1] Fill the legal fixed-coordinate action list and milestone assertions in `test/scenarios/first_patron_reachable.json`
- [X] T024 [US1] Implement the data-driven headless runner and normalized evidence output in `scripts/run_first_patron_scenario.gd`
- [X] T025 [US1] Add the real full-stack fresh-town acceptance test in `test/integration/progression/test_first_patron_flow.gd`

**Checkpoint**: User Story 1 completes without debug state mutation or presentation content.

---

## Phase 4: User Story 2 — See Story Buildings in the Intended Order (Priority: P1)

**Goal**: Wants and the Theatre remain visible, explainable, and unselectable until their story states permit them.

**Independent Test**: At each progression boundary, UniqueRegistry, Builder, Palette/radial projection, and Playtest choices return the same availability and reasons; rejected placement changes no state.

### Tests for User Story 2

- [X] T026 [P] [US2] Add zero-mutation want/landmark rejection and replacement-prerequisite tests in `test/unit/builder/test_builder_commands.gd`
- [X] T027 [P] [US2] Add player-facing story-lock label tests in `test/unit/palette/test_palette.gd`
- [X] T028 [P] [US2] Add radial/Palette/Builder/Playtest gate parity coverage in `test/integration/progression/test_progression_parity.gd`

### Implementation for User Story 2

- [X] T029 [US2] Make Builder consume the canonical unique decision, preserve all evidence, and evaluate planned replacement removals in `scripts/builder.gd`
- [X] T030 [US2] Render canonical want, patron, tier, demand, and prerequisite labels from detached decisions in `plugins/palette/palette_plugin.gd`
- [X] T031 [US2] Expose the complete canonical decision through radial entries and Playtest choices in `plugins/palette/palette_plugin.gd` and `plugins/playtest/playtest_plugin.gd`

**Checkpoint**: Every public selection surface agrees and locked actions are atomic no-ops.

---

## Phase 5: User Story 3 — Recover from Ordering and Legacy-Save Mismatches (Priority: P1)

**Goal**: Real saves at every progression boundary resume to one valid state without duplicated events or land.

**Independent Test**: Resource-save fixtures for every boundary reload with cache bypass, preserve accrued demand and pending dialogue, and reconcile requests, landmark completion, contributors, and donation exactly once.

### Tests for User Story 3

- [X] T032 [P] [US3] Add accrued-demand round-trip and fulfilled rebuild tests in `test/unit/demand/test_demand_buckets.gd`
- [X] T033 [P] [US3] Add map-loaded pending-event reconstruction and count-deduplication tests in `test/unit/event_system/test_event_system.gd` and `test/unit/inbox/test_inbox.gd`
- [X] T034 [US3] Add real `ResourceSaver`/`ResourceLoader.CACHE_MODE_IGNORE` boundary fixtures in `test/integration/progression/test_progression_save_load.gd`

### Implementation for User Story 3

- [X] T035 [US3] Synchronize and restore accrued demand totals before fulfilled-capacity reconciliation in `plugins/demand/demand_plugin.gd`
- [X] T036 [US3] Reconcile progression and pending events after every map load without replaying resolved effects in `plugins/character_system/character_system_plugin.gd`, `plugins/patron_system/patron_system_plugin.gd`, and `plugins/event_system/event_system_plugin.gd`
- [X] T037 [US3] Add canonical save/apply helpers needed by progression boundary tests without introducing lifecycle UI in `scripts/builder.gd`

**Checkpoint**: Every pre/post progression boundary survives a cold resource round-trip.

---

## Phase 6: User Story 4 — Understand Current Progression (Priority: P2)

**Goal**: The Patron drawer and automated snapshot identify the next action using current and required authored values.

**Independent Test**: At every canonical milestone the Dashboard, Palette, and Playtest snapshot show the same next subject, values, tier evidence, and story-building reason.

### Tests for User Story 4

- [X] T038 [P] [US4] Add current/required demand, tier, authored-name, and next-action tests in `test/unit/dashboard/test_dashboard.gd`
- [X] T039 [P] [US4] Add progression-complete snapshot serialization tests in `test/unit/playtest/test_playtest_choices.gd`

### Implementation for User Story 4

- [X] T040 [US4] Make Dashboard consume CharacterSystem and PatronSystem projections for lines and next-step hints in `plugins/dashboard/dashboard_plugin.gd`
- [X] T041 [US4] Include canonical next-step and stable authored labels in the progression snapshot in `plugins/playtest/playtest_plugin.gd`

**Checkpoint**: Player and automation can explain every next progression gate.

---

## Phase 7: Polish and Cross-Cutting Verification

**Purpose**: Validate content references, external contracts, determinism, regressions, and presentation evidence.

- [X] T042 [P] Add repository-wide progression reference validation with file and field errors in `scripts/progression_content_validator.gd` and `test/unit/progression/test_progression_content_validator.gd`
- [X] T043 [P] Strengthen matching authoring validations and tests in `tools/data_editor/src/validators.ts`, `tools/data_editor/src/validators.test.ts`, `tools/data_editor/src/buildings/validation.ts`, and `tools/data_editor/src/buildings/validation.test.ts`
- [X] T044 [P] Extend server schemas and source tests for resolve-dialogue and progression snapshots in `server/src/playtest/playtest-contract.ts`, `server/src/tools/playtest-tools.ts`, and `server/src/tools/playtest-tools.test.ts`
- [X] T045 Add direct runtime first-patron contract coverage in `server/src/tools/first-patron-runtime-live.test.ts`
- [X] T046 Run the canonical scenario ten times and record equivalent milestones/hashes in `specs/005-reachable-first-patron/validation/deterministic-replay.md`
- [X] T047 Run Godot, Player UI, server, and data-editor gates and record results in `specs/005-reachable-first-patron/validation/test-results.md`
- [X] T048 Capture and inspect 1280×720 canonical milestone frames via `scripts/capture_first_patron_validation.gd` and `specs/005-reachable-first-patron/validation/screenshots/`
- [X] T049 Complete the save/load boundary result matrix in `specs/005-reachable-first-patron/validation/save-load-matrix.md`
- [X] T050 Re-run `git diff --check` and verify spec FR/SC coverage against `specs/005-reachable-first-patron/spec.md`

---

## Dependencies and Execution Order

### Phase dependencies

- Phase 1 has no dependencies.
- Phase 2 depends on Phase 1 and blocks every user story.
- User Story 1 depends on Phase 2 and is the MVP.
- User Story 2 depends on User Story 1's canonical unique decision.
- User Story 3 depends on User Story 1's transition and donation contracts.
- User Story 4 depends on the projections delivered by User Stories 1 and 2.
- Phase 7 depends on all four stories.

### User-story dependency graph

```text
Foundations → US1 → US2
              ├──→ US3
              └──→ US4 (after US2 projection labels)
US2 + US3 + US4 → Polish and verification
```

### Parallel examples

- In US1, tier/character tests, unique tests, donation tests, dialogue tests, and
  Playtest tests touch separate suites and can be authored in parallel.
- In US2, Builder, Palette, and parity test preparation use separate files after
  the canonical decision exists.
- In US3, Demand persistence tests and Event/Inbox reconstruction tests are
  independent before the combined resource fixture.
- In Phase 7, runtime validation, data-editor validation, and server schema work
  are independent until final gates.

## Implementation Strategy

### MVP first

Complete Phases 1–3. This proves the first legal patron/donation route before UI
polish, legacy breadth, and external tooling.

### Incremental delivery

1. Freeze the impossible baseline.
2. Establish shared derived state and reason contracts.
3. Complete the fresh-town route.
4. Make all selection surfaces converge.
5. Prove cold save/load reconciliation.
6. Improve player explanation.
7. Run full regression, determinism, and visual gates.

### Task format validation

All 50 tasks use the required checkbox, sequential ID, optional parallel marker,
user-story label where required, imperative description, and concrete file path.

---

## Phase 8: Convergence

- [X] T051 Reject unknown and incomplete progression bucket sets with actionable file and field errors in `scripts/progression_content_validator.gd`, `test/unit/progression/test_progression_content_validator.gd`, `tools/data_editor/src/validators.ts`, and `tools/data_editor/src/validators.test.ts` per FR-019 (partial)
- [X] T052 Add an every-milestone parity matrix across Palette/radial, Dashboard/Patron drawer, Builder gameplay decisions, and Playtest progression projections in `test/integration/progression/test_progression_parity.gd` per SC-003 and FR-015 (partial)
- [X] T053 Add a deterministic focused progression-refresh benchmark with a 16.7 ms ceiling in `test/unit/progression/test_progression_refresh_performance.gd` per plan: performance goals (missing)
