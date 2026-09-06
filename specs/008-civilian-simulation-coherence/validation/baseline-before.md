# Civilian Simulation Baseline

Captured 2026-09-06 before feature 008 runtime changes, at commit `3d98503`, on
Godot 4.6.2 and GUT 9.3.0.

| Suite | Scripts | Tests | Assertions | Result |
|---|---:|---:|---:|---|
| `test/unit/community` | 11 | 38 | 516 | PASS |
| `test/unit/traffic` | 3 | 7 | 19 | PASS |
| `test/unit/day_night` | 1 | 6 | 16 | PASS |
| `test/unit/playtest` | 4 | 18 | 89 | PASS |
| **Focused total** | **19** | **69** | **640** | **PASS** |

Commands were the four headless GUT invocations in `quickstart.md`, with logs at
`/tmp/city-builder-civilian-{community,traffic,day-night,playtest}.log`.

Godot reported the existing macOS certificate lookup message and GUT
orphan/resource-at-exit warnings. None was an assertion failure. Earlier research
observed 13 repository-wide BuildingCatalog fixture failures when `user://` was not
writable; final full-suite evidence must use the normal writable Godot application
data directory rather than accepting those failures.

The pre-change contradiction is documented by the feature research probe:
Community assigned a connected worker correctly, but the visible proxy returned
home while work remained active; in a disconnected layout Community assigned no
work while People created a direct fallback path. No pre-existing civilian debug
projection exists, so CHK019 cannot be completed until the observability seam can
capture the same cases without changing authority.
