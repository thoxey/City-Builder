# Vehicle Flow Phase Evidence

## Red

- `test_car_manager_capacity.gd`: 4/6 failed. The old projection omitted next claims,
  same-direction display positions were identical, and released global slots were not
  promoted.
- `test_car_manager_canonical_waiting.gd`: the long blockage fixture completed and
  removed the still-valid journey after invoking the legacy reroute path.
- `test_vehicle_flow.gd`: the downstream blockage fixture lost both valid journeys
  instead of retaining an on-road queue.

## Green

| Suite | Result | Assertions |
|---|---:|---:|
| `test_car_manager_capacity.gd` | 6/6 passing | 20 |
| `test_car_manager_canonical_waiting.gd` | 2/2 passing | 9 |
| `test_vehicle_flow.gd` | 2/2 passing | 6 |
| all `test/unit/traffic` | 33/33 passing | 117 |
| all `test/integration/traffic_flow` | 2/2 passing | 6 |

The manager now applies two claims total per tile for all directions. A crossing holds
both current and next claims, promotes the next claim to current atomically, and allows
at most one tile boundary per update even for a large delta. Same-direction cars use
distinct bounded front/rear anchors; opposing cars use direction-derived lanes. A
twenty-second fixed-step blockage preserves active identities, route bytes, and waiting
state with zero legacy route queries or completion.

Known baseline headless/GUT resource warnings remain present.
