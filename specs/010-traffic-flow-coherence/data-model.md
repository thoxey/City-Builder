# Data Model: Traffic Flow Coherence

All entities are transient presentation records, excluded from saves and gameplay hashes.

## PendingDeparture

| Field | Meaning | Validation |
|---|---|---|
| `journey_id` | Stable identity shared with People | Non-negative; unique across pending/active |
| `resident_id` | Bound resident | Non-negative; one civilian car journey per resident |
| `plan_key` | Current civilian plan identity | Non-empty; matches People on lifecycle events |
| `origin_stop`, `destination_stop` | Canonical endpoints | Equal first/last route cells |
| `road_path` | Detached canonical route | Non-empty, contiguous, immutable while valid |
| `road_revision` | Route resolution revision | Non-negative |
| `request_epoch` | Fixed-step admission epoch | Monotonic in a reconstructed session |
| `request_sequence` | Stable within-epoch order | Monotonic and unique |
| `first_direction` | Initial road direction | Cardinal and non-zero |
| `waiting_reason` | Admission constraint | `origin_capacity` or `car_pool_capacity` |

Ordering key: `(request_epoch, request_sequence, resident_id, journey_id)`.

```text
validated request -> PENDING -> ACTIVE -> COMPLETED
                         |          |
                         +----------+-> CANCELLED
```

## ActiveCarJourney

| Field | Meaning | Validation |
|---|---|---|
| identity/route fields | Copied from pending | Preserve journey, resident, plan, and route |
| `current_tile` | Occupied/departed tile | Has a claim while active |
| `next_tile` | Reserved crossing target | Null or contiguous |
| `travel_direction` | Current segment direction | Cardinal; consistent with route |
| `current_claim_slot` | Current display slot | `0` or `1` |
| `next_claim_slot` | Reserved next slot | Null, `0`, or `1` |
| `segment_progress` | Visual crossing fraction | 0 through 1 inclusive |
| `waiting` | Capacity-blocked state | True only when next claim unavailable |
| `display_position` | Claim-derived transform | Inside permitted road bounds |

```text
ACTIVE_AT_TILE -> CROSSING -> ACTIVE_AT_TILE -> ... -> COMPLETED
       |              |
       +-> WAITING ---+
       +-------------------------------> CANCELLED
```

## RoadTileOccupancy

CarManager-owned record keyed by canonical road cell. It contains zero to two unique
claims and fixed capacity two. Each claim records journey ID, direction, phase
(`current` or `next`), stable slot, and claim order. One journey may hold claims on two
adjacent tiles while crossing but never twice on one tile.

## PedestrianSpacingClaim

| Field | Meaning | Validation |
|---|---|---|
| `resident_id` | Stable walker identity | Unique in a segment group |
| `from_tile`, `to_tile` | Directed canonical segment | Contiguous and in the plan |
| `order` | Front-to-back order | Progress then resident ID |
| `lateral_slot` | Pavement-relative offset | Deterministic and bounded |
| `limited_progress` | Following-limited display progress | Does not pass safe preceding position |

It affects the rendered proxy only, never current place, intent, route, or outcome.

## TrafficDiagnosticProjection

```text
schema_version
pending_departure_count
active_car_count
waiting_car_count
pending_departures[]
active_journeys[]
tile_occupancy[]
pedestrian_spacing[]
violations[]
```

Stable codes: `road_tile_over_capacity`, `duplicate_car_position`,
`car_transform_off_road`, `spawned_without_admission`, `pending_order_violation`,
`missing_current_tile_claim`, `invalid_next_tile_claim`,
`canonical_route_changed_by_congestion`, and `persistent_pedestrian_overlap`.

## Reconstruction

Full map load discards every pending departure, active journey, claim, display position,
and spacing claim. People reconciles loaded Community intents against RoadNetwork and
submits fresh journeys in stable resident order.
