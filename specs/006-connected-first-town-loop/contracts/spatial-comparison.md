# Contract: Spatial Comparison

## Pair manifest

Every comparison fixture declares:

```json
{
  "schema_version": 1,
  "pair_id": "compact-spread",
  "left_scenario": "first_town_compact",
  "right_scenario": "first_town_spread",
  "held_constant": {
    "non_road_building_multiset": {},
    "nature_multiset": {},
    "capacities": {},
    "starting_cash": 0,
    "starting_demand": {},
    "resident_stream": [],
    "seed": 0,
    "duration_hours": 168,
    "story_enabled": false
  },
  "permitted_differences": ["anchors", "road_cells"]
}
```

The comparator reconstructs actual values from both traces. A missing field,
unpermitted difference, mismatched multiset/capacity/seed/duration/resource, or
non-canonical trace makes the pair `admissible=false`; no outcome delta is then
accepted.

## Required metrics

- exposures and distinct coverage per effect/stacking group;
- road count and spend, route distance, occupied cells/extent, remaining land;
- fulfilled work/activity assignments and capacities;
- output, hourly/cumulative income, cash, demand totals/fulfilment;
- Community qualities, population, migration;
- tier and story progression observations.

## Trade-off gate

A greater road count, route distance, or extent passes only if it changes cash,
remaining land, a useful available placement, fulfilled capacity, or milestone
timing. Metrics never combine into a hidden layout score.

## Determinism

Each accepted side repeats ten times. Exposure sets, coverage sets,
assignments, milestones, and balance hashes must match within a side. Left and
right may differ only in the declared outcomes of their admissible layouts.
