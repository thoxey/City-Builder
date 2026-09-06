# Feature Specification: First Land Quest and Townspeople

**Feature Branch**: `codex/009-performance-foundation` (feature directory is independent)

**Created**: 2026-09-06

**Status**: Planned; implementation paused at collaborative creative checkpoint

**Input**: Workstream 2 in `NEXT_IDEA_PROMPTS.md`: start the first full-dialogue
quest after the opening shop, negotiate with Sir William for more land, and establish
four recurring human viewpoints on Opportunity, Livability, Beauty, and Belonging.

## Scope and boundaries

This feature adds one staged, recoverable land quest. It consumes the opening tutorial's
durable `tutorial_opening_completed` receipt, uses the existing EventSystem/Inbox/
Dialogue late-commit contracts, and asks the existing BuildableArea authority to apply
one authored, idempotent first-land grant. It does not reimplement placement, dialogue
traversal, save/load, or land-cell mutation.

The quest also establishes the smallest reusable townsperson foundation: four authored
minor-character profiles with recognizable motivations, tensions, expression sets, and
semantic reaction viewpoints. This slice proves one reaction or vignette for each
viewpoint and defines later reuse; it does not build a procedural conversation engine,
resident-wide bark system, or every future encounter.

Final residence/estate association, character identities and voices, scene prose,
choice labels, and exact land-grant shape remain user decisions. No draft prose or
provisional identity may enter runtime content as approved copy. The invariant quest
contracts below are implementation-ready; files depending on those creative selections
remain blocked until the decisions in [dialogue-workshop.md](dialogue-workshop.md) are
approved.

One existing presentation decision must also be resolved: semantic `player` currently
uses Ambrose's portrait and display name. The user must confirm that the player speaks
through Ambrose in this quest, or approve a distinct player identity before Ambrose can
appear as a separate NPC alongside player choices.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Receive the Land Petition (Priority: P1)

As a player who has completed the opening mini-quest, I receive exactly one full-
dialogue invitation from Ambrose explaining that the growing town needs land and that
Sir William is the person to approach.

**Why this priority**: This is the promised handoff from the tutorial and the durable
start of the first story quest.

**Independent Test**: Complete the first qualifying shop both in-session and by loading
a save that already contains the tutorial completion receipt. Confirm one pending land-
quest dialogue is available in either route, independently of whether B18 was read.

**Acceptance Scenarios**:

1. **Given** the tutorial completion receipt is absent, **When** the town changes or the
   map loads, **Then** the land quest remains unavailable.
2. **Given** the tutorial completion receipt is first written, **When** live handoff
   reconciliation runs, **Then** the first land-quest event becomes pending exactly once.
3. **Given** a completed-tutorial save loads, **When** the quest has never started,
   **Then** the same event becomes pending without requiring the transient handoff signal
   or acknowledgement of tutorial dialogue B18.
4. **Given** the invitation is pending or already completed, **When** duplicate shop,
   map-load, or reconciliation signals occur, **Then** it is not dispatched again.

---

### User Story 2 - Petition Sir William at an Established Place (Priority: P1)

As a player, I take part in a staged conversation at a clearly established Sir William
location, where Ambrose and Sir William are already acquainted and the request for land
has a personal, world-grounded context.

**Why this priority**: The full-dialogue scene and its sense of place are the feature's
dramatic core.

**Independent Test**: Open the authored quest fixture, read the approach and Sir William
stages, select each semantic petition approach in separate runs, and verify participant,
expression, branch, effect, staging, and terminal outcomes.

**Acceptance Scenarios**:

1. **Given** the invitation opens, **When** Ambrose introduces the problem, **Then** the
   scene states why more land matters, why Sir William controls it, and why persuasion is
   plausible without presenting the characters as strangers.
2. **Given** the petition stage begins, **When** Sir William enters the exchange, **Then**
   the scene identifies his approved residence/estate association and makes the location
   legible in the town or surrounding world.
3. **Given** a choice is reached, **When** the player selects an authored reply, **Then**
   its semantic approach is recorded at the existing dialogue commit boundary and the
   consequence is clear before the quest closes.
4. **Given** the dialogue is interrupted before a commit boundary, **When** the save is
   loaded, **Then** the pending scene can restart without applying choice flags, granting
   land, or duplicating completion.

---

### User Story 3 - Meet Four Human Viewpoints (Priority: P1)

As a player, I meet or hear from four minor townspeople whose lived priorities make
Opportunity, Livability, Beauty, and Belonging feel like competing human desires rather
than tutorial labels.

**Why this priority**: These voices are the bridge between abstract planning values and
the people affected by the player's decisions.

**Independent Test**: Play the approved vignette set and identify each person's concrete
want, tolerated downside, unacceptable downside, and disagreement with at least one
other viewpoint without seeing the community-quality labels used as their names.

**Acceptance Scenarios**:

