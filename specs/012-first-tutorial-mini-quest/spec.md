# Feature Specification: First Tutorial Mini-Quest

**Feature Branch**: `codex/009-performance-foundation` (feature directory is independent)

**Created**: 2026-09-06

**Status**: Implemented and verified with user-approved labelled placeholders

**Input**: Workstream 1 in `NEXT_IDEA_PROMPTS.md`: guide a fresh town from its Town Hall through roads, nature, homes, decoration, work, and its first shop, then hand off to the separate first-land-quest workstream.

## Scope and boundaries

This feature adds one durable, state-driven opening mini-quest. It reuses canonical
placement, demand, attractiveness, Community, compact-guidance, dialogue, event, and
persistence authorities. The tutorial observes those systems and projects the next
useful lesson; it never places buildings, awards demand, edits simulation values, or
reimplements placement validity.

The later Sir William land quest, new townspeople, balance tuning, live cell-specific
placement consequences, and final dialogue not explicitly approved by the user are out
of scope. Completion exposes one idempotent handoff fact/event that Workstream 2 can
consume; it does not author that later quest.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Found and Green the Town (Priority: P1)

As a new player, I receive characterful guidance to place the free Town Hall, connect a
useful stretch of road, and add two different kinds of nature until the city-wide
attractiveness shown with the Beauty visual language is positive.

**Why this priority**: It establishes the rooted placement rules and the causal chain
that generates early Homes demand.

**Independent Test**: Start a fresh rooted-town save, follow only the projected lesson,
and reach `NATURE_COMPLETE`; repeat by placing qualifying items before their lesson is
shown and confirm the projection catches up without replaying completed beats.

**Acceptance Scenarios**:

1. **Given** a fresh rooted town with no Town Hall, **When** guidance is projected,
   **Then** Town Hall placement is the sole first objective.
2. **Given** a Town Hall exists, **When** fewer than four road cells belong to its rooted
   road component, **Then** guidance asks for a short connected road and reports progress.
3. **Given** at least four rooted road cells, **When** fewer than two distinct placed
   nature building IDs contribute to the city, **Then** guidance asks for a different
   kind of nature and never treats duplicate copies as two kinds.
4. **Given** two distinct nature kinds exist but city attractiveness is not positive,
   **When** state reconciles, **Then** guidance asks for more/improved nature until the
   canonical city score is greater than zero.
5. **Given** the player completed any of these facts early, **When** the tutorial starts
   or reloads, **Then** all already-satisfied objectives reconcile in one forward pass.

---

### User Story 2 - Learn Homes and Neighbour Effects (Priority: P1)

As a new player, I connect positive attractiveness to Homes demand, place early housing,
see that tightly grouping homes can reduce attractiveness/quality, and improve the area
with decoration rather than memorising an abstract warning.

**Why this priority**: It turns the first simulation trade-off into an observable action
and response.

**Independent Test**: Reach positive attractiveness, accrue enough canonical Homes bank
for available tier-one housing, place two qualifying homes directly adjacent, observe
the before/after score evidence, then add nature/decoration that produces a measurable
improvement around the affected home.

**Acceptance Scenarios**:

1. **Given** nature is complete, **When** no qualifying residential building exists,
   **Then** guidance explains that Beauty/attractiveness creates Homes demand and asks
   for any currently legal early home rather than one hard-coded model.
2. **Given** one qualifying home exists, **When** a second is still needed, **Then** the
   next lesson deliberately asks for a second home beside the first so the authored
   residential adjacency effect can be observed.
3. **Given** two homes have been placed adjacent within the canonical attractiveness
   radius, **When** their local/city attractiveness is compared with the pre-placement
   snapshot, **Then** the tutorial records whether the expected penalty was observed and
   explains the consequence using the actual result.
4. **Given** the adjacency lesson has been observed, **When** a subsequent nature or
   decorative placement increases the affected home's canonical score, **Then** the
   decoration lesson completes.
