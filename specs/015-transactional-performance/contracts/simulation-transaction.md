# Contract: Simulation Transaction

## Registration

`register_contributor(contributor_id, domains, collect_callable) -> Result`

- IDs are stable and unique; duplicate registration is rejected.
- The callable receives only an immutable HourContext and an IntentSink.
- Registration grants no access to other contributors or coordinator internals.
- Unregistration removes future participation and cannot alter an active transaction.

## Collection

`collect(context, sink) -> void`

- Must be deterministic and side-effect free.
- May submit zero or more immutable SimulationIntents.
- A plugin may batch all owned buildings but must preserve an `entity_key` on each independent intent.
- Random choices use only the named deterministic stream in context.
- Direct GameState mutation, signal emission, presenter refresh, file I/O, or peer calls during collection are contract violations.

## Validation and Reduction

`resolve(transaction) -> CommitPlan | TransactionFailure`

- Intent schema and IDs are validated before domain reduction.
- Reducers are selected by target domain and operate in canonical order.
- Reducers declare allowed operations, payload schema, combination rules, and conflicts.
- Every conflict has a deterministic winner/combine rule or rejects the complete transaction.
- The commit plan contains only prevalidated authoritative field deltas and expected pre-values/versions.

## Commit

`commit(plan) -> AuthoritativeChangeSet | TransactionFailure`

- The coordinator is the sole caller.
- Commit is non-reentrant and applies exactly once.
- No downstream notification occurs until all authoritative deltas and StateVersion are complete.
- Success emits one `transaction_committed(change_set, ledger_summary)`.
- Failure preserves the pre-state version/hash and emits one `transaction_rejected(failure, ledger_summary)`.
- Legacy hourly/stat signals may be emitted only by compatibility adapters after success.

## Required Failure Codes

`duplicate_contributor`, `duplicate_intent`, `unknown_domain`, `unknown_operation`, `invalid_payload`, `stale_state_version`, `undeclared_conflict`, `collection_side_effect`, `reentrant_transaction`, `reducer_failure`, `commit_precondition_failed`.

## Deterministic Order

`[reducer_phase, target_domain, target_key, priority, contributor_id, entity_key, intent_id]`

The tuple must completely order all entries. Incidental array/dictionary/scene/signal order is prohibited as a tie-break.

## Compatibility Invariants

- DayNight remains the clock and advances the authoritative hour only with a committed transaction.
- GameState/DataMap remains gameplay truth.
- Same pre-state, seed, and inputs produce the same state hash and ledger, including with reversed registration order.
- Diagnostics and timings never enter intent payloads used for gameplay decisions.
