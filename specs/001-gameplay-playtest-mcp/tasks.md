# Tasks: Gameplay Playtest MCP

**Input**: Design documents from `specs/001-gameplay-playtest-mcp/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/mcp-tools.md`, `quickstart.md`

**Tests**: Required by the feature specification and project constitution. Write
the listed tests first, verify that they fail for the intended missing behavior,
then implement the corresponding task.

**Organization**: Tasks are grouped by user story so each gameplay capability
can be implemented and verified as an increment. User Story 1 is the MVP.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with adjacent tasks because it touches different files and has no dependency on their incomplete work
- **[Story]**: User story from `spec.md`
- Every task names its exact target file or directory

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish first-class locations for game-side playtesting, scenarios,
and the small MCP entry point without changing gameplay yet.

- [x] T001 Create the Playtest plugin, scenario, and test directory skeletons at `plugins/playtest/`, `test/unit/playtest/`, `test/unit/builder/`, `test/unit/day_night/`, and `test/scenarios/`
- [x] T002 [P] Add the `playtest-index.ts` build entry and a `playtest:start` script without registering tools yet in `server/src/playtest-index.ts` and `server/package.json`
- [x] T003 [P] Add shared TypeScript contract types and schema-version constant in `server/src/playtest/playtest-contract.ts`
- [x] T004 [P] Add shared GDScript action status and stable reason-code constants in `scripts/playtest_action_result.gd`

**Checkpoint**: The new source locations compile as empty infrastructure and do
not alter normal game startup or release behavior.

---

## Phase 2: Foundational (Blocking Gameplay Seams)

**Purpose**: Create one atomic gameplay truth and one deterministic hour boundary
before exposing any external playtest action.

**⚠️ CRITICAL**: No user-story implementation starts until this phase passes.

### Atomic placement and demolition

- [x] T005 [P] Write failing unit coverage for non-mutating placement quotes and reason details in `test/unit/demand/test_demand_buckets.gd`
- [x] T006 [P] Write failing unit coverage for non-mutating cash quotes and insufficient-cash details in `test/unit/economy/test_economy.gd`
- [x] T007 Implement detailed non-mutating `quote_placement` behavior while preserving existing `can_afford` and `try_spend` callers in `plugins/demand/demand_plugin.gd`
- [x] T008 Implement detailed non-mutating `quote_cash` behavior while preserving existing cash APIs in `plugins/economy/economy_plugin.gd`
- [x] T009 Write failing command tests for success, outside land, occupied footprint, replacement-required, insufficient cash, threshold, insufficient demand, unmet prerequisites, unique duplication, unknown building, multi-cell rotation, and demolition-by-satellite-cell in `test/unit/builder/test_builder_commands.gd`
- [x] T010 Add a non-mutating placement evaluation that resolves concrete catalog ID, seeded pool variant, rotated footprint, occupancy, land, unique rules, cash quote, and demand quote in `scripts/builder.gd`
- [x] T011 Refactor placement into an atomic public `try_place_building` command that validates all gates before spending and returns structured outcomes in `scripts/builder.gd`
- [x] T012 Refactor demolition into a public `try_demolish_cell` command that resolves any footprint cell and returns a structured outcome in `scripts/builder.gd`
- [x] T013 Route existing mouse placement, road painting, replacement confirmation, and mouse demolition through the new public commands without changing player-visible behavior in `scripts/builder.gd`
- [x] T014 Add regression coverage proving rejected placement never consumes cash or demand and applied placement emits exactly one `structure_placed` event in `test/unit/builder/test_builder_commands.gd`

### Exact simulation time

- [x] T015 [P] Write failing tests for manual mode, zero-hour advance, one-hour advance, day rollover, exact event count, and the 1000-hour bound in `test/unit/day_night/test_manual_advance.gd`
- [x] T016 Extract one chronological hour-transition method used by real-time processing and add exact manual `advance_hours` behavior in `plugins/day_night/day_night_plugin.gd`
- [x] T017 Add defensive null handling for lighting and UI references so headless hour tests do not emit the existing DayNight nil-property errors in `plugins/day_night/day_night_plugin.gd`

### Canonical fresh state

