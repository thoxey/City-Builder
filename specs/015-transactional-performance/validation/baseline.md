# Pre-Implementation Performance Baseline

**Captured**: 2026-09-06
**Engine**: Godot 4.6.2
**Reference environment**: Current macOS development machine, debug/headless unless marked rendered
**Status**: Frozen immediately before implementation

## Frozen identity

| Field | Value |
|---|---|
| Git HEAD | `d04d3b01c2db7aa76ce54fa5a77f979762283b6d` |
| Checked-out branch | `codex/009-performance-foundation` (pre-existing; no branch operation performed) |
| Dirty-tree fingerprint | `84e9e1436578c37f605fcff0c067a73b9af24317` |
| Host | `Toms-MacBook-Pro.local`, Darwin 25.5.0 arm64 |
| Engine | `4.6.2.stable.official.71f334935` |
| Build mode | editor/debug, headless |
| Scenario | `first_town/rebalance` |
| Seed | `6066` |
| Workload | 135 placed buildings, 75 road cells, 140 residents, 240 exact hours |
| Frozen state hash | `97f9a572217d4dfa12de8feb8f9a66589aa25fa416aaf48e10a12450712bf83b` |
| Percentile rule | nearest rank, `ceil(p * n) - 1`, clamped |

The worktree already contained overlapping Community, Builder, attractiveness,
Player UI, dialogue, palette, and specification work. The fingerprint includes
tracked changes and untracked-file content so later parity compares against the
actual state inherited by this feature rather than HEAD alone.

## Canonical headless town

| Measurement | Observed |
|---|---:|
| Workload | 240 hours, 135 buildings |
| Complete run | 47.25–47.87 s |
| Existing gate | 45 s |
| 06:00 migration transition | 506–516 ms |

### Frozen three-run sample (2026-09-06)

| Run | Scenario time | Maximum hour | Migration maximum | State hash |
|---:|---:|---:|---:|---|
| 1 | 47.422841 s | 505.230 ms | 505.230 ms | `97f9a572…f83b` |
| 2 | 46.924563 s | 479.610 ms | 479.610 ms | `97f9a572…f83b` |
| 3 | 46.626088 s | 501.692 ms | 501.692 ms | `97f9a572…f83b` |

Outer suite time was 144.23 s. The older 009 runner expected hash
`4440de04…2942`; all three runs therefore reported `state_hash_changed`. That
drift belongs to the pre-existing dirty worktree and is frozen here, not treated
as a transactional-performance regression.

## Frozen test baseline

The complete GUT suite with writable `user://` passed 116 scripts, 566 tests,
and 3,751 assertions in 85.087 s. A sandboxed diagnostic invocation failed 16
tests because it could not create `user://` fixtures or save files; rerunning
the same command with normal `user://` access passed all tests. This is recorded
as an environment-only pre-existing failure mode.

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

These values were gathered from the active development worktree. Raw headless
records are in `baseline-before.json`; the rendered observation remains the
planning capture above until the reproducible rendered runner is introduced.
