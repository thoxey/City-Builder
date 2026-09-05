# Implementation Plan: Connected First-Town Loop

**Branch**: `006-connected-first-town-loop` *(planning identifier; no branch created)* | **Date**: 2026-09-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-connected-first-town-loop/spec.md`

## Summary

Make the existing road graph the single access and route authority, then use it
to allocate named Community residents deterministically to workplaces and
participant destinations. Workplace output, tax income, commercial demand, and
participant effects will consume those canonical fulfilled assignments rather
than building presence or global population alone. Local and resident effects
remain spatial and continue to be calculated only by Community.

The same derived projection will feed playtest snapshots and player inspection.
Resident-serving outcomes replace uncapped city-wide nature totals in housing
demand, positive same-group overlap receives a finite stacking tail, and
starter content receives explicit Community or cosmetic roles. A small
data-authored road cash cost supplies the opening's real compact-versus-spread
trade-off. Frozen matched scenarios and pair manifests verify connectivity,
economy, spatial exposure, nature service, determinism, and milestone-005
progression; the human and blind-review protocol remains a release evidence
gate that cannot be fabricated by automation.

## Technical Context

**Language/Version**: GDScript for Godot 4.6.x; JSON-authored content/scenarios; TypeScript 5.6 for authoring validators and local playtest contracts

**Primary Dependencies**: Godot 4.6.2, GUT 9.3, PluginManager/GameEvents, existing GridMap/building registry, Node.js with Vitest and Zod

**Storage**: Existing `DataMap` Godot Resource state and JSON content/scenario fixtures; no database

**Testing**: GUT unit/integration suites, headless deterministic scenario runner, data-editor Vitest suites, normal-renderer screenshot capture

**Target Platform**: Local desktop game on Godot 4.6.x; macOS development host

**Project Type**: Godot desktop application with local TypeScript authoring and playtest tooling

**Performance Goals**: Road projection rebuild below one 16.7 ms frame at representative map size; 168 hourly updates with 500 residents remain within the existing Community performance budget

**Constraints**: One gameplay truth; exact-hour deterministic simulation; stable reason codes; no simulation dependence on visible agents; no hidden beauty/density score; story presentation optional; preserve milestone-005 reachability

**Scale/Scope**: Starter T1/T2 growth catalog, three nature variants plus Pond/Nature Patch, up to 500 residents, matched 168-hour scenarios, one current patron route

## Constitution Check

*GATE: Passed before research and re-checked after Phase 1 design.*

| Principle | Design evidence | Result |
|-----------|-----------------|--------|
| I. One Gameplay Truth | `RoadNetwork` owns access/components/routes; Community owns assignments/effects; runtime, UI, and playtest consume detached projections from those owners. | PASS |
| II. Deterministic, Controllable Simulation | Components, destinations, residents, ties, exposure IDs, and scenario actions have explicit stable ordering and run on exact simulation boundaries. | PASS |
| III. Observable and Explainable State | Access, routes, assignments, operation blockers, output, income, exposure, coverage, land, spend, and manifest validation are projected with stable evidence. | PASS |
| IV. Data-Driven Balance, Narrative Separation | Costs, thresholds, effects, stacking, and cosmetic roles remain authored data; all core scenarios run with story presentation disabled. | PASS |
| V. Small Interfaces and Layered Verification | Existing plugins gain narrow query/projection methods; unit, integration, scenario, replay, performance, and visual seams cover each boundary. | PASS |

No constitutional exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/006-connected-first-town-loop/
├── spec.md
├── layout-validation-strategy.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── connectivity-operation.md
│   ├── spatial-comparison.md
│   └── starter-content.md
├── checklists/requirements.md
├── validation/
└── tasks.md
```

### Source Code (repository root)

