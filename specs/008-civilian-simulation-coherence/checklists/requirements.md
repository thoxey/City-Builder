# Requirements Checklist: Coherent Civilian Simulation

**Purpose**: Verify that the civilian-coherence specification and implementation plan
are complete, testable, asset-bounded, and consistent with the project constitution.

**Created**: 2026-09-06

**Feature**: [spec.md](../spec.md)

## Specification quality

- [x] CHK001 The player-facing problem distinguishes authoritative simulation from visible presentation.
- [x] CHK002 Work, activity, home, connectivity, dwell, and interruption behaviour have independently testable outcomes.
- [x] CHK003 Edge cases cover assignment changes, connectivity changes, roster changes, pool limits, proxy caps, programme changes, and save/load.
- [x] CHK004 Every functional requirement is unambiguous and contains no unresolved clarification marker.
- [x] CHK005 Success criteria measure alignment, invalid travel, continuity, determinism, fault detection, performance, regressions, and asset scope.
- [x] CHK006 In-scope and out-of-scope boundaries explicitly prohibit new runtime assets and a new public playtest command.

## Constitution and ownership

- [x] CHK007 Community is the sole owner of work/activity assignments and outcomes.
- [x] CHK008 RoadNetwork is the sole owner of access, stops, canonical routes, and route distance.
- [x] CHK009 People and CarManager remain transient presentation consumers.
- [x] CHK010 Visual timing and diagnostics are excluded from save state, gameplay hashes, economy, demand, and happiness.
- [x] CHK011 Stable ordering, resident seeds, revisions, and fixed stepping define deterministic behaviour.
- [x] CHK012 New interfaces are narrow, detached reads or resolved-route requests with layered tests.

## Planning readiness

- [x] CHK013 Existing People, CarManager, Community, RoadNetwork, Playtest, and venue-data gaps are recorded in research.
- [x] CHK014 The plan starts with observability and failing regression cases before behavioural changes.
- [x] CHK015 Requirement groups map to delivery stages, contracts, and verification seams.
- [x] CHK016 Venue eligibility is separated from balance values and includes an explicit decision for every named building.
- [x] CHK017 Full map load is distinguished from ordinary incremental town edits.
- [x] CHK018 The quickstart includes focused, scenario, replay, regression, performance, visual, and asset-scope gates.

## Implementation evidence gates

- [ ] CHK019 Freeze the pre-change connected/disconnected civilian diagnostic traces.
- [x] CHK020 Demonstrate that deliberately injected civilian contradictions fail the new diagnostics.
- [x] CHK021 Record ten byte-identical normalised same-seed civilian traces.
- [x] CHK022 Record 512-proxy performance with diagnostics disabled and on-demand projection cost separately.
- [x] CHK023 Record before/after Community and first-town traces for venue data changes.
- [ ] CHK024 Confirm through a normal-renderer full-day observation that no mass resets, invalid crossings, or assignment mismatches remain.
- [x] CHK025 Confirm the implementation diff adds or changes no runtime art/audio asset for this feature.
