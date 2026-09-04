# Implementation Plan: Community Happiness Simulation

**Branch**: `002-community-happiness-simulation` *(planning identifier; no branch created)* | **Date**: 2026-09-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-community-happiness-simulation/spec.md`

## Summary

Add a dedicated `Community` plugin that owns persistent residents, deterministic
personality generation, explainable per-resident effects, hourly happiness,
participation, migration, relocation, and departure. Building JSON receives an
optional community-effect profile; pure helpers evaluate personality and effects
without scene or UI dependencies. Residential remains the housing-capacity
authority, while Community becomes population authority and feeds compatibility
facades in Residential, Satisfaction, People, CityStats, Demand, Workplace, and
the existing six-tool Playtest snapshot.

The first deliverable proves that Identity- and Freedom-oriented residents react
differently to the same theatre programmes. Later increments add spatial and
participant effects, persistent migration/retention, and emergent personality
composition. All randomness is driven by persisted/session RNG state and every
balance result remains reproducible and numerically explainable.

## Technical Context

**Language/Version**: GDScript for Godot 4.6.x; TypeScript 5.7 targeting ES2022 for existing MCP contract verification

**Primary Dependencies**: Existing Godot plugin/event architecture, `DataMap` resources, BuildingCatalog JSON loader, DayNight exact-hour boundary, GUT 9.3.0, Vitest, existing Playtest plugin

**Storage**: Existing `DataMap` save resources extended with JSON-safe resident records, community RNG/version state, counters, home assignments, and selected programmes; authored JSON under `data/community/` and `data/buildings/`

**Testing**: Pure GUT units for generation/evaluation/migration, plugin integration tests, existing Vitest MCP schemas, deterministic JSON scenarios, live Godot playtest replays

**Target Platform**: Godot 4.6.x desktop and headless test execution; local macOS development initially

**Project Type**: Godot desktop game with plugin-based simulation and a local development-only MCP bridge

**Performance Goals**: Simulate at least 500 residents for 168 exact hours in under 10 seconds; bounded resident/effect snapshots; four-decimal stable balance output

**Constraints**: One gameplay truth; no wall-clock/global RNG dependence; no new public MCP tools; four headline qualities only; cohort data is generative rather than faction state; narrative-independent; resident/effect history bounded

**Scale/Scope**: Four qualities, three interpretive lenses, four effect scopes, four initial cohort prototypes, four deterministic scenarios, existing building catalog, up to 500+ persistent residents

## Constitution Check

*GATE: Passed before design and re-checked against the completed design below.*

| Principle | Design evidence | Gate |
|-----------|-----------------|------|
| One Gameplay Truth | Community listens to canonical building/map/hour events; UI and Playtest placement continue through Builder and never write resident effects directly. | PASS |
| Deterministic Simulation | Personality, candidate generation, assignments, stacking, housing selection, and migration tie-breaks use explicit state and stable sorting. | PASS |
| Observable State | AppliedEffect records retain source, formula multipliers, scope, schedule, signed contribution, and reason; snapshots expose aggregates and bounded resident details. | PASS |
| Data-Driven / Narrative-Separate | Effects, cohorts, thresholds, schedules, and programmes are authored data; no quest or dialogue state is required. | PASS |
| Small Interfaces / Layered Verification | Existing Playtest snapshots are extended without adding tools; pure units, plugin integration, replay scenarios, and live parity provide layered tests. | PASS |
| Project Constraints | Godot 4.6.x, existing model layout, plugin ownership, current content, and development-only Playtest behavior remain intact. | PASS |

Post-design re-check: population authority moves to one dedicated plugin and
legacy plugins delegate through narrow compatibility APIs. No architectural
exception requires Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/002-community-happiness-simulation/
├── spec.md
├── plan.md
├── tasks.md
└── validation/
    ├── personality-contrast.md
    ├── park-and-noise.md
    ├── migration-week.md
    ├── retention-failure.md
    ├── deterministic-replay.md
    ├── performance.md
    └── test-results.md
```

### Source Code (repository root)

```text
data/
├── community/
│   ├── balance.json
│   └── cohorts.json
└── buildings/                         # optional CommunityEffectProfile data

scripts/community/
├── community_constants.gd
├── community_resident.gd
├── community_effect_profile.gd
├── community_personality_generator.gd
└── community_effect_evaluator.gd

plugins/
└── community/
    ├── community_plugin.gd            # population and hourly simulation authority
    └── community_inspector.gd         # player-facing four-quality explanation view

test/unit/community/
├── test_community_models.gd
├── test_personality_generator.gd
├── test_effect_evaluator.gd
├── test_community_plugin.gd
├── test_community_migration.gd
├── test_community_persistence.gd
└── test_community_composition.gd

test/scenarios/
├── community_personality_contrast.json
├── community_park_and_noise.json
├── community_migration_week.json
└── community_retention_failure.json
```

Existing integration targets:

```text
scripts/data_map.gd
scripts/game_events.gd
scripts/plugin_manager.gd
plugins/building_catalog/building_catalog_plugin.gd
plugins/residential/residential_plugin.gd
plugins/satisfaction/satisfaction_plugin.gd
plugins/people/people_plugin.gd
plugins/workplace/workplace_plugin.gd
plugins/demand/demand_plugin.gd
plugins/city_stats/city_stats_plugin.gd
plugins/dashboard/dashboard_plugin.gd
plugins/playtest/playtest_plugin.gd
server/src/tools/playtest-tools.test.ts
```

**Structure Decision**: Keep pure community value/generation/evaluation helpers
under `scripts/community/`, lifecycle and authority in one injected Community
plugin, and presentation in a separate view script. This keeps `builder.gd`
unchanged except through its existing canonical events and permits headless unit
tests without constructing the scene.

## Implementation Phases

### Phase 1 - Deterministic personality and interpretation

Define save-safe residents, authored cohorts and balance settings, deterministic
generation, tagged/neutral effect formulas, smoothing, composite happiness, and
source-level explanations. Prove the theatre plays-versus-rock personality
contrast before integrating spatial systems.

**Test seams**: pure generator vectors and versioning; exact evaluator math;
same-seed replay; cross-quality lens independence; personality contrast fixture.

### Phase 2 - Spatial, scheduled, and participant effect web

Parse community profiles from building JSON, evaluate local/resident/city and
participant scopes, apply deterministic stacking and schedules, and assign
capacity-limited activities at each exact hour. Add bounded player and Playtest
explanations for simultaneous benefits and nuisances.

**Test seams**: catalog profile parsing; radius/schedule boundary tables;
capacity and canonical assignment order; stacking ties; park-and-night-venue
integration with separate positive and negative AppliedEffects.

### Phase 3 - Persistent population, migration, and compatibility

Make Residential expose capacity/slots while Community owns resident count.
Implement non-mutating housing quotes, deterministic daily candidates, arrivals,
relocation, grace-period departure, persistence/migration of older saves, and
full reset behavior. Delegate legacy population and satisfaction APIs and render
only persistent residents in People.

**Test seams**: no-capacity/below-threshold/best-home quote; daily arrival;
24-hour departure and relocation boundaries; save/load/reset; compatibility
consumers; seven-day migration and retention scenarios.

### Phase 4 - Emergent composition and balance proof

Complete authored general/Identity/Freedom/Care cohorts, weighted candidate
generation, distribution snapshots, and seven-day comparisons. Verify there is
no global faction approval, diversity bonus, or monoculture penalty.

**Test seams**: cohort variation and weighting; distribution aggregation;
same-stream neighbourhood comparison; specialisation viability.

## Complexity Tracking

No constitution violations or material architectural exceptions are planned.
