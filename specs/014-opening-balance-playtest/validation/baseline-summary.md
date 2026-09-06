# Opening Balance Baseline Summary

The accepted baseline uses seeds `14014`, `14015`, and `14016`, plus a fresh
isolated replay of `14014`. All four runs reached the 75 lifetime-Homes
post-war mid-block unlock under the declared 240-hour/1000-action bounds.

| Seed | Endpoint hour | Idle hours | Actions | Homes total | Final Beauty | Lowest Beauty after floor | Rejections |
|---|---:|---:|---:|---:|---:|---:|---:|
| 14014 | 114 | 114 | 161 | 75.120 | 242 | 204 | 0 |
| 14015 | 114 | 114 | 161 | 75.234 | 242 | 204 | 0 |
| 14016 | 114 | 114 | 161 | 75.388 | 242 | 204 | 0 |

The primary run placed the Town Hall at sequence 1, completed its 32-cell
rooted road grid at sequence 33, reached Beauty 200 at sequence 42, then placed
the first home, work, shop, and terrace by sequence 47. The only idle span ran
from hour 0 to hour 114. Every hour was an explicit one-hour `advance` command;
the binding rule was the `below_demand_threshold` mid-block gate while lifetime
residential demand grew from 25 to 75.

The later balance pass should rerun the same strategy for introductory Homes
boosts of 0, 5, 10, 15, 20, and 25, comparing endpoint hour, idle span,
milestone timing, demand earned/spent, and any changed resource constraint.
This workstream deliberately leaves those balance values unchanged.

Machine-readable source: [baseline-report.json](baseline-report.json).
