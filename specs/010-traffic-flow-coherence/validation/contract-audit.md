# Contract and Authority Audit

Captured 2026-09-06 after all automated gates passed.

## Traffic admission and occupancy

- Valid resolved requests copy the canonical route into detached pending records and
  return a stable identity without allocating a renderer slot or transform.
- Admission processes origins in stable tile order and requests FIFO. Temporary
  origin or render-pool pressure records `origin_capacity` or `car_pool_capacity`
  instead of rejecting the request.
- Active cars hold a current claim and reserve the next claim before crossing. A tile
  admits at most two total claims across all directions, and one process step crosses
  at most one capacity boundary.
- Congested resolved journeys keep their canonical route and wait indefinitely while
  it remains valid. Cancellation and demolition are targeted; full map load clears
  all pending, active, claim, and allocation state.
- Direction-aware lane anchors and stable front/rear slots remain inside the claimed
  road-tile union. Unit and integration tests cover starts, releases, opposing travel,
  turns, large deltas, long blockage, and targeted invalidation.

## People lifecycle and pedestrian spacing

- People keeps an admitted request's resident visible in `WAITING_FOR_CAR` until the
  matching deferred `journey_started` signal, then hides only that resident.
- Matching completion restores the proxy at the road stop. Cancellation, plan changes,
  late signals, rebuild, and reconstruction preserve the feature-008 lifecycle.
- Pedestrian grouping uses directed canonical segments and resident-ID tie breaks.
  Following and lateral changes are stored in display-only fields; canonical position,
  waypoints, assignment, destination, and outcome remain unchanged.

## Diagnostics, persistence, and public surface

- Full snapshots append detached, stably ordered `traffic_flow` data only after the
  gameplay hash is calculated. Compact snapshots omit it.
- All nine specified traffic fault codes are injected and detected by the deterministic
  runner. Clean focused, integration, civilian, and first-town traces report no traffic
  violations.
- Save resources and gameplay hashes contain no traffic claims, transforms, spacing,
  queue state, or diagnostics. Existing hash-exclusion and persistence suites pass.
- No public playtest operation was added; explicit `get_traffic_flow` and
  `step_visual_time` requests remain unknown operations.

## Authority boundaries

- Community remains the sole owner of resident intent, assignment, and outcomes.
- RoadNetwork remains the sole owner of road access, canonical stops/routes, distance,
  and topology revision.
- CarManager owns only transient admission, claims, queue ordering, and car transforms.
- People owns only transient proxy lifecycle and display spacing.
- Runtime implementation changes do not touch Community, RoadNetwork, economy, demand,
  satisfaction, save schema, art, or audio.

## Task-order audit

The task graph is dependency-valid: baseline/fixtures precede behavior; pending
admission precedes active capacity; capacity precedes pedestrian integration and
diagnostics; diagnostics precede scenario/release evidence. For each behavioral phase,
the named unit/contract tests were run red for the absent behavior before implementation
and green afterward, as recorded in `admission.md`, `vehicle-flow.md`,
`pedestrian-flow.md`, and `diagnostics.md`.

Result: all three written contracts and every automated authority boundary are covered.
The normal-renderer observation remains the sole open evidence gate.
