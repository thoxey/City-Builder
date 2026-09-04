# Rejection Matrix

Builder unit coverage exercises every placement gate and verifies rejected
commands leave cash, demand, registries, and placement signals unchanged.

| Class | Stable code | Evidence |
|---|---|---|
| Unknown content | `unknown_building` | Builder command test |
| Rotation | `invalid_rotation` | Builder command test |
| Land | `outside_buildable_area` | Builder test and live `(99,99)` rejection |
| Decorative occupancy | `occupied_footprint` | Builder command test |
| Proper building occupancy | `replacement_required` | Builder command test |
| Cash | `insufficient_cash` | Builder + Economy quote tests |
| Tier gate | `below_demand_threshold` | Builder + Demand quote tests |
| Demand balance | `insufficient_demand` | Builder + Demand quote tests |
| Unique prerequisites | `unmet_prerequisite` | Builder + UniqueRegistry tests |
| Unique duplicate | `unique_already_placed` | Builder + UniqueRegistry tests |
| Empty demolition | `nothing_to_demolish` | Builder command test |
| Protected demolition | `demolition_not_allowed` | Builder command surface |
| Invalid time | `invalid_hours` | DayNight tests |
| Stale sequence | `sequence_conflict` | Playtest tests |

The live duplicate request check returned `duplicate` at the original sequence
with one building still present, proving it did not place twice.
