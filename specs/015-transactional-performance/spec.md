# Feature Specification: Transactional Performance Architecture

**Feature Branch**: `015-transactional-performance`

**Created**: 2026-09-06

**Status**: Planning complete; implementation not started

**Input**: Replace synchronous simulation and presentation fan-out with modular, deterministic transaction boundaries; retain independent contribution records; apply dirty invalidation broadly; optimize traffic ordering and migration reuse; and establish performance budgets without coupling plugins or UI modules.

## Context

Profiling of the 135-building reference town found visible stalls in synchronous hourly signal fan-out, the 06:00 migration boundary, placement cascades, and diagnostic-heavy UI refreshes. The existing performance foundation reduced earlier pathological costs and supplies the canonical playthrough and timing evidence. This feature defines the architectural boundary needed for the next order of scale while preserving gameplay truth, deterministic replay, modular plugins, and independently owned UI.

## Clarifications

### Session 2026-09-06

- Q: How must hourly work preserve plugin independence? → A: Contributors submit independent intents through inversion of control; one coordinator validates and commits them without contributors knowing one another.
- Q: What record must survive an hourly commit? → A: Every submitted intent and its outcome remains independently identifiable in an ordered, queryable transaction ledger.
- Q: How must simultaneous UI updates preserve modularity? → A: Presenters subscribe independently to invalidation domains and are flushed together without direct presenter-to-presenter knowledge.

## User Scenarios & Testing

### User Story 1 - Atomic, Explainable Hourly Simulation (Priority: P1)

As a player, I can advance time in a developed town without inconsistent intermediate state, while developers can explain exactly which independent contributions produced each hourly result.

**Why this priority**: The hourly boundary is the authoritative simulation spine. Establishing one deterministic commit removes order-by-signal side effects and provides the stable seam required by every later optimization.

**Independent Test**: Run a fixed-seed town through repeated hourly advances with multiple registered contributors, compare final hashes across runs and registration orders, and inspect the ledger for every accepted or rejected contribution.

**Acceptance Scenarios**:

1. **Given** multiple building and system contributors, **When** an hour advances, **Then** each submits an independently identified intent against the same immutable pre-hour snapshot and one atomic commit publishes the resulting authoritative change set.
2. **Given** the same seed and gameplay state, **When** contributors register in different incidental orders, **Then** the committed state, ledger ordering, and final state hash remain identical.
3. **Given** any invalid or conflicting intent, **When** the hourly transaction is validated, **Then** the entire transaction is rejected, authoritative state remains at the pre-hour version, and the ledger identifies the cause and contributor.
4. **Given** a successful commit, **When** downstream systems are notified, **Then** they observe only the completed post-hour state and its single change set.

---

### User Story 2 - Coordinated, Decoupled Presentation (Priority: P2)

As a player, I see all visible interface regions update coherently after gameplay changes without repeated rebuilding, while each interface module remains independently owned.

**Why this priority**: Profiling shows that diagnostic snapshot and dashboard rebuilding can consume far more than a frame. A shared invalidation vocabulary and one presentation boundary remove duplicate work without introducing UI coupling.

**Independent Test**: Register independent fake presenters for different domains, publish several changes in one frame, and show that each relevant visible presenter runs at most once, irrelevant presenters do not run, and hidden presenters catch up when shown.

**Acceptance Scenarios**:

1. **Given** several authoritative changes before the next presentation boundary, **When** invalidations are published, **Then** each affected visible presenter refreshes no more than once using the latest committed state.
2. **Given** unrelated UI modules, **When** the same change affects both, **Then** both may present in the same flush without calling or referencing one another.
3. **Given** a hidden presenter becomes dirty, **When** presentation flushes occur while it remains hidden, **Then** its expensive projection is deferred and its dirty state is retained.
4. **Given** a previously hidden dirty presenter becomes visible, **When** the next presentation boundary occurs, **Then** it catches up from the latest authoritative version without replaying every intermediate update.

---

### User Story 3 - Bounded Operational Queries and Placement (Priority: P3)

As a player, I can place, replace, or demolish buildings in a developed town without a noticeable pause, and routine UI reads do not construct resident-level or whole-city diagnostics.

