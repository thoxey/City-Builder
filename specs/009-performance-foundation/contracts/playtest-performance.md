# Contract: Playtest Performance Controls

## Action request additions

`place`, `demolish`, `advance` and `resolve_dialogue` params MAY contain:

```json
{
  "snapshot_mode": "full | compact | none",
  "profile": true
}
```

- Missing `snapshot_mode` is equivalent to `full` for compatibility.
- `compact` calls the existing compact projection.
- `none` omits the `snapshot` key entirely.
- An unsupported value rejects the action with `reason: "invalid_snapshot_mode"` before gameplay mutation.
- Missing or false `profile` omits action performance diagnostics.

## Action response additions

When `profile` is true:

```json
{
  "performance": {
    "command_usec": 120,
    "snapshot_usec": 80,
    "total_usec": 220,
    "snapshot_mode": "compact"
  }
}
```

For profiled `advance`, the normal gameplay result also contains:

```json
{
  "performance": {
    "total_usec": 1000,
    "max_hour_usec": 300,
    "hour_timings": [
      {"absolute_hour": 30, "day": 2, "hour": 6, "elapsed_usec": 300, "migration_boundary": true}
    ]
  }
}
```

The nested advance performance describes authoritative clock work. The outer action performance separately describes command versus snapshot overhead.

## Compatibility and determinism

- Existing callers receive full snapshots and existing result fields by default.
- Request-id idempotency and expected-sequence conflicts behave unchanged.
- No timing field participates in trace state hashes, snapshots, saves or replay equivalence.
