# Contract: Canonical Progression Projection

## Purpose

All progression consumers use the same detached, JSON-safe decisions. Consumers
may format labels but must not recalculate eligibility.

## Bucket projection

```json
{
  "bucket_id": "industrial",
  "display_name": "industrial",
  "fulfilled": 63.0,
  "attained_tier": 3,
  "tier_evidence": [
    {"building_id":"building_pipe_factory","tier":3,"anchor":{"x":1,"z":2},"source":"unique"}
  ]
}
```

## Character projection

```json
{
  "character_id": "aristocrat_industrial",
  "display_name": "Sir Reginald Cogsworth",
  "state": 0,
  "state_name": "NOT_ARRIVED",
  "bucket": "industrial",
  "bucket_label": "industrial",
  "fulfilled": 63.0,
  "required_fulfilled": 100.0,
  "attained_tier": 3,
  "required_tier": 1,
  "demand_met": false,
  "tier_met": true,
  "arrival_ready": false,
  "want_building_id": "building_crazy_golf",
  "want_display_name": "Crazy Golf",
  "reasons": ["fulfilled_demand_not_reached"]
}
```

Arrival reason order is:

1. `fulfilled_demand_not_reached`
2. `required_tier_not_reached`

## Story-building projection

The projection retains existing fields and adds the complete progression gate:

```json
{
  "building_id": "building_crazy_golf",
  "display_name": "Crazy Golf",
  "unique": true,
  "role": "want",
  "placed": false,
  "selectable": false,
  "unlocked": false,
  "bucket": "industrial",
  "current": 72.0,
  "threshold": 60.0,
  "prerequisites": ["building_pipe_factory"],
  "missing_prerequisites": [],
  "character": {"id":"aristocrat_industrial","display_name":"Sir Reginald Cogsworth","state":1,"state_name":"ARRIVED"},
  "patron": null,
  "reasons": ["want_not_revealed"],
  "primary_reason": "want_not_revealed"
}
```

Complete reason priority is:

1. `unique_already_placed`
2. `want_not_revealed`
3. `patron_not_ready`
4. `unmet_prerequisite`
5. `below_demand_threshold`
6. `insufficient_demand`
7. `insufficient_cash`
8. footprint/land/replacement reasons applied by Builder

The complete `reasons` array remains stable and sorted by this priority.
`primary_reason` is the first element or null.

## Patron projection

```json
{
  "patron_id": "aristocrat",
  "display_name": "The Howarth Players",
  "state": 1,
  "state_name": "LANDMARK_AVAILABLE",
  "characters": [
    {"character_id":"aristocrat_commercial","state":3,"state_name":"SATISFIED"}
  ],
  "satisfied_count": 3,
  "required_count": 3,
  "landmark_building_id": "building_theatre",
  "landmark_display_name": "The Theatre",
  "donation_applied": false
}
```

## Consumer obligations

- Builder rejects with `primary_reason` and attaches the complete detached gate
  in action details.
- Palette and radial UI use `selectable`, `primary_reason`, and authored names.
- Dashboard uses CharacterSystem and PatronSystem projections for next-step text.
- Playtest choices expose the same reason set and progression evidence.
- No consumer mutates a returned record or progression state.
