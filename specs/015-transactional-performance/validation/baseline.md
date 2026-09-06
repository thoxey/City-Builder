# Pre-Implementation Performance Baseline

**Captured**: 2026-09-06
**Engine**: Godot 4.6.2
**Reference environment**: Current macOS development machine, debug/headless unless marked rendered
**Status**: Planning evidence; rerun immediately before implementation to freeze commit/worktree identity

## Canonical headless town

| Measurement | Observed |
|---|---:|
| Workload | 240 hours, 135 buildings |
| Complete run | 47.25–47.87 s |
| Existing gate | 45 s |
| 06:00 migration transition | 506–516 ms |

## Building placement

| Statistic | Observed |
|---|---:|
| Mean | ~54 ms |
| p95 | ~187 ms |
| Maximum | ~344 ms |

## Rendered populated town

| Measurement | Observed |
|---|---:|
| Median process time | ~18.25 ms |
| Maximum process time | 578 ms |
| Mean observed FPS | 54.4 |
| Median draw calls | ~167 |
| Submitted primitives | ~3 million |
| Population | 140 people |
| Traffic | 20 active cars, 25 pending |

## Projection and diagnostics

| Boundary | Observed |
|---|---:|
| Community compact snapshot | 34 ms |
| Community full snapshot | 46 ms |
| Community spatial snapshot | 32 ms |
| Community UI model | 125 ms |
| Dashboard refresh | 44 ms |
| Playtest full snapshot | 222 ms |
| RoadNetwork rebuild | 1.56 ms |

## Entity processing

| Boundary | Observed |
|---|---:|
| 512-civilian movement average | 5.08 ms |
| 512-civilian movement maximum | 5.94 ms |
| Civilian diagnostics | ~34 ms |

## Interpretation

The dominant visible spikes are synchronous hourly fan-out, the migration boundary, placement cascades, and diagnostic-heavy UI rebuilds. Entity loops and rendering are scaling pressure rather than the largest isolated stall. Debug output is present in several hot paths and can distort development-build timing.

## Reproduction caveat

These values were gathered from the active development worktree. Before implementation, record the exact commit, dirty-worktree fingerprint, machine identifier, build mode, scenario seed/state hash, sample counts, percentile method, and raw JSON so before/after gates meet the [performance evidence contract](../contracts/performance-evidence.md).
