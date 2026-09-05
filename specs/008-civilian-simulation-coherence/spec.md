# Feature Specification: Coherent Civilian Simulation

**Feature Branch**: `008-civilian-simulation-coherence` *(planning identifier; no branch created)*

**Created**: 2026-09-06

**Status**: Draft

**Input**: User description: "Deep-dive the existing civilian simulation and use the existing AI testing framework to plan concrete improvements that make the town feel more alive using existing assets."

## Problem Statement

The game already owns the ingredients of a convincing civilian simulation: named
Community residents, deterministic work and activity assignments, opening-hour
schedules, road reachability, pedestrian proxies, and pooled traffic. They do not
currently tell one coherent story. A visible proxy can forget its resident identity,
choose a different destination from Community, cross disconnected ground after a
failed path search, abandon a destination after a few seconds, or reset to home when
an unrelated building changes. Automated playtests verify the authoritative town
simulation but cannot currently detect those visible contradictions.

This feature makes visible civilians a faithful, continuous projection of the
existing Community and RoadNetwork truth. It deliberately deepens existing systems
and content instead of adding new models, animations, vehicles, props, or public
testing commands.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Residents Live Their Assigned Day (Priority: P1)

As a player watching the town, I see the same named residents who are counted as
working or participating travel to their actual assigned place, remain there for the
assignment's active period, and return home when their assignment ends.

**Why this priority**: The most damaging illusion break is a resident visually doing
something that contradicts the simulation that drives output and happiness.

**Independent Test**: Build one connected home, workplace, and scheduled activity;
advance through a day and compare each visible resident's location and purpose with
the Community assignment at each boundary.

**Acceptance Scenarios**:

1. **Given** a resident with a reachable work assignment, **When** that assignment becomes active, **Then** the resident travels to that exact workplace and remains there until the assignment changes or becomes inactive.
2. **Given** a resident with a reachable activity assignment, **When** that activity becomes active, **Then** the resident travels to that exact activity destination rather than choosing a category-random alternative.
3. **Given** an assigned period has ended and no replacement assignment is active, **When** the civilian projection reconciles, **Then** the resident returns to their immutable home and remains available for the next assignment.
4. **Given** the same town, seed, resident data, and sequence of simulation actions, **When** the sequence is replayed, **Then** resident purposes, destinations, departure ordering, and route choices are identical.

---

### User Story 2 - Journeys Respect the Town Players Built (Priority: P1)

As a player, I see civilians walk or drive only when their origin and destination are
connected by the town's real road network; disconnected places do not attract
teleporting or cross-country walkers.

**Why this priority**: Roads only feel meaningful if both the authoritative assignment
and its visible journey obey the same connectivity decision.

**Independent Test**: Run matched connected and disconnected layouts. The connected
layout produces a journey along the canonical route; the disconnected layout keeps
the resident at a valid current place with a stable blocked reason.

**Acceptance Scenarios**:

1. **Given** a reachable assigned destination, **When** a journey is planned, **Then** its stops and road path come from the canonical RoadNetwork route used to validate the assignment.
2. **Given** a destination is not reachable from the resident's current valid place, **When** a journey is requested, **Then** no direct fallback path is created and the resident stays at that place.
3. **Given** a short reachable route, **When** the resident travels, **Then** the existing pedestrian proxy follows connected placed cells or road-edge waypoints.
4. **Given** a longer reachable route and car capacity, **When** the resident travels, **Then** the existing car system follows the resolved route and returns the same resident to pedestrian travel at the resolved destination stop.

---

### User Story 3 - Town Edits Do Not Reset Daily Life (Priority: P2)

As a player building while the town is active, I can place or remove an unrelated
structure without every pedestrian popping home or every car disappearing.

**Why this priority**: Continuity is a high-value sign of life and can be achieved by
reconciling affected residents rather than producing new visual assets.

**Independent Test**: Start several civilians in different journey states, place an
unrelated structure, and verify their identities, positions, destinations, and active
vehicles are unchanged.

