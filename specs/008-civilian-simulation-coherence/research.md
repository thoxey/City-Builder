# Research: Coherent Civilian Simulation

## Method

This research followed the runtime path from authoritative resident state through
assignment, connectivity, pedestrian scheduling, vehicle dispatch, and playtest
snapshotting. It also ran the focused Community, traffic, day/night, and playtest
suites plus small connected/disconnected runtime probes. The purpose was to identify
the narrowest improvements that make existing people, cars, roads, and buildings tell
the same story.

## Existing System Findings

### Community already owns the useful civilian simulation

- Residents have stable IDs, seeds, cohorts/personalities, homes, work assignments,
  and activity assignments.
- Hourly assignment is deterministic. It assigns work before activities, respects
  active capacity, requires reachable sources, and breaks ties by benefit, route
  distance, anchor, and resident identity.
- Workplace output, economy, and participant effects consume these assignments.
- `get_snapshot()` already exposes assignment records and resident state suitable for
  a presentation consumer.

Conclusion: a second destination scheduler in People is unnecessary and harmful.

### People is a visually rich but logically independent projection

- `_spawn_people()` iterates Community records but passes only home and seed into
  `_spawn_person()`; `resident_id` is discarded.
- The dictionaries named `_home` and `_origin` split current base from fixed spawn
  home, making location semantics hard to reason about.
- Hour 8 chooses any industrial tile. Hours 17-22 randomly send some idle people to
  commercial tiles. Otherwise an idle timer selects a random category destination.
- Random decisions use the global random stream. Equal game state can therefore
  produce a different visual trace.
- Arrival mutates the current base and starts another 4-10 second timer, so workers do
  not dwell through their Community work assignment.
- When its walk graph cannot find a path, People creates a direct destination
  waypoint. In a disconnected layout a person can visibly cross empty land to a
  workplace that Community correctly refused to assign.
- Walk versus drive uses anchor Manhattan distance rather than the canonical route
  distance.
- Every structure/resident change calls `_rebuild()`, cancelling journeys and
  respawning the full visible population at home.

Conclusion: preserve rendering and movement, replace scheduling, identity loss,
fallback routing, and rebuild policy.

### CarManager already solves traffic movement but re-resolves journey truth

- It owns efficient per-type MultiMesh pools, lane reservations, limited same-lane
  sharing, congestion-aware path cost, rerouting, and staggered deadlock handling.
- `request_journey()` receives building tiles, chooses the first origin stop, and
  pathfinds internally. It can therefore choose different stop evidence from the
  Community/RoadNetwork route that made the assignment reachable.
- Every structure placement, demolition, or map load calls `_cancel_all()`.

Conclusion: keep the movement/pooling engine, add a resolved-route entry point and
targeted invalidation.

### RoadNetwork is the correct route authority

- It already derives building-adjacent stops, connected components, stable routes,
  route distance, and connectivity snapshots from placed structures.
- `get_route_between_buildings()` considers valid stops rather than relying on one
  arbitrary adjacent road tile.

Conclusion: all civilian modes and waypoints should consume its single route result.

### The playtest framework verifies gameplay but not visible coherence

- The existing six semantic commands can set up and advance the authoritative town.
- `get_snapshot()` hashes simulation/economy/community/connectivity/operation state,
  then appends some presentation-only Community UI data outside the hash.
- It has no People or CarManager projection.
- `advance_hours()` emits simulation boundaries immediately; it does not advance the
  frame-time movement used by pedestrians and cars. A multi-hour headless replay can
  therefore pass with visible agents frozen in a stale journey.

Conclusion: append debug-only civilian state after hashing and make internal scenario
code step visual time explicitly. Do not expand the public six-command interface.

### Existing buildings are underused as participant destinations

- Pub, Restaurant, and Private Members' Club have commercial categories, capacities,
  and opening hours but no Community participant effects.
- Crazy Golf has a suitable leisure identity but no BuildingProfile or Community
  participant effect.
- Town Hall has a local civic effect but no reason for routine attendance yet.
- Pirate Radio has no physical participant programme and is better treated as
  productive/cosmetic unless one is deliberately authored.
- Theatre demonstrates the intended data pattern: programme-specific participant
  effects can create capacity without a generic category.
- `Community.set_programme()` changes programme data but does not currently invalidate
  the cached same-hour assignment projection.

Conclusion: make an explicit content-role decision per venue, add data only to clear
attendance destinations, and fix programme invalidation.

## Runtime Probe Evidence

The focused suites passed at the time of research:

- Community: 38/38
- Traffic: 7/7
- Day/night: 6/6
- Playtest: 18/18
- Focused total: 69/69

