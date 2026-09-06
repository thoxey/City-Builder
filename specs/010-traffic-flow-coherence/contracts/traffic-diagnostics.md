# Contract: Traffic Diagnostic Projection

Extend non-compact `civilian_simulation` after gameplay hash calculation. Add no public
playtest command. Compact snapshots may omit it as feature 008 permits.

```json
{
  "traffic_flow": {
    "schema_version": 1,
    "pending_departure_count": 0,
    "active_car_count": 0,
    "waiting_car_count": 0,
    "pending_departures": [],
    "active_journeys": [],
    "tile_occupancy": [],
    "pedestrian_spacing": [],
    "violations": []
  }
}
```

Pending rows include journey/resident/plan identity, endpoints, order, first direction,
and reason. Active rows add current/next claims, slots, progress, waiting, and normalized
display position. Occupancy sorts by tile; claims by slot, claim order, then journey.

Stable faults are those listed in `data-model.md`. Violations sort by code, tile,
resident, then journey. Results are deep detached copies.

Normalize vectors as integer cells or fixed-precision positions. Exclude wall-clock,
frame-rate, logging, and renderer metadata. All traffic/spacing state and diagnostics
remain excluded from saves, hashes, economy, demand, happiness, and Community effects.
