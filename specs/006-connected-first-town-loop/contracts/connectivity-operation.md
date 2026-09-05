# Contract: Connectivity and Operation

## RoadNetwork queries

`get_connectivity_snapshot()` returns `revision`, sorted `road_cells`, stable
components, and access states for all placed non-road buildings.

`get_access_for_building(internal_id)` returns the complete footprint-derived
access state. Unknown IDs return `road_accessible=false` and
`primary_reason="unknown_building"`.

`get_route_between_buildings(origin_id, destination_id)` returns the stable
shortest route. Multiple equal routes are resolved by sorted starting stop,
sorted neighbour expansion, then sorted destination stop.

No consumer may infer connectivity from raw adjacency, visual path completion,
or a separate graph.

## Reason ordering

Operation blockers use this priority:

1. `no_road_access`
2. `isolated_road_component`
3. `outside_active_hours`
4. `no_free_capacity`
5. `no_reachable_residents`

The projection includes every applicable reason and one primary reason selected
by this order. `operating=true` only when the blocking set is empty and the
place has at least one fulfilled access-dependent assignment.

## Allocation

- Work destinations sort by authored priority, route distance, anchor,
  building ID, internal ID.
- Residents sort by stable resident ID.
- Valid prior assignments are retained only if they remain open, reachable,
  and within capacity.
- Work is allocated before overlapping participant activity.
- Rehoming, departure, demolition, closure, or connectivity revision forces
  revalidation at the next simulation boundary.

## Downstream contribution

Workplace output and budget are functions of its fulfilled canonical work
assignments. Economy multiplies the resulting operational output by the
authored tax rate. Commercial demand reads that same output. Participant effects
apply only to residents in the canonical activity assignment.
