# Feature Specification: Reachable First-Patron Progression

**Feature Branch**: `005-reachable-first-patron` *(planning identifier; no branch created)*

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "Prove and repair the complete first progression run from a fresh town through the first patron landmark and land expansion before further balance work."

## 1. Purpose

Establish one reachable, deterministic progression spine through the systems that
already exist. A player starting a fresh town must be able to grow all three
development buckets, meet the Howarth Players' three characters, reveal and
complete their requests, place the Theatre, and receive the associated land
donation without debug state changes or hidden implementation knowledge.

This milestone is primarily about progression correctness. It defines the
ordering and reconciliation rules that later balance work can tune without
reintroducing impossible or sequence-dependent states.

## 2. Scope Boundary

### In scope

- A canonical fresh-town scenario covering the complete first-patron sequence.
- Runtime meaning for authored character tier and fulfilled-demand requirements.
- Character-aware availability for requested unique buildings.
- Patron-aware availability for the landmark.
- Reconciliation when a save, old content revision, or simultaneous event makes
  the world state and progression state temporarily disagree.
- Stable, player-readable and machine-readable reasons for every progression
  gate.
- Provisional data corrections needed to make the existing single-patron route
  finite and reachable.
- Deterministic trace milestones and regression coverage for the complete route.

### Explicitly out of scope

- Making roads affect production, employment, commerce, or Community activity.
- Final economy, demand, migration, or pacing balance.
- New patrons, characters, buildings, or quest branches.
- Replacing placeholder dialogue, biographies, portraits, or videos.
- Main menu, pause menu, autosave, save browser, settings, or export packaging.
- Remote playtesting, multiplayer, or arbitrary progression mutation tools.

## 3. Canonical Progression Contract

### 3.1 Bucket tier attainment

A development bucket's attained tier is the highest authored tier represented
by a currently placed building in that bucket. Pool members inherit the tier of
their pool; unique chain buildings use their authored unique tier. Decorative,
road, want, and landmark entries do not raise an unrelated bucket's tier.

A quest character may arrive only when both conditions are true:

1. fulfilled demand in the associated bucket meets `arrival_threshold`; and
2. attained tier in that bucket meets `arrival_requires_tier`.

Both conditions use canonical runtime state and must be exposed in the same
availability/progression projection used by automated playtests and player UI.

### 3.2 Character request sequence

Each quest character follows one monotonic state sequence:

```text
NOT_ARRIVED
→ ARRIVED
→ WANT_REVEALED
→ SATISFIED
→ CONTRIBUTES_TO_LANDMARK
```

- Arrival occurs once when the bucket requirements become true.
- Resolving the arrival dialogue changes `ARRIVED` to `WANT_REVEALED`.
- A character-linked `want` building is visible for progression clarity but is
  not selectable until that character reaches `WANT_REVEALED`.
- Placing the requested building at or after reveal changes the character to
  `SATISFIED` exactly once.
- Existing saves that already contain the requested building reconcile to
  `SATISFIED` during load only when their persisted state is already
  `WANT_REVEALED` or later; otherwise reconciliation waits until the want is
  validly revealed. This compatibility rule does not let new games bypass the
  reveal order.
- Character progress never regresses when a satisfied request is demolished.
  Rebuilding may still be required by the landmark's physical prerequisites.

### 3.3 Patron and landmark sequence

The first patron follows one monotonic state sequence:

```text
LOCKED
→ LANDMARK_AVAILABLE
→ COMPLETED
```

- The patron becomes `LANDMARK_AVAILABLE` after every associated character is
  satisfied.
- A patron landmark remains visible but is not selectable before the patron is
  available, even if its physical building prerequisites happen to be present.
- Placing the available landmark completes the patron, promotes its characters,
  and grants its land donation exactly once.
- Loading, rebuilding, or replaying events must not duplicate the donation or
  event count.
- A completed patron remains completed if the landmark is later demolished.

### 3.4 Canonical milestone trace

The complete scenario records, at minimum:

1. first tier-one building placed in each bucket;
2. each character arrival;
3. each want reveal;
4. each requested unique placement and character satisfaction;
5. patron landmark availability;
6. landmark placement and patron completion; and
7. buildable-area expansion, including the number of newly granted cells.

Each milestone records simulation time, action sequence, relevant demand and
tier state, current progression state, placed building IDs, and the resulting
state hash.

## 4. User Scenarios & Testing

### User Story 1 — Complete the first patron from a fresh town (Priority: P1)

As a player, I can progress from an empty starter plot to the first patron's land
donation using only actions presented as legal by the game.

**Why this priority**: The first patron is the only authored campaign arc and the
only normal route to more buildable land. If it is not reachable, the game has no
complete progression loop.

**Independent Test**: Start the canonical scenario with a declared seed, choose
only currently available actions, resolve queued arrival dialogue, complete all
three requests, place the Theatre, and verify the buildable area expands.

**Acceptance Scenarios**:

