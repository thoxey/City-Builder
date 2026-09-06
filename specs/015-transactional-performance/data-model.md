# Data Model: Transactional Performance Architecture

All records below are runtime value objects or detached dictionaries. Only the resulting gameplay fields in GameState/DataMap are authoritative and saveable.

## StateVersion

| Field | Type | Rules |
|---|---|---|
| value | int | Monotonic, non-negative, increments once per successful authoritative commit |
| state_hash | String | Optional diagnostic hash of the associated committed gameplay state |

**Transitions**: `current → current + 1` on successful commit; unchanged on rejection or empty presentation flush. An intent referencing any other version is stale.

## HourContext

| Field | Type | Rules |
|---|---|---|
| transaction_id | String | Stable from absolute hour and pre-state version |
| absolute_hour | int | The proposed next authoritative hour |
| day | int | Derived deterministically |
| clock_hour | int | 0–23 |
| seed_context | Dictionary | Detached deterministic random inputs/streams |
| pre_state_version | int | Must equal current StateVersion |
| projections | Dictionary | Named, immutable, bounded read views |
| dependency_revisions | Dictionary | Topology/programme/occupancy/schedule/balance revisions |

The context is created once, frozen for collection, and discarded after commit/rejection.

## SimulationContributorRegistration

| Field | Type | Rules |
|---|---|---|
| contributor_id | StringName | Globally unique and stable across loads |
| domains | Array[StringName] | Declared intent domains |
| collect | Callable | Side-effect-free collection callable |
| enabled | bool | Disabled registrations are skipped |

Lifecycle: `unregistered → registered → disabled/enabled → unregistered`. Duplicate IDs fail registration.

## SimulationIntent

| Field | Type | Rules |
|---|---|---|
| intent_id | String | Unique within transaction; stable from semantic inputs |
| contributor_id | StringName | Must match an active registration |
| entity_key | String | Building/system identity; may be empty only for declared aggregate operations |
| target_domain | StringName | Must map to a registered reducer |
| operation | StringName | Must be allowed by the reducer |
| payload | Dictionary | Detached, schema-valid, JSON-safe where included in evidence |
| priority | int | Domain-semantic priority, not connection order |
| combine_mode | StringName | add/set/min/max/allocate or domain-declared mode |
| ordering_key | Array | Complete deterministic tie-break tuple |

Lifecycle: `submitted → validated → accepted → committed` or `submitted → rejected`. Intent objects never mutate; disposition lives in ledger entries.

## HourlyTransaction

| Field | Type | Rules |
|---|---|---|
| transaction_id | String | Unique for attempted hour/version |
| context | HourContext | Shared by all contributors |
| intents | Array[SimulationIntent] | Canonically ordered after collection |
| commit_plan | Dictionary | Fully validated authoritative deltas |
| status | enum | collecting, validating, ready, committing, committed, rejected |
| failure | Dictionary | Empty unless rejected |
| post_state_version | int | Set only on commit |
| change_set | AuthoritativeChangeSet | Set only on commit |

Valid transitions:

```text
collecting → validating → ready → committing → committed
                       └────────────────────────→ rejected
collecting ─────────────────────────────────────→ rejected
```

No re-entry is permitted while status is collecting through committing.

## TransactionLedgerEntry

| Field | Type | Rules |
|---|---|---|
| transaction_id | String | Parent transaction |
| sequence | int | Canonical zero-based position |
| intent_id | String | Original independent intent |
| contributor_id | StringName | Attribution |
| entity_key | String | Attribution |
| target_domain | StringName | Intended effect |
| operation | StringName | Intended operation |
| disposition | enum | committed, rejected, superseded, combined |
| reason_code | StringName | Stable machine-readable outcome |
| related_intent_ids | Array[String] | Conflict/combine links |
| pre_state_version | int | Shared pre-version |
| post_state_version | int | Commit version or unchanged pre-version on rejection |

