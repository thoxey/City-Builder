# Tasks: Community Insight UI

**Input**: Design documents from `specs/003-community-ui/`

**Tests are required.** Tasks are grouped by independently testable user story and use the existing Godot plugin architecture.

## Phase 1: Setup and contract fixtures

- [x] T001 Verify every display field against authoritative Community/catalog/clock sources in `specs/003-community-ui/contracts/community-view-model.md`
- [x] T002 [P] Create UI fixture builders for empty, full-capacity, contrast, park-and-noise, retention 23/24, stale metadata, and 500 residents in `test/unit/community_ui/community_ui_test_fixtures.gd`
- [x] T003 [P] Add presentation preferences with backward-compatible defaults in `scripts/data_map.gd`
- [x] T004 [P] Add bounded Community UI notification/selection signals in `scripts/game_events.gd`

## Phase 2: Foundational projection and UI primitives

- [x] T005 Implement the pure immutable `CommunityInspector.project` view-model projection in `plugins/community/community_inspector.gd`
- [x] T006 Add canonical presentation snapshot/catalog/schedule/threshold exposure and programme request delegation in `plugins/community/community_plugin.gd`
- [x] T007 [P] Add shared accessible icon/row/card helpers using only `sprites/community_icons/game/*.png` in `plugins/community/community_ui_factory.gd`
- [x] T008 Implement event-coalesced projection ownership and bounded notifications in `plugins/community/community_panel.gd`
- [x] T009 [P] Add view-model contract, ordering, fallback, immutability, and raw-field exclusion tests in `test/unit/community_ui/test_community_view_model.gd`

## Phase 3: User Story 1 — Understand community health at a glance (P1)

**Independent test**: Park-and-noise HUD and overview match the same-tick authoritative snapshot; empty/full-capacity states remain explicit.

- [x] T010 [US1] Extend the HUD with population/capacity, composite happiness, recent signed change, icons, and Community entry point in `plugins/hud/hud_plugin.gd`
- [x] T011 [US1] Refactor the Dashboard into a single non-overlapping Community/Patrons tab shell while preserving Patron behavior and collapse state in `plugins/dashboard/dashboard_plugin.gd`
- [x] T012 [US1] Build Housing, Four Qualities, Migration, Composition, Drivers, Warnings, and empty-state overview sections in `plugins/community/community_panel.gd`
- [x] T013 [P] [US1] Add aggregate/empty/full-capacity/direction/notification tests in `test/unit/community_ui/test_community_overview.gd`
- [x] T014 [P] [US1] Extend Dashboard/HUD regression and 1280×720 bounds tests in `test/unit/community_ui/test_community_navigation.gd`

## Phase 4: User Story 2 — Explain why a resident feels this way (P1)

**Independent test**: A resident near pond and nightclub shows separate positive and negative effects with complete provenance.

- [x] T015 [US2] Implement deterministic search/filter/page resident list with stable selection in `plugins/community/community_panel.gd`
- [x] T016 [US2] Implement resident profile, current/target qualities, outlook/lenses, sensitivities, activity/programme, and retention display in `plugins/community/community_panel.gd`
- [x] T017 [US2] Implement grouped positive/negative effect rows with source, quality, manifestation, scope, reason, schedule, sign, and optional developer details in `plugins/community/community_panel.gd`
- [x] T018 [P] [US2] Add park-and-noise, personality contrast, provenance, filtering, stale-selection, and capped-list tests in `test/unit/community_ui/test_resident_detail.gd`

## Phase 5: User Story 3 — Understand migration and retention (P1)

**Independent test**: Matched/nuisance seven-day results and retention hour 23/24 are accurately explained.

- [x] T019 [US3] Add authoritative event context for arrival, departure, rehome, rejection, capacity, homelessness, and at-risk transitions in `plugins/community/community_plugin.gd`
- [x] T020 [US3] Render configured grace progress and distinguish capacity from happiness rejection in `plugins/community/community_panel.gd`
- [x] T021 [US3] Implement concise coalesced arrival/departure/rehome/capacity/risk notifications with safe deep links in `plugins/community/community_panel.gd`
- [x] T022 [P] [US3] Add migration-week, coalescing, recovery, rehome, and retention 23/24 tests in `test/unit/community_ui/test_community_overview.gd`

