# Tasks: Radial Build UI and Player HUD

**Input**: Design documents from `specs/004-radial-build-ui/`

**Tests**: Required by the feature specification and project constitution.

**Format**: `[ID] [P?] [Story] Description`

## Phase 1: Setup and prototypes

- [x] T001 Create PlayerUI/test/asset directories from the implementation plan without altering existing Community UI files.
- [x] T002 [P] Prototype 7/8-wedge drawing, polar hit testing, dead zone, and safe-area clamping in `plugins/player_ui/radial_build_menu.gd`; record findings in `specs/004-radial-build-ui/validation/radial-prototype.md`.
- [x] T003 [P] Audit input actions/controller mappings in `project.godot`; record the semantic action policy in `specs/004-radial-build-ui/validation/input-map.md`.
- [x] T004 [P] Inventory standalone/pool entries and proposed group/order/icon keys in `specs/004-radial-build-ui/validation/catalog-ui-inventory.md`.

## Phase 2: Foundational model and input ownership

**Purpose**: Establish canonical read/command boundaries that block UI work.

- [x] T005 [P] Add failing catalog metadata fixture tests in `test/unit/building_catalog/test_building_catalog.gd`.
- [x] T006 [P] Add failing Palette projection/selection tests for exact-once entries, detached data, stable order/revision, reasons, pools, and revalidation in `test/unit/palette/test_palette.gd`.
- [x] T007 [P] Add failing input-mode priority and one-event/one-owner tests in `test/unit/builder/test_builder_input_modes.gd`.
- [x] T008 Extend `plugins/palette/palette_entry.gd` with stable UI metadata and availability decision fields.
- [x] T009 Extend `plugins/building_catalog/building_catalog_plugin.gd` to validate/project UI metadata with deterministic fallbacks.
- [x] T010 Add reason-bearing read-only decisions to `plugins/economy/economy_plugin.gd`, `plugins/demand/demand_plugin.gd`, and `plugins/unique_registry/unique_registry_plugin.gd` without duplicating rules.
- [x] T011 Implement detached `get_build_menu_model()` and revalidated `request_select_entry()` in `plugins/palette/palette_plugin.gd`.
- [x] T012 Add mutually exclusive input modes and priority routing in `scripts/builder.gd`, preserving existing command bodies.
- [x] T013 Add only necessary menu/mode signals in `scripts/game_events.gd` and document their payloads in the contract.
- [x] T014 Run T005–T007 suites and record evidence in `specs/004-radial-build-ui/validation/foundation-tests.md`.

**Checkpoint**: Menu truth and input ownership are authoritative and testable.

## Phase 3: User Story 1 — Choose and place visually (P1 MVP)

- [x] T015 [P] [US1] Add failing radial model/geometry tests in `test/unit/player_ui/test_radial_build_menu.gd`.
- [x] T016 [P] [US1] Add failing selection-to-placement tests in `test/integration/player_ui/test_radial_placement.gd`.
- [x] T017 [US1] Implement wedge state/rendering in `plugins/player_ui/radial_wedge.gd`.
- [x] T018 [US1] Implement category/item views, safe origin, centre Back/Close, pointer, and keyboard navigation in `plugins/player_ui/radial_build_menu.gd`.
- [x] T019 [US1] Implement Build and idle/placement/repeat/cancel contexts in `plugins/player_ui/tool_dock.gd`.
- [x] T020 [US1] Compose overlay/dock and Palette/Builder handoff in `plugins/player_ui/player_ui_plugin.gd`.
- [x] T021 [US1] Register PlayerUI in `scripts/plugin_manager.gd` and semantic actions in `project.godot`.
- [x] T022 [US1] Verify pool behavior, repeat, rotation, road paint, and cancel; record in `specs/004-radial-build-ui/validation/us1-placement.md`.

## Phase 4: User Story 2 — Explain unavailable choices (P1)

- [x] T023 [P] [US2] Add failing cash/demand/prerequisite/already-built/live-change UI tests in `test/integration/player_ui/test_radial_availability.gd`.
- [x] T024 [US2] Add disabled pattern, block glyph, costs/requirements, and rejected-confirm feedback to radial controls.
- [x] T025 [US2] Subscribe PlayerUI to Palette revisions and update controls without full reconstruction.
- [x] T026 [US2] Add blocked dock state/reason and safe preview clearing/updating across `plugins/player_ui/tool_dock.gd` and `scripts/builder.gd`.
- [x] T027 [US2] Validate all unavailable fixtures and record `specs/004-radial-build-ui/validation/us2-availability.md`.