**Why this priority**: Placement currently triggers broad synchronous cascades, while several normal UI paths request full projections. Separating operational views from diagnostics and updating indexes incrementally addresses both sources without changing construction rules.

**Independent Test**: In the 135-building reference town, perform representative place, replace, and demolish actions while timing commands and counting projection/index work; compare authoritative outcomes with the existing behavior.

**Acceptance Scenarios**:

1. **Given** an operational UI surface, **When** it requests current information, **Then** it receives only the explicitly contracted aggregate projection and does not construct resident, spatial, or replay diagnostics.
2. **Given** a building mutation, **When** it commits, **Then** only indexes and projections affected by the recorded change set are invalidated or incrementally updated.
3. **Given** a placement that fails validation, **When** the command completes, **Then** no authoritative or derived index is partially mutated.
4. **Given** an explicit diagnostic request, **When** a full projection is generated, **Then** it remains available, labelled as diagnostic, detached from authoritative state, and separately timed.

---

### User Story 4 - Scalable Migration, People, and Traffic (Priority: P4)

As a player, I can grow a busy town without daily migration or visible agents producing periodic freezes, unfair traffic admission, or different simulation outcomes.

**Why this priority**: Migration has the largest measured hourly spike, and per-frame people and traffic loops are the principal scale risks. These optimizations should build on the new transaction and invalidation seams rather than create alternate authorities.

**Independent Test**: Exercise the reference migration batch, 512 civilians, 256 vehicle slots, and congested admission queues under fixed seeds; compare hashes, decisions, ordering, and timing distributions across repeated runs.

**Acceptance Scenarios**:

1. **Given** a migration batch, **When** candidates are evaluated against unchanged city facts, **Then** all candidates reuse one immutable batch context while candidate-specific decisions remain independent and auditable.
2. **Given** cached migration facts become invalid, **When** a relevant authoritative change commits, **Then** only affected facts are recomputed before the next decision.
3. **Given** many pending journeys, **When** admission is evaluated repeatedly, **Then** stable queues preserve deterministic fairness without repeatedly sorting or copying the complete pending population.
4. **Given** many civilians or cars, **When** a frame is processed, **Then** inactive, unchanged, or off-screen presentation work is skipped without changing authoritative schedules, routes, reservations, or outcomes.

---

### User Story 5 - Enforced Performance Budgets (Priority: P5)

As a developer, I can detect regressions at the correct boundary because simulation, presentation, diagnostic, entity-loop, placement, and rendering costs are measured separately against reproducible budgets.

**Why this priority**: Optimization without durable boundary-specific evidence will regress. Budgets also prevent expensive diagnostics from being misattributed to core simulation.

**Independent Test**: Run the canonical headless playthrough and rendered-town profile three times on the reference machine, produce percentile and worst-case evidence per boundary, and exercise a deliberately exceeded budget to prove the gate identifies the responsible category.

**Acceptance Scenarios**:

1. **Given** a profiled run, **When** evidence is produced, **Then** it reports simulation collection, validation, commit, projection, presentation, diagnostic, placement, entity-loop, and rendering costs separately.
2. **Given** three equivalent runs, **When** results are compared, **Then** the report includes median, 95th percentile, maximum, workload identity, seed, engine version, and authoritative hashes.
3. **Given** a budget breach, **When** the gate reports failure, **Then** it identifies the breached boundary and preserves the evidence needed to reproduce it.

### Edge Cases

