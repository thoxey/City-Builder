---
description: "Implementation tasks for the first land quest and townspeople"
---

# Tasks: First Land Quest and Townspeople

**Input**: Design documents from `specs/016-first-land-quest-townspeople/`

**Tests**: Required by the feature brief and project constitution. Content-dependent
tasks remain blocked until Phase 2 approvals are recorded.

## Phase 1: Specification, design, and baseline

- [x] T001 Audit the tutorial handoff, EventSystem pending/effects, Dialogue late-commit
  path, Sir William character data, BuildableArea donations, and Community personality
  foundation; record decisions in `research.md`.
- [x] T002 Complete `spec.md`, the quality checklist, `plan.md`, `data-model.md`, and the
  three contracts with explicit ownership and test seams.
- [x] T003 Prepare the full dramatic purpose, staged beat map, semantic choices,
  motivations, expressions, outcomes, cast/voice options, and clearly unapproved copy
  workshop in `dialogue-workshop.md`.
- [x] T004 Run and record the focused pre-change foundation suites in
  `validation/baseline-before.md`.

## Phase 2: Collaborative creative approval (blocking)

**Checkpoint**: Do not begin runtime content or content-coupled scaffolding until the
user has made and approved these decisions.

- [ ] T005 Approve whether semantic `player` speaks as Ambrose or a distinct player
  identity; if distinct, approve its display name/portrait/expression policy.
- [ ] T006 Approve Sir William's place association, place name, staging mode, and any new
  building/model/art requirement.
- [ ] T007 Approve the four roles, names, relationships, voice anchors, portrait policy,
  and minimum expression maps.
- [ ] T008 Approve the outcome kind, equivalent-versus-branching behavior, grant ID,
  exact contiguous parcel geometry, and aftermath timing.
- [ ] T009 Workshop and approve Scene S1 LQ01–LQ10 exact prose, option labels,
  expressions, and branch acknowledgements.
- [ ] T010 Workshop and approve Scene S2 LQ11–LQ15 and Scene S3 LQ16–LQ20 exact prose,
  expressions, and any optional narrative flags.
- [ ] T011 Record a complete approval table in `dialogue-workshop.md` and confirm the
  runtime scene package contains no provisional text.

## Phase 3: Failing state/content tests

- [ ] T012 [P] Add failing normalization, monotonic phase, malformed legacy state,
  receipt idempotency, and diagnostic tests under `test/unit/first_land_quest/`.
- [ ] T013 [P] Add failing quest-definition validation tests for event references, place
  association, approach flags, outcome, and grant geometry.
- [ ] T014 [P] Add failing townsperson-profile validation tests for four-quality coverage,
  stable IDs, concrete trade-offs, tensions, voice fields, reaction tags, expressions,
  and draft-marker rejection.
- [ ] T015 [P] Add failing BuildableArea tests for valid rect/polygon grants,
  deduplication, overlap, malformed/oversize rejection, receipt persistence, and patron-
  donation independence.
- [ ] T016 [P] Add failing activation/recovery integration tests for live handoff, cold
  load, B18 independence, pending redispatch, event-count repair, and completed replay.
- [ ] T017 [P] Add failing visible/headless dialogue completion-edge tests covering each
  approved approach and interruption boundary.

## Phase 4: State and canonical land foundation

- [ ] T018 Add versioned `first_land_quest_state` and `land_grants_applied` fields to
  `scripts/data_map.gd`.
- [ ] T019 Implement pure quest state/definition normalization and stable diagnostics in
  `plugins/first_land_quest/first_land_quest_plugin.gd`.
- [ ] T020 Register `FirstLandQuest` in `scripts/plugin_manager.gd` with only the
  dependencies declared in `plan.md`.
- [ ] T021 Add the detached post-acknowledgement completion signal to
  `plugins/dialogue/dialogue_plugin.gd` without changing traversal/effect order.
- [ ] T022 Implement `BuildableArea.apply_land_grant()` and quest-specific receipts in
  `plugins/buildable_area/buildable_area_plugin.gd` through the existing parser/expand
  path.
- [ ] T023 Extend `scripts/progression_content_validator.gd` for the approved quest,
  townsperson, event, expression, and land contracts.

## Phase 5: User Story 1 — Activate once

**Goal**: Convert the durable tutorial handoff into exactly one recoverable first-land
quest event without depending on B18.

**Independent Test**: Live completion and cold-load receipt reconciliation both create
one pending event; duplicates and completed saves create none.

- [ ] T024 [US1] Implement receipt-first live/boot/map-load activation reconciliation
  and EventSystem dispatch in `plugins/first_land_quest/first_land_quest_plugin.gd`.
- [ ] T025 [US1] Implement pending/count/flag recovery, contradiction diagnostics, and
  non-replay after completion.
