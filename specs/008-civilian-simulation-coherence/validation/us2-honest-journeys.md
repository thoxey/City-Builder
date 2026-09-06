# US2 Honest Journeys Checkpoint

Date: 2026-09-06  
Godot: 4.6.2 stable  
GUT: 9.3.0

## Focused results

All commands used headless Godot with a unique `--log-file` and `-gexit`.

| Test | Result | Assertions |
|---|---:|---:|
| `test/unit/traffic/test_road_network_civilian_routes.gd` | 2/2 | 16 |
| `test/unit/traffic/test_car_manager_resolved_journeys.gd` | 2/2 | 6 |
| `test/unit/people/test_people_journey_policy.gd` | 3/3 | 8 |
| `test/integration/civilian_simulation/test_honest_journeys.gd` | 1/1 | 4 |

Total: **8/8 tests passed, 34 assertions**.

## Evidence

- Connected routes expose detached chosen stops, stable ordered road cells, route
  distance, and road revision. Repeated equal-cost resolution selects the same path.
- Route distance at the authored threshold walks; threshold plus one requests a car.
- Pedestrian waypoints are copied from the canonical route projection. A failed
  projection produces `blocked/disconnected` with no direct fallback waypoint.
- Resolved car requests copy route data and retain resident ID, plan key, and route
  revision. Pool exhaustion returns the resident to deterministic bounded retry in
  `waiting_for_car`; it never switches to walking.
- Car completion is associated with the originating plan key, allowing superseded
  completions to be rejected.
- The connected/disconnected integration fixture produced respectively an ordered
  five-cell canonical walk and an explained stationary resident with zero waypoints.

The macOS headless certificate lookup warning and shutdown resource-count warning
were non-test infrastructure warnings; no focused assertion failed.
