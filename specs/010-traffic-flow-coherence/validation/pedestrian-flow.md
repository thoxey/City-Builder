# Pedestrian Flow Phase Evidence

## Red

The new unit and integration fixtures failed before implementation because PersonSlot
had no detached display position and People had no segment-spacing pass or projection.
No assertions could complete until those presentation-only seams existed.

## Green

| Suite | Result | Assertions |
|---|---:|---:|
| `test_people_spacing.gd` | 5/5 passing | 17 |
| `test_pedestrian_flow.gd` | 1/1 passing | 31 |
| all `test/unit/people` | 24/24 passing | 75 |
| all `test/integration/traffic_flow` | 3/3 passing | 37 |

Equal-progress walkers are ordered by resident ID, limited by a 0.16-segment following
gap, and assigned unique bounded pavement-relative offsets. Opposing directions use
opposite pavement normals. Ten identical grouped-walker replays are byte-identical.
Tests confirm intent, plan, waypoint, current-place, and destination fields are
unchanged by spacing. At 512 proxies the post-change phase sample averaged 1.2603 ms
(1.5150 ms maximum), below the 16.7 ms budget.

Known baseline headless/GUT resource warnings remain present.