```text
data/
├── buildings/
└── community/
plugins/
├── traffic/road_network_plugin.gd
├── workplace/workplace_plugin.gd
├── commercial/commercial_plugin.gd
├── community/
├── demand/demand_plugin.gd
├── economy/economy_plugin.gd
├── hud/hud_plugin.gd
└── playtest/playtest_plugin.gd
scripts/
├── community/
├── data_map.gd
└── game_events.gd
test/
├── integration/first_town_loop/
├── scenarios/
└── unit/
    ├── traffic/
    ├── workplace/
    ├── commercial/
    ├── community/
    └── playtest/
tools/data_editor/src/
```

**Structure Decision**: Extend the plugins that already own roads, residents,
employment, commerce, demand, economy, HUD, and playtest state. `RoadNetwork`
remains pure derived infrastructure and Community remains the allocation/effect
owner. No new controller, parallel simulation, or visual-agent dependency is
introduced.

## Phase 0: Research Decisions

The findings and alternatives are recorded in [research.md](research.md). The
critical conclusions are:

1. RoadNetwork already reconstructs orientation-aware orthogonal road edges and
   footprint-adjacent stops, so it should add stable components and shortest
   routes rather than introduce another graph.
2. Community already owns stable resident ordering and participant assignment;
   extending it to work assignments prevents two workplaces from claiming the
   same resident and lets all downstream plugins consume named assignments.
3. CityStats remains the aggregate distribution/reporting bus. Workplace and
   commercial sinks request only counts fulfilled by Community, so downstream
   output and income stay on the existing path.
4. Local/resident effects do not require road access. Only participant effects
   and productive assignments consume route reachability.
5. Housing demand must use served residential/Community evidence rather than
   raw city-wide Attractiveness, which currently allows unused nature to grow
   demand.
6. Positive duplicate stacking currently gives every third-and-later effect
   25%; it must be `1.0, 0.5, 0.25, 0.0...`. Negative effects remain
   independently cumulative and visible.
7. Existing road cells are free, so distance has no scarce consequence. A small
   one-time authored road cash cost is the narrowest allowed trade-off.
8. Legacy Satisfaction is a compatibility facade over Community happiness when
   residents exist; its duplicate HUD presentation should be removed while its
   internal compatibility API remains during this milestone.

## Phase 1: Design and Contracts

- [data-model.md](data-model.md) defines connectivity revisions, access states,
  routes, assignments, operation states, exposures, nature service, and matched
  comparison evidence.
- [contracts/connectivity-operation.md](contracts/connectivity-operation.md)
  defines the canonical RoadNetwork and operation projection fields/reasons.
- [contracts/spatial-comparison.md](contracts/spatial-comparison.md) defines
  pair manifests, admissibility checks, metrics, and deterministic evidence.
- [contracts/starter-content.md](contracts/starter-content.md) defines content
  roles and validation rules for every selectable starter item.
- [quickstart.md](quickstart.md) gives the runnable verification and evidence
  sequence.

### Post-design constitution re-check

PASS. State changes still travel through Builder, simulation ticks, and existing
plugin owners. New interfaces are derived reads or deterministic allocation
owned by Community. Content remains authored, scenarios are narrative-free,
and all balance candidates require same-seed before/after evidence.

## Implementation Strategy

1. Freeze current roadless/connected traces and add failing graph, route,
   assignment, finite-stacking, and unserved-nature tests.
2. Add revisioned component/access/route projections to RoadNetwork, including
   every footprint edge and stable component IDs.
3. Add cached hourly work/activity allocation to Community and make Workplace
   and Commercial consume only canonical fulfilled counts.
4. Extend Community and Playtest projections with operation, assignments,
   exposures, coverage, routes, roads, land, and spend evidence.
5. Replace housing demand's raw city Attractiveness input with resident-served
   Community evidence; author all missing starter effects/cosmetic roles and
   the one-time road cost; tune starting demand and tier thresholds.
6. Add matched pair manifests, comparator rejection, canonical/adversarial
   scenarios, deterministic replay, and milestone-005 regression coverage.
7. Run automated gates, capture visual evidence, and prepare—but do not claim—
   the preregistered human behaviour/durability/blind-review evidence.

## Complexity Tracking

No constitution violations require justification.
