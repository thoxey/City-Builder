# Diagnostics Phase Evidence

## Red

- Vehicle fault injection found none of the eight required vehicle codes.
- Both pedestrian diagnostic/reset tests failed because exact spacing overlap was not
  checked and clear/rebuild retained spacing rows.
- Playtest lacked `civilian_simulation.traffic_flow` (the no-new-command assertion was
  already green).
- The integration off-road fixture was not detected.

## Green

| Suite | Result | Assertions |
|---|---:|---:|
| `test_car_manager_traffic_diagnostics.gd` | 3/3 passing | 17 |
| `test_people_spacing_diagnostics.gd` | 2/2 passing | 2 |
| `test_playtest_traffic_flow.gd` | 2/2 passing | 6 |
| `test_traffic_diagnostics.gd` | 2/2 passing | 5 |
| all `test/unit/traffic` | 36/36 passing | 134 |
| all `test/unit/people` | 26/26 passing | 77 |
| all `test/unit/playtest` | 29/29 passing | 114 |
| all `test/integration/traffic_flow` | 5/5 passing | 42 |

The detached projection now reports pending, active, waiting, occupancy, pedestrian
spacing, and stable violations. Fault tests cover over-capacity, duplicate car
position, off-road transform, admission bypass, pending-order violation, missing
current claim, invalid next claim, canonical-route mutation, and persistent pedestrian
overlap. Returned nested route and occupancy data is detached. Playtest appends the
projection after state hashing, compact snapshots omit it, and `get_traffic_flow`
remains an unknown public operation.

Known baseline headless/GUT resource warnings remain present.
