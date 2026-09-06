# Research: Transactional Performance Architecture

## Decision 1: Use a synchronous deterministic transaction, not asynchronous gameplay mutation

**Decision**: Keep hourly gameplay work on the main thread behind one bounded transaction. Optimize what is computed, how often it is computed, and when presentation occurs.

**Rationale**: Godot signals are synchronous, and current authoritative state is scene/plugin owned. Awaitable task libraries would move stalls rather than remove duplicate work, complicate deterministic ordering, and expose partially advanced state. Background workers remain suitable only for detached, version-checked pure calculations in a future feature.

**Alternatives considered**: Coroutines/await for each plugin; worker-thread mutation; an ECS/job-system replacement. Rejected because they expand scope and create new authority/concurrency hazards before the work graph is made efficient.

## Decision 2: Register plugin-owned batched contributors

**Decision**: Each domain plugin registers a stable contributor contract. It may batch contributions for all buildings of the programme it owns, while every emitted intent retains the originating building/entity identity.

**Rationale**: This preserves inversion of control and independent audit records without creating one Node, callback, allocation, or signal connection per building.

**Alternatives considered**: One contributor object per building; a coordinator that loops through and understands every building type. The first adds avoidable dispatch/allocation cost; the second couples orchestration to domains.

## Decision 3: Use immutable pre-hour context plus declarative reducers

**Decision**: Contributors read one immutable HourContext and emit facts/proposals. Registered reducers validate and combine compatible intents, derive dependent allocations, and construct the commit plan.

**Rationale**: Economy currently relies on CityStats having already run through signal connection order. Declarative resource intents let a reducer compute supply, demand, fulfillment, satisfaction, and economic deltas without contributor-to-contributor calls or a one-hour lag.

**Alternatives considered**: Explicit sequential plugin phases; preserving signal ordering; letting contributors query peers during collection. Explicit phases still encode domain coupling in orchestration, while the latter choices keep hidden ordering.

## Decision 4: Make ordering semantic and stable

**Decision**: Sort by phase/reducer domain, target key, declared priority, contributor ID, entity ID, and intent ID. Registration order, dictionary order, scene-tree order, and signal connection order never break ties.

**Rationale**: Stable ordering is required for deterministic replay and fair allocation.

**Alternatives considered**: Registration order or creation sequence. Both are incidental and change during plugin migration or save loading.

## Decision 5: Reject invalid hourly transactions before mutation

**Decision**: Collection and validation are side-effect free. Any invalid schema, duplicate identity, unknown operation, undeclared conflict, stale pre-state version, or reducer failure rejects the whole hour; clock/state remain at the pre-hour version and a failure record is emitted.

**Rationale**: Partial application would violate one gameplay truth and make recovery non-deterministic. Commit operations are prevalidated and deliberately simple.

**Alternatives considered**: Drop only invalid intents; rollback after partial mutation. Best-effort changes hide contributor defects; rollback would require duplicating and restoring broad Godot object state.

## Decision 6: Keep the detailed ledger bounded and non-authoritative

**Decision**: Keep full current/recent transaction entries for debugging and playtests behind a configurable memory bound; always retain the latest result and aggregate counters. Do not persist diagnostics or hash them.

**Rationale**: Independent intent history is essential for explainability, but unbounded runtime history would become its own performance problem.

**Alternatives considered**: Persist every intent; aggregate only. The former bloats saves and the latter loses attribution.

## Decision 7: Coalesce presentation at one end-of-frame scheduler

**Decision**: Presenters register consumed invalidation domains, a visibility predicate, and a refresh callable. Change sets dirty registrations; one deferred scheduler flushes each relevant visible presenter once against a captured committed version.

**Rationale**: This preserves modular UI ownership while eliminating repeated synchronous rebuilding during signal bursts. A presenter dirtied during a flush is queued for the next flush to prevent recursion.

**Alternatives considered**: One monolithic UI refresh; debounce timers per panel; presenters calling each other. These respectively add coupling, inconsistent latency, or hidden dependencies.

