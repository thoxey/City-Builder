# Feature Specification: Performance and Regression Foundation

**Feature Branch**: `codex/009-performance-foundation`

**Created**: 2026-09-06

**Status**: Approved for implementation

**Input**: Eliminate simulation stalls, strengthen AI playtesting and establish broad regression coverage before quests and progression are added. UI coverage is limited to the radial menu, top status bar and bottom tool bar.

## User Scenarios & Testing

### User Story 1 - Smooth Daily Simulation Boundary (Priority: P1)

As a player with a developed, road-connected town, I can cross the 06:00 daily migration boundary without the game visibly freezing or changing simulation results.

**Why this priority**: The current synchronous 06:00 work can block the whole game for tens of seconds, making the core loop feel broken.

**Independent Test**: Build the established 60-building rooted-town scenario through gameplay commands, advance through at least ten daily boundaries, and inspect per-hour timing and the final deterministic state.

**Acceptance Scenarios**:

1. **Given** a town with a Town Hall, rooted roads, residents, homes, workplaces, shops, civic venues and nature, **When** time crosses 06:00, **Then** daily migration completes without a multi-second stall.
2. **Given** the same scenario and seed before and after optimization, **When** the scenario completes, **Then** the authoritative state hash and gameplay outcomes are unchanged.
3. **Given** a road network used repeatedly during candidate evaluation, **When** no placement, demolition, load or clear invalidates the network, **Then** equivalent route requests reuse a detached cached result.

---

### User Story 2 - Fast, Observable AI Playtesting (Priority: P2)

As a developer or testing agent, I can run legal, varied city playthroughs without paying for a full world snapshot after every command, while still requesting deterministic checkpoints and per-hour performance evidence.

**Why this priority**: The current harness performs expensive diagnostics after every action and has no timing view, hiding the source of stalls and making long playthroughs unnecessarily slow.

**Independent Test**: Run a command sequence using each supported snapshot mode, request a profiled multi-hour advance, and verify the response contract, action trace and deterministic checkpoint hashes.

**Acceptance Scenarios**:

1. **Given** an active playtest session, **When** an action requests `none`, `compact` or `full` snapshot mode, **Then** the response contains exactly the requested snapshot detail without altering gameplay behavior.
2. **Given** a profiled advance, **When** multiple hours elapse, **Then** the result reports total and maximum tick duration plus ordered per-hour samples, separately from snapshot cost.
3. **Given** three complete rule-compliant playthroughs, **When** the agent places a wide variety of buildings, **Then** every meaningful building follows Town Hall, road-rooting and road-access rules and every run finishes without action failure.

---

### User Story 3 - Simulation Regression Safety Net (Priority: P3)

As a developer preparing to add quests and progression, I can change the game with confidence because deterministic unit, integration, contract and full-town tests detect simulation drift and performance regressions.

**Why this priority**: New progression systems will exercise existing gameplay seams; durable tests must protect the current source of truth first.

**Independent Test**: Run the focused and full automated suites, deterministic replay, civilian day scenarios, and performance playthrough gate from a clean checkout.

**Acceptance Scenarios**:

1. **Given** repeated route, migration and snapshot operations, **When** their inputs are unchanged, **Then** tests prove stable detached outputs and bounded repeated work.
2. **Given** a changed building or road topology, **When** the next route is requested, **Then** stale cached routes are never returned.
3. **Given** the full automated test suite, **When** it completes, **Then** existing construction, economy, community, civilian and playtest behaviors still pass.

---

### User Story 4 - Stable Core HUD Controls (Priority: P4)

As a player, I can continue building while the simulation grows because the radial menu, top status bar and bottom tool bar keep their interaction and update contracts.

**Why this priority**: These are the core build-loop controls that future progression will update or gate. Side-panel behavior is intentionally excluded.

**Independent Test**: Run isolated unit and integration tests covering radial selection/navigation, top-bar value updates and bottom-bar tool-mode behavior without instantiating or asserting on side panels.

**Acceptance Scenarios**:

1. **Given** the radial menu is opened and navigated, **When** choices change availability, **Then** focus, rejection and selection behavior remain deterministic.
2. **Given** game-state values change, **When** the top bar refreshes, **Then** it displays the new canonical values without rebuilding unrelated UI.
3. **Given** build, demolition and cancel actions, **When** the bottom bar changes modes, **Then** it exposes exactly one canonical active mode and signal sequence.

### Edge Cases

