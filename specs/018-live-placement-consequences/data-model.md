# Data Model: Live Placement Consequences

## Placement consequence quote

```text
status: valid | invalid | replacement
certainty: exact | mixed | uncertain
reason: canonical reason code
anchor, rotation, footprint
requires_confirmation
costs: detached canonical cash/demand quotes
access: detached rooted-placement evidence
replacement: removed internal/building IDs and anchors
community:
  quality_deltas: four signed aggregate values
  affected_resident_count, affected_home_count
  affected_residents[] (bounded)
  effect_radii[]
attractiveness:
  city_delta
  affected_tile_count
  changed_tiles[] (bounded)
uncertainties[]: stable reason codes
state_revision: transient Builder quote revision
```

The record is transient, detached, and excluded from `DataMap`, saves, progression, replay hashes, and RNG.

## Invariants

- An invalid quote has no positive/negative domain consequences.
- `quality_deltas` always contains all four community keys.
- Lists use deterministic coordinate/entity ordering.
- Bounded lists include a separate total count so truncation never changes meaning.
- Intrinsic effect descriptions are not members of this record.
