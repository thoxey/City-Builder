# Feature Specification: Gameplay Playtest MCP

**Feature Branch**: `001-gameplay-playtest-mcp` *(planning identifier; no branch created)*

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Create a very small MCP for playing the city builder so an AI can repeatedly drive the real game, assess and tune the city-building fundamentals, and establish balanced, interesting gameplay before story content is authored over it."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Through the Real City-Building Loop (Priority: P1)

As a game designer working with an AI collaborator, I can start a fresh city,
inspect the choices available to a player, place or demolish buildings, and
advance the simulation through a small set of semantic commands so that the AI
can genuinely play the game rather than infer balance from static data.

**Why this priority**: Without a trustworthy action loop there is no automated
playtest capability and no basis for tuning gameplay.

**Independent Test**: Start a fresh session, place one currently affordable
building, advance one simulation hour, and verify that the resulting state is
the same as performing the equivalent action through the normal player
interface.

**Acceptance Scenarios**:

1. **Given** a fresh playable city, **When** the playtester requests the current state, **Then** it receives the resources, simulation time, structures, buildable area, demand, attractiveness, and legal building choices needed to choose a next action.
2. **Given** a building that the player can legally place, **When** the playtester places it on valid land, **Then** the normal placement rules, costs, signals, and simulation effects occur exactly once.
3. **Given** a placed building that the player can demolish, **When** the playtester demolishes it, **Then** the normal demolition rules and downstream recalculations occur exactly once.
4. **Given** a requested action that is not legal, **When** the playtester attempts it, **Then** no gameplay state changes and the response identifies the applicable gameplay reason.

---

### User Story 2 - Run Deterministic Balance Experiments (Priority: P1)

As a game designer, I can replay the same starting conditions and action
sequence while advancing time without real-time waiting so that balance changes
can be compared fairly.

**Why this priority**: Repeatability is required to distinguish a tuning effect
from timing differences or random variation.

**Independent Test**: Run the same seeded scenario and ordered actions twice,
then compare all balance-relevant fields in the final snapshots.

**Acceptance Scenarios**:

1. **Given** a declared scenario and seed, **When** it is started twice and receives the same ordered actions, **Then** both runs produce equivalent balance-relevant snapshots.
2. **Given** a paused automated session, **When** the playtester advances a declared number of hours, **Then** exactly that many simulation-hour updates occur without requiring equivalent wall-clock time.
3. **Given** a completed run, **When** its trace is reviewed, **Then** every action, rejection, time advance, and resulting snapshot can be associated with its sequence position.

---

### User Story 3 - Understand Available Choices and Rejections (Priority: P2)

As an AI playtester, I can discover which buildings are available now and why
other buildings are unavailable so that I can form strategies without relying
on private implementation knowledge.

**Why this priority**: An agent that cannot understand constraints will waste
actions and cannot make meaningful comparisons between strategies.

**Independent Test**: Inspect choices in a fresh city, attempt one action from
the available set and one locked action, and verify that availability and
rejection reasons agree with the player-facing rules.

**Acceptance Scenarios**:

1. **Given** the current city state, **When** available actions are requested, **Then** each build choice includes its identity, footprint, relevant cost, and current availability.
2. **Given** a locked, unaffordable, occupied, out-of-bounds, or unique-already-placed building action, **When** availability is inspected or placement is attempted, **Then** a stable machine-readable reason is returned.
3. **Given** a pooled building choice, **When** it is selected using a declared seed, **Then** the chosen variant is recorded in the result and can be reproduced.

---

### User Story 4 - Compare Gameplay Tuning (Priority: P2)

As a game designer, I can run named baseline scenarios before and after changing
balance data and compare their outcomes so that changes are supported by
evidence rather than intuition alone.

**Why this priority**: The purpose of the playtest interface is to improve the
gameplay loop, not merely to demonstrate remote control.

**Independent Test**: Run a standard early-city scenario against two tuning
configurations and produce a comparison containing progression time, resource
pressure, action rejections, and final city state.

**Acceptance Scenarios**:

1. **Given** a named balance scenario, **When** it completes, **Then** its initial conditions, seed, ordered trace, milestones, and final snapshot are retained as a comparable result.
2. **Given** two results for the same scenario and seed, **When** they are compared, **Then** differences in progression time, resources, demand fulfilment, attractiveness, build choices, and failure states are visible.
3. **Given** an unfinished narrative layer, **When** a core balance scenario runs, **Then** missing dialogue, portraits, or story copy do not prevent completion.

### Edge Cases