- [ ] T026 [US1] Pass T012/T016 activation cases and add normalized activation state to
  `plugins/playtest/playtest_plugin.gd`.

## Phase 6: User Story 2 — Approved Sir William negotiation

**Goal**: Deliver the approved, world-grounded staged negotiation with clear choices.

**Independent Test**: Play every approved approach, interrupt at each boundary, and
verify exact participant/expression/flag/outcome semantics.

- [ ] T027 [US2] Add the approved quest definition under `data/quests/` including Sir
  William's place and event/outcome references.
- [ ] T028 [US2] Add only the approved Scene S1 event JSON under
  `data/events/quests/first_land_quest/` using stable approach flags and common agreement.
- [ ] T029 [US2] Add the approved place association to the world/catalog only if T006
  selected a new/visible structure; preserve canonical placement and asset conventions.
- [ ] T030 [US2] Implement semantic approach/agreement reconciliation and pass every
  visible/headless/interruption test from T017.

## Phase 7: User Story 3 — Four recurring people

**Goal**: Introduce four approved people through two staged tensions and leave reusable,
non-generative profiles.

**Independent Test**: Validate exact quality coverage and play both aftermath scenes;
reviewers can distinguish desires, concessions, and conflicts without stat labels.

- [ ] T031 [P] [US3] Add the four approved CharacterSystem definitions and expression
  assets/fallback declarations under `data/characters/`.
- [ ] T032 [US3] Add only the approved Scene S2/S3 events, respecting the three-
  participant limit and stable reaction/profile IDs.
- [ ] T033 [US3] Implement profile lookup/reaction-tag projection without changing
  CommunityResident or generating prose.
- [ ] T034 [US3] Pass T014 and add manifest parity checks against the workshop approval
  record.

## Phase 8: User Story 4 — Apply outcome and resume

**Goal**: Apply the approved land grant/follow-up once and complete after the approved
aftermath sequence.

**Independent Test**: Resolve every branch visibly/headlessly, save/load around every
commit, and compare land/quest receipts and hashes.

- [ ] T035 [US4] Implement post-acknowledgement outcome reconciliation, applying the
  authored grant only through BuildableArea.
- [ ] T036 [US4] Implement ordered aftermath dispatch/completion receipts and recovery
  when any scene remains pending.
- [ ] T037 [US4] Add the normalized land outcome/completion projection and deterministic
  hash fields to Playtest.
- [ ] T038 [US4] Pass T015/T017 plus cold ResourceSaver/ResourceLoader boundary tests.

## Phase 9: Scenario and release verification

- [ ] T039 Add `scripts/run_first_land_quest_scenario.gd` covering the full fresh opening,
  tutorial receipt, B18 independence, all approved dialogue events, chosen first-option
  approach, land change, four profiles, and terminal completion.
- [ ] T040 Extend the scenario for duplicate invalidations, pending restart, malformed
  state/content, overlap, post-completion replay, and visible/headless semantic parity.
- [ ] T041 Run focused quest/dialogue/event/opening/buildable-area/progression/playtest
  suites and record exact totals in `validation/test-results.md`.
- [ ] T042 Run the scenario twice and record stable state/action hashes, phase/receipt
  parity, cell counts, and bounded execution in `validation/deterministic-replay.md`.
- [ ] T043 Export the manifest and prove every runtime line/label/identity/expression is
  in the workshop approval record and no draft marker exists.
- [ ] T044 Add/run `scripts/capture_first_land_quest_validation.gd`; capture the place,
  approach choice, all four expressions/tensions, and granted parcel at 1280×720,
  1920×1080, and 3840×2160.
- [ ] T045 Perform the in-game checklist for staging, voice, choice clarity, pacing,
  humanized viewpoints, and land feedback in `validation/in-game-review.md` with direct
  user approval.
- [ ] T046 Run full unit/integration GUT with writable `user://`, record release evidence,
  and update Workstream 2 tracker gates only when they actually pass.

## Dependencies and execution order

- T004 is independent and can run before approval.
- T005–T011 are a hard content gate for T013–T014 and T027–T034. T012, T015, and T016
  may be authored from invariant contracts once implementation resumes, but no runtime
  scaffolding should be enabled with missing content.
- T018–T023 are the shared implementation foundation and block user stories.
- US1 activation precedes negotiation; US2 agreement precedes US4 outcome; US3 vignettes
  precede final quest completion under the recommended staging.
- T039–T040 require all desired stories. T041–T046 are release gates.

## Completion rule

Implementation is complete only after T018–T040 pass with approved content. Automated
verification is complete only after T041–T043 and T046 pass. Dialogue/character review
is complete only after T044–T045 and explicit user approval. Specification, plan, and
task generation do not imply implementation authorization.
