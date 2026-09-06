# Tasks: Buildable Area and Community Quality Playtest Pass

**Input**: Design documents from `/specs/013-buildable-community-pass/`

## Phase 1: Specify and plan

- [x] T001 Translate the playtest request into prioritized, independently testable stories in `spec.md`.
- [x] T002 Audit BuildableArea lifecycle/presentation seams and current community sources in `research.md`.
- [x] T003 Record authority, geometry, balance, and persistence contracts before implementation.

## Phase 2: Tests first

- [x] T004 [US1] Add failing overlay geometry/emphasis/lifecycle tests in `test/unit/buildable_area/test_buildable_area.gd`.
- [x] T005 [US2] Add failing rooted 16×16 seed and rooted donation-delta tests in `test/unit/buildable_area/test_buildable_area.gd`.
- [x] T006 [US3] Add failing deterministic mixed/poor/spam/save-load tests under `test/unit/community` and `test/integration/community`.

## Phase 3: Buildable presentation and seed

- [x] T007 [US1] Build the original derived boundary presentation from authoritative cells in `plugins/buildable_area/buildable_area_plugin.gd`.
- [x] T008 [US1] Refresh and emphasize the overlay on map, expansion, radial, and placement transitions.
- [x] T009 [US2] Change the rooted starter rect to 16×16 and update hard-coded rooted counts.

## Phase 4: Community tuning

- [x] T010 [US3] Tune existing Town Hall and local-commerce belonging values in authored building JSON.
- [x] T011 [US3] Prove poor adjacency and the existing repeated-source ceiling remain effective.
- [x] T012 [US3] Prove exact community state survives save/load.

## Phase 5: Verification and evidence

- [x] T013 Run focused BuildableArea and Community unit suites.
- [x] T014 Run relevant Community and progression integration suites with writable `user://`.
- [x] T015 Run the fixed-seed full-town replay and record before/after quality traces.
- [x] T016 Capture and inspect normal/emphasized boundary frames at normal gameplay zoom.
- [x] T017 Record exact changes and results under `validation/`, then re-check scope and constitution compliance.
- [x] T018 [US1] Invert the presentation to a subtle white non-buildable texture mask while leaving authoritative cells clear; tune to 5% perceptual opacity after visual review.
- [x] T019 [US1] Refresh focused tests and normal/placement visual evidence for the inverted mask.
