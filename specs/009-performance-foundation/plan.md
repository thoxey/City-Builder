# Implementation Plan: Performance and Regression Foundation

**Branch**: `codex/009-performance-foundation` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/009-performance-foundation/spec.md`

## Summary

Remove the 06:00 freeze without changing authoritative outcomes by hoisting migration-invariant source construction out of the candidate loop, caching deterministic routes for each road-network revision, and replacing hourly full diagnostic snapshots with lightweight aggregate calculations. Extend the shared Playtest/DayNight seams with opt-in snapshot modes and non-authoritative timings, then verify the same realistic rooted-town scenario repeatedly alongside targeted simulation and core-HUD tests.

## Technical Context

**Language/Version**: GDScript 4.x on Godot 4.6.2; JSON scenario/configuration files

**Primary Dependencies**: Godot autoload plugins, GUT 9.3.0, shared Builder/Playtest command boundary

**Storage**: Existing JSON building/scenario data and Godot save-state dictionaries; Markdown/JSON validation evidence

**Testing**: GUT unit/integration tests, headless Godot scenario runners, deterministic state hashes

**Target Platform**: Desktop Godot game; macOS reference development machine for benchmark evidence

**Project Type**: Godot desktop game with plugin-oriented simulation

**Performance Goals**: Existing 240-hour realistic run under 45 seconds; worst hourly transition under 500 ms; no 06:00 multi-second stall

**Constraints**: Preserve gameplay outputs, saves and hashes; do not bypass construction rules; performance diagnostics remain non-authoritative; no side-panel UI work

**Scale/Scope**: 145-resident/135-building reference town, 240 simulated hours, 60 meaningful placements, 20 daily candidates, at least three complete playthroughs

## Constitution Check

*GATE: Passed before research and re-checked after design.*

- **One Gameplay Truth — PASS**: All scenario actions continue through Builder, DayNight and Playtest. Route caching memoizes the canonical resolver and never creates an alternate path rule.
- **Deterministic Simulation — PASS**: Cache keys depend only on stable building IDs and topology revision. Timings are excluded from snapshots, saves and hashes. Sorted traversal and deterministic tie-breaking are retained.
- **Observable State — PASS**: The Playtest contract gains opt-in timing output and explicit snapshot detail. Full diagnostic snapshots remain available on demand.
- **Data-Driven Balance — PASS**: Candidate count, migration hour, thresholds and programme data remain in current balance/configuration files. No tuning values move into logic.
- **Small Interfaces, Layered Verification — PASS**: Changes are narrow additions to existing plugin seams. Unit tests cover cache/batching/contracts, integration tests cover UI and simulation, and the full scenario supplies end-to-end evidence.
- **Post-design re-check — PASS**: No new manager, state authority, persistence domain or simulation clock is introduced.

## Project Structure

### Documentation (this feature)

```text
specs/009-performance-foundation/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
├── contracts/
│   ├── playtest-performance.md
│   └── route-cache.md
└── validation/
    ├── baseline-before.md
    ├── benchmark-after.md
    ├── playthrough-report.json
    └── test-results.md
```

### Source Code (repository root)

```text
plugins/
├── community/community_plugin.gd       # migration/source and summary work
├── day_night/day_night_plugin.gd       # optional per-hour timing
├── playtest/playtest_plugin.gd         # snapshot modes/action timing
└── traffic/road_network_plugin.gd      # revision-scoped route cache

scripts/
├── run_town_rebalance.gd               # canonical legal full-town workload
└── run_performance_playthroughs.gd      # repeated profiled validation

test/
├── unit/
│   ├── community/                      # migration batching/summary
│   ├── day_night/                      # timing contract
│   ├── player_ui/                      # radial/top/bottom only
│   ├── playtest/                       # snapshot/performance contract
│   └── traffic/                        # cache hit/invalidation/copy safety
└── integration/
    ├── civilian_simulation/
    └── player_ui/                      # no side-panel additions
```

**Structure Decision**: Extend the existing Godot plugin and GUT layout. The optimized code remains beside its authoritative behavior and validation runners remain under `scripts/`.

## Execution Design

1. Add failing contract tests for route reuse/invalidation, migration source reuse, Playtest snapshot modes, DayNight timing, and the three approved HUD surfaces.
2. Cache route and anchor lookups by road revision, returning deep detached copies and clearing all cache state during rebuild.
3. Construct the daily source catalogue once per migration batch and calculate hourly summary averages directly.
4. Add optional per-hour timing to DayNight and opt-in snapshot modes/action timings to Playtest, preserving full snapshots by default.
5. Adapt the canonical town runner to low-overhead actions and add a three-run performance report with deterministic checkpoints.
6. Run focused suites, full GUT, repeated playthroughs and before/after benchmark; record evidence and commit all feature work.

## Complexity Tracking

No constitution violations require exceptions.