## Decision 8: Use finite invalidation domains plus entity scopes

**Decision**: Define canonical domains such as clock, structures, topology, occupancy, resources, economy, demand, community, traffic, progression, and presentation configuration. Change sets may add affected entity keys and revision counters.

**Rationale**: Free-form event names make dependency coverage impossible to audit; a finite vocabulary supports precise invalidation without over-dirtying every UI.

**Alternatives considered**: One global dirty flag; a signal per field. Global invalidation repeats too much work; per-field signals recreate fan-out and an unmanageable contract surface.

## Decision 9: Separate operational selectors from diagnostics

**Decision**: Each runtime consumer gets a small named, versioned projection. Full resident/spatial/replay views remain explicit diagnostic calls with independent timing.

**Rationale**: Profiling found normal UI paths constructing broad snapshots. Versioned selectors allow reuse and make accidental full-diagnostic work detectable.

**Alternatives considered**: Cache one universal snapshot; let each UI query plugins directly. A universal snapshot stays expensive and broad direct reads are inconsistent and hard to invalidate.

## Decision 10: Publish building mutation change sets

**Decision**: Builder validates first, applies one mutation, then publishes affected cells/entities/domains and revisions. Derived indexes update or invalidate from that change set.

**Rationale**: Place/replace/demolish currently cause wide cascades. A precise mutation record supports incremental road, occupancy, programme, attractiveness, and presentation work while retaining Builder as the gameplay command authority.

**Alternatives considered**: Full index rebuild after every action; let each plugin infer changes from global state. Both duplicate scanning and risk observing different intermediate state.

## Decision 11: Key migration cache entries by dependency revisions

**Decision**: Build one immutable batch context per migration boundary and cache sub-facts against explicit revisions for topology, structure programme, occupancy, schedules, balance/config, and hour/day.

**Rationale**: Candidate evaluation repeats invariant source, route, and schedule work. Revision keys make reuse and invalidation deterministic and observable.

**Alternatives considered**: Time-to-live cache; one opaque cache key; caching candidate decisions. TTL is non-deterministic, an opaque key over-invalidates, and candidate decision caching risks stale person-specific results.

## Decision 12: Maintain traffic and people order incrementally

**Decision**: Traffic uses stable per-origin FIFO queues and an ordered active-origin cursor. People keeps resident order updated on insert/remove and maintains active/relevant sets; diagnostics create sorted copies only on request.

**Rationale**: Current hot paths duplicate and sort whole collections each frame. Stable maintained order gives equivalent determinism with work proportional to changes and active entities.

**Alternatives considered**: Continue per-frame sorting; unordered iteration with deterministic hashes afterward. The first scales poorly and the second changes visible/simulation ordering.

## Decision 13: Optimize rendering only from attributed evidence

**Decision**: First separate script, submission, draw-call, primitive, and diagnostic costs. Then apply visibility culling, update-frequency tiers, and instancing within existing visual contracts. Do not redesign assets in this feature.

**Rationale**: The rendered baseline shows both script and approximately three-million-primitive pressure. Attribution prevents architecture work from claiming engine/render cost it did not fix.

**Alternatives considered**: Immediate asset reduction or wholesale renderer replacement. Both are premature and exceed the approved scope.

## Decision 14: Enforce percentile budgets with adapters and parity gates

**Decision**: Use three-run reference evidence with median, p95, and maximum thresholds. Migrate story by story behind adapters and remove each legacy path only after focused contracts, parity, replay, full-suite, and scenario gates pass.

**Rationale**: Percentiles distinguish sustained cost from spikes. Adapters keep increments shippable and limit the blast radius of a central architectural change.

**Alternatives considered**: One big-bang migration; mean-only budgets; subjective play feel. These obscure regressions or make failure isolation difficult.

## Resolved Unknowns

No `NEEDS CLARIFICATION` items remain. The feature targets Godot 4.6.2, preserves synchronous deterministic authority, uses existing plugin injection, and treats all measurement artifacts as non-authoritative.