- [x] T018 [P] Define the story-neutral `fresh_city` scenario, starting resources, empty-map rule, starter mask rule, clock mode, and narrative mode in `test/scenarios/fresh_city.json`
- [x] T019 Add a public fresh-map application method that clears registries, applies a new `DataMap`, resets building IDs, and emits the existing map-load reconciliation path in `scripts/builder.gd`

**Checkpoint**: Builder command tests and DayNight manual-time tests pass; UI
actions use the same public commands; no failed placement partially mutates
resources; a canonical fresh city can be applied without a user save.

---

## Phase 3: User Story 1 - Play Through the Real City-Building Loop (Priority: P1) 🎯 MVP

**Goal**: Start a fresh session, observe the live city, place and demolish through
real rules, advance one hour, and receive structured results through a small MCP.

**Independent Test**: Start `fresh_city`, inspect state, place one affordable
building, advance one hour, demolish it, and prove each state matches the
equivalent normal gameplay command.

### Tests for User Story 1

- [x] T020 [P] [US1] Write failing Playtest session-start and readiness tests in `test/unit/playtest/test_playtest_plugin.gd`
- [x] T021 [P] [US1] Write failing normalized city-snapshot tests covering simulation, cash, population, output, satisfaction, attractiveness, demand axes, land count, structures, and progression in `test/unit/playtest/test_playtest_plugin.gd`
- [x] T022 [P] [US1] Write failing Playtest place/demolish delegation and UI-command parity tests in `test/unit/playtest/test_playtest_plugin.gd`
- [x] T023 [P] [US1] Write failing MCP schema tests for `playtest_start`, `playtest_get_state`, `playtest_place`, `playtest_demolish`, and `playtest_advance` in `server/src/tools/playtest-tools.test.ts`

### Implementation for User Story 1

- [x] T024 [US1] Implement Playtest plugin dependency injection, debug-build activation, session lifecycle, and Builder discovery in `plugins/playtest/playtest_plugin.gd`
- [x] T025 [US1] Register the Playtest plugin without activating it in non-debug builds in `scripts/plugin_manager.gd`
- [x] T026 [US1] Implement normalized `CitySnapshot`, stable building ordering, JSON-safe coordinates, and state hashing in `plugins/playtest/playtest_plugin.gd`
- [x] T027 [US1] Implement semantic start, state, place, demolish, and advance dispatch that delegates to Builder and DayNight in `plugins/playtest/playtest_plugin.gd`
- [x] T028 [US1] Add a single editor-side `city_playtest_command` adapter using the existing runtime request/response IPC in `addons/godot_mcp/commands/playtest_commands.gd`
- [x] T029 [US1] Register the playtest editor command class in `addons/godot_mcp/command_router.gd`
- [x] T030 [US1] Add runtime `city_playtest` request routing that finds the Playtest plugin and delegates `{operation, params}` without accepting arbitrary code in `addons/godot_mcp/mcp_game_inspector_service.gd`
- [x] T031 [US1] Implement the five US1 MCP tool schemas, gameplay-rejection response mapping, and infrastructure-error mapping in `server/src/tools/playtest-tools.ts`
- [x] T032 [US1] Register the US1 tools on the separate stdio server and reuse `GodotConnection` without registering general Godot tools in `server/src/playtest-index.ts`
- [x] T033 [US1] Add `city-playtest` beside `godot-mcp-pro` using the built playtest entry in `.mcp.json`
- [x] T034 [US1] Add a live smoke harness for start → state → place → advance → demolish in `server/src/tools/playtest-live.test.ts`
- [x] T035 [US1] Run the User Story 1 independent test through the live Godot MCP and record the command/result evidence in `specs/001-gameplay-playtest-mcp/validation/us1-smoke.md`

**Checkpoint**: The general MCP launches/debugs the game; the separate MCP shows
only semantic city tools; the complete five-command play loop works without UI
coordinates or direct state mutation.

---

## Phase 4: User Story 2 - Run Deterministic Balance Experiments (Priority: P1)

**Goal**: Replay controlled sessions with exact time, deterministic pooled
variants, idempotent actions, ordered traces, and equivalent final snapshots.

