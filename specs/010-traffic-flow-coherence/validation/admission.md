# Admission Phase Evidence

## Red

- `test_car_manager_admission.gd`: the pre-change implementation had no
  `get_traffic_flow_snapshot`, allocated render slots synchronously, and did not expose
  pending departures.
- `test_people_car_lifecycle.gd`: 2/3 tests failed because an accepted request moved the
  person directly to `IN_CAR`, hid the proxy, and did not handle a deferred or stale
  `journey_started` signal.

## Green

| Suite | Result | Assertions |
|---|---:|---:|
| `test_car_manager_admission.gd` | 5/5 passing | 15 |
| `test_people_car_lifecycle.gd` | 3/3 passing | 11 |
| all `test/unit/traffic` | 25/25 passing | 88 |
| all `test/unit/people` | 19/19 passing | 58 |

The four-request fixture produces two active and two pending records. Cancelling the
first active identity admits only the next FIFO identity. Origin claims carry the first
canonical direction, and pending reasons distinguish road-tile capacity from render
pool capacity. People remains visible in `WAITING_FOR_CAR` until the matching deferred
start event; stale starts are cancelled without entering `IN_CAR`.

Known baseline headless/GUT resource warnings remain present.
