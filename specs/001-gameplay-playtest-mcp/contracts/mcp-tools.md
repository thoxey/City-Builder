# MCP Tool Contract: City Playtest

Server name: `city-playtest`

The server exposes exactly six public tools. All responses include
`schema_version: 1`. Gameplay rejections return structured content with
`status: "rejected"`; malformed input, unavailable runtime, and internal errors
set the MCP error response.

## 1. `playtest_start`

Start or reset a deterministic local session and wait until the game-side
Playtest plugin reports ready.

### Input

```json
{
  "scenario_id": "fresh_city",
  "seed": 1,
  "narrative_mode": "presentation_disabled"
}
```

- `scenario_id`: optional string, default `fresh_city`
- `seed`: optional signed 32-bit integer, default `1`
- `narrative_mode`: optional enum; v1 accepts only `presentation_disabled`

### Output

```json
{
  "schema_version": 1,
  "session": {
    "session_id": "...",
    "scenario_id": "fresh_city",
    "seed": 1,
    "sequence": 0,
    "status": "ready"
  },
  "snapshot": {}
}
```

Starting again closes the previous session and creates a new identity.

## 2. `playtest_get_state`

Read normalized state without changing the sequence or trace unless
`record_observation` is true.

### Input

```json
{
  "include_choices": true,
  "include_land_cells": false,
  "record_observation": false
}
```

All fields are optional. `include_choices` defaults true;
`include_land_cells` defaults false to bound routine snapshots.

### Output

Returns the `CitySnapshot` defined in [../data-model.md](../data-model.md).

## 3. `playtest_get_choices`

Return every player-facing palette choice, including unavailable choices and
their global lock/resource reasons.

### Input

```json
{
  "available_only": false,
  "category": "generic"
}
```

- `available_only`: optional boolean, default false
- `category`: optional enum `road`, `nature`, `generic`, `unique`

### Output

```json
{
  "schema_version": 1,
  "session_id": "...",
  "sequence": 0,
  "choices": []
}
```

## 4. `playtest_place`

Evaluate and, when legal, atomically place one concrete building or one seeded
palette choice.

### Input

```json
{
  "request_id": "place-001",
  "choice_id": "residential_t1",
  "anchor": { "x": 0, "z": 0 },
  "rotation": 0,
  "replace": false,
  "expected_sequence": 0,
  "include_snapshot": true
}
```

- Exactly one of `choice_id` or `building_id` is required.
- `variant_id` is optional when `choice_id` names a pool.
- `rotation` defaults to `0` and must be `0..3`.
- `replace` defaults false. If occupied and false, return
  `replacement_required`/`occupied_footprint` without UI.
- `expected_sequence` is optional. A mismatch returns `sequence_conflict`.
- `request_id` is required and provides per-session idempotency.

### Output

Returns `ActionOutcome`. Applied details include concrete `building_id`, anchor,
rotation, footprint, cash spent, demand bucket/cost, and replaced building IDs.

## 5. `playtest_demolish`

Demolish the building owning a cell through the normal game command.

### Input

```json
{
  "request_id": "demolish-001",
  "cell": { "x": 0, "z": 0 },
  "expected_sequence": 1,
  "include_snapshot": true
}
```

Clicking any cell in a multi-cell footprint resolves to the owning building.
An empty cell returns `nothing_to_demolish` without state change.

### Output

Returns `ActionOutcome`. Applied details include concrete building id, anchor,
footprint, and balance values restored or recalculated.

## 6. `playtest_advance`

Advance an exact number of in-game hours in manual clock mode.

### Input

```json
{
  "request_id": "advance-001",
  "hours": 24,
  "expected_sequence": 2,
  "include_snapshot": true
}
```

`hours` is a whole number from `0` through `1000`. Zero is valid and settles a
snapshot without emitting an hour event.

### Output

Returns `ActionOutcome`. Applied details include starting absolute hour, ending
absolute hour, requested hours, and emitted hourly update count.

## Error Separation

Examples of normal gameplay responses:

```json
{
  "status": "rejected",
  "changed": false,
  "reason": "insufficient_demand",
  "details": { "bucket": "commercial", "required": 30, "available": 12 }
}
```

Examples of MCP errors:

- Godot editor or game not running;
- Playtest plugin not ready;
- malformed arguments rejected by the server schema;
- editor/runtime IPC timeout;
- unhandled game exception.

## Contract Invariants

1. State-changing tools require `request_id`.
2. A duplicate request never applies twice.
3. A rejected action has the same pre/post `state_hash`.
4. A sequence increments only for a new, accepted command dispatch; duplicates
   report the original sequence.
5. Applied placement/demolition occurs through Builder's shared command path.
6. Applied advancement occurs through DayNight's shared hour-transition path.
7. No tool accepts arbitrary GDScript, node paths, file paths, or property names.