## Phase 5: User Story 3 — Clean, unified player shell (P1)

- [x] T028 [P] [US3] Add failing removal and release-activation tests in `test/unit/plugin_manager/test_plugin_activation.gd` and `test/integration/player_ui/test_clean_shell.gd`.
- [x] T029 [US3] Implement the responsive status bar in `plugins/player_ui/status_bar.gd` and wire it through PlayerUI.
- [x] T030 [US3] Remove old Palette/HUD CanvasLayers from `plugins/palette/palette_plugin.gd` and `plugins/hud/hud_plugin.gd`.
- [x] T031 [US3] Remove legacy Top, Instructions, and DevCommands nodes and unused resources from `scenes/main.tscn`.
- [x] T032 [US3] Remove QuestDebug UI and apply explicit QuestDebug/RoadDebug/Playtest activation policy in `scripts/plugin_manager.gd` and debug plugins.
- [x] T033 [US3] Integrate Insights, Inbox, Dialogue, notification, and DayNight safe areas without changing domain behavior.
- [x] T034 [US3] Capture minimum/wide normal/debug/release screenshots and complete `specs/004-radial-build-ui/validation/clean-shell.md`.

## Phase 6: User Story 4 — Keyboard/gamepad parity (P2)

- [x] T035 [P] [US4] Add failing paging/focus/stick/device-switch/escape tests in `test/unit/player_ui/test_radial_navigation.gd`.
- [x] T036 [P] [US4] Add failing modal/inspection/overbuild/input-collision tests in `test/integration/player_ui/test_input_priority.gd`.
- [x] T037 [US4] Implement deterministic Previous/Next pages and focus restoration in `plugins/player_ui/radial_build_menu.gd`.
- [x] T038 [US4] Implement gamepad angular focus and semantic prompts in radial and dock controls.
- [x] T039 [US4] Complete modal priority, one-frame input consumption, and invoking-control focus restoration across PlayerUI and Builder.
- [x] T040 [US4] Run keyboard-only/gamepad-only paths and record `specs/004-radial-build-ui/validation/us4-input.md`.

## Phase 7: User Story 5 — Data-driven production assets (P2)

- [x] T041 [P] [US5] Create/review a labelled icon exploration sheet under `art/ui/build-menu/proofs/`; record the chosen direction.
- [x] T042 [P] [US5] Add UI group/order/icon metadata to every standalone building and pool under `data/buildings/`.
- [x] T043 [US5] Produce category, entry, navigation, lock, missing, build, and demolish masters under `art/ui/build-menu/masters/`.
- [x] T044 [US5] Create deterministic 256 px radial and 128 px compact RGBA derivatives under `sprites/ui/build-menu/`.
- [x] T045 [US5] Populate `art/ui/build-menu/manifest.json` with the complete asset handoff contract.
- [x] T046 [US5] Create 24/32/56/72 px calm and 56 px gameplay proofs; revise ambiguous/fringed assets.
- [x] T047 [US5] Implement/apply shared UI tokens and states in `themes/player_ui_theme.tres`.
- [x] T048 [US5] Add manifest/path/dimension/RGBA/alpha tests in `test/unit/player_ui/test_ui_assets.gd`.

## Phase 8: Polish and verification

- [x] T049 [P] Verify localization, text scale, grayscale, edge origins, resize, and layouts; record `validation/accessibility-layout.md`.
- [x] T050 [P] Profile cold/warm open, navigation, refresh, allocations, and scans; record `validation/performance.md`.
- [x] T051 [P] Update controls and authoring documentation in `README.md` and the data-editor docs.
- [x] T052 Inspect release export for inert/absent QuestDebug, RoadDebug, and Playtest; record `validation/release.md`.
- [x] T053 Run recursive GUT, deterministic replay, Community UI acceptance, and a full build scenario; record `validation/test-results.md`.
- [x] T054 Complete `quickstart.md`, resolve failures, and update approved behavioral changes in spec/plan.

## Dependencies and delivery

- Phase 2 blocks all stories. US1 is the MVP and blocks US2/US4 interaction.
- US3 can proceed after Phase 2 and integrates after the US1 dock exists.
- US5 metadata can begin after Phase 2; full art waits for geometry and direction approval.
- Review milestones: T014, T022, T034, T040, T048, and T054.
- No staging, committing, branching, merging, or pushing without explicit request.
