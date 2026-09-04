# Data Model: Gameplay Playtest MCP

All external values are JSON-safe. Coordinates use `{ "x": int, "z": int }`;
rotations use clockwise quarter-turns `0..3`; balance floats are rounded to four
decimal places for comparison.

## PlaytestSession

| Field | Type | Rules |
|-------|------|-------|
| `session_id` | string | Non-empty, unique for a start/reset lifecycle |
| `scenario_id` | string | Must resolve to a known scenario |
| `seed` | integer | Explicit; default may be supplied by caller schema |
| `snapshot_schema` | integer | Starts at `1` |
| `sequence` | integer | Starts at `0`; increments once per accepted new command |
| `status` | enum | `starting`, `ready`, `failed`, `closed` |
| `clock_mode` | enum | `manual` during automated play |
| `content_revision` | string | Best available local revision label; informational |
| `narrative_mode` | enum | `presentation_disabled` for core balance scenarios |
| `started_at` | string | Wall-clock metadata only; excluded from determinism comparisons |

### State transitions

```text
absent → starting → ready → closed
             └────→ failed
ready  → starting (reset creates a new session_id)
```

## CitySnapshot

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | integer | Snapshot contract version |
| `session_id` | string | Owning session |
| `sequence` | integer | Last processed command |
| `simulation` | object | Day, hour, absolute elapsed hours, manual/paused state |
| `economy` | object | Cash, last hourly income, industrial output |
| `population` | object | Current population, residential capacity, worker demand/fulfilment where available |
| `satisfaction` | object | Composite score and component scores exposed by CityStats |
| `attractiveness` | object | City total and per-occupied-tile score records |
| `demand` | map | `residential`, `industrial`, `commercial`, each with total, fulfilled, unserved, reference cost, bank render |
| `land` | object | Allowed cell count and canonical sorted allowed coordinates |
| `buildings` | array | Sorted `PlacedBuilding` records |
| `choices` | array | Sorted `BuildingChoice` records; optionally omitted only when caller requests compact state |
| `progression` | object | Unique unlock/placement state without presentation/dialogue content |
| `state_hash` | string | Hash of normalized balance-relevant fields, excluding metadata |

## PlacedBuilding

| Field | Type | Rules |
|-------|------|-------|
| `building_id` | string | Stable catalog identifier |
| `anchor` | coordinate | Canonical origin cell |
| `rotation` | integer | `0..3` |
| `footprint` | coordinate[] | Sorted occupied cells |
| `category` | string | Catalog category |
| `pool_id` | string/null | Null for standalone content |
| `unique` | boolean | Whether one-of-a-kind rules apply |

Sort order is anchor `x`, anchor `z`, then `building_id`. Internal numeric
registry IDs are deliberately omitted.

## BuildingChoice

| Field | Type | Description |
|-------|------|-------------|
| `choice_id` | string | Palette pool id or standalone building id |
| `display_name` | string | Human-readable authored name |
| `variants` | string[] | Sorted concrete building IDs selectable by this choice |
| `category` | string | Road, nature, generic, or unique |
| `tier` | integer/null | Tier when applicable |
| `footprints` | object[] | Variant id plus normalized footprint |
| `cash_cost` | integer | Current authored cost where applicable |
| `demand` | object/null | Bucket, per-unit cost, threshold |
| `unique` | boolean | One-of-a-kind choice |
| `available` | boolean | True if at least one variant can be selected now |
| `reasons` | string[] | Stable reason codes; empty when available |

Choice availability is global. Location-specific land and occupancy validation
is returned by placement evaluation.

## PlaytestAction

| Field | Type | Rules |
|-------|------|-------|
| `request_id` | string | Required and unique within session for state-changing actions |
| `kind` | enum | `place`, `demolish`, `advance` |
| `parameters` | object | Kind-specific validated values |
| `expected_sequence` | integer/null | Optional optimistic concurrency guard |

### Place parameters

- `choice_id` or concrete `building_id`
- `anchor`
- `rotation` (`0..3`, default `0`)
- `variant_id` optional; if absent for a pool, seeded selection chooses it
- `replace` boolean, default `false`; automated sessions never open confirmation UI

### Demolish parameters

- `cell`; any footprint cell resolves to the owning anchor

### Advance parameters

- `hours`; whole number `0..1000` per command

## ActionOutcome

| Field | Type | Description |
|-------|------|-------------|
| `request_id` | string | Echoed request identity |
| `session_id` | string | Owning session |
| `sequence` | integer | Sequence after processing |
| `status` | enum | `applied`, `rejected`, `duplicate`, `failed` |
| `changed` | boolean | Whether gameplay state changed |
| `reason` | string/null | Stable code for rejection/failure |
| `details` | object | Costs, chosen variant, affected coordinates, hours advanced |
| `snapshot` | CitySnapshot/null | Post-settlement state when requested |

`duplicate` returns the original sequence, details, and state hash and never
reapplies the mutation.

## Stable Reason Codes

### Gameplay rejection

- `unknown_choice`
- `unknown_building`
- `invalid_coordinate`
- `invalid_rotation`
- `outside_buildable_area`
- `occupied_footprint`
- `replacement_required`
- `insufficient_cash`
- `below_demand_threshold`
- `insufficient_demand`
- `unmet_prerequisite`
- `unique_already_placed`
- `nothing_to_demolish`
- `demolition_not_allowed`
- `invalid_hours`
- `sequence_conflict`

### Infrastructure failure

- `game_not_running`
- `game_not_ready`
- `session_not_ready`
- `connection_lost`
- `command_timeout`
- `internal_error`

Infrastructure failures are surfaced as protocol errors; gameplay rejection
codes remain normal structured outcomes.

## Scenario

| Field | Type | Description |
|-------|------|-------------|
| `scenario_id` | string | Stable name |
| `description` | string | Purpose of the experiment |
| `initial_state` | object | Fresh-map/resources/land overrides |
| `narrative_mode` | enum | Presentation behaviour |
| `max_hours` | integer | Safety bound |
| `success_conditions` | condition[] | Observable milestone conditions |
| `soft_failure_conditions` | condition[] | Poor but recoverable states |
| `hard_failure_conditions` | condition[] | Deadlocks or invalid states |
| `milestones` | condition[] | Named observation points |

Initial scenarios are authored fixtures rather than arbitrary save resources.

## TraceEntry and PlaytestTrace

`TraceEntry` contains `sequence`, simulation hour, action or observation kind,
normalized request, outcome, and resulting `state_hash`. Wall-clock duration may
be recorded but is excluded from deterministic equality.

`PlaytestTrace` contains session/scenario metadata, ordered entries, discovered
milestones, terminal condition, and final snapshot. The in-memory trace and
idempotency cache are bounded; persisted completed traces are immutable files.

## BalanceComparison

Comparisons require matching `scenario_id` and seed. They report:

- milestone-hour deltas;
- final cash, population, output, satisfaction, attractiveness, and demand deltas;
- building-count and choice differences;
- rejected-action counts by reason;
- soft/hard failure differences;
- state hashes for source trace identity.

The comparison deliberately contains no universal balance or fun score.