- The game is not running, is still loading, has crashed, or disconnects during an action.
- A command is repeated after the caller times out and the first command may already have completed.
- Coordinates are malformed, outside the buildable mask, overlap a multi-cell footprint, or reference a non-anchor cell for demolition.
- A requested building identifier is unknown, hidden support content, locked, unaffordable, or already placed when unique.
- Advancing zero, a negative amount, a fractional amount, or an excessive number of hours.
- Natural random variation exists in pooled models or simulation systems.
- A story event or modal would normally interrupt input during a core-system scenario.
- A saved scenario references content removed by the aristocrat-only prune.
- The action succeeds but a downstream plugin reports an error or fails to update before the snapshot is returned.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST expose a small, documented set of semantic playtest commands for starting or resetting a session, observing state, discovering choices, placing, demolishing, and advancing time.
- **FR-002**: Automated placement and demolition MUST use the same gameplay validation and mutation path as equivalent player actions.
- **FR-003**: The system MUST reject any automated action the player could not legally perform in the same state.
- **FR-004**: Every action response MUST include whether state changed, the stable outcome or rejection code, and enough context to identify the affected building or location.
- **FR-005**: A state snapshot MUST include simulation time, cash, population, employment or industrial output, satisfaction, attractiveness, each demand bucket's total/fulfilled/unserved values, placed structures, buildable-area extent, and progression-neutral unlock state.
- **FR-006**: The system MUST identify all currently selectable building choices and expose the information necessary to reason about their cost, capacity, footprint, category, tier, uniqueness, and lock state.
- **FR-007**: Unavailable choices MUST expose one or more stable reasons, including at minimum insufficient resources, unmet threshold, unmet prerequisite, already placed, invalid land, and occupied footprint.
- **FR-008**: Automated sessions MUST support an explicit deterministic random seed.
- **FR-009**: The system MUST allow wall-clock simulation progression to be paused while an automated session is active.
- **FR-010**: The system MUST advance an exact non-negative whole number of simulation hours on request.
- **FR-011**: The state returned after an action MUST reflect all synchronous balance-relevant effects of that action before control returns.
- **FR-012**: The system MUST record an ordered trace containing session identity, scenario identity, seed, actions, outcomes, time advances, and observation points.
- **FR-013**: A caller MUST be able to start from a standard fresh-city scenario without depending on a user save file.
- **FR-014**: Repeating the same scenario, seed, content revision, and ordered actions MUST produce equivalent balance-relevant results.
- **FR-015**: The system MUST distinguish transport or runtime failures from valid gameplay rejections.
- **FR-016**: A timed-out or repeated request MUST NOT unknowingly apply the same state-changing action twice.
- **FR-017**: Core-system balance scenarios MUST be runnable without completing or consuming narrative dialogue.
- **FR-018**: The playtest interface MUST be local-development-only and MUST be absent or inert in normal release play.
- **FR-019**: Standard scenarios MUST support before-and-after comparison across balance-data revisions using the same initial conditions and seed.
- **FR-020**: The initial interface MUST remain limited to city-building observation and action; authoring story content, manipulating arbitrary runtime properties, controlling the camera, and editing project files are out of scope.

### Key Entities

- **Playtest Session**: One controlled run, identified by scenario, seed, content revision, current sequence number, clock mode, and connection status.
- **City Snapshot**: A point-in-time, balance-relevant representation of the city and all choices available from it.
- **Building Choice**: A player-selectable building or pool together with its gameplay characteristics and current availability reasons.
- **Playtest Action**: A semantic request to place, demolish, or advance time, with a unique request identity and ordered outcome.
- **Action Outcome**: The applied, rejected, duplicate, or failed result of one action, including stable reason codes and resulting sequence number.
- **Scenario**: Named initial conditions and completion/failure criteria used for reproducible balance experiments.
- **Playtest Trace**: The ordered evidence from one session, including observations and milestone timestamps.
- **Balance Comparison**: Differences between compatible traces for the same scenario and seed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a contract test matrix covering every placement and demolition rejection class, automated actions and equivalent player actions produce matching outcomes in 100% of cases.
- **SC-002**: Ten repeated runs of the same scenario, seed, content revision, and action list produce equivalent balance-relevant final snapshots in all ten runs.
- **SC-003**: A playtester can start a fresh city, obtain a usable state, place a building, advance time, and observe the result using no more than five commands.
- **SC-004**: Every rejected gameplay action in the acceptance suite returns a stable reason and leaves the balance-relevant snapshot unchanged.
- **SC-005**: Advancing 100 simulation hours completes in no more than 10 seconds on the development machine while returning exactly 100 hourly updates.
- **SC-006**: Twenty consecutive standard scenario runs complete without a lost connection, duplicate action, unclassified failure, or need for manual UI input.
- **SC-007**: A before-and-after balance comparison for the same scenario can identify milestone-time and final-state differences without manually reading engine logs.
- **SC-008**: All core balance scenarios run successfully when narrative presentation is disabled or contains placeholder content.

## Assumptions

- The initial user is the local developer or an AI collaborator acting with the developer's authority; remote and multi-user access are not required.
- The running development game remains the authority for gameplay state.
- Standard scenarios initially focus on the story-independent early and mid-game city loop, even though one aristocrat questline remains in the project.
- Existing building JSON and pool configuration remain the primary balance-authoring surface where their schemas are sufficient.
- Visual feel and spatial readability will still receive periodic human review; automated state traces do not replace subjective playtesting.
- Comparison storage may be local and disposable in the first version.