There are no direct unit suites for People or CarManager behaviour. A connected
one-home/one-workplace probe showed a Community work assignment at hour 8 while the
proxy drove to that workplace, arrived, then returned home during the still-active
work interval. A disconnected version showed no Community assignment while the
proxy walked directly across empty space and arrived anyway. This is the core
contradiction the feature addresses.

The repository-wide run observed 310/323 tests in the sandbox; the 13 failures were
existing BuildingCatalog fixture writes to `user://`, outside this feature's focused
systems. They are not used as evidence against the civilian design.

## Decisions

### Decision 1: Community assignment is the sole civilian intent

**Chosen**: Add a narrow, detached per-resident intent projection and have People
reconcile against it.

**Why**: It already includes stable identity, schedule, capacity, reachability, and
the exact destination used by gameplay effects.

**Rejected**: Retain People heuristics and merely bias them toward Community. This
still permits visible/economic contradiction and creates two rule sets to tune.

### Decision 2: Visual movement remains downstream presentation

**Chosen**: Community assignment becomes effective on its existing exact simulation
boundary. A proxy's travel state never gates work output or participant effects.

**Why**: Frame rate, car congestion, and headless stepping must not change gameplay.

**Rejected**: Count a resident only after visual arrival. This makes outcomes depend
on renderer timing and creates save/load and pool-cap exploits.

### Decision 3: Use one resolved route from origin through destination

**Chosen**: Build a JourneyPlan from RoadNetwork evidence and pass its stops/path to
both People and CarManager.

**Why**: Reachability, mode, waypoints, and vehicle dispatch then agree and stable
multi-stop selection is preserved.

**Rejected**: Let each system select its own nearest or first stop. Equal-footprint
buildings can resolve to different components or paths.

### Decision 4: Failed route means no journey

**Chosen**: Keep the resident at the last valid place and expose a stable blocked
reason. Pool-full driving may queue, but it may not create an invalid walk.

**Why**: Honest absence is less damaging than movement that contradicts player-built
roads.

**Rejected**: Direct-to-destination fallback or teleport-to-destination. Both hide a
network fault and weaken the road-building loop.

### Decision 5: Seed variation per resident and simulation context

**Chosen**: Use resident seed/ID plus absolute hour and purpose for departure stagger
and cosmetic offsets.

**Why**: This retains variety while producing reproducible traces.

**Rejected**: Global `randi()`/`randf()` or persisted RNG streams. Global randomness
is unstable; persisting a presentation RNG expands save compatibility for no gameplay
benefit.

### Decision 6: Reconcile by identity and dependency

**Chosen**: Maintain a resident-ID index. Roster events affect one binding;
RoadNetwork revisions revalidate plans whose home, destination, or path dependencies
changed. Map load alone may reconstruct everything.

**Why**: This preserves visible continuity and bounds work.

**Rejected**: Full `_rebuild()`/`_cancel_all()` on every event. It is simple but visibly
erases life whenever the player builds.

### Decision 7: Explicit dwell follows assignment lifetime

**Chosen**: An arrived proxy stays `AT_DESTINATION` until the intent changes, ends, or
is invalidated.

**Why**: A worker should visibly remain at work while Community counts them there.

**Rejected**: Real-time 4-10 second destination timers. They have no relationship to
simulation time and cause repeated arbitrary wandering.

### Decision 8: Append diagnostics outside authoritative hashes and saves

**Chosen**: Add `civilian_simulation` to non-compact playtest state after calculating
`state_hash`; build it on demand and omit it from persistence.

**Why**: It exposes contradictions without redefining deterministic gameplay state.

**Rejected**: Put movement in the main hash or save every transform. This makes
presentation timing authoritative and creates brittle saves.

### Decision 9: Reuse the existing test commands

**Chosen**: Internal scenario code alternates existing semantic actions with a fixed
delta loop that explicitly advances People and CarManager.

**Why**: It tests the missing time domain without expanding the public tool contract.

**Rejected**: A seventh `step_visual_time` MCP/playtest command. The existing contract
is intentionally bounded; this is an implementation-test concern.

### Decision 10: Activate venues through role-led data, not asset availability

**Chosen**: Pub, Restaurant, Private Members' Club, and Crazy Golf are the initial
participant candidates. Town Hall remains local civic unless a staffed programme is
specified. Pirate Radio remains productive/cosmetic unless physical attendance is
specified. Theatre retains programme-based participation.

**Why**: The first four naturally explain visible visits; the other two would be
fiction invented solely to create movement.

**Rejected**: Make every unique building a destination. More trips would not create a
more legible town if the reasons are arbitrary.

## Recommended Sequence

1. Diagnostics and fixed-step tests.
2. Resident binding and Community intent.
3. Canonical JourneyPlan and car handoff.
4. Incremental reconciliation and targeted invalidation.
5. Existing-venue content pass and balance evidence.

This order makes contradictions testable before changing behaviour and prevents new
venue demand from increasing traffic on an incoherent projection.
