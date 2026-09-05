# Implementation Plan: Coherent Civilian Simulation

**Branch**: `008-civilian-simulation-coherence` *(planning identifier; no branch created)* | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-civilian-simulation-coherence/spec.md`

## Summary

Make the existing visible People and CarManager layers a coherent projection of
Community's deterministic resident assignments and RoadNetwork's canonical routes.
Each proxy keeps its resident identity and immutable home, reconciles against the
resident's exact work/activity intent at simulation boundaries, dwells for the
assignment interval, and follows a route that RoadNetwork has already declared
reachable. A missing route blocks the visual journey instead of producing a direct
fallback.

Replace global rebuild/cancel reactions with identity-based reconciliation and
route-revision invalidation so unrelated town edits preserve activity already in
progress. Add participant data only to suitable existing venues. Extend the existing
playtest state with non-authoritative civilian diagnostics and add an internal
fixed-step scenario runner; neither transient visuals nor diagnostics enter saves,
gameplay hashes, or economic outcomes.

## Technical Context

**Language/Version**: GDScript for Godot 4.6.x; JSON-authored building content and scenarios

**Primary Dependencies**: Godot 4.6.2, GUT 9.3, PluginManager/GameEvents, existing Community, RoadNetwork, People, CarManager, DayNight, BuildingCatalog, and Playtest plugins

**Storage**: Existing `DataMap`/Community persistence and JSON building data; civilian journey state remains transient and is reconstructed after load

**Testing**: GUT unit/integration suites, existing six-command headless playtest interface, deterministic scenario runner, normal-renderer observation

**Target Platform**: Local desktop game on Godot 4.6.x; macOS development host

**Project Type**: Godot desktop application with data-authored content and local playtest tooling

**Performance Goals**: Maintain a 60 fps presentation budget at the existing 512-proxy cap; reconciliation work is event-driven and proportional to affected residents; debug projection cost is paid only when requested

**Constraints**: Community and RoadNetwork remain gameplay authorities; visual progress never gates production/effects; no new runtime assets; no new public playtest command; deterministic same-seed traces; preserve current MultiMesh pools

**Scale/Scope**: Up to 500 persisted resident records, 512 visible person proxies, 256 pooled civilian cars, current starter/unique building catalog, one-day and edit-interruption scenario coverage

## Constitution Check

*GATE: Passed before Phase 0 research and re-checked after Phase 1 design.*

| Principle | Design evidence | Result |
|-----------|-----------------|--------|
| I. One Gameplay Truth | Community continues to own resident work/activity assignments; RoadNetwork owns access/routes. People and CarManager consume detached intent and route projections without becoming authoritative. | PASS |
| II. Deterministic, Controllable Simulation | Resident binding, assignment reconciliation, route/mode choice, departure jitter, and equal-cost ties use stable IDs, revisions, and seeded context. Headless tests step visual time explicitly. | PASS |
| III. Observable and Explainable State | Existing playtest state gains resident binding, intent, current/destination state, route evidence, cars, blocked reasons, and stable alignment violation codes. | PASS |
| IV. Data-Driven Balance, Narrative Separation | Walk threshold and venue schedules/effects remain authored data. Venue roles are explicit and scenarios run independently of story presentation. | PASS |
| V. Small Interfaces and Layered Verification | Community exposes resident intent; RoadNetwork exposes resolved routes/revisions; CarManager accepts resolved journeys; People owns projection/reconciliation; tests cover each seam and the full day. | PASS |

No constitutional exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/008-civilian-simulation-coherence/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── civilian-projection.md
│   ├── journey-policy.md
│   └── venue-participation.md
└── validation/                 # implementation evidence; created when needed
```

`tasks.md` is intentionally deferred to `/speckit.tasks`.

### Source Code (repository root)

```text
data/
├── buildings/unique/
└── community/balance.json
plugins/
├── community/community_plugin.gd
├── people/
│   ├── people_plugin.gd
│   └── person_slot.gd
├── traffic/
│   ├── car_manager_plugin.gd
│   ├── car_slot.gd
│   └── road_network_plugin.gd
└── playtest/playtest_plugin.gd
scripts/
└── run_civilian_simulation_scenario.gd   # planned fixed-step verifier
test/
├── integration/civilian_simulation/      # planned full-day/edit scenarios
└── unit/
    ├── community/
    ├── people/                            # planned projection/reconciliation tests
    ├── traffic/
    └── playtest/
```

