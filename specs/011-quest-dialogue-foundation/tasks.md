---

description: "Implementation tasks for the quest dialogue foundation"

---

# Tasks: Quest Dialogue Foundation

**Input**: Design documents from `specs/011-quest-dialogue-foundation/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Required by the specification and constitution. Write each listed test first,
verify it fails for the intended missing behavior, then implement.

**Organization**: Tasks are grouped by independently testable user story. P1 stories
form the MVP together because readable presentation, speaker state, and safe completion
are all required for one shippable quest.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with adjacent tasks because it changes different files
- **[Story]**: User story from [spec.md](spec.md)
- Every task names its intended repository path

## Phase 1: Setup and Baseline

**Purpose**: Preserve existing semantic behavior before the renderer and commit timing
change.

- [x] T001 Run the pre-change focused suites from `specs/011-quest-dialogue-foundation/quickstart.md` and record commands, pass/fail totals, legacy visible traversal, headless effects, acknowledgement, and arrival transition in `specs/011-quest-dialogue-foundation/validation/baseline-before.md`
- [x] T002 [P] Add reusable valid, legacy, malformed, two-person, three-person, branching, cyclic, long-text, and 200-beat dictionaries in `test/unit/dialogue/dialogue_fixtures.gd`
- [x] T003 [P] Record the current dialogue event and character manifest fields plus runtime dialogue asset inventory in `specs/011-quest-dialogue-foundation/validation/authoring-before.md` and `specs/011-quest-dialogue-foundation/validation/runtime-assets-before.txt`

---

## Phase 2: Foundational Authored-Data Contract

**Purpose**: Normalize new and legacy content before any UI consumes it.

**⚠️ CRITICAL**: No user-story implementation begins until normalization is green.

- [x] T004 [P] Add failing normalization tests for participants, speech/narration beats, legacy `body`, unknown types/speakers, empty text, duplicate/missing node IDs, missing destinations, detached output, and 128-node traversal diagnostics in `test/unit/dialogue/test_dialogue_schema.gd`
- [x] T005 Implement detached normalization, ordered stable diagnostics, legacy-body projection, graph validation, and traversal-bound helpers in `plugins/dialogue/dialogue_schema.gd` until T004 passes
- [x] T006 Refactor `plugins/dialogue/dialogue_plugin.gd` to normalize an event once on visible/headless entry and reject invalid normalized records without applying effects or acknowledging pending IDs
- [x] T007 Extend existing cases in `test/unit/dialogue/test_dialogue.gd` to prove body-only records retain their current node order, first-option path, effects, acknowledgement, and arrival transition after normalization

**Checkpoint**: New and legacy dialogue graphs have one validated internal shape.

---

## Phase 3: User Story 1 — Read and Advance a Conversation (Priority: P1) 🎯

**Goal**: Accumulate progressively revealed transcript beats and advance by activating
the whole non-interactive conversation surface, with no Continue button.

**Independent Test**: Play a linear speech/narration fixture using surface, keyboard,
and controller inputs and prove every physical event causes exactly one transition.

### Tests for User Story 1

- [x] T008 [P] [US1] Add failing reveal-state tests for final-size row creation, deterministic character stepping, punctuation timing, instant mode, timer completion, and rapid complete/advance inputs in `test/unit/dialogue/test_dialogue_reveal.gd`
- [x] T009 [P] [US1] Add failing input tests for frame clicks, bubble/narration clicks, Space, Enter, controller confirm, key echo rejection, handled events, child-control precedence, terminal completion, and absence of Continue/Finish buttons in `test/unit/dialogue/test_dialogue_input.gd`
- [x] T010 [P] [US1] Add failing append-only transcript tests proving old row node identities and text remain unchanged as new beats arrive in `test/unit/dialogue/test_dialogue_thread_view.gd`

### Implementation for User Story 1

- [x] T011 [US1] Add the programmatic dim layer, inner frame, header/status, transcript `ScrollContainer`, content column, interaction hint, and test hooks in `plugins/dialogue/dialogue_thread_view.gd`
- [x] T012 [US1] Add left/right speech-row and centred unboxed narration-row factories plus current-row visible-prefix updates in `plugins/dialogue/dialogue_thread_view.gd`
- [x] T013 [US1] Replace the single `_body` renderer in `plugins/dialogue/dialogue_plugin.gd` with `REVEALING`, `READY`, `CHOOSING`, and `DONE` session modes and deterministic reveal stepping
- [x] T014 [US1] Implement one internal `advance_dialogue()` command in `plugins/dialogue/dialogue_plugin.gd` that returns a stable transition projection and performs at most one state change per call
- [x] T015 [US1] Add the `dialogue_advance` controller-confirm action in `project.godot` and route surface click/tap, Space, Enter, and that action through `advance_dialogue()` while consuming accepted events
- [x] T016 [US1] Ensure choice/scroll/return-to-latest controls consume their input and remove all construction of terminal/default Continue or Finish-line buttons from `plugins/dialogue/dialogue_plugin.gd` and `plugins/dialogue/dialogue_thread_view.gd`

**Checkpoint**: Linear conversations are readable and completable with the surface only;
there is no advance button in the UI tree.

---

## Phase 4: User Story 2 — Follow Speakers, Expressions, and Narration (Priority: P1)

**Goal**: Fix the player left, place the current/recent NPC right, swap NPCs in
three-way scenes, and preserve expression/inactive/narration state.

**Independent Test**: Run the two- and three-person fixtures and inspect bubble sides,
portrait identities/expressions, narration state, layout geometry, and scroll behavior.

### Tests for User Story 2

- [x] T017 [P] [US2] Add failing expression-resolution tests for authored, default, legacy portrait, missing-art fallback, stable diagnostics, and semantic `player -> ambrose` mapping in `test/unit/dialogue/test_dialogue_expressions.gd`
- [x] T018 [P] [US2] Extend `test/unit/dialogue/test_dialogue_thread_view.gd` with failing active-left, active-right, narration/both-inactive, consecutive-NPC swap, participant-name retention, 5%-overlap, and 1280×720/1920×1080/3840×2160 geometry cases
- [x] T019 [P] [US2] Add failing bottom-follow, upward-scrollback preservation, new-content indicator, return-to-latest, and long-transcript tests in `test/unit/dialogue/test_dialogue_thread_view.gd`

### Implementation for User Story 2

- [x] T020 [US2] Add fixed bottom-left player and bottom-right counterpart portrait hosts, active/non-colour emphasis, inactive muting, narration state, and responsive approximately 5% frame overlap in `plugins/dialogue/dialogue_thread_view.gd`
- [x] T021 [US2] Implement semantic participant/display-name/expression resolution, latest-expression retention, and right-slot NPC swapping before reveal in `plugins/dialogue/dialogue_plugin.gd`
- [x] T022 [US2] Implement bottom-aware auto-follow, manual scrollback preservation, and the inside-frame return-to-latest control in `plugins/dialogue/dialogue_thread_view.gd`
- [x] T023 [P] [US2] Add `default_expression` and semantic `expressions` maps with legacy portrait fallback to `data/characters/ambrose.json`, `data/characters/aristocrat_residential.json`, and `data/characters/aristocrat_commercial.json`
- [x] T024 [P] [US2] Prepare provisional high-resolution masters, semantic Ambrose/Baba/Flick expression crops, portrait frame, active emphasis, manifests, and actual-size/noisy-context proofs in `art/ui/dialogue/`; export verified Godot derivatives to `data/characters/*/expressions/` and `sprites/ui/dialogue/` without altering `talking_videos`
- [x] T025 [US2] Create `themes/dialogue_theme.tres` using the approved/reused frame, choice-button, scrollbar, divider, portrait-frame, and emphasis assets; keep all dialogue copy and names as engine text

**Checkpoint**: Two- and three-person scenes share one stable layout and the right slot
changes identity before each new NPC line reveals.

---

## Phase 5: User Story 3 — Choose a Reply and Resolve Progression Safely (Priority: P1)

**Goal**: Append selected replies, commit effects exactly once, recover interrupted
pending dialogue, and preserve visible/headless semantic parity.

**Independent Test**: Resolve every branch visibly and headlessly; interrupt before
commit; reload; and compare effects, nodes, progression, and pending IDs.

### Tests for User Story 3

- [x] T026 [P] [US3] Add failing unit tests for choice gating, player-left selected reply rows, node-then-option effect order, duplicate selection/completion rejection, terminal surface commit, and destination navigation in `test/unit/dialogue/test_dialogue.gd`
- [x] T027 [P] [US3] Add failing visible/headless parity tests for ordered visited nodes, ordered effects, arrival transition, acknowledgement, missing destination, and traversal ceiling in `test/unit/dialogue/test_dialogue_parity.gd`
- [x] T028 [P] [US3] Add failing EventSystem → Inbox → Dialogue integration tests for open, pre-commit interruption, map-load redispatch, single pending projection, restart, completion, and exact-once effects in `test/integration/dialogue/test_dialogue_recovery.gd`
- [x] T029 [P] [US3] Extend semantic resolve and progression regressions in `test/unit/playtest/test_playtest_plugin.gd`, `test/unit/inbox/test_inbox.gd`, `test/unit/event_system/test_event_system.gd`, and `test/integration/progression/test_progression_save_load.gd`

### Implementation for User Story 3

- [x] T030 [US3] Move visible `on_enter` execution out of node entry and add one guarded node-commit helper applying node effects then option effects in `plugins/dialogue/dialogue_plugin.gd`
- [x] T031 [US3] Render choices inside the frame only after the final beat is ready, block ordinary advance in `CHOOSING`, and append the accepted label as a player-left row before navigation/closure in `plugins/dialogue/dialogue_thread_view.gd` and `plugins/dialogue/dialogue_plugin.gd`
- [x] T032 [US3] Route terminal ready-advance through the same guarded commit, existing arrival/patron completion, EventSystem acknowledgement, session clear, and modal close in `plugins/dialogue/dialogue_plugin.gd`
- [x] T033 [US3] Refactor `resolve_pending_event()` in `plugins/dialogue/dialogue_plugin.gd` to use the normalized graph and shared ordered commit semantics without constructing UI or loading textures
- [x] T034 [US3] Preserve pending truth until completion and ensure map-load redispatch restores an interrupted conversation exactly once in `plugins/inbox/inbox_plugin.gd` and `plugins/event_system/event_system_plugin.gd`
- [x] T035 [US3] Migrate `data/events/characters/aristocrat_residential/arrival.json` into the production vertical slice with player speech, Baba speech, narration, expression changes, at least one meaningful choice, existing flag/progression semantics, and a terminal node

**Checkpoint**: The production arrival quest resolves safely and identically through
visible and headless paths.

---

## Phase 6: User Story 4 — Author Dialogue Without Renderer Changes (Priority: P2)

**Goal**: Make the new contract visible to authoring/export tooling and prove new events
need data changes only.

**Independent Test**: Export the manifest, inspect valid/invalid fixtures and the
production event, then add a data-only three-way fixture without renderer changes.

### Tests for User Story 4

- [x] T036 [P] [US4] Add exporter regression coverage for participants, ordered beats, semantic expressions/defaults, legacy body records, and round-trip preservation in the existing data-editor tool test location or `test/unit/event_system/test_event_manifest.gd`
- [x] T037 [P] [US4] Add an authored-data validation test that scans all dialogue events and character expression maps and reports stable file/event/node/beat context in `test/unit/event_system/test_dialogue_content_validation.gd`

### Implementation for User Story 4

- [x] T038 [US4] Extend event/character manifest export fields without schema rewriting in `addons/data_editor_tools/manifest_exporter.gd` and regenerate `data/events/_manifest.json`
- [x] T039 [US4] Add a data-only Baba/Flick/player three-way fixture under `test/scenarios/dialogue/three_way_conversation.json` and prove it plays through the unchanged DialoguePlugin
- [x] T040 [US4] Document semantic authoring, legacy migration, expression fallback, commit boundaries, and the no-Continue surface interaction in `docs/quest-dialogue-authoring.md`, linking the contracts in `specs/011-quest-dialogue-foundation/contracts/`

**Checkpoint**: Authors can create another supported conversation without adding or
special-casing presentation code.

---

## Phase 7: Validation and Release Evidence

**Purpose**: Prove the complete story and protect adjacent gameplay.

- [x] T041 [P] Add deterministic instant-text capture states and viewport loops for player active, NPC active, narration, three-way swap, choices, long text/scrollback, and fallbacks in `scripts/capture_dialogue_validation.gd`
- [x] T042 Run focused schema/reveal/input/view/dialogue/inbox/event/character/playtest/progression suites and record commands, totals, and failures in `specs/011-quest-dialogue-foundation/validation/test-results.md`
- [x] T043 Run the dialogue integration suite and compare visible/headless ordered outcomes in `specs/011-quest-dialogue-foundation/validation/parity-and-recovery.md`
- [x] T044 Run manifest export/content validation and record all migrated, legacy, and fallback diagnostics in `specs/011-quest-dialogue-foundation/validation/authoring-contract.md`
- [x] T045 Run the 200-beat stress fixture, capture worst reveal-update duration and unchanged prior-row identities, and record results in `specs/011-quest-dialogue-foundation/validation/performance.md`
- [x] T046 Run the normal-renderer capture at 1280×720, 1920×1080, and 3840×2160; store screenshots/manifest under `specs/011-quest-dialogue-foundation/validation/screenshots/` and complete `specs/011-quest-dialogue-foundation/validation/visual-qa.md`
- [x] T047 Run full unit/integration GUT plus deterministic first-patron and first-town scenarios with writable `user://`; record regressions and final release disposition in `specs/011-quest-dialogue-foundation/validation/release.md`
- [x] T048 Compare `validation/runtime-assets-before.txt` with final runtime paths/digests, confirm only approved dialogue/character assets changed, and record the result in `specs/011-quest-dialogue-foundation/validation/runtime-assets-after.txt`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately and freezes the baseline.
- **Foundational (Phase 2)**: Depends on fixtures; blocks all user stories.
- **US1 (Phase 3)**: Depends on normalized beats and delivers the reveal/input spine.
- **US2 (Phase 4)**: Depends on the thread view from US1; expression asset production
  can begin in parallel after dimensions/state requirements are fixed.
- **US3 (Phase 5)**: Depends on US1 state transitions and normalized traversal. Most
  failing semantic/integration tests can be written while US2 art work proceeds.
- **US4 (Phase 6)**: Depends on the final authored schema; exporter tests may start
  after Phase 2.
- **Validation (Phase 7)**: Depends on all selected story phases.

### User Story Dependencies

- **US1**: Independently demonstrates linear readable conversation and whole-surface
  advance, but does not yet ship safe gameplay effects.
- **US2**: Adds independently testable speaker/expression/multi-NPC presentation to US1.
- **US3**: Adds independently testable branch, completion, recovery, and progression
  semantics; together US1+US2+US3 are the release MVP.
- **US4**: Makes the feature sustainably authorable after the MVP contract is stable.

### Within Each User Story

- Add failing tests before runtime behavior.
- Normalize data before entering presentation or headless traversal.
- Append the UI row and update portrait state before reveal begins.
- Complete all text beats before showing choices or allowing terminal commit.
- Commit effects before navigation/completion; acknowledge only after final semantics.
- Validate focused suites before full regressions and screenshots.

### Parallel Opportunities

- T002 and T003 can run together.
- T008–T010 can be authored together in separate test files.
- T017 and T018 can proceed while T019 defines scroll tests.
- T023 and provisional T024 asset preparation can proceed once semantic names and view
  dimensions are fixed; T025 waits for approved derivatives.
- T026–T029 can be authored in parallel before T030–T034 implementation.
- T036–T037 can proceed in parallel after schema normalization.
- T041 and validation document scaffolding can proceed while final implementation tests
  are being completed.

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete US1 and prove surface-only linear advance with no button.
3. Complete US2 using provisional expression assets and prove two/three-way readability.
4. Complete US3 and prove one production arrival quest, interruption recovery, and
   visible/headless parity.
5. Stop for milestone review before authoring more quests or adding QuestSystem.

### Incremental Delivery

1. **Interaction spine**: normalized beats, append-only transcript, reveal, surface input.
2. **Illustrated identity**: fixed player slot, swapping NPC slot, expressions, narration.
3. **Safe quest semantics**: choices, late commit, completion, pending recovery, parity.
4. **Authoring scale**: manifest/export validation and data-only additional conversation.
5. **Release proof**: performance, visual matrices, full regression, deterministic town.

## Notes

- Do not stage, commit, branch, merge, or push without explicit user instruction.
- Preserve unrelated working-tree changes.
- Final portrait art direction is intentionally replaceable; quest data addresses
  semantic speakers/expressions, not temporary Ambrose/Flick/Baba file packing.
- Do not add a generic QuestSystem until a later feature requires durable objectives
  not already represented by existing gameplay authorities.
