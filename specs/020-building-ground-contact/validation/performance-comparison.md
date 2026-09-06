# Reference-town performance comparison

The performance gate passes on a paired current-tree comparison. The 135-building,
138-cell reference town uses 46 underlay cells after feature 020.

## Frozen baseline investigation

The frozen pre-change run and first final run produced these median deltas:

| Measure | Frozen before | Final run | Delta |
|---|---:|---:|---:|
| Map load | 100,536 µs | 107,705 µs | +7.131% |
| Placement | 21,439 µs | 24,948 µs | +16.367% |
| Steady rendered frame | 6,913 µs | 16,657 µs | +140.952% |
| Draw calls | 368 | 352 | -4.348% |
| Visible objects | 469 | 453 | -3.412% |
| Primitives | 2,684,542 | 2,682,818 | -0.064% |

This triggered the required investigation. The dirty shared tree's concurrent feature-019
work continued after the baseline freeze. More importantly, the frozen frame samples
switch from the display's roughly 16.7 ms cadence to roughly 6.9 ms partway through the
run, whereas both final repeats remain at roughly 16.7 ms. Rendering counts all decreased
in the first final run, contradicting an underlay-driven 141% render-cost increase.

## Paired feature-cost result

The validation harness therefore ran the settled tree twice in immediate sequence. The
control changes every in-memory catalogue treatment to legacy `replace` after scene setup;
it does not edit production data, models, saves, or gameplay. The paired run enables the
authored underlays normally.

| Measure | Current-tree control | Underlays enabled | Delta |
|---|---:|---:|---:|
| Map load | 105,770 µs | 103,834 µs | -1.830% |
| Placement | 22,134 µs | 21,694 µs | -1.988% |
| Steady rendered frame | 16,659 µs | 16,658 µs | -0.006% |
| Draw calls | 344 | 354 | +2.907% |
| Visible objects | 445 | 455 | +2.247% |
| Primitives | 2,682,958 | 2,683,074 | +0.004% |

All timing and render-count medians stay within the 5% budget. Raw samples, environment,
renderer, viewport, and ground-state hashes remain in the linked JSON reports.

- Frozen baseline: `performance-before.json`
- Initial final run: `performance-after.json`
- Final repeat: `performance-after-repeat-1.json`
- Paired final-tree legacy control: `performance-current-control.json`
- Paired final-tree underlay run: `performance-current-underlay.json`