**Structure Decision**: Extend the four plugins that already own residents,
pedestrians, cars, and roads. Keep movement state in the existing lightweight slot
objects and MultiMesh pools. Add no parallel civilian controller, new scene graph,
navigation subsystem, or persistence model.

## Phase 0: Research Decisions

The audit evidence and alternatives are recorded in [research.md](research.md). The
critical decisions are:

1. Community's per-resident work/activity assignment is the only daily intent.
   People must stop selecting destinations by category or global randomness.
2. Visual movement remains non-authoritative. Assignment effects and production
   continue at the exact simulation boundary even if a proxy is still travelling.
3. A journey is valid only when RoadNetwork returns a canonical resolved route.
   Straight-line distance, first-stop guesses, and direct path fallback are removed.
4. Resident-seeded presentation jitter is allowed only to stagger departures or
   positions; it may not alter purpose, destination, reachability, or route choice.
5. Stable resident binding plus incremental reconciliation replaces global proxy
   rebuilds and global car cancellation during ordinary construction.
6. Civilian diagnostics are appended after authoritative hash calculation and are
   never persisted. Fixed visual stepping belongs in internal scenario code, not a
   seventh public playtest command.
7. Existing venue assets gain life through data-authored participant roles only when
   the building's established function supports attendance.

## Phase 1: Design and Contracts

- [data-model.md](data-model.md) defines resident bindings, civilian intents, journey
  plans, visual states, invalidation revisions, venue roles, and diagnostics.
- [contracts/civilian-projection.md](contracts/civilian-projection.md) defines the
  read-only Community-to-People intent boundary and debug projection.
- [contracts/journey-policy.md](contracts/journey-policy.md) defines route planning,
  walk/car handoff, state transitions, failure reasons, and event reconciliation.
- [contracts/venue-participation.md](contracts/venue-participation.md) defines the
  content audit and data-only eligibility rules for existing destinations.
- [quickstart.md](quickstart.md) gives the planned red-green verification and evidence
  sequence.

### Post-design constitution re-check

PASS. The design removes duplicated scheduling and routing truth rather than adding
another simulator. Presentation remains downstream of deterministic gameplay,
existing plugin ownership stays intact, balance stays authored, and every new read
surface has a focused test seam plus a full-scenario check.

## Implementation Strategy

### Stage 1 - Build the observability seam first

1. Add focused People and CarManager test fixtures capable of supplying Community
   intent and canonical route projections without a rendered scene.
2. Add detached `get_civilian_snapshot()` projections to People and CarManager with
   stable ordering and violation codes from the projection contract.
3. Append the combined projection to non-compact Playtest state only after
   `state_hash` is calculated; verify hash and save payload exclusion.
4. Add `run_civilian_simulation_scenario.gd`, which uses existing playtest actions for
   town state and advances visual plugins with a fixed delta between hour actions.
5. Freeze failing baseline cases for assignment mismatch, disconnected fallback,
   programme-change staleness, and unrelated-build reset.

### Stage 2 - Bind one visual proxy to one real resident

1. Extend `PersonSlot` with stable `resident_id`, resident seed, immutable home,
   current valid place, intent revision, and journey revision.
2. Add a narrow Community query/projection for a resident's current work/activity
   intent, including exact destination, purpose, active state, and assignment revision.
3. Replace People category/random scheduling with an event-driven reconciliation of
   visible bindings against current Community records and intents.
4. Preserve the current 512 cap using stable resident ordering. Seed spawn offset and
   departure staggering from resident ID/seed plus absolute simulation hour.
5. Represent dwell explicitly: an arrived resident remains at the destination until
   intent changes or becomes invalid, then reconciles toward the next valid place.

### Stage 3 - Make every journey honest

1. Introduce a detached JourneyPlan built from `RoadNetwork.get_route_between_buildings`
   or a narrow equivalent that returns both resolved stops and the ordered road path.
2. Compute travel mode from route distance and a data-authored walk threshold.
3. For walkers, derive last-mile and route-edge waypoints solely from the resolved
   stops/path. Remove the `[destination]` pathfinding fallback.
4. Add a CarManager entry point that consumes the resolved origin stop, destination
   stop, and path. Retain the existing lane reservation, congestion, pooling, and
   completion machinery.
5. On pool exhaustion or route failure, keep the resident at a valid place with a
   stable reason; do not silently invent another route through unconnected space.

### Stage 4 - Preserve continuity through town changes

