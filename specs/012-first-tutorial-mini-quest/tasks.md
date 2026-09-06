---
description: "Implementation tasks for the first tutorial mini-quest"
---

# Tasks: First Tutorial Mini-Quest

**Input**: Design documents from `specs/012-first-tutorial-mini-quest/`

**Tests**: Required by the feature brief and project constitution. Each phase closes
with independently executable evidence.

## Phase 1: Baseline and state contracts

- [x] T001 Record the focused pre-change result and unrelated known failure in `validation/baseline-before.md`.
- [x] T002 Add failing normalization, step-order, receipt-idempotence, and malformed legacy-state tests under `test/unit/opening_tutorial/`.
- [x] T003 Add failing canonical evidence tests for rooted-road union, stable category/pool identity, footprint distance, authored impact radii, assignment identity, and detached stable sorting.
- [x] T004 Add failing projection/copy tests for B01–B18, all blocker variants, unknown-copy rejection, and placeholder labelling.
- [x] T005 Add failing persistence and completion-handoff integration tests, including receipt-before-signal re-entry and load non-re-emission.

## Phase 2: State and canonical evidence foundation

- [x] T006 Add the versioned `opening_tutorial_state` save field to `scripts/data_map.gd`.
- [x] T007 Register `OpeningTutorial` in `scripts/plugin_manager.gd` with only the canonical dependencies in `plan.md`.
- [x] T008 Implement state normalization, ordered semantic steps, immutable receipt writing, diagnostics, detached getters, and projection revisions in `plugins/opening_tutorial/opening_tutorial_plugin.gd`.
- [x] T009 Implement stable RoadNetwork/catalog evidence for Town Hall plus registry/catalog evidence for nature IDs, tier-one homes/workplaces/shops, anchors, and footprints.
- [x] T010 Implement rooted-road union and Town Hall route/access evidence through RoadNetwork public APIs.
- [x] T011 Implement city/home attractiveness, Demand quote, Community operation/assignment, and authored negative-radius evidence.
- [x] T012 Wire/coalesce invalidations and retain ordered settled placement observations without adding idle frame work.

## Phase 3: Monotonic opening sequence

- [x] T013 Implement Town Hall, four-rooted-road, two-distinct-nature plus positive-Beauty gates.
- [x] T014 Implement first-home baseline and adjacent-home observation from actual before/after canonical scores.
- [x] T015 Implement honest no-penalty and legacy-baseline-unavailable variants that require a new observable action.
- [x] T016 Implement subsequent nature improvement evidence and the immutable home-repair receipt.
- [x] T017 Implement separated/rooted workplace evaluation from authored effects and the canonical work-assignment gate.
- [x] T018 Implement rooted first-shop gate, multi-receipt forward reconciliation, demolition non-regression, and completion state.

## Phase 4: Guidance and approved placeholders

- [x] T019 Implement the B01–B18 approved placeholder copy map with stable keys/arguments and no draft alternatives.
- [x] T020 Make Dashboard depend on OpeningTutorial, prioritize it while incomplete, and preserve existing patron guidance after completion.
- [x] T021 Remove the Dashboard one-off Town Hall override after equivalent tutorial coverage is passing.
- [x] T022 Extend compact-guidance tests for semantic direction changes, progress-only dismissal stability, modal/radial/inspection suppression, and all supported viewports.

## Phase 5: Full beats and handoff

- [x] T023 Author valid placeholder dialogue events for B05, B09, B15, and B18 under `data/events/tutorial/` using existing participant/expression/schema rules.
- [x] T024 Extend EventSystem trigger support only as needed for `tutorial_opening_completed`, retaining EventSystem pending/count/effect ownership.
- [x] T025 Dispatch full beats once through EventSystem with separate durable presentation receipts and visible/headless recovery parity.
- [x] T026 Add `GameEvents.tutorial_opening_completed`, persist the handoff before emission, prevent load re-emission, and keep Workstream 2 absent.
- [x] T027 Add normalized tutorial state/evidence to Playtest snapshots and deterministic hashes.

## Phase 6: Scenario and release verification

- [x] T028 Add `scripts/run_opening_tutorial_scenario.gd` covering the canonical fresh sequence, nine receipts, pending-resolution flow, and one handoff.
- [x] T029 Extend the scenario with early/out-of-order actions, duplicate invalidations, demolition, no-penalty/content diagnostics, and legacy missing-baseline recovery.
- [x] T030 Add save/load fixtures at every semantic boundary and compare visible/headless normalized outcomes and hashes.
- [x] T031 Run focused tutorial/Dashboard/dialogue/event/playtest suites and record exact totals in `validation/test-results.md`.
- [x] T032 Run adjacent Traffic/Attractiveness/Demand/Community/progression/dialogue suites and separate the frozen baseline failure from introduced regressions.
- [x] T033 Run the scenario twice and record receipts, handoff counts, bounded execution, and hash parity in `validation/deterministic-replay.md`.
- [x] T034 Run manifest export and prove only approved `AMBROSE PLACEHOLDER` text appears in tutorial runtime content.
- [x] T035 Add/run `scripts/capture_opening_tutorial_validation.gd`; store three-resolution captures and complete `validation/visual-qa.md`.
- [x] T036 Perform the fresh in-game mechanical pacing/clarity checklist in `validation/in-game-review.md`, explicitly leaving final prose/play-feel approval deferred.
- [x] T037 Run full unit/integration GUT with writable `user://`, record final regression disposition in `validation/release.md`, and update both workflow trackers only for gates that truly passed.

## Dependencies and order

- T002–T005 may be developed in parallel after T001.
- T006–T012 are the shared foundation and block all user-facing slices.
- T013–T018 follow semantic step order because later evidence uses earlier receipts.
- T019–T022 can begin after projection contracts pass; T023–T027 depend on durable
  presentation/completion receipts.
- T028–T030 require the end-to-end implementation; T031–T037 are final gates.

## Completion rule

Implementation is complete only after T006–T030 pass. Automated verification is
complete only after T031–T034 and T037 pass. The tracker’s dialogue/play-feel item
cannot be marked complete while the user-requested placeholders remain; T035–T036 may
verify layout, mechanics, pacing, clarity, and visible placeholder status only.