**Independent Test**: Run the same seeded scenario and action list twice, retry
one successful request ID in each run, and verify identical variants, milestones,
hour counts, action outcomes, and balance-relevant final state hashes.

### Tests for User Story 2

- [x] T036 [P] [US2] Write failing seeded pool-selection tests independent of global random state in `test/unit/palette/test_palette.gd`
- [x] T037 [P] [US2] Write failing request-id idempotency, expected-sequence conflict, bounded-cache, and ordered-trace tests in `test/unit/playtest/test_playtest_plugin.gd`
- [x] T038 [P] [US2] Write failing repeated-scenario equivalence and normalized-hash tests in `test/unit/playtest/test_playtest_replay.gd`
- [x] T039 [P] [US2] Add MCP contract tests for duplicate requests, gameplay rejections versus MCP errors, zero-hour advance, and maximum-hour validation in `server/src/tools/playtest-tools.test.ts`

### Implementation for User Story 2

- [x] T040 [US2] Replace global `pick_random` use with an injectable/session-seeded RNG while retaining normal random play defaults in `plugins/palette/palette_plugin.gd`
- [x] T041 [US2] Implement per-session request-id caching, expected-sequence guards, and bounded eviction in `plugins/playtest/playtest_plugin.gd`
- [x] T042 [US2] Implement ordered trace entries for actions, rejections, time advances, observations, state hashes, and discovered milestones in `plugins/playtest/playtest_plugin.gd`
- [x] T043 [US2] Implement scenario loading, seed application, manual clock activation, and narrative-presentation suppression in `plugins/playtest/playtest_plugin.gd`
- [x] T044 [US2] Add explicit session seed and narrative presentation toggles that do not disable city-system signals in `plugins/dialogue/dialogue_plugin.gd` and `plugins/inbox/inbox_plugin.gd`
- [x] T045 [US2] Add exact requested/emitted hour counts and pre/post absolute-hour details to advance outcomes in `plugins/playtest/playtest_plugin.gd`
- [x] T046 [US2] Add a deterministic replay runner for JSON scenario/action fixtures in `test/scenarios/run_replay.gd`
- [x] T047 [US2] Run ten identical-seed replays and record equivalence evidence and ignored volatile fields in `specs/001-gameplay-playtest-mcp/validation/deterministic-replay.md`

**Checkpoint**: Ten same-input runs match, retries never apply twice, exact hours
are emitted, and story presentation cannot block core balance experiments.

---

## Phase 5: User Story 3 - Understand Available Choices and Rejections (Priority: P2)

**Goal**: Let an AI discover every player-facing build choice, its variants and
costs, and stable global or location-specific reasons why an action is blocked.

**Independent Test**: From a fresh city, request all choices, perform one legal
placement, and provoke each defined rejection class while confirming rejected
state hashes remain unchanged.

### Tests for User Story 3

- [x] T048 [P] [US3] Write failing palette projection tests for pools, standalone entries, hidden road-support tiles, variants, category filtering, and available-only filtering in `test/unit/playtest/test_playtest_choices.gd`
- [x] T049 [P] [US3] Write failing availability-reason tests for cash, threshold, demand, prerequisites, and unique-already-placed in `test/unit/playtest/test_playtest_choices.gd`
- [x] T050 [P] [US3] Write failing location-specific rejection tests for land, occupancy, replacement, rotated footprint, unknown ID, and empty demolition in `test/unit/builder/test_builder_commands.gd`
- [x] T051 [P] [US3] Add `playtest_get_choices` request/response and category-validation contract tests in `server/src/tools/playtest-tools.test.ts`

### Implementation for User Story 3

- [x] T052 [US3] Expose read-only palette entry enumeration without exposing auto-tiler support structures in `plugins/palette/palette_plugin.gd`
- [x] T053 [US3] Add detailed read-only unlock evaluation returning threshold, prerequisites, and placed state in `plugins/unique_registry/unique_registry_plugin.gd`
- [x] T054 [US3] Project sorted `BuildingChoice` records with variants, footprints, cash, demand, uniqueness, availability, and reason arrays in `plugins/playtest/playtest_plugin.gd`
- [x] T055 [US3] Complete stable Builder-to-Playtest rejection mapping for every code in `specs/001-gameplay-playtest-mcp/data-model.md` within `plugins/playtest/playtest_plugin.gd`
- [x] T056 [US3] Register and implement `playtest_get_choices` as the sixth and final MCP tool in `server/src/tools/playtest-tools.ts` and `server/src/playtest-index.ts`
- [x] T057 [US3] Run the rejection matrix against the live game and record UI-command parity and unchanged-state evidence in `specs/001-gameplay-playtest-mcp/validation/rejection-matrix.md`