1. Replace People `_rebuild()` listeners for ordinary resident events with add,
   remove, and rehome operations keyed by `resident_id`.
2. On structure/road invalidation, compare journey dependencies against the new
   RoadNetwork revision and revalidate only affected origins, destinations, or paths.
3. Replace CarManager `_cancel_all()` on ordinary structure events with targeted
   invalidation. Keep full transient reconstruction for `map_loaded`.
4. Define safe interruption behaviour: finish current segment when valid, otherwise
   stop at the last valid place and reconcile. Never teleport merely to hide a fault.
5. Cover simultaneous destination demolition, resident departure, rehome, and proxy
   cap transitions with deterministic ordering.

### Stage 5 - Activate suitable existing destinations through data

1. Audit Pub, Restaurant, Private Members' Club, Crazy Golf, Town Hall, and Pirate
   Radio against the venue contract before changing values.
2. Author participant schedules/effects/capacities for the clear attendance venues:
   Pub, Restaurant, Private Members' Club, and Crazy Golf, subject to balance evidence.
3. Keep Town Hall local/civic unless a specific staffed public programme is justified;
   keep Pirate Radio productive/cosmetic unless physical attendance is justified.
4. Ensure Theatre remains programme-driven and add immediate current-hour assignment
   invalidation to `Community.set_programme()`.
5. Run building-data validation and compare participant capacity/effects before and
   after to avoid accidental economy or happiness inflation.

### Stage 6 - Prove the complete daily story

1. Run work, leisure, return-home, disconnected, short-walk, long-drive, car-pool,
   edit-continuity, rehome, programme-change, proxy-cap, and save/load scenarios.
2. Repeat canonical scenarios ten times and compare normalised civilian traces.
3. Run existing Community, traffic, day/night, playtest, save/load, and first-town
   regression suites.
4. Measure 512-proxy frame cost with diagnostics off and store the result under this
   feature's validation directory.
5. Observe one normal-renderer full-day scenario using only current person, car,
   building, and road assets; record any remaining visual contradiction separately
   from asset-quality requests.

## Delivery Order and Dependencies

```text
diagnostics + fixed-step harness
            ↓
resident identity + Community intent
            ↓
canonical journey planning + car handoff
            ↓
targeted invalidation / continuity
            ↓
existing-venue data pass
            ↓
full-day deterministic evidence
```

The observability seam comes first so every later behavioural change has evidence.
Venue data comes after assignment and routing coherence so new destinations cannot
amplify existing contradictions.

## Requirement Traceability

| Requirement group | Delivery stage | Primary contract | Verification |
|-------------------|----------------|------------------|--------------|
| FR-001–FR-007 resident identity, intent, determinism, dwell | Stage 2 | Civilian projection | People unit tests + full-day work/activity trace |
| FR-008–FR-013 canonical routes and car handoff | Stage 3 | Journey policy | Route boundary, disconnect, multi-stop, and pool tests |
| FR-014–FR-016 incremental continuity | Stage 4 | Journey policy | Unrelated-build, demolition, rehome, and stale-completion tests |
| FR-017–FR-019 existing venue roles/programmes | Stage 5 | Venue participation | Data validation + connected/disconnected capacity traces |
| FR-020–FR-024 diagnostics and fixed-step testing | Stage 1 and Stage 6 | Civilian projection | Hash-exclusion, fault-injection, and ten-run replay tests |
| FR-025–FR-026 non-authoritative visuals and asset reuse | All stages | All contracts | Economy regression, persistence test, and asset-scope diff |

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Visual travel time drifts from hourly authority | Keep Community authoritative; use travel only as presentation and reconcile at assignment boundaries. |
| Incremental invalidation leaves a stale path | Store route revision plus path dependencies; revalidate on revision change and expose stale-plan violations. |
| Adding venue effects changes first-town balance | Separate eligibility from numeric tuning; run before/after assignment, happiness, demand, and economy traces. |
| Diagnostics accidentally destabilise replay hashes | Build and hash authoritative snapshot first; append diagnostics afterward and test hash equality. |
| Deterministic staggering creates visible clumps | Derive offset from resident seed and absolute hour; distribution is stable but varied. |
| Car pool exhaustion reintroduces cross-country walking | Queue or block with an explicit reason; never fall back to an invalid pedestrian path. |
| 512-person reconciliation exceeds frame budget | Reconcile only at relevant events, index by resident ID, cache intents/routes by revision, and keep per-frame motion allocation-free. |

## Complexity Tracking

No constitution violations require justification.
