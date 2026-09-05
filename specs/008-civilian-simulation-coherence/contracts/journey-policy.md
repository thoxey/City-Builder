# Contract: Civilian Journey Policy

## Authority

- Community decides whether a resident is assigned and the exact destination.
- RoadNetwork decides whether origin/destination are connected and returns the stable
  stops, road path, distance, and revision.
- People decides only how to present a valid intent.
- CarManager executes a supplied valid road path; it does not select a different
  building destination or independently choose first stops.

## Planning Input

```json
{
  "resident_id": 42,
  "intent_revision": 18,
  "purpose": "work",
  "origin_anchor": {"x": -4, "z": 0},
  "destination_anchor": {"x": 3, "z": 0}
}
```

## Successful Plan Output

```json
{
  "ok": true,
  "origin_stop": {"x": -3, "y": 0, "z": 0},
  "destination_stop": {"x": 2, "y": 0, "z": 0},
  "road_path": [],
  "route_distance": 6,
  "mode": "car",
  "road_revision": 7,
  "plan_key": "stable-digest",
  "blocked_reason": ""
}
```

## Failure Output

```json
{
  "ok": false,
  "road_revision": 7,
  "blocked_reason": "disconnected"
}
```

Stable blocked reasons:

- `missing_origin`
- `missing_destination`
- `origin_has_no_road_access`
- `destination_has_no_road_access`
- `disconnected`
- `route_invalidated`
- `car_pool_full`
- `resident_unhoused`

## Mode Policy

1. Resolve the canonical route before selecting a mode.
2. Use `route_distance`, never anchor Manhattan distance.
3. If distance is at or below the data-authored walk threshold, use `walk`.
4. If distance is above the threshold, use `car`.
5. If the car pool is full, enter `waiting_for_car` and retry in stable resident order
   at a bounded interval.
6. Never convert a pool-full or disconnected car request into a direct walk across
   unsupported ground.

## Waypoint Policy

- Origin and destination last-mile segments use building footprint/road-edge points
  supplied or validated by RoadNetwork.
- Short walking routes follow the ordered canonical road cells with the existing
  sidewalk offset presentation.
- Every waypoint has a source cell recorded for diagnostics.
- An empty path is valid only when origin and destination are the same valid place.
- Pathfinding failure never returns `[destination]` as a synthetic success.

## CarManager Entry Point

A narrow resolved request is added without removing other callers immediately:

```gdscript
request_resolved_journey(
    resident_id: int,
    origin_stop: Vector3i,
    destination_stop: Vector3i,
    road_path: Array[Vector3i],
    road_revision: int,
    plan_key: String,
    car_type: int = CarSlot.CarType.CIVILIAN
) -> int
```

The path is copied. CarManager may adjust lane positions and congestion timing but
may not replace the endpoints or destination. Completion retains `journey_id` and
enough stable identity for People to reject a stale completion.

## Event Reconciliation

| Event | Required response |
|-------|-------------------|
| Hour/assignment revision | Reconcile each visible resident whose intent changed |
| Resident arrived | Add binding if within stable cap selection |
| Resident departed | Cancel/remove only that resident's journey and binding |
| Resident rehomed | Update immutable home field and replan that resident as needed |
| Programme changed | Invalidate Community assignment immediately, then reconcile affected intents |
| Structure placed | Preserve journeys unless endpoints/path dependencies changed |
| Structure demolished | Revalidate plans using affected endpoint/path dependencies |
| Road revision changed | Revalidate before the next segment; keep plan if still canonically valid |
| Map loaded | Cancel all transient cars and reconstruct all visible bindings from authoritative state |

## Interruption Rules

- If the current segment remains valid, it may finish before replanning.
- If the current cell/segment becomes invalid, stop at the last valid place or road
  stop and enter `blocked` until a new valid plan exists.
- A stale car completion whose `plan_key` no longer matches must not deliver the
  resident to the superseded destination.
- No interruption may mutate Community assignment or economic state.

## Required Contract Tests

- Connected multi-stop buildings use RoadNetwork's selected stops exactly.
- Equal-cost route ties are stable across ten runs.
- Disconnected destinations produce no pedestrian/car journey.
- Route distance controls walk/car mode at threshold-1, threshold, and threshold+1.
- Pool exhaustion produces stable waiting order.
- Unrelated placement preserves proxy positions, plan keys, and active journey IDs.
- Removing a used road cell invalidates only dependent plans.
- A stale completion cannot overwrite a newer intent.