- A town with every housing slot occupied must skip candidate work but still emit a correct hourly summary.
- A candidate batch with many free homes and many service sources must reuse the same 24-hour source catalogue.
- Missing road access, disconnected components and zero-length same-stop routes must remain distinct outcomes.
- Cached route arrays and dictionaries returned to callers must be detached from cache storage.
- Network revision changes caused by place, demolish, replace, map load or clear must invalidate every affected cache entry.
- Unknown snapshot modes must be rejected predictably and duplicate request IDs must remain idempotent.
- Performance diagnostics must never enter the authoritative state hash or saved gameplay state.
- Empty top-bar values and unavailable radial or tool actions must retain their current fallback behavior.

## Requirements

### Functional Requirements

- **FR-001**: The daily migration process MUST construct invariant per-hour service-source data no more than once per migration batch.
- **FR-002**: The road network MUST reuse deterministic building-to-building routes while its topology revision is unchanged.
- **FR-003**: Every topology rebuild MUST invalidate route and building-anchor lookup caches before new queries can observe them.
- **FR-004**: Cached results returned across plugin boundaries MUST be detached copies so callers cannot mutate shared state.
- **FR-005**: Hourly community summary emission MUST avoid constructing resident-level and spatial diagnostic snapshots.
- **FR-006**: The Playtest action contract MUST support `full`, `compact` and `none` snapshot modes, defaulting to the existing full response for compatibility.
- **FR-007**: Time advancement MUST optionally report ordered, non-authoritative per-hour timings including total and maximum tick duration.
- **FR-008**: Playtest performance measurements MUST separate gameplay-command duration from snapshot-generation duration.
- **FR-009**: The performance scenario MUST use the shared Builder and Playtest gameplay commands and MUST NOT bypass construction rules.
- **FR-010**: The performance scenario MUST place the Town Hall first, extend roads from its rooted component, connect every non-cosmetic building to that road system, and exercise homes, workplaces, shops, civic venues and nature.
- **FR-011**: Automated evidence MUST include at least three completed full-town playthroughs and deterministic replay checks.
- **FR-012**: Regression tests MUST cover migration batching, route cache hit/invalidation/copy safety, snapshot modes and timing contracts.
- **FR-013**: UI tests MUST cover only the radial menu, top status bar and bottom tool bar; this feature MUST NOT alter or add side-panel tests.
- **FR-014**: Existing authoritative save, state-hash, balance and construction outcomes MUST remain compatible.
- **FR-015**: Before/after evidence MUST record the same scenario, seed, building variety, final state hash, total runtime and worst hourly boundary.

### Key Entities

- **Tick Timing Sample**: A diagnostic record of absolute hour, day, clock hour and elapsed microseconds for one authoritative hourly transition.
- **Action Performance Record**: Non-authoritative command, snapshot and total durations associated with one Playtest request.
- **Route Cache Entry**: A detached deterministic route result keyed by origin, destination and the current road-network revision.
- **Performance Playthrough Report**: One or more rule-compliant scenario runs containing construction coverage, action failures, hashes and timing aggregates.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The established 240-hour, 60-meaningful-building rooted-town playthrough completes in under 45 seconds on the reference development machine, compared with the recorded 132.75-second baseline.
- **SC-002**: No profiled hourly transition in the reference scenario takes longer than 500 milliseconds, eliminating the observed 30-second-plus 06:00 stall.
- **SC-003**: Three consecutive complete performance playthroughs finish with zero rejected construction actions and cover at least five building roles including road and civic construction.
- **SC-004**: Replaying the baseline scenario with seed 6066 preserves the final authoritative hash unless a separately documented intentional gameplay correction is discovered.
- **SC-005**: Focused route, migration, Playtest, civilian and core-HUD tests pass, followed by the complete automated Godot test suite.
- **SC-006**: Repeated unchanged route queries produce cache hits, while every tested topology mutation produces a miss and a newly resolved result.
- **SC-007**: AI actions using `none` mode contain no snapshot payload and are measurably cheaper than equivalent full-snapshot actions in the scenario report.

## Assumptions

- Godot 4.6.2 on the current development machine is the reference environment for recorded timing evidence; behavioral tests remain portable.
- The existing first-town rebalance scenario is the canonical realistic workload and already encodes the construction rules.
- Performance records are diagnostics only and are excluded from saves and deterministic state hashes.
- This work optimizes existing behavior; new quests, progression rules, balance changes, side panels and visual redesign are out of scope.
- Wall-clock thresholds belong to the scenario validation gate rather than fragile per-commit unit assertions where possible.