1. **Given** the first shop and surrounding town, **When** the four viewpoints are
   introduced, **Then** each townsperson cites a concrete lived concern supported by the
   current town (for example walking distance, disturbance, appearance, or shared use).
2. **Given** two townspeople discuss the same planning outcome, **When** their reactions
   differ, **Then** both positions remain understandable and neither is presented as the
   uniquely correct stat answer.
3. **Given** a townsperson profile is authored, **When** later features request a
   reaction, **Then** the profile exposes a stable identity, dominant quality, motivation,
   trade-off, voice notes, and approved expressions without generating prose at runtime.
4. **Given** this first quest completes, **When** no later reaction content exists,
   **Then** the four profiles remain reusable data and do not manufacture future scenes.

---

### User Story 4 - Receive Land and Resume Safely (Priority: P1)

As a player, I finish the negotiation with a clear result: a declared parcel becomes
buildable, or an approved follow-up objective is recorded, exactly once and survives
save/load.

**Why this priority**: The quest needs a tangible city-building consequence and must not
corrupt the canonical buildable-area state.

**Independent Test**: Resolve every approved branch visibly and through the headless
first-option path; save/load before choice, after choice, and after grant application;
then compare quest receipts, choice flags, allowed cells, pending events, and hashes.

**Acceptance Scenarios**:

1. **Given** the terminal decision commits, **When** the approved outcome is an immediate
   grant, **Then** BuildableArea applies the authored parcel through one idempotent receipt
   and reports newly added versus overlapping cells.
2. **Given** the approved outcome is a follow-up objective, **When** dialogue completes,
   **Then** one durable semantic objective is recorded and land does not expand early.
3. **Given** the completion receipt already exists, **When** completion or load
   reconciliation repeats, **Then** no land cells, event counts, or flags duplicate.
4. **Given** narrative presentation is disabled, **When** the pending event is resolved
   headlessly, **Then** its semantic branch, outcome, acknowledgement, and deterministic
   game state match the visible path.

## Required dramatic and character map

The complete purpose, participant constraints, staged beats, motivations, expression
uses, semantic choices, gameplay outcomes, and prose options live in
[dialogue-workshop.md](dialogue-workshop.md). That document is workshop material, not
runtime content. Only a user-approved scene package may be implemented.

## Edge Cases

- Tutorial completion and B18 dialogue acknowledgement occur in either order.
- The quest event is already pending when a completed save loads.
- Event count exists but pending/completion receipts are malformed or from an older
  schema version.
- The player closes the game before any beat, during reveal, at a choice, after a choice
  but before the terminal beat, or immediately after land expansion.
- Two reaction vignettes need the same NPC portrait slot; the existing two-slot dialogue
  contract limits a single scene to the player plus at most two NPCs.
- A proposed scene needs more than three participants; it must be staged into separate
  event nodes/scenes rather than expanding the established renderer in this workstream.
- A selected branch records a preference but every approved branch grants equivalent
  land; the presentation must not imply materially different geometry.
- The grant overlaps current buildable cells, is empty/malformed, or lies outside the
  declared presentation bounds.
- The player has already built against the starter boundary before the grant.
- A townsperson's dominant viewpoint and actual current Community score disagree;
  personality is a preference lens, not a claim about the live aggregate.
- An expression asset is missing; established semantic fallback and diagnostics apply.
- Draft dialogue accidentally reaches event JSON or the exported manifest; release
  validation must reject unapproved copy/status.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Activation MUST consume the durable tutorial completion receipt as its
  source of truth and MUST also listen to the live handoff for same-session dispatch.
- **FR-002**: Activation MUST be idempotent across boot, map load, duplicate signals,
  pending recovery, and completed saves.
- **FR-003**: The quest MUST NOT depend on tutorial B18 being opened or acknowledged.
- **FR-004**: Quest availability, pending presentation, chosen approach, outcome, and
  completion MUST use stable semantic IDs and durable JSON-safe receipts.
- **FR-005**: Dialogue MUST use the established authored event schema, participant
  limits, expression vocabulary, late-commit effects, pending recovery, and headless
  traversal.
- **FR-006**: Runtime scene text and option labels MUST be limited to prose explicitly
  approved by the user; drafts and option workshops MUST remain documentation-only.
- **FR-007**: The scene MUST establish Ambrose and Sir William as already acquainted and
  identify the approved residence, estate, or building association.
- **FR-008**: The quest MUST provide at least one explicit player choice with a stable
  semantic approach; cosmetic prose variation MUST NOT masquerade as a different
  gameplay outcome.
- **FR-009**: The staged content MUST remain within the existing maximum of three
  participants per dialogue event; additional people MUST appear in separate staged
  vignettes/events.
- **FR-010**: Four minor townsperson profiles MUST represent Opportunity, Livability,
  Beauty, and Belonging through concrete motivations, desired benefits, tolerated costs,
  unacceptable costs, and tensions with another profile.