- A tick with no submitted intents still advances time once, produces an empty committed change set, and does not dirty unrelated presenters.
- Duplicate contributor or intent identifiers are rejected deterministically before commit.
- A contributor that disappears between hours leaves no stale registration or queued intent.
- Intents that target the same value declare compatible combination semantics; undeclared conflicts reject the transaction.
- Re-entrant authoritative mutation during collection, validation, commit, or notification is rejected and reported.
- Save or map load during pending work clears transient transactions, queues, invalidations, and caches before the loaded state becomes observable.
- A presenter invalidated again while flushing remains dirty for a subsequent boundary rather than recursively refreshing.
- Hidden UI that is never shown does not accumulate unbounded historical change sets.
- Diagnostic projections cannot mutate cached operational projections or authoritative records.
- Migration caches distinguish facts invalidated by topology, building programme, occupancy, schedule, balance, and time.
- Journey cancellation or topology revision cannot leave stale admission entries, tile claims, or render slots.
- Performance measurements and debug traces never enter saves, balance decisions, replay hashes, or release-mode hot paths.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST provide one authoritative transaction boundary for each elapsed simulation hour.
- **FR-002**: Each simulation contributor MUST register and submit intents through a stable inversion-of-control contract without referencing other contributors.
- **FR-003**: Every contributor MUST read the same immutable pre-hour state version while producing intents.
- **FR-004**: Every intent MUST include a stable unique identifier, contributor identifier, target domain, operation, payload, and deterministic ordering key.
- **FR-005**: The coordinator MUST validate all intents before any authoritative mutation occurs.
- **FR-006**: Validation or conflict failure MUST reject the complete hourly transaction, preserve pre-hour authoritative state, and publish a structured failure record.
- **FR-007**: A successful hourly transaction MUST apply its validated changes atomically and publish exactly one immutable change set after commit.
- **FR-008**: The transaction ledger MUST retain each submitted intent, its disposition, reason, order, pre-state version, and resulting commit version independently of aggregate totals.
- **FR-009**: Ledger, contributor, and conflict ordering MUST be deterministic and independent of incidental registration, scene-tree, dictionary, or signal connection order.
- **FR-010**: Authoritative gameplay consumers MUST observe only pre-commit or post-commit state, never a partially applied hour.
- **FR-011**: Existing save data, construction rules, balance outcomes, and deterministic replay semantics MUST remain compatible unless a separately approved gameplay change documents otherwise.
- **FR-012**: The system MUST define a finite shared vocabulary of invalidation domains derived from committed change sets.
- **FR-013**: Each presenter MUST independently declare the invalidation domains it consumes and MUST NOT reference other presenters.
- **FR-014**: Multiple invalidations before a presentation boundary MUST coalesce so each affected visible presenter refreshes at most once per boundary.
- **FR-015**: A presenter MUST read a consistent committed state version for the duration of one refresh.
- **FR-016**: Hidden presenters MUST defer expensive work, retain only the latest dirty state, and catch up from the latest committed version when visible.
- **FR-017**: Invalidations raised during a flush MUST be scheduled for a later boundary and MUST NOT trigger recursive presentation.
- **FR-018**: Operational projections MUST be explicitly separated from full diagnostic projections and MUST include only data required by their named consumers.
- **FR-019**: Diagnostic projections MUST remain opt-in, detached, non-authoritative, and separately measurable.
- **FR-020**: Building place, replace, demolish, map load, and clear operations MUST update or invalidate only affected derived indexes and projections according to their committed change sets.
- **FR-021**: Failed building mutations MUST leave authoritative state and derived indexes at the same version.
- **FR-022**: Migration evaluation MUST reuse immutable batch facts across candidates and expose invalidation dependencies for every cached fact.
- **FR-023**: Candidate-specific migration decisions MUST remain independently attributable and deterministic.
- **FR-024**: Traffic admission MUST maintain deterministic fair ordering without complete pending-queue sorting or copying on every admission pass.
- **FR-025**: People and traffic presentation loops MUST skip work proven irrelevant to the current frame without altering authoritative simulation outcomes.
- **FR-026**: Performance instrumentation MUST attribute elapsed time and workload size to collection, validation, commit, notification, operational projection, diagnostic projection, presentation, placement, migration, people, traffic, and rendering boundaries.
- **FR-027**: Performance evidence MUST record engine version, reference-machine identity, build mode, seed, town/state identity, entity counts, run count, percentiles, maxima, and authoritative hashes.
- **FR-028**: Performance data, transaction diagnostics, and presentation diagnostics MUST NOT affect saved gameplay state or deterministic hashes.
- **FR-029**: Debug logging in hourly, per-frame, placement, and presentation hot paths MUST be disabled or aggregated by default and MUST be explicitly opt-in.
- **FR-030**: Each delivery story MUST preserve a compatibility adapter until all existing consumers have moved to the new contract and parity evidence passes.

### Key Entities

