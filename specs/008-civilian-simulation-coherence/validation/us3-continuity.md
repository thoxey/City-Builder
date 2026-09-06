# US3 Edit Continuity Checkpoint

Date: 2026-09-06

## Focused results

| Test | Result | Assertions |
|---|---:|---:|
| `test/unit/people/test_people_reconciliation.gd` | 3/3 | 9 |
| `test/unit/people/test_people_roster_events.gd` | 2/2 | 9 |
| `test/unit/traffic/test_car_manager_invalidation.gd` | 2/2 | 5 |
| `test/integration/civilian_simulation/test_edit_continuity.gd` | 1/1 | 5 |

Total: **8/8 tests passed, 28 assertions**.

## Identity and continuity evidence

- An unrelated placement preserved both tested proxy positions, plan keys
  (`plan-1`, `plan-2`), and active journey IDs (`11`, `12`).
- Removing a cell from resident 1's route cancelled and blocked only resident 1.
  Resident 2 retained journey ID `12`, plan key `plan-2`, and its reservation.
- A global RoadNetwork revision change with an identical canonical route refreshed
  the stored revision while preserving the plan key and active car identity.
- Arrival, departure, and rehome events update the resident-indexed roster without a
  full visual rebuild. The 512-proxy boundary selects the lowest stable resident IDs.
- Map load remains the explicit full reconstruction/cancellation boundary; transient
  transform, route-progress, and car identity are not restored.
- Stale car completions remain guarded by the plan key. Interrupted residents retain
  their last authoritative `current_place` and become visibly blocked until replanned.

Headless macOS emitted its existing certificate and shutdown resource warnings; no
focused test assertion or script execution failed.