Detailed entries are bounded diagnostics. Aggregate counts may be kept longer; neither affects saves or hashes.

## AuthoritativeChangeSet

| Field | Type | Rules |
|---|---|---|
| change_id | String | Stable per command/transaction |
| source_kind | enum | hourly_transaction, building_mutation, map_load, map_clear |
| source_id | String | Transaction/command identity |
| pre_state_version | int | Version observed before mutation |
| post_state_version | int | Exactly pre + 1 for committed mutation |
| domains | Array[StringName] | Unique, canonical order |
| entity_keys | Dictionary | Domain → sorted affected identities |
| deltas | Dictionary | Bounded aggregate before/after or amount records |
| dependency_revisions | Dictionary | Updated revision values |

Change sets are immutable and published once, after the authoritative mutation is complete.

## InvalidationDomain

Canonical initial values:

`clock`, `structures`, `topology`, `occupancy`, `resources`, `economy`, `demand`, `community`, `traffic`, `progression`, `presentation_config`.

Every domain has an owner, a meaning, and mapped change-set sources. New values require a contract update rather than ad-hoc strings.

## PresenterRegistration

| Field | Type | Rules |
|---|---|---|
| presenter_id | StringName | Globally unique |
| domains | Array[StringName] | Non-empty declared dependencies |
| is_visible | Callable | Cheap visibility predicate |
| present | Callable | Refresh callable receiving version/change summary |
| dirty_domains | Dictionary | Coalesced set only |
| target_version | int | Latest dirty authoritative version |
| last_presented_version | int | Never exceeds current version |
| state | enum | clean, dirty_hidden, queued, presenting |

Transitions:

```text
clean → queued → presenting → clean
clean/queued → dirty_hidden → queued (when visible)
presenting + invalidation → queued for next flush
```

Historical change sets are not accumulated per presenter.

## OperationalProjection

| Field | Type | Rules |
|---|---|---|
| projection_id | StringName | Named for one consumer/use case |
| dependency_domains | Array[StringName] | Explicit invalidation mapping |
| state_version | int | Version represented |
| input_revisions | Dictionary | Domain revisions used |
| payload | Variant | Detached bounded result |
| workload_counts | Dictionary | Optional diagnostic sizes |

It is reusable only when all dependency revisions match. A DiagnosticProjection is separate, explicitly requested, and never substituted into an operational call.

## MigrationBatchContext

| Field | Type | Rules |
|---|---|---|
| batch_id | String | Day/hour/version identity |
| dependency_revisions | Dictionary | Topology, programme, occupancy, schedules, balance, time |
| housing_slots | Array | Stable ordered eligible slots |
| service_sources | Array | Stable authored schedule/source facts |
| route_facts | Dictionary | Revision-scoped reachability/distance facts |
| quality_context | Dictionary | Shared evaluator inputs |

Candidate identity, personality, target slot, score, and decision remain outside the shared context and receive separate ledger attribution.

## StableAdmissionQueue

| Field | Type | Rules |
|---|---|---|
| origin_stop | Vector3i | Queue partition key |
| journey_ids | deque-like sequence | FIFO request order |
| active | bool | Whether included in ordered origin cursor |
| revision | int | Changes on enqueue/dequeue/cancel |

The active-origin collection has canonical tile order and a deterministic round-robin cursor. Cancellation removes the journey from its partition without changing relative order of survivors.

## PerformanceSample and PerformanceBudget

**PerformanceSample** fields: boundary, started/elapsed microseconds, state version, absolute hour/frame, workload counts, build mode, engine version, seed, town ID, and optional parent sample.

**PerformanceBudget** fields: budget ID, boundary, workload profile, statistic (median/p95/max), threshold, unit, reference environment, enforcement level, and warm-up/exclusion rules.

Samples and budgets are diagnostics. Reports aggregate at least three equivalent runs and include an explicit engine/unattributed category so measured time is not silently dropped.
