# Implementation Plan: Traffic Flow Coherence

**Branch**: `codex/009-performance-foundation` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/010-traffic-flow-coherence/spec.md`

## Summary

Improve the deterministic tile-reservation presentation so a road tile has at most
two visible cars, departures wait non-physically until an origin slot is available,
and congestion produces stable on-road queues without rerouting or silent completion.
Add deterministic pedestrian separation. Community remains authoritative for civilian
intent/outcomes and RoadNetwork for access and canonical routes; CarManager and People
remain transient consumers.

The design uses pending departures, direction-aware two-phase tile reservations,
bounded lane/queue anchors, and an explicit pending-to-active signal. It does not add
traffic lights, priority rules, lane changing, overtaking, or strategic routing.

## Technical Context

**Language/Version**: GDScript 4.x on Godot 4.6.x

**Primary Dependencies**: Existing PluginBase/GameEvents architecture; Community,
RoadNetwork, CarManager, People, Playtest, MultiMeshInstance3D, and Pathfinder

**Storage**: No new persistent storage; admission, reservation, spacing, and diagnostic
records are transient and reconstructed after map load

**Testing**: GUT 9.3 unit/integration tests, fixed-step headless scenario runners,
normal-renderer observation, data-editor and first-town regressions

**Target Platform**: Godot desktop game, initially macOS local playtesting

**Project Type**: Desktop game with plugin-based simulation and presentation systems

**Performance Goals**: Average combined People/CarManager update below 16.7 ms at the
established 512-visible-civilian cap; diagnostic projection measured separately

**Constraints**: Two visible cars total per road tile; deterministic fixed stepping;
no new runtime art/audio; no new public playtest command; no traffic-derived changes
to saves, gameplay hashes, economy, demand, happiness, assignments, or outcomes

**Scale/Scope**: Up to 512 visible people, the existing 256-car render pool, one
transient request per resident journey, and current grid-sized road networks

## Constitution Check

*GATE: Passed before research and re-checked after design.*

- **I. One Gameplay Truth — PASS**: Only transient presentation changes. Community
  continues to own assignment/outcome truth and existing gameplay commands remain the
  sole authoritative mutation path.
- **II. Deterministic, Controllable Simulation — PASS**: Pending order, admission,
  occupancy, movement, and spacing use stable identities and fixed-step processing.
- **III. Observable and Explainable State — PASS**: A detached projection exposes
  pending requests, active journeys, tile claims, waiting reasons, and stable faults.
- **IV. Data-Driven Balance, Narrative Separation — PASS**: No balance or narrative
  dependency is introduced. Capacity is presentation policy only.
- **V. Small Interfaces and Layered Verification — PASS**: The resolved request is
  retained, one lifecycle signal is added, and tests span unit through visual evidence.
- **Project constraints — PASS**: Godot 4.6.x, plugin boundaries, existing assets, and
  release-inert Playtest behaviour are preserved.
- **Quality gates — PASS BY DESIGN**: Test seams precede behaviour; writable `user://`,
  replay, full suite, first-town, and normal-renderer gates are in `quickstart.md`.

No constitutional exception or complexity justification is required.

## Design Phases

### Phase A — Baseline and failing contracts

Freeze traces for same-origin bursts, a backed-up straight route, opposing traffic,
turns, and grouped pedestrians. Add failing contract tests before runtime changes.

### Phase B — Pending departure admission

Every valid resolved request receives a stable journey ID and initially enters a
pending collection. CarManager admits it during deterministic update only when both a
render slot and origin capacity are available. People keeps the resident at the origin,
maps the ID immediately, and hides the resident only after `journey_started`.

Pending order is stable by request epoch, request sequence, and resident ID. Admission
is FIFO per origin. Cancellation addresses pending and active records through the same
journey identity.

### Phase C — Capacity and queue propagation

Replace direction-zero spawn claims with first-segment direction claims. Each tile has
two total units. Before crossing, a car claims its next tile and retains its current
claim until crossing completes. If full, it stays in its current bounded queue position.

Resolved civilian routes never enter the legacy congestion rerouter or retry-limit
completion path. RoadNetwork remains the sole source of route changes.

### Phase D — Bounded transforms

RoadNetwork continues to provide route cells and lane anchors. CarManager derives at
most two display slots per tile: opposing directions use opposite lanes; same-direction
claims use stable front/rear positions. Promotion is interpolated. Turns interpolate
between bounded incoming and outgoing anchors without an off-road overflow queue.

### Phase E — Pedestrian separation

People groups walkers by directed route segment. Stable resident ordering assigns
bounded pavement-relative offsets and a minimum following position. This may slow only
the visible proxy; it cannot change intent, route, authoritative arrival, or outcomes.

### Phase F — Diagnostics and release evidence

Extend the civilian projection after gameplay hash calculation with pending departures,
tile claims, display slots, and stable faults. Add a fixed-step runner using existing
authoritative playtest actions, then run performance, full regression, first-town,
asset-scope, and normal-renderer gates.

## Project Structure

### Documentation (this feature)

```text
specs/010-traffic-flow-coherence/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── traffic-admission.md
│   ├── people-car-lifecycle.md
│   └── traffic-diagnostics.md
├── checklists/requirements.md
└── tasks.md                 # created later by /speckit.tasks
```

### Source Code (repository root)

```text
plugins/
├── people/{people_plugin.gd,person_slot.gd}
├── playtest/playtest_plugin.gd
└── traffic/{car_manager_plugin.gd,car_slot.gd,road_network_plugin.gd}
scripts/run_traffic_flow_scenario.gd
test/
├── integration/traffic_flow/
├── scenarios/traffic_flow/
├── unit/people/
├── unit/playtest/
└── unit/traffic/
```

**Structure Decision**: Extend existing People, Traffic, and Playtest plugins and tests.
Add one internal runner and no public playtest operation. RoadNetwork may expose only
geometry helpers needed to bound presentation; it remains route authority.

## Test Seams

- Injected RoadNetwork route/lane-anchor double for CarManager admission tests.
- Render-pool double with controlled availability independent of road capacity.
- Fixed-delta CarManager stepping with detached pending/active/occupancy snapshots.
- People/CarManager lifecycle double that delays or cancels `journey_started`.
- Deterministic pedestrian fixture with resident IDs and identical waypoints.
- Fault injection through transient test records only.
- Normalized scenario trace excluding only wall-clock/log fields.

## Post-Design Constitution Re-check

All gates remain satisfied. Queues and claims are transient; contracts prohibit route
or outcome authority leakage; diagnostics are detached and excluded from hashes/saves;
all additions fit existing plugins and tests. No Complexity Tracking entry is needed.

## Complexity Tracking

No constitutional violations.
