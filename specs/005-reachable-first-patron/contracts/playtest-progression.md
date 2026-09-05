# Contract: Playtest Progression Commands and State

## Semantic action

`resolve_dialogue` is accepted by the debug-only Playtest command surface.

Request:

```json
{
  "operation": "resolve_dialogue",
  "params": {
    "request_id": "resolve-industrial-arrival",
    "event_id": "aristocrat_industrial_arrival",
    "expected_sequence": 21
  }
}
```

Applied outcome uses the existing `PlaytestActionResult` envelope. Details
include the event and character IDs plus before/after state names. The action
uses the same Dialogue traversal, effects, close callback, and pending-queue
acknowledgement as visible presentation.

Stable rejections:

- `unknown_dialogue_event`
- `dialogue_not_pending`
- existing `sequence_conflict`

Request IDs remain idempotent under the existing 256-entry cache. This surface
does not expose arbitrary state assignment, demand mutation, patron completion,
or land expansion.

## Snapshot additions

`snapshot.progression` contains:

- `buckets`: residential, industrial, and commercial bucket projections;
- `characters`: every quest character projection keyed by ID;
- `patrons`: every live patron projection keyed by ID;
- `story_buildings`: every unique chain/want/landmark decision keyed by ID;
- `unlocked` and `placed`: retained compatibility arrays;
- `donations_applied`, `flags`, and `event_counts`;
- `milestones`: ordered milestone IDs observed so far.

All keys and collections use stable ordering before hash construction. The
balance-relevant state hash includes these additions but excludes session ID,
request sequence, presentation state, and wall-clock time.

## Milestone trace

`get_trace()` retains action records. `get_progression_milestones()` returns
detached records defined in `data-model.md`. A milestone is appended after the
canonical action completes and before that action's final snapshot/hash is
returned.

Required milestone IDs:

- `bucket.<bucket>.tier1_placed`
- `character.<id>.arrived`
- `character.<id>.want_revealed`
- `character.<id>.satisfied`
- `patron.aristocrat.landmark_available`
- `patron.aristocrat.completed`
- `patron.aristocrat.land_donated`

Repeated observation, load reconciliation, and duplicate requests do not append
a duplicate milestone.
