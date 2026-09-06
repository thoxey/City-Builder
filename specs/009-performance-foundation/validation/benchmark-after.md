# Benchmark After Optimization

**Recorded**: 2026-09-06

**Godot**: 4.6.2.stable

**Scenario**: `res://test/scenarios/first_town/rebalance.json`

**Runner**: `res://scripts/run_performance_playthroughs.gd`

**Seed**: 6066

## Result

All three independently launched, rule-compliant playthroughs passed both performance gates and preserved the authoritative baseline state.

| Run | Scenario time | Worst hour | Worst 06:00 | State hash |
|---:|---:|---:|---:|---|
| 1 | 41.778 s | 469.062 ms | 469.062 ms | `4440de04356f95a80c7219dba3718825de1cc1b258adae28a61b7cf735fb2942` |
| 2 | 41.801 s | 462.343 ms | 462.343 ms | `4440de04356f95a80c7219dba3718825de1cc1b258adae28a61b7cf735fb2942` |
| 3 | 41.823 s | 463.831 ms | 463.831 ms | `4440de04356f95a80c7219dba3718825de1cc1b258adae28a61b7cf735fb2942` |

- Mean scenario time: 41.801 seconds
- Baseline scenario time: 132.75 seconds
- Mean total-time reduction: 68.5%
- Worst measured hour after optimization: 469.062 milliseconds
- Baseline observed 06:00 pause: more than 30 seconds
- Stall reduction: more than 98.4%, or at least 64 times shorter
- Performance gates: scenario <=45 seconds and individual hour <=500 milliseconds
- Three-run gate result: passed

## Deterministic gameplay comparison

Every run produced the same results:

- Authoritative hash exactly matches the pre-optimization baseline.
- 240 simulated hours, ending at 06:00.
- 60/60 meaningful placement attempts succeeded.
- 145 residents, 135 total buildings and 75 road cells.
- Building-role counts: 75 road, 30 residential, 17 nature, 6 industrial, 6 commercial and 1 civic.
- Town Hall was placed first; duplicate placement and protected replacement were rejected as required.
- No functional building failed the Town Hall-rooted road-access check.
- All 17 nature placements were functional community places.

## Diagnostic evidence

- 240 individual hourly timings were collected per run.
- AI actions used `snapshot_mode: "none"`; profiled snapshot time remained zero.
- The final route cache held 211 routes and recorded 1,881 hits against 211 misses (89.9% hit rate).
- The complete machine-readable record is `playthrough-report.json` in this directory.

The optimization changes diagnostic cost and avoids repeated invariant work only. Timings and cache counters remain outside saved state and state hashes.
