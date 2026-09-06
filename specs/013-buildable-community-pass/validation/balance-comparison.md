# Balance Comparison

**Scenario**: `first_town/rebalance`
**Seed**: `6066`
**Horizon**: 240 simulation hours / 60 meaningful placements

## Authored changes

| Source | Effect | Before | After |
|---|---|---:|---:|
| Town Hall | `civic_heart` Belonging amount | +2 | +4 |
| Town Hall | `civic_heart` local radius | 3 | 5 |
| Small Commercial B | `high_street_encounter` participant Belonging | +3 | +4 |

No baseline, response-rate, Liveability, Beauty, negative-effect, scope, or
stacking values changed. The existing same-group positive stacking curve stays
at `1.0, 0.5, 0.25, 0.0...`, so five identical +6 nature effects still cap at
+10.5 rather than +30.

## Fixed-seed result

| Quality | Before | After | Delta |
|---|---:|---:|---:|
| Liveability | 68.8143 | 69.0390 | +0.2247 |
| Beauty | 56.3298 | 56.5390 | +0.2092 |
| Belonging | 50.4525 | 51.9713 | +1.5188 |

All three requested qualities finish above the neutral 50 baseline. The small
Liveability/Beauty movement is an indirect consequence of the larger starter
area changing the deterministic placement mix; their authored balance values
were deliberately left alone. The run retained both a Town Hall bustle penalty
near homes and a nearby-shop bonus, with 17 functional nature places and no
unrooted functional buildings.

The rooted land result changed from 196 to 256 starter cells. With the same 138
occupied cells, free capacity increased from 58 to 118. The final after-state is
recorded in `rebalance-after.json` and also refreshes the affected feature-006
progression snapshot.
