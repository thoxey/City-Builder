# Research: Traffic Flow Coherence

## Decision 1: Improve the tile model before full traffic simulation

**Decision**: Keep grid-route presentation and add strict admission, capacity, spacing,
and queue semantics.

**Rationale**: The failures come from missing origin admission and inconsistent claim/
render rules. Current code already has canonical paths, claims, stable IDs, and tests.

**Alternatives considered**: Microscopic continuous simulation is disproportionate;
visual jitter does not create honest queues; one car per tile is too sparse.

## Decision 2: Queue departures before physical spawn

**Decision**: Excess origin demand becomes transient pending departures with no car
transform or render-pool slot.

**Rationale**: A resident waiting to pull out has no road-space claim. Rendering behind
the origin causes the off-road queue.

**Alternatives considered**: Parking on buildings needs new geometry; pre-origin road
queues consume unrelated approaches; repeated People rejection loses FIFO identity.

## Decision 3: Every valid request starts pending

**Decision**: The request allocates a stable identity, but deterministic CarManager
stepping performs admission and emits `journey_started`.

**Rationale**: Deferral avoids a synchronous signal race, unifies empty and congested
origins, and makes simultaneous requests orderable.

**Alternatives considered**: Immediate mixed results widen the contract; synchronous
signals race People mapping; polling adds coupling.

## Decision 4: Two conservative tile claims during crossing

**Decision**: A moving car claims current and next tiles until crossing completes; each
tile has two capacity units total.

**Rationale**: Followers cannot enter a swept segment too early, and congestion backs
up naturally. It is conservative but stable.

**Alternatives considered**: Destination-only claims permit close overlap; continuous
collision integration is complex; whole-route reservation causes starvation.

## Decision 5: Preserve canonical routes under congestion

**Decision**: Resolved civilian cars wait on their supplied route until capacity,
invalidation, or cancellation. No congestion rerouting or retry-limit completion.

**Rationale**: RoadNetwork owns routes. The legacy rerouter interprets route entries
differently and can make congested cars disappear.

**Alternatives considered**: Timeout rerouting needs an explicit future route revision;
silent completion and teleporting are visually false.

## Decision 6: Derive bounded positions from claims

**Decision**: Compute at most two lane-relative slots from stable claim order and
direction, with interpolated promotion.

**Rationale**: Direction-zero spawns share the centre and fixed backward offsets are not
consistently bounded. Claim-derived positions align occupancy and rendering.

**Alternatives considered**: Physics bodies add cost; random offsets are unstable; more
sub-slots violate the chosen capacity.

## Decision 7: Lightweight pedestrian following

**Decision**: Use stable pavement offsets and a presentation-only following gap on a
directed segment.

**Rationale**: This prevents exact overlap without a crowd pathfinder or route authority.

**Alternatives considered**: Crowd avoidance is oversized; random separation jitters;
hard pedestrian capacity risks large artificial building crowds.

## Decision 8: Keep presentation non-authoritative

**Decision**: Waiting and visual arrival do not change assignments, effects, economy,
demand, happiness, hashes, or persistence. All new state is reconstructed.

**Rationale**: This preserves the constitution and feature 008 contracts.

**Alternatives considered**: Traffic-dependent outcomes are a separate simulation
feature; persisted queues become stale against loaded authority.

## Trigger for a future full simulation

A fuller system is justified only when design requires several of: traffic lights,
junction priority, turning conflicts, acceleration/braking, lane changes, overtaking,
congestion-sensitive routing, traffic-derived economy, or robust gridlock recovery.
