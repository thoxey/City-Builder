# Contract: Performance Evidence

## Boundary Vocabulary

Required named boundaries:

`hour.total`, `hour.collect`, `hour.validate_reduce`, `hour.commit`, `hour.notify`, `projection.operational`, `projection.diagnostic`, `presentation.flush`, `building.command`, `building.index_update`, `migration.context`, `migration.candidates`, `people.process`, `traffic.admission`, `traffic.process`, `render.submit`, `frame.total`, `engine_unattributed`.

## Sample Schema

Each sample records:

- boundary and optional parent boundary;
- elapsed microseconds;
- state version plus absolute hour or frame index;
- workload counts relevant to the boundary;
- engine version, build mode, platform/reference-machine ID;
- seed and scenario/town identity;
- whether warm-up, loading, or explicit diagnostic capture applies.

Instrumentation is disabled or aggregated in release hot paths and cannot affect gameplay inputs, saves, or hashes.

## Aggregate Report

Each enforced report contains at least three equivalent measured runs and records sample count, median, p95, maximum, exclusions, budget, pass/fail, final state hash, and ledger hash. Percentiles use one documented nearest-rank rule.

The report must account for at least 95% of measured main-thread frame time through named nested boundaries or `engine_unattributed`.

## Initial Gates

| Budget | Workload | Statistic | Threshold |
|---|---|---:|---:|
| Canonical playthrough | 135 buildings, 240 hours | each run | ≤35 s |
| Hourly transaction | same playthrough, includes 06:00 | p95 / max | ≤16.7 / 33.3 ms |
| Building mutation | representative place/replace/demolish | median / p95 / max | ≤16.7 / 33.3 / 50 ms |
| Operational UI projection | dashboard and community | median / p95 | ≤4 / 8 ms |
| Entity processing | 512 civilians, up to 256 vehicles | p95 | ≤8 ms |
| Rendered town | representative saved town | median FPS | ≥60 |
| Rendered process time | excludes load/diagnostic capture | median / p95 / max | ≤16.7 / 25 / 50 ms |

## Reproducibility

A failure report identifies the exact boundary, workload counts, run, sample range, engine/build environment, seed, state/ledger hashes, and command needed to reproduce it. Baselines and after-reports use the same scenario and seed unless an intentional gameplay change is documented separately.
