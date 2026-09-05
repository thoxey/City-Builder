# Connected First-Town Balance Evidence

The deterministic `first_town_connected` full-stack run uses one resident, one
home, and one garage. At hour 8 the roadless garage reports `no_road_access`
with zero workers, output, income, and road spend.

Two £2 road cells connect the same buildings. At hour 9 the garage has one
fulfilled worker, output 1, hourly income £5, cumulative income £5, and a
recorded road spend of £4. Removing the bridge cell and advancing exactly one
hour clears the worker, output, and income; the surviving road component is
reported as isolated.

The full machine-readable observations and hashes are in [last-run.json](last-run.json).
The milestone-005 patron regression also passes after the opening-demand
rebalance: 109 actions, 1,011 exact hours, population 329, final land 256, and
state hash `027f79c43bf3ad09c095172b9e81cec4593be2dd7c45499f17d9b80ae614e495`.
That evidence is stored at
`specs/005-reachable-first-patron/validation/m006-regression.json`.