5. **Given** a legacy save contains adjacent or already-improved homes but no historical
   experiment receipt, **When** it loads, **Then** the tutorial labels the baseline as
   unavailable, makes no causal claim, and asks for one new observable qualifying action;
   valid receipts from post-feature saves resume without regression.

---

### User Story 3 - Add Work and a First Shop (Priority: P1)

As a new player, I provide work away from homes, understand that residents travel to
work and earn money, then place a first shop while considering access versus nearby
residential impacts.

**Why this priority**: It closes the opening Homes → Work → Shops loop and establishes
the handoff boundary to the first full quest.

**Independent Test**: From the decorated-home state, place any legal early industrial
building outside its negative residential-effect radius with rooted-road access, wait
for at least one resident's canonical work participation, then place any legal early
commercial building with rooted access and complete the mini-quest exactly once.

**Acceptance Scenarios**:

1. **Given** the home lesson is complete, **When** no early industrial building exists,
   **Then** guidance asks for a workplace and explains that its authored negative local
   effects should not overlap homes.
2. **Given** an industrial building is placed, **When** it lacks rooted road access or a
   home lies inside an authored negative residential-effect radius, **Then** the lesson
   remains active and reports the observed issue without undoing the legal placement.
3. **Given** a suitably separated, accessible workplace exists, **When** canonical
   Community operation shows at least one resident participating at work, **Then** a
   brief full exchange may explain work and earnings before the shop objective.
4. **Given** the work lesson is complete, **When** no early commercial building exists,
   **Then** guidance asks for a shop and frames access versus residential impact using
   the shop's authored effects and canonical route/access facts.
5. **Given** a legal, rooted-access commercial building is committed, **When** tutorial
   state reconciles, **Then** the mini-quest completes, emits its handoff exactly once,
   and never starts or invents Workstream 2's land-quest dialogue.

---

### User Story 4 - Resume Without Repetition (Priority: P1)

As a returning or experimental player, I can save, reload, demolish, pre-build, and take
valid actions in unusual order without losing progress or being forced through stale
instructions.

**Independent Test**: Save/load at every state boundary; separately pre-place later
categories, demolish completed-step buildings, and perform multiple qualifying actions
in one frame. Compare the final state, receipts, and handoff count.

**Acceptance Scenarios**:

1. **Given** a tutorial step was completed, **When** its building is later demolished,
   **Then** the durable step receipt does not regress.
2. **Given** later-step evidence exists before an earlier prerequisite, **When** the
   earlier prerequisite completes, **Then** reconciliation advances through every now-
   satisfied step in stable order without repeating presentations.
3. **Given** the game saves and reloads at any boundary, **When** map reconciliation
   runs, **Then** the same or a later semantic step is active and completed guidance is
   not redispatched.
4. **Given** the same placement or map-load signal is observed more than once, **When**
   state reconciles, **Then** receipts, dialogue events, and the terminal handoff remain
   idempotent.

## Required dialogue beat map

Final wording is deliberately deferred. The complete beat
inventory, speaker, emotional purpose, trigger, lesson, format, expression, and writing
options live in [dialogue-workshop.md](dialogue-workshop.md). Compact beats must be one
dismissible direction; full exchanges use the established dialogue authoring schema.
Only user-approved text may enter runtime event/content data. On 2026-09-06 the user
explicitly approved labelled `AMBROSE PLACEHOLDER` purpose text for B01–B18 so technical
implementation and verification can proceed without pretending the copy is final.

## Edge Cases

- The player places roads not connected to the Town Hall, or places more than the target
  in one drag.
- Two nature models share a pool/category; distinctness uses canonical building ID, not
  UI label, tile count, or pool.
- Positive attractiveness is reached before the second nature kind; both conditions are
  still required.
- Housing demand has not accrued enough to afford a home; the active guidance explains
  the wait and updates from demand signals rather than accepting an impossible action.