**Checkpoint**: The agent can reason from public choices and stable outcomes
without reading source code, private fields, toasts, or debug logs.

---

## Phase 6: User Story 4 - Compare Gameplay Tuning (Priority: P2)

**Goal**: Produce a reusable early-city baseline and compare equivalent traces
before and after a tuning change without inventing a universal “fun” score.

**Independent Test**: Run `early_city_baseline` against two controlled tuning
fixtures and produce a report showing milestone, resource, demand, structure,
rejection, and failure-condition deltas.

### Tests for User Story 4

- [x] T058 [P] [US4] Write failing scenario schema and success/soft-failure/hard-failure condition tests in `server/src/playtest/scenario.test.ts`
- [x] T059 [P] [US4] Write failing trace persistence, compatibility, and bounded-size tests in `server/src/playtest/trace-store.test.ts`
- [x] T060 [P] [US4] Write failing compatible-trace comparison and mismatched-scenario/seed rejection tests in `server/src/playtest/trace-comparison.test.ts`

### Implementation for User Story 4

- [x] T061 [US4] Define the canonical early-game start, bounds, success/failure conditions, and milestone set in `test/scenarios/early_city_baseline.json`
- [x] T062 [US4] Implement scenario schema validation and condition evaluation in `server/src/playtest/scenario.ts`
- [x] T063 [US4] Implement immutable local completed-trace writing and normalized trace reading under `user://playtests/` through `plugins/playtest/playtest_plugin.gd`
- [x] T064 [US4] Implement compatible-trace comparison for milestone hours, core resources, demand axes, building counts, choices, rejections, and terminal conditions in `server/src/playtest/trace-comparison.ts`
- [x] T065 [US4] Add a `playtest:compare` command for two local trace files without adding a seventh MCP tool in `server/src/playtest/compare-cli.ts` and `server/package.json`
- [ ] T066 [US4] Run the baseline with two controlled tuning fixtures and record the resulting evidence-led comparison in `specs/001-gameplay-playtest-mcp/validation/balance-comparison.md`

**Checkpoint**: A designer can see what changed between equivalent runs while
retaining human judgment about whether the change is more interesting.

---

## Phase 7: Polish & Cross-Cutting Verification

**Purpose**: Prove reliability, performance, safety, and usability across all
stories before using the bridge to tune the game.

- [x] T067 [P] Add snapshot-size bounds, trace/cache limits, sensitive-path rejection, and localhost/development-only assertions in `server/src/tools/playtest-tools.test.ts` and `test/unit/playtest/test_playtest_plugin.gd`
- [x] T068 [P] Add structured playtest lifecycle and failure logging without logging entire routine snapshots in `plugins/playtest/playtest_plugin.gd` and `server/src/playtest-index.ts`
- [x] T069 Confirm a release-feature launch does not register or activate the Playtest plugin in `test/unit/playtest/test_playtest_release_gate.gd`
- [x] T070 Measure and optimize exact 100-hour advancement to meet the 10-second target, recording results in `specs/001-gameplay-playtest-mcp/validation/performance.md`
- [x] T071 Run all TypeScript/Vitest and recursive GUT suites in a writable-`user://` environment and record commands, versions, totals, and failures in `specs/001-gameplay-playtest-mcp/validation/test-results.md`
- [x] T072 Run 20 consecutive standard scenario sessions across the declared seed set and record connection, duplicate, manual-input, and unclassified-failure counts in `specs/001-gameplay-playtest-mcp/validation/reliability.md`
- [ ] T073 Capture general Godot MCP screenshots at fresh-city, first-positive-economy, tier-two-unlock, and starter-land-pressure milestones and index them in `specs/001-gameplay-playtest-mcp/validation/visual-review.md`
- [x] T074 Execute every step in `specs/001-gameplay-playtest-mcp/quickstart.md` and update the guide only for verified command or expectation corrections
- [ ] T075 Freeze the first unchanged early-city baseline trace location and document the balance-iteration protocol in `specs/001-gameplay-playtest-mcp/validation/baseline.md`