## Phase 6: User Story 4 — See personality-driven variety emerge (P2)

**Independent test**: Exact outlook/lens counts and resident differences are visible without faction or diversity mechanics.

- [x] T023 [US4] Complete exact-count/proportion composition and player-facing Rooted/Independent/Civic labels in `plugins/community/community_inspector.gd`
- [x] T024 [US4] Add resident comparison-ready lens emphasis and neighbourhood composition presentation in `plugins/community/community_panel.gd`
- [x] T025 [P] [US4] Add small-population, empty-composition, and personality contrast assertions in `test/unit/community_ui/test_resident_detail.gd`

## Phase 7: User Story 5 — Inspect places and choose programmes (P2)

**Independent test**: Inspect a theatre, change programme through the canonical API, and verify active schedule/participants/effects after authoritative refresh.

- [x] T026 [US5] Implement place and home-anchor neighbourhood projection in `plugins/community/community_inspector.gd`
- [x] T027 [US5] Implement place/neighbourhood detail, actual housed/affected/participant lists, radii, capacities, schedules, and programme previews in `plugins/community/community_panel.gd`
- [x] T028 [US5] Add explicit inspect-mode map selection that suppresses consumed Builder placement/demolition input in `scripts/builder.gd`
- [x] T029 [US5] Implement canonical programme selection with success-after-event and failure feedback in `plugins/community/community_panel.gd`
- [x] T030 [US5] Implement opt-in quality/outlook overlays with numeric legend and cleanup in `plugins/community/community_map_overlay.gd`
- [x] T031 [P] [US5] Add place, radius-boundary, schedule/end-hour, demolition, participant, neighbourhood, overlay, and programme tests in `test/unit/community_ui/test_place_inspector.gd`

## Phase 8: Accessibility, performance, integration, and visual acceptance

- [x] T032 Implement deterministic keyboard/gamepad focus order, visible focus, Escape hierarchy, focus-following scroll, wrapping, and non-colour labels/icons in `plugins/community/community_panel.gd`
- [x] T033 [P] Add keyboard/gamepad, non-colour, icon-path, and 1280×720 accessibility tests in `test/unit/community_ui/test_community_accessibility.gd`
- [x] T034 Implement bounded resident row reuse/paging and verify no projection/list rebuild in `_process` in `plugins/community/community_panel.gd`
- [x] T035 [P] Add 500-resident projection/update/scroll/live-row performance tests in `test/unit/community_ui/test_community_ui_performance.gd`
- [x] T036 Register Community UI source and test scripts as needed in `project.godot`
- [x] T037 Run all new Community UI GUT tests and record exact totals in `specs/003-community-ui/validation/test-results.md`
- [x] T038 Run the full existing GUT suite and record exact totals in `specs/003-community-ui/validation/test-results.md`
- [x] T039 Run TypeScript contract tests and record exact totals in `specs/003-community-ui/validation/test-results.md`
- [x] T040 Run the live AI outcome suite and all four canonical Community scenarios, recording seeds/results in `specs/003-community-ui/validation/test-results.md`
- [x] T041 Run live Godot keyboard-only and 1280×720 overlap verification in `specs/003-community-ui/validation/visual-qa.md`
- [x] T042 Capture and review overview, resident detail, place inspection, empty, full-capacity, and at-risk screenshots under `specs/003-community-ui/validation/screenshots/`
- [x] T043 Record 500-resident projection and scrolling performance and seven-day matched-versus-nuisance results in `specs/003-community-ui/validation/test-results.md`
- [x] T044 Re-run the quickstart acceptance path and update every verified checkbox in `specs/003-community-ui/tasks.md`

## Dependencies and execution order

- Phase 1 precedes the foundational projection.
- T005–T009 block all UI stories.
- US1 establishes the shared shell; US2–US5 build on it.
- Place inspection depends on resident/place indexes from the projector; programme UI delegates only to Community.
- Accessibility/performance and final verification follow all surfaces.

## Contract review

The generated task set covers every planned source file, all five user stories, FR-001–FR-022, SC-001–SC-010, all four canonical scenarios, the six required screenshots, full regression/TypeScript/live suites, 1280×720 keyboard QA, simultaneous signed effects, hour 23/24 retention, seven-day comparison, and the 500-resident target. No task introduces simulation formulas or direct programme-state writes in UI code.
