# Tasks: Automated Opening Balance Playtest

## Phase 1: Contracts and fixtures

- [x] T001 Add the rooted opening-balance strategy fixture at
  `test/scenarios/first_town/opening_balance.json`.
- [x] T002 Add report/runner contracts and rerun instructions under
  `specs/014-opening-balance-playtest/`.

## Phase 2: State-directed agent

- [x] T003 Implement the deterministic Playtest-only policy in
  `scripts/opening_balance_agent.gd`.
- [x] T004 Record before/after balance slices, deltas, rationale, blockers,
  rejections, milestone times, Beauty history, waits, and semantic hashes.
- [x] T005 Enforce Town Hall/grid/Beauty/growth/terrace decision priority and
  one-hour-only wait behavior.
- [x] T006 Enforce the 75 lifetime-Homes mid-block endpoint plus hour/action bounds.

## Phase 3: Suite runner and tests

- [x] T007 Add `scripts/run_opening_balance_playtest.gd` for primary replay,
  declared seed cohort, comparison, aggregation, and report persistence.
- [x] T008 Add focused policy/report unit coverage in
  `test/unit/playtest/test_opening_balance_agent.gd`.
- [x] T009 Add the complete real-game multi-seed scenario and prove all state
  changes delegate through canonical Playtest commands.

## Phase 4: Verification and evidence

- [x] T010 Run focused agent/Playtest GUT tests.
- [x] T011 Run the multi-seed baseline and deterministic primary replay; preserve
  `validation/baseline-report.json` and summaries.
- [x] T012 Run full recursive GUT and server build/tests.
- [x] T013 Capture and inspect a normal-renderer final-town screenshot.
- [x] T014 Audit every acceptance criterion, record remaining risks, and update
  both workflow checklists only after all gates pass.

## Dependencies

T001–T002 precede T003–T007. T003–T006 precede T007–T009. Verification tasks are
sequential after implementation, and T014 is last.
