# Research: Connected First-Town Loop

## Canonical network

**Decision**: Extend `RoadNetwork` with a monotonically increasing revision,
stable connected-component IDs, building access records, and deterministic
shortest-route queries.

**Rationale**: It already reads authoritative GridMap state, understands
orientation-aware road connections, and gathers stops across every footprint
cell. Reusing it preserves one gameplay truth.

**Rejected**: A second flood-fill in Community or Playtest would drift from
vehicle graph semantics. Visible pedestrian/car paths are frame-dependent and
cannot own simulation truth.

## Allocation ownership

**Decision**: Community allocates named residents to work first and participant
destinations second, in resident-ID order, with destination priority, route
distance, anchor, building ID, and internal ID tie-breaks. Allocation is cached
by simulation hour plus RoadNetwork revision.

**Rationale**: Community owns resident identity, home, departure, and rehoming.
It already performs stable activity allocation and can prevent double use of a
resident during overlapping schedules.

**Rejected**: Per-workplace greedy queries can double-assign residents and make
results depend on sink registration order. CityStats has counts but no resident
identity or home anchor.

## Aggregate simulation integration

**Decision**: Keep CityStats. Workplace/commercial sinks request their canonical
fulfilled assignment count. Workplace output/budget sources continue to derive
from sink fulfilment, preserving Demand and Economy integration.

**Rationale**: This is the smallest change to the existing output/tax/demand
chain and retains current stats snapshots.

**Rejected**: Direct cash mutation from Community would couple unrelated
systems and bypass established tick ordering.

## Effect scope and connectivity

**Decision**: `participant` effects require a reachable canonical assignment.
`local`, `resident`, and `city` effects preserve authored spatial/schedule
semantics even if their source is disconnected. `requires_active_building`
means schedule/capacity operation, not removal of local nuisance caused by an
idle disconnected industrial building unless content explicitly says so.

## Stacking

**Decision**: Positive same-quality/same-group effects use the default sequence
`1.0, 0.5, 0.25, 0.0` for ordinals zero through three and remain zero after.
Negative effects use their own signed group and remain visible independently.

**Rationale**: The current evaluator implements `1.0, 0.5, 0.25, 0.25...`, an
unbounded spam incentive contrary to FR-035.

## Residential demand source

**Decision**: Replace raw city-wide Attractiveness as housing growth input with
a bounded Community residential signal derived from occupied residents; use
candidate-home Community evaluation for migration. An empty town receives no
nature-count demand bonus.

**Rejected**: Capping the existing city total still rewards unserved decoration.
A hidden beauty or variety score would violate the specification.

## Spatial scarcity

**Decision**: Give road catalog entries a small one-time `cash_cost`, charged by
the existing Economy/Builder atomic placement transaction and reported as road
spend.

**Rationale**: Roads are currently free, land extent can be inert, and the
starter plot does not reliably make every extra route cell consequential. This
is the minimal scarcity explicitly allowed by the spec.

**Rejected**: Maintenance, loans, traffic, or a blanket spread/density penalty
would expand scope. Inert distance cannot satisfy FR-039.

## Satisfaction presentation

**Decision**: Retain the Satisfaction plugin as a compatibility adapter during
006 but stop presenting it as a second resident-wellbeing value. HUD and
inspection use named Community qualities/composite happiness plus operation.

## Human evidence

**Decision**: Automate simulation and screenshot preparation only. The 3-player
pilot, 12-player acceptance cohort, three blind reviewers, and four durability
sessions remain explicitly incomplete until real anonymised records exist.

**Rationale**: Generated or inferred player evidence would invalidate FR-041.
