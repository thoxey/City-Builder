# Data Model: Connected First-Town Loop

## Connectivity Projection

- `revision: int` — increments after each authoritative rebuild.
- `road_cells: Array<Coordinate>` — stable x/y order.
- `components: Array<RoadComponent>`.
- `buildings: Array<BuildingAccessState>`.

## Road Component

- `component_id: String` — stable ID derived from the lexicographically first
  road cell in the component.
- `cells: Array<Coordinate>` — sorted unique road cells.
- `cell_count: int`.

## Building Access State

- `internal_id`, `building_id`, `anchor`, `footprint_cells`.
- `stops` and `component_ids`, both sorted and unique.
- `road_accessible: bool`.
- `primary_reason: String` and `reasons: Array<String>`.
- State is derived only; it is never persisted.

## Reachable Pair

- `reachable: bool`, `origin_internal_id`, `destination_internal_id`.
- `origin_stops`, `destination_stops`, `shared_component_ids`.
- `distance: int` — road-edge count on the selected shortest route.
- `path: Array<Coordinate>` — stable shortest path.
- `reason` — empty, `no_road_access`, or `isolated_road_component`.

## Resident Assignment

- `resident_id`, `purpose` (`work` or `activity`).
- `destination_internal_id`, `building_id`, `anchor`.
- `route_distance`, `component_id`, `assigned_hour`.
- `priority` and stable `allocation_order` evidence.
- Work and activity records persist only as resident continuity hints; they are
  revalidated against current schedule/home/network before reuse.

## Operational State

- Place identity and access evidence.
- `open_now`, `capacity`, `fulfilled`, `available_capacity`.
- `operating`, `primary_reason`, ordered `reasons`.
- `latest_output`, `latest_income`, `latest_activity`.
- Reasons are recalculated at every canonical boundary; stale assignments do
  not survive a changed connectivity revision.

## Spatial Exposure Record

- `exposure_id` — resident/source/effect stable composite key.
- `resident_id`, `resident_anchor`, source identity and anchor.
- effect ID, quality, manifestation, scope, reason.
- authored radius, Manhattan distance, signed base amount.
- stacking group, ordinal, multiplier, and applied amount.
- participant/reachability evidence where relevant.

## Coverage Summary

- Keyed by effect and stacking group.
- Stable distinct resident IDs and occupied-home anchors.
- positive/negative sign, source count, exposure count, applied total.
- Candidate-home service is reported separately from occupied-resident service.

## Resident-Serving Nature Record

- source identity, role (`functional` or `cosmetic_only`) and named effects.
- occupied residents/homes served.
- candidate homes served.
- reachable participants.
- overlap counts and applied totals.

## Layout Pair Manifest

- pair/scenario IDs and schema version.
- exact held constants: non-road/nature multisets, capacities, resident stream,
  starting cash/demand/land, seed, duration, story mode.
- permitted differences: anchors and required roads.
- trace references and validation result/errors.
- Comparison deltas are calculated only when admissible.

## First-Town Balance Trace

- ordered semantic actions and exact hours.
- connectivity revisions, assignments, operation, exposures, coverage.
- road count, occupied land, cash and spend by category.
- output, income, demand, population, qualities, migration, tiers, progression.
- deterministic balance hash excluding presentation-only state.

## Rooted Town State

- `town_hall_internal_id`, authored building ID, anchor, and footprint.
- protected/placed state and zero-cost evidence.
- sorted rooted component IDs and road cells.
- placement candidate kind, footprint, eligibility, stable reason, and touching
  rooted road cells.

## Town Hall Proximity

- destination internal/building ID and category.
- Town Hall and destination stops, stable route, and road-edge distance.
- band (`core`, `near`, or `outside`).
- shop activity multiplier and incremental income.
- occupied-home signed Liveability amount and exposure reason.

## Cadence Checkpoint

- real minutes and corresponding exact simulation hours.
- successful/rejected meaningful placements by category.
- separately counted roads, cosmetics, replacements, and rejections.
- current simultaneous meaningful structure count.
- rooted-access coverage, cash, demand, population, operation, Community,
  occupied land, and remaining land.

## State transitions

```text
placement/demolition/load
  -> RoadNetwork rebuild/revision
  -> next assignment request invalidates cached allocation
  -> Community assigns reachable residents
  -> workplace/commercial sinks request fulfilled counts
  -> CityStats distributes canonical counts
  -> output -> income/commercial demand
  -> Community applies local/resident/participant effects
  -> snapshots expose the same evidence
```
