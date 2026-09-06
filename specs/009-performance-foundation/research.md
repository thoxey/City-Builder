# Research: Performance and Regression Foundation

## Baseline workload

The existing `first_town/rebalance` scenario is the correct representative workload. It starts a Playtest session, proves pre-Town-Hall rejection, places the single protected Town Hall, grows 75 road cells from the rooted network, places 60 meaningful road-accessible buildings across residential, industrial, commercial, civic and nature roles, and advances 240 hours. The baseline completed successfully with 145 residents and 135 total buildings.

Measured on Godot 4.6.2 using seed 6066:

- total wall time: 132.75 seconds
- final authoritative hash: `4440de04356f95a80c7219dba3718825de1cc1b258adae28a61b7cf735fb2942`
- observed symptom: more than 30 seconds without progress immediately after an intermediate 06:00 tick

## Decision 1: Cache canonical road routes by topology revision

**Decision**: Memoize `get_route_between_buildings(origin, destination)` and building-anchor ID lookup until `_rebuild()` advances the road revision.

**Rationale**: Daily migration evaluates the same home/source pairs across candidates and hours. The current resolver repeatedly scans/sorts buildings and runs breadth-first search despite unchanged topology.

**Alternatives considered**:

- A global all-pairs route table was rejected because it eagerly computes unused pairs and has larger memory/rebuild cost.
- A Community-owned route cache was rejected because People and other route consumers would duplicate logic and invalidation.
- Approximate Manhattan distance was rejected because it would create a second, incorrect gameplay truth.

## Decision 2: Hoist candidate-invariant daily sources

**Decision**: Build the 24 hourly source arrays once in `_run_daily_migration()` and pass them into each candidate quote.

**Rationale**: Sources and road topology do not change while a single candidate batch is evaluated. Rebuilding them 20 times multiplies registry scans, sorting and routing without changing results.

**Alternatives considered**:

- Spreading candidates across frames could mask the stall but changes when migration results become visible and complicates save/replay semantics.
- Reducing the data-driven batch size changes balance and leaves the underlying repeated-work defect.

## Decision 3: Separate gameplay work from diagnostics

**Decision**: Add explicit `full`, `compact` and `none` Playtest snapshot modes and report command/snapshot timings independently. Preserve `full` as the default.

**Rationale**: AI scenario runners need frequent semantic actions but only occasional checkpoints. Full resident, spatial, UI and hash projections after every road placement make the harness dominate the measured workload.

**Alternatives considered**:

- Removing snapshots from action responses would break existing callers.
- Adding a parallel batch API would enlarge the public surface while still needing observability controls.

## Decision 4: Time authoritative hours at the clock boundary

**Decision**: `DayNight.advance_hours()` accepts an opt-in profiling flag and records elapsed microseconds around each `hour_changed` emission.

**Rationale**: All synchronous plugin work triggered by an hour is included, so the timing directly measures the player-visible pause and identifies 06:00 boundaries.

**Alternatives considered**:

- Timing only Community would miss CityStats, People and other listeners.
- External wall time cannot identify individual hour spikes or separate snapshot overhead.

## Decision 5: Keep wall-clock gates out of ordinary unit tests

**Decision**: Unit tests assert bounded repeated calls and correct diagnostic shape; the reference scenario owns the 45-second/500-millisecond thresholds.

**Rationale**: Absolute microbenchmarks are noisy across CI hardware, while the headless representative workload is suitable for recorded release evidence.

## Decision 6: Target only the core HUD surfaces

**Decision**: Add/strengthen tests for radial navigation/availability, top status updates and bottom tool modes. Do not change dashboard, community drawer or side-panel tests.

**Rationale**: This matches the requested stabilization boundary and avoids coupling performance work to the next UI feature area.

## Decision 7: Preserve detailed evaluation while adding a score-only projection

**Decision**: Keep the existing detailed Community effect evaluation for public diagnostics, but let migration use an exact totals-only projection with effect ordering prepared once per authored hour and participant benefits calculated once per candidate/source/hour.

**Rationale**: Migration consumes only target qualities and composite score. Constructing full exposure dictionaries, repeatedly sorting the same effects and recalculating home-independent participant preferences produced avoidable allocation and comparison work. Unit tests prove that full, totals-only and prepared totals produce identical quality totals.

**Alternatives considered**:

- Removing detailed quote effects was rejected because public diagnostic callers rely on them.
- Approximating or reordering stacking was rejected because it could change candidate acceptance, tie-breaking and deterministic hashes.