**Acceptance Scenarios**:

1. **Given** active civilian journeys, **When** a structure that does not affect their homes, destinations, or routes is placed or demolished, **Then** those journeys continue without respawn or cancellation.
2. **Given** a resident arrives, departs, or is rehomed, **When** the roster changes, **Then** only that resident's visible proxy is added, removed, or replanned.
3. **Given** a destination or route segment used by a journey is removed, **When** connectivity is invalidated, **Then** only affected journeys replan or stop at a valid place and report why.
4. **Given** a save is loaded, **When** visible proxies are reconstructed, **Then** each proxy is rebound to its resident and the current authoritative assignment without requiring transient journey transforms to be saved.

---

### User Story 4 - Existing Venues Create Recognisable Rhythms (Priority: P2)

As a player, I see existing social, leisure, and civic buildings become purposeful
destinations at appropriate hours, giving the town a daily rhythm without requiring
new art.

**Why this priority**: Several finished building assets are visually distinctive but
do not yet participate consistently in Community activity assignment.

**Independent Test**: Place the existing eligible venues in a connected town, advance
across their authored schedules, and verify that activity capacity and visible visits
appear only while their participant programme is active.

**Acceptance Scenarios**:

1. **Given** an existing venue with an authored participant effect and capacity, **When** its schedule is active, **Then** eligible residents may be assigned to it by Community and their proxies visit it.
2. **Given** the venue is closed or its programme changes, **When** assignments are reconciled in the same simulation hour, **Then** stale visits are removed and replacement assignments are deterministic.
3. **Given** an existing building whose gameplay role should remain cosmetic, local-only, or productive, **When** content is validated, **Then** it is not made a civilian destination merely because an asset exists.

---

### User Story 5 - Civilian Contradictions Are Automatically Detectable (Priority: P3)

As a developer or AI playtester, I can inspect and advance the visible civilian layer
in a deterministic scenario and receive explicit evidence when it diverges from the
authoritative Community or RoadNetwork state.

**Why this priority**: The present snapshot and hour-advance flow can pass while
visible residents are frozen, reset, or headed somewhere invalid. A test seam is
needed before the behaviour can be safely changed.

**Independent Test**: Run a headless scenario that interleaves exact simulation-hour
advances with fixed visual-time steps and asserts the civilian diagnostics at work,
activity, return-home, disconnect, and unrelated-build checkpoints.

**Acceptance Scenarios**:

1. **Given** a playtest snapshot request, **When** civilian diagnostics are available, **Then** the response reports resident binding, purpose, current place, destination, travel mode, route evidence, active cars, waiting cars, and alignment violations.
2. **Given** transient civilian diagnostics change while authoritative gameplay state is unchanged, **When** the gameplay state hash is calculated, **Then** the hash remains unchanged.
3. **Given** a headless multi-hour test, **When** each simulation-hour action is followed by fixed-duration visual stepping, **Then** journeys make deterministic progress and can be asserted without a seventh public playtest command.
4. **Given** two identical scenario runs, **When** their civilian traces are compared, **Then** they contain the same ordered resident states and zero unexplained divergence.

### Edge Cases