- **State Version**: A monotonically increasing identifier for an authoritative committed state.
- **Hour Context**: Immutable pre-hour facts shared by contributors, including clock, seed context, state version, and bounded read projections.
- **Simulation Contributor**: Independently registered owner that produces zero or more intents for an hour.
- **Simulation Intent**: Immutable proposed mutation with stable identity, target domain, operation, payload, and deterministic order.
- **Hourly Transaction**: Collection of intents evaluated against one pre-state version and resolved to committed or rejected exactly once.
- **Intent Ledger Entry**: Independent audit record connecting an intent to its validation and commit disposition.
- **Change Set**: Immutable post-commit description of changed domains, entity identities, before/after versions, and aggregate deltas.
- **Invalidation Domain**: Canonical label mapping authoritative changes to dependent projections or presenters.
- **Presenter Registration**: Independent declaration of consumed domains, visibility, last-presented version, and refresh callback.
- **Operational Projection**: Bounded derived view for a named runtime consumer.
- **Diagnostic Projection**: Explicit, potentially expensive detached view used for inspection or testing.
- **Performance Sample**: Non-authoritative timing and workload record attached to one named boundary.
- **Performance Budget**: Boundary, workload, statistic, threshold, environment, and enforcement level.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Fixed-seed replay produces identical authoritative hashes and ledger ordering across at least three runs and across reversed contributor registration order.
- **SC-002**: Every tested hourly failure leaves the authoritative version and state hash unchanged and identifies the rejected contributor, intent, and reason.
- **SC-003**: In one frame containing any number of same-domain changes, each affected visible presenter refreshes no more than once; unrelated and hidden presenters perform zero projection work.
- **SC-004**: The 135-building, 240-hour canonical headless playthrough completes within 35 seconds on the reference machine in each of three runs, improving on the measured 47.25–47.87-second baseline.
- **SC-005**: In that playthrough, hourly authoritative transaction time is at most 16.7 ms at the 95th percentile and 33.3 ms maximum, including the 06:00 migration boundary, improving on the measured 506–516 ms boundary.
- **SC-006**: Representative place, replace, and demolish commands in the 135-building town complete within 16.7 ms median, 33.3 ms at the 95th percentile, and 50 ms maximum, improving on the measured 54 ms mean and 187 ms 95th percentile placement cost.
- **SC-007**: Routine dashboard and community presentation projections each complete within 4 ms median and 8 ms at the 95th percentile without constructing full diagnostics; explicit full diagnostics are measured separately and never run implicitly.
- **SC-008**: A reference load of 512 civilians and up to 256 vehicle slots spends no more than 8 ms at the 95th percentile on combined per-frame people and traffic processing, excluding rendering submission.
- **SC-009**: The rendered reference town sustains at least 60 observed frames per second at the median, with process time at most 16.7 ms median, 25 ms at the 95th percentile, and 50 ms maximum outside loading or explicit diagnostic capture.
- **SC-010**: All transaction, invalidation, cache, ordering, parity, deterministic replay, focused performance, full automated Godot, and canonical full-city scenario gates pass before removal of compatibility adapters.
- **SC-011**: Profiling evidence attributes at least 95% of measured main-thread frame time to named boundaries or an explicit engine/unattributed category.

## Assumptions

- Godot 4.6.2 on the current macOS development machine is the reference environment for wall-clock gates; deterministic and contract checks remain portable.
- The workload introduced by `009-performance-foundation` remains the canonical headless comparison, extended to the current 135-building reference state where required.
- One hourly transaction is synchronous and atomic; this feature does not introduce background mutation, coroutines, or an alternate simulation clock.
- Intent collection may be batched by building type or plugin so modular ownership does not require one scene-tree node, signal connection, or allocation per building.
- The ledger retains detailed entries for the current profiling/test horizon; save-file retention and player-facing history are outside this feature unless separately specified.
- Rendering optimization may include visibility policy, instancing, update frequency, and presentation level of detail, but visual redesign and new art are out of scope.
- Balance tuning, new gameplay rules, worker-thread simulation, ECS replacement, and engine-version upgrades are out of scope.
- This specification is one epic delivered as independently testable stories; implementation may land story by story only after the complete planning gate is approved.
