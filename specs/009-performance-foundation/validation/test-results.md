# Automated Test Results

**Recorded**: 2026-09-06

**Godot**: 4.6.2.stable

**GUT**: 9.3.0

## Final result

The complete repository suite passed after the final optimization:

- 86 test scripts
- 401 tests
- 2,711 assertions
- 401 passing, 0 failing
- GUT-reported duration: 48.958 seconds

Godot headless import also completed successfully. It retained known environmental/project warnings: the disabled local MCP endpoint, a pre-existing duplicate portrait UID, GUT orphan counts and resources/RIDs reported at process exit. No parse, import or test failure was present.

## Focused verification

| Area | Result | Important coverage |
|---|---:|---|
| Community | 47/47 | migration reuse, full/large capacity, exact score-only evaluation, assignment and persistence |
| DayNight | 8/8 | manual advance and opt-in ordered per-hour timings |
| Playtest | 27/27 | snapshot modes, action timing, replay determinism |
| RoadNetwork | 20/20 | cache hits, copy safety, anchor index and every topology-event invalidation |
| People | 16/16 | intent reconciliation, journeys, deterministic proxy performance |
| Core PlayerUI | 17/17 | radial menu, top status bar and bottom tool dock only |
| Civilian integration | 6/6 | assigned day, diagnostics, connectivity and edit continuity |
| PlayerUI integration | 5/5 | radial availability/placement and input priority |
| Performance integration | 1/1 | real 05:00-to-06:00 migration boundary |
| BuildingCatalog fixture harness | 14/14 | reliable globalized `user://` fixture setup |

The Community stress test simulated 500 residents for 168 hours in 2.568 seconds. The People proxy benchmark updated 512 proxies for 300 samples at 0.643 ms average and 0.728 ms maximum in its focused run.

## End-to-end performance gate

`res://scripts/run_performance_playthroughs.gd` launched three fresh 240-hour towns. All three passed the 45-second scenario gate, 500-millisecond hourly gate, deterministic hash check, legal-construction checks and variety requirements. See `benchmark-after.md` and `playthrough-report.json` for exact results.