1. **Given** a fresh default town, **When** the canonical legal action sequence is played, **Then** all three characters become satisfied, the patron completes, and the land donation is applied.
2. **Given** the same scenario, seed, and actions, **When** the run is repeated ten times, **Then** milestone order, outcomes, and balance-relevant state hashes are equivalent.
3. **Given** ordinary gameplay interfaces only, **When** the route completes, **Then** no test hook directly changes demand, character state, patron state, unique state, or allowed cells.

---

### User Story 2 — See story buildings in the intended order (Priority: P1)

As a player, I can see that later story buildings exist and understand what is
still required, without being allowed to build a character's request before
meeting that character.

**Why this priority**: Visible but correctly gated goals communicate progression
while preventing spoilers and sequence-dependent dead ends.

**Independent Test**: Inspect every chain, want, and landmark entry at successive
milestones and compare its selectable state and reason with canonical
progression state.

**Acceptance Scenarios**:

1. **Given** an unmet chain threshold or prerequisite, **When** the entry is inspected, **Then** it identifies the missing demand, tier, or building requirement.
2. **Given** a request whose character has not revealed it, **When** the entry is inspected or selected, **Then** it is rejected with a character-progression reason and no resources change.
3. **Given** all three characters are not yet satisfied, **When** the Theatre is inspected or selected, **Then** it identifies that the patron is not ready.
4. **Given** a gate becomes satisfied, **When** availability refreshes, **Then** the item becomes selectable without restarting the game or reopening the save.

---

### User Story 3 — Recover from ordering and legacy-save mismatches (Priority: P1)

As a returning player, I do not lose the campaign because an older save already
contains a requested building or because multiple thresholds changed in one
simulation update.

**Why this priority**: The current content can permit a request building to exist
before its character reaches the required state. Reconciliation must make such
saves safe without weakening new-game ordering.

**Independent Test**: Load fixtures at every character and patron boundary,
including a legacy fixture with an already-placed request, and verify the unique
canonical next state and event count.

**Acceptance Scenarios**:

1. **Given** an old save with a request building already placed and its character in `ARRIVED`, **When** the arrival dialogue is resolved, **Then** the character reconciles through reveal to satisfied exactly once.
2. **Given** a request building was placed and later demolished before reconciliation, **When** the save loads, **Then** the character is not falsely satisfied.
3. **Given** multiple arrival conditions become true during one tick, **When** events are queued, **Then** every arrival occurs once in deterministic order and ordinary world input remains usable after the queue is resolved.
4. **Given** a completed patron save, **When** it is loaded repeatedly, **Then** completion events, newspaper items, and land expansion are not duplicated.

---

### User Story 4 — Understand current progression (Priority: P2)

As a player or playtester, I can tell the next meaningful progression step and
why it is not yet available.

**Why this priority**: A route can be mechanically reachable and still be
unplayable if the next step is hidden.

**Independent Test**: At every canonical milestone, inspect the Patron drawer,
radial menu, and playtest snapshot and verify that they agree on the next gate.

**Acceptance Scenarios**:

1. **Given** a character has not arrived, **When** progression is inspected, **Then** required bucket, fulfilled demand, current value, required tier, and attained tier are available without raw implementation identifiers in the default player view.
2. **Given** a want is revealed, **When** the player opens the relevant radial group, **Then** the requested building and any remaining prerequisite are identifiable.
3. **Given** the patron becomes ready, **When** the state changes, **Then** the landmark appears as the next actionable goal and the inbox/dashboard do not advertise an obsolete character step.

## 5. Edge Cases

- Fulfilled demand reaches the threshold before the required tier is placed, and
  vice versa.
- A demand spend causes one unlock while a structure placement causes another
  in the same call stack.
- Two or three characters become eligible in the same simulation hour.
- Dialogue is queued rather than opened immediately when another modal is active.
- The player saves or loads between arrival, dialogue resolution, reveal,
  request placement, patron readiness, and landmark completion.
- A requested unique exists in an older save before its character arrives.
- A requested unique is demolished after satisfaction but before landmark
  placement.
- A chain prerequisite is demolished after a later chain item is placed.
- The landmark or its prerequisites are demolished after patron completion.
- A content revision lowers a threshold beneath the current fulfilled value.
- An authored character references an unknown bucket, tier, request, or patron.
- A donation overlaps already buildable cells or is replayed after completion.
- Narrative presentation is disabled during automated core progression.

## 6. Requirements

### Functional Requirements

