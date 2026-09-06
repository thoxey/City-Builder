# Feature Specification: Traffic Flow Coherence

**Feature Branch**: `codex/009-performance-foundation` (feature directory is independent)

**Created**: 2026-09-06

**Status**: Draft

**Input**: User description: "Improve the lightweight traffic presentation so cars cannot bunch together or queue off-road. A road tile may contain at most two visible cars; additional departures wait before spawning. Traffic should queue naturally along connected roads. Apply similarly lightweight spacing to visible pedestrians, without replacing the current system with a full traffic simulation."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Wait Before Pulling Out (Priority: P1)

As a player watching several residents leave the same building, I see only as many
cars enter the adjoining road as it can visibly hold. Everyone else waits at the
building until space becomes available instead of spawning into an overlapping pile.

**Why this priority**: Origin bunching is the most visible contradiction and is the
source of off-road departure queues.

**Independent Test**: Request four same-route departures from one building beside an
empty road tile and verify that two cars become visible, two departures remain
pending, and the pending departures enter in stable order as capacity clears.

**Acceptance Scenarios**:

1. **Given** four residents are ready to drive from the same origin and the origin road tile has two spaces, **When** all four request departure, **Then** exactly two visible cars occupy the tile and two residents wait before entering traffic.
2. **Given** departures are waiting at an origin, **When** one occupied space clears, **Then** exactly one waiting departure enters next in deterministic first-in-first-out order.
3. **Given** a waiting resident's intent or route becomes invalid, **When** the change is reconciled, **Then** the pending departure is removed without displaying or completing a car journey.

---

### User Story 2 - Form an On-Road Queue (Priority: P1)

As a player watching a busy route, I see cars slow and form an orderly queue inside
road boundaries. Cars do not overlap, jump ahead, leave the road, reroute away from
their assigned route, or vanish merely because traffic is blocked.

**Why this priority**: Fixing spawn admission alone would move bunching downstream;
the full route needs coherent capacity and waiting behaviour.

**Independent Test**: Fill successive tiles on a single connected route, request
additional journeys, and verify capacity, position, ordering, and route identity at
every fixed-step checkpoint.

**Acceptance Scenarios**:

1. **Given** the next road tile is full, **When** a car reaches its movement boundary, **Then** it remains in its current valid road position until capacity becomes available.
2. **Given** multiple cars share a direction, **When** they queue, **Then** their front-to-back order remains stable and no two cars occupy the same visible position.
3. **Given** cars travel in opposite directions, **When** they share a road tile, **Then** each remains in its own valid lane position and total tile occupancy does not exceed two.
4. **Given** a canonical civilian journey remains valid but congested, **When** it waits for an extended period, **Then** it neither reroutes nor completes silently.
5. **Given** a used endpoint or route is invalidated, **When** traffic reconciles, **Then** only dependent pending and active journeys are cancelled.

---

### User Story 3 - Keep Walkers Distinct (Priority: P2)

As a player watching several residents walk the same route, I can distinguish them as
individual people. They use stable pavement-relative positions and following gaps
rather than occupying the same point or spilling into unrelated terrain.

**Why this priority**: Pedestrian overlap is distracting, but vehicle pile-ups and
off-road queues are more severe and should be corrected first.

**Independent Test**: Send several residents along the same short walking route and
verify deterministic lateral placement, minimum visible separation, stable ordering,
and unchanged authoritative destinations.

**Acceptance Scenarios**:

1. **Given** multiple pedestrians share a route segment, **When** they walk in the same direction, **Then** they maintain a visible following gap or occupy distinct bounded offsets.
2. **Given** the same scenario and seed are replayed, **When** pedestrian positions are sampled at matching fixed steps, **Then** ordering and offsets are identical.
3. **Given** pedestrian spacing delays presentation, **When** an assignment remains active, **Then** spacing does not alter the authoritative assignment or outcome.

---

### User Story 4 - Explain Congestion (Priority: P3)

As a developer or playtester, I can inspect pending departures, active occupancy, and
stable violations so that visual traffic contradictions are automatically detectable.

**Why this priority**: Congestion behaviour needs deterministic evidence and regression
protection, but the player-facing flow is valuable before every diagnostic is exposed.

**Independent Test**: Capture traffic diagnostics from clean and deliberately faulty
fixtures and verify stable ordering, counts, and fault codes without changing gameplay
state or hashes.

**Acceptance Scenarios**:

1. **Given** a clean congested scenario, **When** diagnostics are requested, **Then** they report pending order and per-tile occupancy with no violations.
2. **Given** an injected overlap, over-capacity tile, off-road transform, or admission bypass, **When** diagnostics are requested, **Then** the corresponding stable fault code is present.
3. **Given** diagnostics are enabled or requested, **When** gameplay state is hashed or saved, **Then** the result is unchanged.

### Edge Cases

