# Town Hall cadence rebalance

The focused milestone-006 rebalance passed its deterministic normal-speed
acceptance run on 2026-09-05.

## Results

| Real time | Simulation time | Required meaningful placements | Actual | Cash |
|---:|---:|---:|---:|---:|
| 5 minutes | 60 hours | 15 | 15 | £2,240 |
| 10 minutes | 120 hours | 30 | 30 | £4,288 |
| 20 minutes | 240 hours | 60 | 60 | £17,700 |

- Placement success: 60/60 meaningful attempts (100%).
- Final mix: 16 homes, 13 shops, 13 workplaces, 17 functional nature
  places, and one Town Hall.
- Road network: 75 tiles; every functional place remained road-accessible on
  the Town Hall-rooted component.
- Population: 75/80 residential capacity.
- Proximity: both the 0–5 and 6–10 road-tile bands were exercised; nearby
  homes exposed the authored Liveability penalty and nearby shops exposed the
  authored activity bonus. The shop bonus produced £280 incremental income.
- Economy: cash never went negative, cumulative income was positive, and 11
  useful build choices remained available at 20 minutes.
- Renderer evidence: Forward+ on Apple M2 Max, 1280×720.

Machine-readable evidence is in `rebalance-last-run.json`; the exact building
manifest and operation records are stored under `final_summary`.
