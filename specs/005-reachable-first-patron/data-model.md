# Data Model: Reachable First-Patron Progression

## Bucket Progress State

Derived, never persisted.

| Field | Type | Rule |
|-------|------|------|
| `bucket_id` | String | One of residential, industrial, commercial |
| `display_name` | String | Authored/player label from Demand |
| `fulfilled` | float | Canonical placed capacity reported by Demand |
| `attained_tier` | int | Highest positive authored tier among currently placed bucket buildings |
| `tier_evidence` | Array | Stable building ID, placed anchor, tier, and source kind records |

Evidence is sorted by tier, building ID, then anchor. Demolition can lower
`attained_tier`, but it never regresses an already completed narrative state.

## Character Progress Gate

Derived from CharacterSystem definition, persisted state, Demand, and
BuildingCatalog tier evidence.

| Field | Type | Rule |
|-------|------|------|
| `character_id` | String | Stable authored ID |
| `display_name` | String | Authored player-facing name |
| `state` / `state_name` | int / String | Current durable state |
| `bucket` / `bucket_label` | String | Associated growth bucket and display label |
| `fulfilled` / `required_fulfilled` | float | Current and authored arrival values |
| `attained_tier` / `required_tier` | int | Current and authored arrival tiers |
| `demand_met` / `tier_met` / `arrival_ready` | bool | Independent and combined gate results |
| `want_building_id` / `want_display_name` | String | Canonical request identity and label |
| `reasons` | Array[String] | Stable unmet arrival reasons |

State transition:

```text
NOT_ARRIVED --demand_met && tier_met--> ARRIVED
ARRIVED --resolve_arrival--> WANT_REVEALED
WANT_REVEALED --requested building exists/placed--> SATISFIED
SATISFIED --patron completion--> CONTRIBUTES_TO_LANDMARK
```

Transitions are forward-only and idempotent. When resolving ARRIVED, an already
placed request is reconciled immediately after WANT_REVEALED. Demolition never
regresses SATISFIED or CONTRIBUTES_TO_LANDMARK.

## Story Building Gate

Derived by UniqueRegistry and shared by Builder, Palette, radial UI, Dashboard,
and Playtest.

| Field | Type | Rule |
|-------|------|------|
| `building_id` / `display_name` | String | Stable ID and authored label |
| `role` | String | `chain`, `want`, or `landmark` |
| `placed` / `selectable` | bool | Canonical one-of-a-kind and complete gate result |
| `bucket` / `current` / `threshold` | String / float / float | Ordinary demand gate evidence |
| `prerequisites` / `missing_prerequisites` | Array | Authored and unmet physical chain IDs |
| `character` | Dictionary/null | Character ID, name, and state for a want |
| `patron` | Dictionary/null | Patron ID, name, and state for a landmark |
| `reasons` | Array[String] | Stable ordered complete rejection set |
| `primary_reason` | String/null | First reason under the contract priority |

## Patron Progress State

`patron_states[patron_id]` remains persisted in DataMap.

| Field | Type | Rule |
|-------|------|------|
| `patron_id` / `display_name` | String | Stable ID and authored label |
| `state` / `state_name` | int / String | LOCKED, LANDMARK_AVAILABLE, or COMPLETED |
| `characters` | Array | Stable roster with each durable character state |
| `satisfied_count` / `required_count` | int | Satisfied or contributed characters versus roster size |
| `landmark_building_id` / `landmark_display_name` | String | Authored landmark identity and label |
| `donation_applied` | bool | Presence in `DataMap.patron_donations_applied` |

State transition:

```text
LOCKED --all characters satisfied/contributed--> LANDMARK_AVAILABLE
LANDMARK_AVAILABLE --landmark placed and donation applied--> COMPLETED
```

## Donation Receipt

`DataMap.patron_donations_applied` is a Dictionary keyed by patron ID. A true
entry means the canonical donation area was applied. BuildableArea still stores
the full `allowed_cells` set; the receipt makes intent and legacy repair
observable. `apply_donation()` returns only newly added cells and returns an
empty list on repeat.

## Narrow Progression Persistence

`DataMap.pending_dialogue_event_ids` stores ordered stable event IDs awaiting
resolution. IDs are enqueued once, reconstructed for legacy ARRIVED states when
necessary, and removed only after successful dialogue completion.

`DataMap.demand_totals` stores accrued totals for residential, industrial, and
commercial demand. Demand restores those totals before recomputing fulfilled
capacity from the placed registry. These fields preserve milestone-005
continuity; milestone 007 still owns save versioning, slots, autosave, recovery,
and lifecycle presentation.

## Progression Milestone

Recorded in the Playtest session, not the town save.

| Field | Type | Rule |
|-------|------|------|
| `milestone_id` | String | Stable first-occurrence ID |
| `sequence` | int | Semantic action sequence that exposed the state |
| `absolute_hour` | int | Manual simulation hour |
| `demand` / `tiers` | Dictionary | Relevant canonical bucket values |
| `characters` / `patrons` | Dictionary | Durable progression states |
| `placed_building_ids` | Array[String] | Stable sorted IDs |
| `allowed_count` / `new_cells` | int | Land outcome where relevant |
| `state_hash` | String | Hash of normalized balance-relevant state at observation |

The session maintains a milestone-ID set so each record is appended once.

## Content Validation Issue

Derived validation output.

| Field | Type | Rule |
|-------|------|------|
| `severity` | String | `error` or `warning` |
| `path` | String | Exact authored file path |
| `field` | String | Exact JSON/profile field |
| `subject_id` | String | Character, patron, or building ID |
| `message` | String | Actionable explanation |

Unknown buckets, out-of-range tiers, missing/mismatched request/patron/landmark
references, invalid roles, and prerequisite cycles are errors.