- **FR-001**: The game MUST define attained bucket tier from canonical placed-building and catalog data.
- **FR-002**: Character arrival MUST require both the authored fulfilled-demand threshold and authored required tier.
- **FR-003**: Character arrival checks MUST run after relevant placement, demand, load, reset, and content-reconciliation changes.
- **FR-004**: Each character state transition MUST be monotonic, idempotent, persisted, and emitted at most once per actual transition.
- **FR-005**: A character-linked request MUST NOT be selectable in a new game before that character reaches `WANT_REVEALED`.
- **FR-006**: Request availability MUST continue to enforce canonical demand, prerequisite, uniqueness, affordability, footprint, and land rules.
- **FR-007**: A legacy save containing an already-placed request MUST reconcile the character when reveal becomes valid without replaying prior events.
- **FR-008**: A character MUST become satisfied only when its requested building currently exists at reconciliation time or is newly placed after reveal.
- **FR-009**: Patron availability MUST require every associated character to be satisfied or contributed.
- **FR-010**: A landmark MUST NOT be selectable before its patron reaches `LANDMARK_AVAILABLE`.
- **FR-011**: Patron completion, character contribution, event dispatch, and land donation MUST occur atomically from the authoritative landmark placement.
- **FR-012**: Land donation MUST be idempotent and MUST report only newly added cells.
- **FR-013**: Progression locks MUST expose stable reason codes including `required_tier_not_reached`, `want_not_revealed`, and `patron_not_ready`, alongside existing demand and prerequisite reasons.
- **FR-014**: Player-facing gate explanations MUST use authored display names and values rather than raw IDs alone.
- **FR-015**: The radial menu, Patron drawer, event system, and playtest snapshot MUST consume the same progression decisions.
- **FR-016**: The canonical scenario MUST begin from the ordinary fresh-map path and use only the same placement, time, and dialogue-resolution commands available to normal gameplay.
- **FR-017**: The canonical trace MUST retain every milestone listed in section 3.4 with ordered outcomes and deterministic hashes.
- **FR-018**: Provisional content-data changes MAY correct impossible thresholds, but MUST be recorded against an unchanged before trace and MUST NOT be treated as final pacing balance.
- **FR-019**: Unknown or inconsistent authored progression references MUST fail validation with actionable file and field context.
- **FR-020**: Narrative placeholder content or disabled presentation MUST NOT prevent the automated progression scenario from completing.

### Key Entities

- **Bucket Progress State**: Bucket ID, current fulfilled demand, attained tier, and the placed building evidence supporting that tier.
- **Character Progress Gate**: Character ID, current state, associated bucket, current/required fulfilled demand, current/required tier, request ID, and canonical lock reason.
- **Story Building Gate**: Chain role, associated character or patron, ordinary building gates, progression gate, and selectable state.
- **Patron Progress State**: Patron ID, character completion set, current state, landmark ID, and donation-applied state.
- **Progression Milestone**: Stable milestone ID, simulation time, action sequence, supporting state, outcome, and state hash.
- **Progression Reconciliation**: Idempotent comparison of persisted progression with current canonical world state.

## 7. Success Criteria

### Measurable Outcomes

- **SC-001**: The canonical fresh-town run reaches first-patron completion and a non-zero land expansion using only legal public gameplay actions.
- **SC-002**: Ten identical scenario runs produce the same ordered milestone list and equivalent balance-relevant final hash in all ten runs.
- **SC-003**: Every character, want, patron, and landmark gate at every scenario milestone agrees across radial UI, Patron UI, gameplay command, and playtest snapshot tests.
- **SC-004**: No character request can be selected before reveal in the new-game acceptance matrix, and every rejection leaves cash, demand, buildings, and progression unchanged.
- **SC-005**: Fixtures saved at every progression boundary reload to the same character states, patron state, placed unique set, allowed-cell count, flags, and event counts.
- **SC-006**: Legacy fixtures with an already-placed request reconcile exactly once, while fixtures where that request is absent do not falsely advance.
- **SC-007**: Repeated landmark completion reconciliation adds zero duplicate cells and emits zero duplicate completion events.
- **SC-008**: All existing builder, demand, unique, character, patron, event, inbox, dashboard, playtest, Community, and Player UI tests remain passing.

## 8. Assumptions

- The Howarth Players remain the only live patron in this milestone.
- The three current quest characters and Theatre remain the intended first arc.
- `arrival_requires_tier` means a currently placed building has attained at
  least that tier in the character's associated bucket.
- Requested uniques should be visible while locked, but their identity may be
  presented as a mystery until the character arrives if later narrative design
  prefers that treatment.
- Resolving placeholder arrival dialogue is sufficient to reveal a request;
  authored prose is not required for progression verification.
- Provisional threshold corrections establish reachability only. Milestone 006
  owns the intended pace, pressure, and strategic balance.
- Character and patron completion are durable narrative facts and do not regress
  when a completed building is demolished.

## 9. Test Seams

- **Unit**: tier derivation, dual-condition arrival, state idempotency, request
  and landmark gates, reconciliation, stable reasons, and donation deduplication.
- **Integration**: placement/demand signals through CharacterSystem,
  UniqueRegistry, PatronSystem, EventSystem, Inbox, Dashboard, Palette, and
  BuildableArea.
- **Scenario**: one complete fresh-town deterministic patron run plus save/load
  fixtures at every state boundary.
- **Regression**: existing story-independent early-city and Community scenarios
  remain completable with narrative presentation disabled.
- **Visual**: milestone captures for first arrival, revealed request, patron
  ready, landmark placement, and expanded land.

## 10. Dependency and Handoff

This specification is the prerequisite for `006-connected-first-town-loop`.
Milestone 006 may tune thresholds and pacing but must retain this milestone's
ordering, reconciliation, and reachability contracts.
