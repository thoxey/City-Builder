# Contract: Traffic Admission and Occupancy

## Ownership

- RoadNetwork owns roads, stops, canonical paths, distance, and revision.
- CarManager owns transient admission, capacity claims, queue order, and transforms.
- Community owns assignments and outcomes; traffic cannot alter them.

## Resolved request

`request_resolved_journey(...) -> journey_id` returns a non-negative stable ID for a
structurally valid request now in pending state. It does not show a car synchronously.
A negative result is only for malformed, disconnected, unsupported, or duplicate
requests; temporary road or pool capacity is not rejection. CarManager copies the
route. Pending records sort by epoch, sequence, resident ID, then journey ID.

## Admission

During deterministic stepping, process origins in stable tile order and their requests
FIFO. Admit only when a pool slot exists and origin occupancy is below two. Claim the
origin with the first route direction, allocate rendering, and emit
`journey_started(journey_id, origin_stop, position)`. Stop at exhausted capacity.

## Movement

- Claim the next route tile before segment movement.
- Retain the current claim until crossing completes.
- Never exceed two unique journey claims on a tile.
- If the next claim fails, wait at the current bounded slot.
- Release and promote claims in stable journey order.
- A large delta cannot bypass a capacity boundary.

Resolved civilian congestion never causes rerouting, skipped cells, retry completion,
or teleporting.

## Cancellation and load

`cancel_journey` removes pending or active state. Active cancellation releases every
claim and pool slot. Full map load clears transient records; unrelated edits preserve
them.

## Display bounds

Each tile supplies at most two stable slots. Direction selects lane side and same-
direction order selects front/rear placement. Pending records have no transform.