- **FR-011**: Viewpoint IDs MUST map to the existing canonical quality IDs, including the
  repository spelling `liveability`, while player-facing prose may use approved locale
  spelling.
- **FR-012**: A viewpoint MUST influence authored reaction selection/metadata only and
  MUST NOT directly mutate Community qualities, resident personalities, or building
  effects.
- **FR-013**: Later content MUST be able to reference a townsperson by stable ID and
  semantic reaction tags without copying their profile or generating prose at runtime.
- **FR-014**: The land outcome MUST be authored data and MUST pass through BuildableArea;
  dialogue or quest code MUST NOT directly mutate `allowed_cells`.
- **FR-015**: Land application MUST have a quest-specific idempotency receipt distinct
  from the later aristocrat patron landmark donation.
- **FR-016**: An empty or malformed grant MUST fail with a stable reason and MUST NOT
  write a success receipt.
- **FR-017**: The outcome MUST define whether every choice grants equivalent land or
  whether branches have explicitly approved distinct follow-ups; tests MUST cover each.
- **FR-018**: Save/load MUST preserve activation, semantic choice, outcome, completion,
  and land receipt while allowing only transient dialogue transcript/reveal state to
  restart.
- **FR-019**: Playtest snapshots and deterministic hashes MUST include semantic quest
  state and land receipts but exclude transcript, draft copy, portraits, and UI state.
- **FR-020**: Automated coverage MUST include live/boot activation, B18 independence,
  each approved branch, interruption boundaries, malformed state/content, exactly-once
  land application, visible/headless parity, and no replay after completion.
- **FR-021**: Verification MUST include focused and full Godot suites with writable
  `user://`, deterministic replay, one full opening-to-land scenario, manifest content
  audit, and normal-renderer review at supported resolutions.
- **FR-022**: In-game review MUST explicitly cover staging, voice distinction, choice
  clarity, expressions, pacing, and whether all four viewpoints read as people rather
  than stat labels.

### Key Entities

- **First Land Quest State**: Versioned monotonic activation, choice, outcome, and
  completion receipts owned by one focused quest authority.
- **Scene Package**: Approved event graph(s) containing participants, beats, expressions,
  choices, and effects.
- **Sir William Place Association**: Authored world anchor connecting Sir William to an
  approved residence/estate/building and staging label.
- **Townsperson Profile**: Stable minor-character identity plus one dominant viewpoint,
  motivation, trade-offs, voice notes, expression set, and semantic reaction tags.
- **Land Grant Definition**: Authored shape/cells and grant ID, separate from later patron
  donation data.
- **Quest Receipt**: Durable, exactly-once evidence for activation, selected approach,
  land/follow-up outcome, and completion.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Live handoff and completed-save boot each yield exactly one pending first-
  land quest; B18 state has zero effect on the result.
- **SC-002**: 100% of approved dialogue branches terminate with the documented semantic
  approach and outcome, with zero duplicated effects after interruption or reload.
- **SC-003**: An immediate grant adds exactly the authored non-overlapping cells once;
  repeated reconciliation changes the buildable set by zero cells.
- **SC-004**: Visible and headless runs produce equivalent normalized quest state,
  ordered effects, pending acknowledgement, allowed-cell set, and deterministic hash.
- **SC-005**: A blind review can correctly distinguish all four townspeople's concrete
  motivations without relying on quality labels in their names or dialogue.
- **SC-006**: In-game review at 1280×720, 1920×1080, and 3840×2160 finds no staging,
  portrait, choice, wrapping, or pacing blocker.
- **SC-007**: Runtime event data and the generated manifest contain zero workshop drafts,
  unapproved dialogue, or copy marked as provisional.
- **SC-008**: Focused quest/dialogue/event/buildable-area/persistence suites, full GUT,
  deterministic replay, and the full opening-to-land scenario pass without regression.

## Assumptions

- The first quest starts because the town is spatially constrained after the first shop;
  it does not require an additional demand threshold.
- Sir William already has a character definition and complete semantic expression map;
  his world-place association, not his renderer support, is the open decision.
- A first grant must use a new quest-specific grant ID so it cannot consume the later
  `aristocrat` patron-donation receipt or pre-complete the theatre questline.
- Existing dialogue events support at most three participants, so four townsperson
  viewpoints are introduced across short vignettes rather than one crowded group scene.
- Personality profiles are authored anchors for recurring minor characters. They do not
  replace the deterministic variation of ordinary Community residents.
- The approved mechanical default should give every petition approach an equivalent
  first parcel and record only a narrative preference, avoiding a blind permanent land
  penalty in the game's first full quest.

## Collaborative approval gate

Implementation that depends on authored content is blocked until the user approves the
decisions listed in [dialogue-workshop.md](dialogue-workshop.md). The repository has a
placeholder precedent only where the user explicitly approved labelled placeholders for
Workstream 1; no equivalent approval exists for this quest, so no runtime placeholder
scene is authorized here.
