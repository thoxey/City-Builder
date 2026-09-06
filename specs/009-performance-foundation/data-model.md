# Data Model: Performance and Regression Foundation

All records in this feature are runtime diagnostics or derived caches. None is persisted as authoritative gameplay state.

## TickTimingSample

| Field | Type | Rules |
|---|---|---|
| `absolute_hour` | integer | Monotonically increasing simulated hour after the tick |
| `day` | integer | Derived from the authoritative clock |
| `hour` | integer | `0..23` |
| `elapsed_usec` | integer | Non-negative wall-clock diagnostic |
| `migration_boundary` | boolean | True when `hour` equals configured migration hour |

Samples are ordered exactly as hours are emitted. They are never included in `get_state`, save payloads or deterministic hashes.

## AdvancePerformance

| Field | Type | Rules |
|---|---|---|
| `total_usec` | integer | Duration for the complete advance command |
| `max_hour_usec` | integer | Maximum sample duration, or zero for no hours |
| `hour_timings` | array of TickTimingSample | One entry per advanced hour |

## ActionPerformance

| Field | Type | Rules |
|---|---|---|
| `command_usec` | integer | Shared gameplay-command execution only |
| `snapshot_usec` | integer | Requested post-action projection only |
| `total_usec` | integer | Full Playtest action duration |
| `snapshot_mode` | enum | `full`, `compact`, `none` |

This record is returned only for explicitly profiled actions.

## RouteCacheEntry

| Field | Type | Rules |
|---|---|---|
| cache key | string | Stable origin/destination building IDs scoped to current revision |
| route | dictionary | Canonical route result, including failure results |
| revision | integer | Implicit cache lifetime; all entries clear when revision changes |

Stored and returned dictionaries/arrays are deeply duplicated at the boundary. Diagnostic hit/miss counters reset on rebuild and do not affect gameplay.

## PerformancePlaythroughReport

| Field | Type | Rules |
|---|---|---|
| `schema_version` | integer | Starts at 1 |
| `runs` | array | At least three complete scenario reports |
| `total_elapsed_usec` | integer | Outer runner duration |
| `all_passed` | boolean | True only when every rule, action and threshold passes |

Each run records seed, successful/failed action counts, role coverage, meaningful building count, residents, total buildings, state hash, total scenario time, worst hour and worst migration hour.

## State transitions

```text
road topology mutation -> _rebuild -> revision++ -> route/anchor caches empty
unchanged route query -> miss -> canonical resolve -> stored detached entry
equivalent route query -> hit -> returned detached copy

advance action -> command timing -> optional snapshot timing -> optional diagnostics
daily migration -> build sources/effect order[24] once -> quote N candidates -> accept/reject unchanged
```
