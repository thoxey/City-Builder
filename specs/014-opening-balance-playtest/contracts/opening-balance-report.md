# Contract: Opening Balance Report v1

The runner writes JSON with `schema_version: 1`, `scenario_id`, `config`, `runs`,
`replay`, `aggregate`, `all_passed`, and `failures`.

Each run contains `seed`, `run_label`, `success`, `failures`, `decisions`, `milestones`,
`summary`, `final`, and `semantic_trace_hash`. Decision mutations are limited to
`place` and `advance`. Every `advance` requests exactly one hour. Every decision includes
before/after state hashes and a non-empty reason. Rejected decisions must have identical
before/after state hashes.

Replay passes only when the duplicate primary runs have identical semantic trace hashes,
milestone hour maps, ordered placed concrete variants, and final state hashes.

The report remains useful on failure: completed decisions, last state, blockers, bound
status, and failures must be written before a non-zero exit.
