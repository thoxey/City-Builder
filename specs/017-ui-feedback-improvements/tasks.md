# Tasks: UI and Feedback Improvements

## Phase 1: Contracts and tests

- [x] T001 [P] Add Ambrose keyword mapping, casing, repetition, missing-icon, and authored-text preservation tests in `test/unit/dialogue/`
- [x] T002 [P] Add current/lifetime demand and lifetime-unlock tooltip tests in `test/unit/player_ui/test_status_bar.gd`
- [x] T003 [P] Add representative authored-effect projection tests in `test/unit/palette/test_palette.gd`
- [x] T004 [P] Add signed icon-row and live-preview exclusion tests in `test/unit/player_ui/test_tool_dock.gd`
- [x] T005 [P] Add deterministic feedback-alpha curve tests in `test/unit/builder/test_builder_input_modes.gd`

## Phase 2: User Story 1 - Ambrose keyword icons

- [x] T006 [US1] Implement exact-text-preserving keyword decoration and fallback in `plugins/dialogue/dialogue_thread_view.gd`
- [x] T007 [US1] Enable decoration only for Ambrose-presented speech in `plugins/dialogue/dialogue_plugin.gd`

## Phase 3: User Story 2 - Demand progression hover details

- [x] T008 [US2] Project current, lifetime, and ordered lifetime unique targets in `plugins/player_ui/status_bar.gd`
- [x] T009 [US2] Apply unambiguous hover details to Homes, Work, and Shops demand metrics in `plugins/player_ui/status_bar.gd`

## Phase 4: User Story 4 - Held-building authored effects

- [x] T010 [US4] Project representative base Beauty and authored Community effects in `plugins/palette/palette_plugin.gd`
- [x] T011 [US4] Add signed cash, demand, and Community icon rows to `plugins/player_ui/tool_dock.gd`
- [x] T012 [US4] Preserve dock readability and ensure `preview`/cell consequences remain excluded in `plugins/player_ui/tool_dock.gd`

## Phase 5: User Story 3 - Placement feedback taper

- [x] T013 [US3] Implement the deterministic 3.2-second eased opacity curve and cleanup in `scripts/builder.gd`

## Phase 6: Verification

- [x] T014 Run focused Dialogue, PlayerUI, Palette, Builder, and Demand GUT suites and record evidence in `validation/test-results.md`
- [x] T015 Run the relevant integration suites and record regression evidence in `validation/test-results.md`
- [x] T016 Add and run `scripts/capture_ui_feedback_validation.gd` with the normal renderer at 1280×720, 1920×1080, and 3840×2160
- [x] T017 Inspect wrapping, localization/fallback, hover copy, placement rows, animation samples, and screen-edge clearance; record `validation/visual-qa.md`
- [x] T018 Re-audit scope exclusion and acceptance criteria in `validation/acceptance-audit.md`
- [x] T019 Update only workstream 4 tracking in `NEXT_IDEA_PROMPTS.md`
