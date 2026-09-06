# Deterministic Civilian Replay

Date: 2026-09-06  
Runner: `scripts/run_civilian_simulation_scenario.gd`  
Scenario: `civilian_simulation/connected_day`, seed `8008`

The headless fixed-step runner completed **10/10 clean full-day replays**. Each
replay produced 25 checkpoints (initial state plus 24 hourly boundaries) and the
same normalized SHA-256 trace:

`95775768d2206c8c3d166ce449f4f9dcee2235cfbe63eb1f8ea0d1bd2dc76c1b`

The canonical trace is stored in `last-run.json`. It shows two stable resident
bindings at home, the exact Community workplace destination during active hours,
canonical four-cell route distance, stable per-resident plan keys, dwell at the
destination, and return to immutable home. Every clean checkpoint has zero
violations.

Fault injection detected all requested codes:

- `duplicate_resident_binding`
- `intent_destination_mismatch`
- `unreachable_journey_started`
- `invalid_waypoint_cell`
- `stale_route_revision`
- `missing_car_binding`
- `unexpected_proxy_reset`
- `unexpected_car_cancellation`

The runner resets only diagnostic revision epochs between its in-process replays to
model ten fresh executable runs. All authoritative changes still use the existing
`start`, `place`, and `advance` playtest operations; visual motion is stepped only
through the internal fixed-delta People/CarManager seam. No public command was added.