- A resident's assignment changes while they are walking, driving, or waiting for a car.
- An assigned destination closes, changes programme, is demolished, or becomes disconnected in the current hour.
- A resident's home is demolished, the resident becomes homeless, or they are rehomed while away from home.
- A resident arrives or departs while the visible-proxy cap is already reached.
- More residents exist than the current 512 visible-proxy cap; selection remains stable and diagnostics distinguish simulated residents from visible residents.
- A building has multiple valid adjacent road stops or two routes have equal length; selection uses the existing stable route ordering.
- A short journey becomes long, or a long journey becomes short, after a road edit.
- The car pool is full or a dispatched car cannot reserve the next lane tile.
- Many simulation hours are advanced without rendered frames; authoritative state still advances, while fixed visual stepping is explicit in tests.
- Save/load occurs while a resident is in transit; no transient car or transform is treated as saved gameplay truth.
- A programme changes after Community has already calculated assignments for the current hour; assignment caches are invalidated immediately.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every visible civilian proxy MUST retain the stable `resident_id` and seed of exactly one current Community resident.
- **FR-002**: A resident's authoritative home MUST remain distinct from their current place and current journey destination.
- **FR-003**: Community MUST remain the sole owner of work and activity assignments; People and CarManager MUST NOT create competing gameplay assignments.
- **FR-004**: When a Community assignment is active and reachable, the corresponding visible civilian MUST use that exact assigned destination and purpose.
- **FR-005**: When no assignment is active, the visible civilian MUST remain at or return to their authoritative home unless homelessness or rehoming requires another valid state.
- **FR-006**: Random visual variation MUST be derived from resident seed plus stable simulation context and MUST NOT use unseeded global randomness.
- **FR-007**: A visible civilian MUST dwell at an assigned destination until that assignment changes, becomes inactive, or becomes invalid; it MUST NOT abandon it on an arbitrary real-time timer.
- **FR-008**: RoadNetwork MUST remain the sole authority for building access, connected stops, route choice, and route distance.
- **FR-009**: People and CarManager MUST consume the same resolved route evidence used to establish assignment reachability.
- **FR-010**: A failed route lookup MUST leave the resident at a valid current place with an explainable blocked reason; it MUST NOT create a direct cross-country fallback.
- **FR-011**: Walk-versus-car selection MUST use the canonical reachable route distance and a data-authored threshold, not straight-line or anchor distance.
- **FR-012**: Pedestrian waypoints MUST be restricted to connected placed cells or road-edge waypoints derived from the canonical route.
- **FR-013**: Car journeys MUST preserve resident identity and use the resolved origin stop, destination stop, and road path supplied by the journey plan.
- **FR-014**: Resident arrival, departure, rehoming, structure changes, and map load MUST reconcile visible proxies incrementally except where a full reconstruction is intrinsically required by map load.
- **FR-015**: Unrelated structure placement or demolition MUST NOT reset civilian positions or cancel unaffected car journeys.
- **FR-016**: Route invalidation MUST replan or stop only journeys whose current plan depends on the invalidated home, destination, or road path.
- **FR-017**: Existing venue data MAY gain participant profiles, capacities, and schedules only where the building's established role supports a resident activity; no new runtime art asset is permitted by this feature.
- **FR-018**: The initial venue pass MUST evaluate the existing Pub, Restaurant, Private Members' Club, Crazy Golf, Town Hall, and Pirate Radio, and record an explicit participant, local-only, productive, or cosmetic decision for each.
- **FR-019**: Programme changes MUST invalidate current-hour Community assignment projections before visual civilians reconcile.
- **FR-020**: The existing playtest state response MUST include a debug-only civilian diagnostic projection without adding a new public playtest command.
- **FR-021**: Civilian diagnostics MUST identify resident-to-proxy binding, authoritative and visible destinations, purpose, motion state, travel mode, route evidence, active/waiting cars, blocked reason, and machine-checkable alignment violations.
- **FR-022**: Civilian diagnostics and movement progress MUST be excluded from authoritative gameplay state hashes, balance comparisons, and persisted simulation state.
- **FR-023**: Headless civilian scenario tests MUST interleave existing simulation-hour actions with deterministic fixed visual-time steps.
- **FR-024**: Automated verification MUST cover assignment alignment, destination dwell, disconnected travel refusal, deterministic replay, targeted route invalidation, unrelated-edit continuity, proxy-cap behaviour, and save/load reconstruction.
- **FR-025**: Workplace output, participant effects, economy, demand, and happiness MUST continue to depend on authoritative Community assignments rather than visual arrival timing.
- **FR-026**: The feature MUST reuse the current person meshes, car meshes, building assets, road tiles, MultiMesh pools, and animation/movement presentation.

### Key Entities