- An origin tile is already full when several buildings request departures in the same fixed step.
- The car render pool is full while road capacity remains available, or vice versa.
- A pending departure is rehomed, departs the population, changes destination, or becomes a walking journey.
- A road is demolished while departures are pending or cars are crossing into it.
- Two directions compete for the final capacity slot on the same tile.
- Cars queue through a corner, intersection, dead end, or one-tile road component.
- A valid route remains gridlocked for longer than the former reroute timeout.
- A large frame delta would otherwise let a car cross more than one capacity boundary.
- Two pedestrians receive identical presentation offsets or approach from opposite directions.
- A full map load occurs with pending departures, active cars, and pedestrian spacing state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow no more than two visible cars on any road tile at one time, regardless of direction.
- **FR-002**: The system MUST check origin road capacity before making a requested car visible.
- **FR-003**: Excess departure requests MUST remain non-physical and MUST NOT consume visible road space until admitted.
- **FR-004**: Residents awaiting admission MUST remain visibly associated with their origin rather than disappearing into an unspawned car.
- **FR-005**: Pending departures for the same origin MUST be admitted in deterministic first-in-first-out order, with stable tie-breaking for requests created in the same simulation step.
- **FR-006**: A visible car MUST reserve capacity on its next tile before beginning a crossing and retain its current-tile claim until that crossing completes.
- **FR-007**: A car blocked by capacity MUST remain at a valid, non-overlapping position inside its current road tile.
- **FR-008**: Each occupied road tile MUST provide at most two distinct, road-bounded visible positions appropriate to travel direction and queue order.
- **FR-009**: Opposing cars sharing a tile MUST use distinct lane positions while still counting toward the two-car total.
- **FR-010**: Canonical civilian journeys MUST retain the route supplied by RoadNetwork throughout ordinary congestion.
- **FR-011**: Ordinary congestion MUST NOT cause a canonical civilian journey to reroute, silently complete, teleport, or disappear.
- **FR-012**: Pending and active journeys MUST be cancelled only when their resident intent, endpoint, route, map, or explicit lifecycle is invalidated.
- **FR-013**: Releasing road capacity MUST admit or advance no more traffic than the newly available capacity permits.
- **FR-014**: Admission, movement, promotion, and cancellation order MUST be deterministic for identical starting state, seed, requests, and fixed time steps.
- **FR-015**: Pedestrians sharing a route segment MUST use deterministic bounded offsets or following gaps that prevent persistent exact-position overlap.
- **FR-016**: Pedestrian spacing MUST NOT change Community assignments, outcomes, RoadNetwork route authority, or arrival semantics.
- **FR-017**: The traffic projection MUST expose stable pending-departure order, active journeys, waiting state, and per-tile occupancy.
- **FR-018**: Diagnostics MUST detect stable codes for over-capacity road tiles, duplicate car positions, off-road car positions, spawn admission bypass, and pending-order violations.
- **FR-019**: Diagnostics MUST detect persistent exact-position pedestrian overlaps in covered canonical scenarios.
- **FR-020**: Traffic and pedestrian presentation state MUST remain excluded from authoritative save payloads, gameplay hashes, demand, economy, happiness, and Community outcomes.
- **FR-021**: RoadNetwork MUST remain authoritative for access, stops, canonical paths, and route revision; traffic presentation MUST NOT introduce an alternative route authority.
- **FR-022**: Community MUST remain authoritative for civilian assignments and outcomes; pending traffic MUST NOT rewrite or defer those outcomes.
- **FR-023**: The feature MUST reuse existing runtime art and audio assets.
- **FR-024**: Full map load MUST clear and deterministically reconstruct transient traffic and pedestrian presentation state from current authority.

### Key Entities

- **Pending Departure**: A requested civilian car journey not yet visible; identifies its resident, plan, canonical route, request order, origin, and invalidation revision.
- **Active Car Journey**: A visible car following one canonical route; identifies current and next tile claims, direction, queue position, and waiting state.
- **Road Tile Occupancy**: The at-most-two visible claims associated with a road tile, including direction, journey identity, and bounded display position.
- **Pedestrian Spacing Claim**: Transient presentation information used to keep walkers distinct on a shared segment without changing their route or intent.
- **Traffic Diagnostic Projection**: A detached, stably ordered view of pending requests, active journeys, occupancy, and machine-checkable violations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a canonical four-departure same-origin scenario, exactly two cars are visible on the origin tile and exactly two departures remain pending until capacity clears.
- **SC-002**: Across all automated congestion checkpoints, zero road tiles contain more than two visible cars and zero visible cars share the same world position.
- **SC-003**: In straight, corner, junction, and origin queue fixtures, 100% of sampled car positions remain inside the intended road-tile bounds.
- **SC-004**: In a ten-minute equivalent canonical gridlock scenario, zero still-valid civilian journeys reroute, silently complete, teleport, or disappear.
- **SC-005**: Ten same-seed fixed-step congestion replays produce byte-identical pending order, active order, occupancy, and normalized transforms.
- **SC-006**: Cancelling or invalidating one queued or active journey changes zero unrelated journey identities, queue positions, or canonical paths.
- **SC-007**: In covered multi-pedestrian scenarios, persistent exact-position overlap is zero after spacing is applied and replayed offsets remain identical.
- **SC-008**: Deliberately injected over-capacity, overlap, off-road, admission-bypass, and ordering faults are all detected by stable diagnostics.
- **SC-009**: At the established 512-visible-civilian cap, average combined civilian and traffic presentation work remains below one 16.7 ms frame on the reference development machine, with diagnostics measured separately.
- **SC-010**: All existing civilian coherence, Community, traffic, day/night, playtest, persistence, first-town, and deterministic replay gates continue to pass.
- **SC-011**: Runtime asset comparison reports zero feature-attributable art or audio additions or modifications.
- **SC-012**: A normal-renderer observation confirms that origin waiting, on-road queues, turns, opposing traffic, and pedestrian spacing appear coherent without visible bunching or off-road queues.

## Assumptions

- A road tile visually supports two cars total, not two cars per direction.
- Pending departures represent residents waiting to pull out and therefore do not need a physical off-road car queue.
- Traffic is presentation-only; congestion does not alter authoritative work, activity, economy, happiness, or demand outcomes.
- The current grid and canonical RoadNetwork routes remain the movement basis.
- Lightweight lane anchors, tile capacity, and following gaps are sufficient for the current visual scale.
- Traffic lights, junction priority, lane changing, overtaking, congestion-aware route selection, and sophisticated gridlock recovery are out of scope.
- Pedestrian improvement is limited to visual separation and following behaviour, not crowd simulation or free steering.
