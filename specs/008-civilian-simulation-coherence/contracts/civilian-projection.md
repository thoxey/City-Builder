# Contract: Civilian Intent and Diagnostic Projection

## Purpose

Define the narrow read boundary through which People consumes Community truth and
Playtest observes the visual layer. This contract must not create a new assignment
owner or make rendering authoritative.

## Community Intent Query

Community supplies either a per-resident query or a detached, stably ordered batch:

```gdscript
get_civilian_intents(include_unhoused: bool = true) -> Array[Dictionary]
get_civilian_intent(resident_id: int) -> Dictionary
get_assignment_revision() -> int
```

The precise method split may follow existing Community style, but the returned schema
is fixed:

```json
{
  "resident_id": 42,
  "resident_seed": 314159,
  "home_anchor": {"x": -4, "z": 0},
  "assignment_revision": 18,
  "absolute_hour": 8,
  "purpose": "work",
  "destination_anchor": {"x": 3, "z": 0},
  "destination_building_id": "building_garage",
  "source_effect_ids": [],
  "active": true,
  "valid_until_hour": 17,
  "reachable": true,
  "blocked_reason": ""
}
```

### Intent rules

- Records are sorted by `resident_id`.
- Coordinates use the repository's `{x, z}` contract form.
- `purpose` is one of `home`, `work`, `activity`, `unhoused`.
- People may add cosmetic departure delay but may not change purpose or destination.
- An absent/stale resident ID is not silently mapped to a different resident.
- Programme changes invalidate `assignment_revision` in the same simulation hour.

## People Diagnostic Query

People exposes a detached read:

```gdscript
get_civilian_snapshot() -> Dictionary
```

It contains:

```json
{
  "schema_version": 1,
  "simulated_resident_count": 1,
  "visible_count": 1,
  "proxy_cap": 512,
  "assignment_revision": 18,
  "road_revision": 7,
  "counts_by_state": {"at_destination": 1},
  "counts_by_purpose": {"work": 1},
  "blocked_by_reason": {},
  "residents": [
    {
      "resident_id": 42,
      "home_anchor": {"x": -4, "z": 0},
      "current_place": {"x": 3, "z": 0},
      "authoritative_purpose": "work",
      "authoritative_destination": {"x": 3, "z": 0},
      "visible_destination": {"x": 3, "z": 0},
      "state": "at_destination",
      "mode": "car",
      "route_distance": 6,
      "route_revision": 7,
      "journey_id": null,
      "waiting": false,
      "blocked_reason": "",
      "waypoint_cells": []
    }
  ],
  "violations": []
}
```

### Diagnostic rules

- All collections have stable ordering.
- No live Dictionary, Array, slot, Resource, or transform reference escapes.
- World-space floats may be omitted from deterministic trace comparisons; tile/anchor
  evidence is required.
- `simulated_resident_count` may exceed `visible_count`; this is not a violation when
  the cap is reached.
- Binding, intent, route, and vehicle contradictions produce stable violation codes.

## Playtest Integration

The existing `get_state`/snapshot response MAY append:

```json
{
  "civilian_simulation": {
    "people": {},
    "cars": {}
  }
}
```

Rules:

1. Build the authoritative snapshot and calculate `state_hash` first.
2. Append `civilian_simulation` only afterward and only for non-compact/debug state.
3. Never include this projection in saves, balance hashes, progression decisions, or
   Community evaluation.
4. Do not add a seventh public command.

## Required Contract Tests

- Intent records are stably ordered and detached.
- Same-hour programme change increments the assignment revision.
- Every visible resident within the cap has exactly one binding.
- A forced destination mismatch yields `intent_destination_mismatch`.
- Changing only visual progress leaves authoritative `state_hash` unchanged.
- Compact state remains within its existing bounded purpose and may omit residents.