- **Resident Binding**: Stable association between a Community resident and an optional visible proxy; includes resident identity, seed, authoritative home, and proxy slot.
- **Civilian Intent**: Read-only projection of the resident's current Community assignment, including purpose, exact destination, active interval, and assignment revision.
- **Journey Plan**: Transient route evidence for moving from one valid place to another, including resolved stops, ordered road path, route distance, travel mode, and source revision.
- **Visual Civilian State**: Transient presentation state for a bound resident, including current place, destination, movement phase, waypoints, vehicle handoff, and blocked reason.
- **Venue Participation Role**: Data-authored decision that says whether an existing building supplies participant effects/capacity and on what schedule.
- **Civilian Diagnostic Projection**: Detached, debug-only snapshot that compares visual state with Community intent and RoadNetwork evidence without becoming gameplay truth.

## Scope Boundaries

### In Scope

- Binding visible people and cars to stable Community resident identity.
- Driving daily destinations and dwell from existing Community assignments.
- Reusing canonical RoadNetwork routes for walking/driving decisions.
- Incremental continuity and affected-journey replanning.
- Data-only activity roles for suitable existing buildings.
- Extending existing playtest state and internal scenario stepping.
- Tests and evidence for deterministic visual coherence.

### Out of Scope

- New person, vehicle, building, prop, texture, animation, audio, or VFX assets.
- New service vehicles, parking simulation, traffic lights, accidents, crowds, or bespoke social interactions.
- A new pavement/navmesh subsystem or full pedestrian-network rewrite.
- Making proxy arrival, congestion, or rendering authoritative for production, happiness, demand, or economy.
- Persisting transient positions, path progress, lane reservations, or cars.
- A seventh public AI/playtest tool or changes to the six-command public contract.
- General traffic density tuning except where required to keep an assigned resident's journey coherent.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In canonical work and activity scenarios, 100% of visible residents with an active reachable assignment report the same destination and purpose as Community at every checkpoint.
- **SC-002**: In disconnected matched scenarios, zero civilians start a direct fallback journey and zero civilian waypoints cross cells unsupported by the canonical connected path.
- **SC-003**: Residents remain at their assigned destination for 100% of checked assignment-active intervals unless the assignment or route is explicitly invalidated.
- **SC-004**: Placing or demolishing an unrelated non-route structure causes zero proxy respawns and zero active-car cancellations.
- **SC-005**: Ten same-seed replays of the civilian scenario produce byte-identical ordered diagnostic traces after volatile timing metadata is removed.
- **SC-006**: The automated suite detects deliberately injected destination mismatch, disconnected fallback, duplicate resident binding, and unrelated-edit reset faults.
- **SC-007**: At the existing cap of 512 visible civilians, the civilian update stays within one 16.7 ms frame on the project reference development machine, with the measured result stored as validation evidence.
- **SC-008**: All existing Community, traffic, day/night, playtest, save/load, and first-town scenario regressions pass after the feature is implemented.
- **SC-009**: The content inventory confirms that zero new runtime art assets were introduced and every evaluated existing venue has an explicit participation-role decision.

## Assumptions

- Community's current deterministic assignment rules are the gameplay truth and are not rebalanced by this feature except for explicitly authored existing-venue roles.
- Visual civilians remain a capped presentation layer; residents beyond the cap still participate authoritatively but need not receive a proxy.
- Hour boundaries are sufficient for authoritative assignment changes. Seeded visual staggering may spread departures within the presentation interval without changing who is assigned or when the assignment is counted.
- Map load may reconstruct all transient visual state because journey progress is not saved; ordinary play events must reconcile incrementally.
- Existing road cells and building-edge stops provide sufficient waypoints for this pass. Dedicated pavement geometry can be considered separately later.
- Existing car and person presentation quality is accepted; this feature targets behaviour, continuity, and observability.

## Dependencies

- Community resident, programme, assignment, and snapshot APIs from the connected first-town loop.
- RoadNetwork building-access and stable route queries.
- Existing People, CarManager, traffic pooling, day/night, save/load, and playtest plugins.
- Existing GUT and deterministic scenario infrastructure.