**Final checkpoint**: All success criteria SC-001 through SC-008 have recorded
evidence. The playtest MCP is trustworthy; actual gameplay tuning can begin as a
subsequent evidence-led iteration.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 — Setup**: No dependencies.
- **Phase 2 — Foundational**: Depends on Phase 1 and blocks every user story.
- **Phase 3 — US1**: Depends on Phase 2 and is the functional MVP.
- **Phase 4 — US2**: Depends on US1's session/action loop and the foundational clock seam.
- **Phase 5 — US3**: Depends on US1's snapshots/action results; its choice projection can overlap late US2 work after session contracts stabilize.
- **Phase 6 — US4**: Depends on US2 deterministic traces and US3 choice/rejection classification.
- **Phase 7 — Polish**: Depends on all selected stories.

### User Story Dependency Graph

```text
Setup → Foundation → US1 semantic play loop
                          ├──→ US2 deterministic replay ──┐
                          └──→ US3 explained choices ────┼──→ US4 comparison
                                                       └──→ final verification
```

### Within Each User Story

- Write the listed tests and verify their intended failure before implementation.
- Implement the game-side domain boundary before editor/runtime IPC.
- Implement IPC before MCP registration.
- Pass isolated unit/contract tests before the live MCP scenario.
- Record checkpoint evidence before starting dependent story work.

## Parallel Opportunities

### Setup and Foundation

- T002, T003, and T004 touch separate TypeScript/GDScript files.
- T005, T006, T009, T015, and T018 are independent test/fixture preparation.
- Demand and Economy quote work can proceed independently before Builder consumes both.

### User Story 1

```text
T020-T022: Playtest GUT specifications in test/unit/playtest/test_playtest_plugin.gd
T023: MCP boundary specifications in server/src/tools/playtest-tools.test.ts
```

After T027 defines the game response shape, the editor adapter work (T028-T030)
and TypeScript registration work (T031-T032) can proceed in parallel.

### User Story 2

```text
T036: seeded palette tests
T037-T038: game-side idempotency/replay tests
T039: MCP retry/error contract tests
```

T040 can proceed alongside T041-T042 after the seed/session shape is fixed.

### User Story 3

```text
T048-T050: choice, availability, and location-rejection GUT tests
T051: MCP get-choices contract tests
```

T052 and T053 touch independent plugins before T054 consumes both.

### User Story 4

```text
T058: scenario schema tests
T059: trace-store tests
T060: comparison tests
```

T061, T063, and T064 touch separate fixture/game/server concerns after their
respective tests exist.

## Implementation Strategy

### MVP First

1. Complete Setup and Foundation.
2. Complete US1 through T035.
3. Stop and demonstrate one real semantic play loop through the live game.
4. Do not begin balance tuning yet: deterministic replay remains required before
   experimental results are trustworthy.

### Trustworthy Playtest Increment

1. Add US2 deterministic sessions and idempotency.
2. Add US3 explained choices/rejections.
3. Run the ten-replay and rejection-matrix gates.
4. At this point the MCP can begin exploratory play, even before trace comparison tooling.

### Balance Evidence Increment

1. Add US4 scenarios, persistence, and comparison.
2. Complete performance, reliability, and visual checkpoints.
3. Freeze the unchanged baseline.
4. Start balance tuning as a separate iteration using one hypothesis and one
   before/after scenario comparison at a time.

## Notes

- `[P]` means the task is safe to execute concurrently only after its phase prerequisites are satisfied.
- Tests precede implementation because parity and determinism are non-negotiable for balance evidence.
- Do not create a second gameplay rules implementation in the Playtest plugin or TypeScript server.
- Do not add arbitrary script execution, camera control, property mutation, or file editing to `city-playtest`.
- Do not change authored balance values while building the bridge; first freeze a trustworthy unchanged baseline.
- Git operations remain user-controlled and are not implied by any task checkpoint.