- The second home is placed non-adjacent, or a different valid residential model is used.
- Authored data changes so adjacent homes no longer create a negative observation; the
  tutorial reports a stable content-contract diagnostic and does not fabricate a loss.
- Industry is legal but inaccessible, too close to one home, or later becomes separated
  through demolition.
- Residents have not yet reached an open workplace because of schedule/time; progress
  waits on canonical participation and explains the wait.
- A shop is placed early, demolished, replaced, rotated, or uses a different model from
  the default pool.
- Several state-changing signals fire in one frame; reconciliation is coalesced and
  monotonic.
- The compact direction is dismissed, a modal dialogue opens, or Community inspection
  suppresses it; dismissal is presentation state and does not change tutorial progress.
- A legacy save has no tutorial fields; state is derived safely from current world facts.
- Narrative presentation is disabled for headless play; the state machine and handoff
  still complete without loading portraits or dialogue UI.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST represent the mini-quest as an ordered monotonic semantic
  state with durable completed-step receipts and one durable terminal handoff receipt.
- **FR-002**: The system MUST reconcile state from canonical world facts on boot, map
  load, placement/demolition, demand, attractiveness, Community, and road revisions.
- **FR-003**: Reconciliation MUST advance through multiple already-satisfied steps in one
  stable forward pass and MUST NOT regress after demolition or changed simulation data.
- **FR-004**: The tutorial MUST observe canonical placement and simulation authorities;
  it MUST NOT mutate the grid, demand, cash, attractiveness, residents, or progression
  to force completion.
- **FR-005**: The first active objective MUST be the Town Hall and complete only from
  RoadNetwork's canonical Town Hall internal ID plus BuildingCatalog identity.
- **FR-006**: The road objective MUST require at least four road cells in the Town Hall-
  rooted component; disconnected roads MUST NOT count.
- **FR-007**: The nature objective MUST require at least two distinct canonical nature
  building IDs and a canonical city attractiveness score greater than zero.
- **FR-008**: The first housing objective MUST accept any legal placed residential
  building from an available early pool and expose affordability/wait state truthfully.
- **FR-009**: The adjacency lesson MUST use canonical footprint/radius evidence and an
  actual before/after attractiveness observation; it MUST NOT claim a penalty that the
  current authored content does not produce.
- **FR-010**: The decoration lesson MUST complete only after a subsequent authored nature
  placement measurably improves the affected home's canonical score; “decoration” is
  player-facing language for the catalogue's existing nature category in this slice.
- **FR-011**: The work objective MUST accept any early industrial building, require
  rooted-road access, and require no home inside any authored negative residential-
  impact radius before separation is considered taught.
- **FR-012**: Work participation MUST be confirmed by canonical Community operation data
  for at least one resident; elapsed time alone MUST NOT satisfy the lesson.
- **FR-013**: The shop objective MUST accept any early commercial building with rooted
  road access and project its actual authored positive/negative trade-off without
  tile-specific preview calculations.
- **FR-014**: Completing the first qualifying shop MUST write one terminal receipt and
  emit one stable `tutorial_opening_completed` handoff signal/event for Workstream 2.
- **FR-015**: Compact guidance MUST remain a presentation of the tutorial's canonical
  projection and retain its current dismissal, suppression, portrait, and input rules.
- **FR-016**: Longer explanatory beats MUST use the established dialogue schema,
  expression vocabulary, late-commit behavior, pending recovery, and headless parity.
- **FR-017**: Runtime dialogue text MUST be limited to prose explicitly approved through
  `dialogue-workshop.md`; draft alternatives MUST remain documentation-only.
- **FR-018**: Dialogue/event effects MUST remain owned by EventSystem, while tutorial
  objective progression MUST remain owned by one focused tutorial authority.
- **FR-019**: Tutorial state MUST be included in ordinary save resources and normalized
  playtest snapshots with stable semantic IDs and no UI-only data.
- **FR-020**: Automated coverage MUST include every transition, early/out-of-order
  completion, duplicate signals, demolition non-regression, save/load boundary, content-
  contract diagnostics, headless parity, and exactly-once handoff.
- **FR-021**: Verification MUST include focused and full Godot suites with writable
  `user://`, deterministic replay, a full automated opening scenario, and normal-
  renderer in-game review of every approved guidance/dialogue beat.
- **FR-022**: The completed feature MUST remain legible and operable at 1280×720,
  1920×1080, and 3840×2160 and MUST not obscure placement, modal dialogue, the bottom
  dock, or the insights drawer.

### Key Entities

- **Opening Tutorial State**: Current semantic step, completed-step receipt set, any
  durable lesson anchor/evidence needed after reload, and terminal handoff receipt.
- **Tutorial Evidence Snapshot**: Detached observation of Town Hall, rooted roads,
  distinct nature IDs, attractiveness, qualifying categories, access, radii, home
  scores, resident participation, demand affordability, and shop placement.
- **Tutorial Projection**: Presentation-neutral current direction containing step ID,
  progress, blocker/wait reason, speaker/expression, and approved copy key.
- **Dialogue Beat Group**: One approved compact direction or full exchange mapped to a
  semantic trigger and expression vocabulary.
- **Opening Completion Handoff**: Exactly-once fact/event consumed by the separate land-
  quest workstream.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The canonical fresh-town scenario reaches terminal completion through the
  brief's eight narrative phases and all nine semantic objective receipts with zero
  direct state mutation by the tutorial.
- **SC-002**: A declared out-of-order matrix reaches the same terminal semantic state and
  exactly one handoff for 100% of covered valid action orders.
- **SC-003**: Save/load at every semantic boundary preserves all completed receipts,
  repeats zero completed presentations, and produces zero duplicate handoffs.
- **SC-004**: Every projected claim about connectivity, attractiveness, adjacency,
  impact radius, operation, and access matches the corresponding canonical subsystem.
- **SC-005**: Visible and headless runs end with equivalent normalized tutorial state and
  deterministic hashes for identical seeds/actions.
- **SC-006**: At each supported resolution, every approved compact/full beat is readable,
  dismissible/advanceable as designed, and clear of protected HUD regions.
- **SC-007**: In-game review confirms every approved beat is clear, well paced, and fun;
  no temporary or unapproved prose appears in runtime content.
- **SC-008**: Focused tutorial/dashboard/dialogue/event/persistence suites, full GUT,
  deterministic replay, and the automated opening scenario all pass without regression.

## Assumptions

- “Beauty returns to a positive value” refers to the existing city-wide attractiveness
  value presented with the Beauty icon; Community residents do not yet exist at that
  early point, so their average Beauty is not a viable gate.
- Four Town Hall-rooted road cells are a short, understandable minimum that can front
  early homes, work, and shops without prescribing a layout.
- “Directly beside one another” uses the existing Chebyshev/radius semantics and actual
  canonical score change rather than a new bespoke adjacency penalty.
- A legacy save without stored before/after evidence cannot prove the adjacency or
  improvement experiment historically; it resumes at a safe observable action and
  never substitutes authored intent for measured evidence.
- The catalogue currently exposes nature, not a separate decoration category. This
  workstream calls suitable nature “decoration” in guidance and does not add a category.
- A qualifying early building is identified by its canonical `BuildingProfile.category`
  and availability, not a specific art/model ID.
- If current starter balance temporarily makes a requested action unaffordable, the
  tutorial explains the canonical wait. Balance changes belong to Workstream 3.
- Ambrose is the guide and uses the existing semantic expression vocabulary. The player
  need not speak during compact directions; any full exchange retains the existing
  `player` semantic participant and Ambrose stand-in convention until art direction
  changes.

## Deferred creative gate

The user-approved labelled placeholder convention in
[dialogue-workshop.md](dialogue-workshop.md) removes the implementation blocker. Final
voice and prose remain a clearly tracked later replacement and must not be described as
reviewed or final during this workstream's verification.
