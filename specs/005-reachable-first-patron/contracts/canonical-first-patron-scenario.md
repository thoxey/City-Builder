# Contract: Canonical First-Patron Scenario

## File

`test/scenarios/first_patron_reachable.json`

## Required shape

```json
{
  "schema_version": 2,
  "scenario_id": "first_patron_reachable",
  "seed": 5005,
  "initial_state": {
    "map": "empty",
    "cash": 1000,
    "demand": {"residential":100,"industrial":100,"commercial":100},
    "clock": {"mode":"manual","start_hour":6},
    "narrative": {"mode":"presentation_disabled"}
  },
  "max_hours": 3000,
  "actions": [],
  "expected_milestones": [],
  "success_conditions": [],
  "hard_failure_conditions": []
}
```

## Action grammar

Actions are ordered objects with a stable `request_id` and one of:

- `place`: `choice_id` or `building_id`, anchor, optional variant and rotation;
- `advance`: positive hours within the existing per-command limit;
- `resolve_dialogue`: pending event ID;
- `observe`: no mutation; asserts the current state;
- `save_reload`: test-runner boundary action using the normal Builder map save
  and apply paths, never direct state mutation.

Every placement must be available under `get_choices` and pass Builder's
canonical command. The runner fails on the first rejected action unless that
action declares an expected rejection and reason.

## Required ordered outcomes

The trace proves:

1. all three tier-one bucket milestones;
2. all three arrivals and resolved wants;
3. each prerequisite chain and request through canonical placement;
4. every character satisfied exactly once;
5. Theatre blocked before patron readiness;
6. patron availability, Theatre placement, and completion;
7. a 192-cell donation with no duplicate cells; and
8. final allowed count greater than the starter count of 64.

## Boundary matrix

Separate fixtures save and reload immediately before/after arrival, reveal,
satisfaction, patron availability, completion, and donation. Each reload must
use `ResourceLoader.CACHE_MODE_IGNORE`, reconcile through the same map-loaded
path as gameplay, and preserve event counts while repairing any legacy missing
receipt.

## Determinism

Ten runs with seed 5005 and the same actions must have identical milestone IDs,
milestone evidence hashes, final balance-relevant state hashes, and gate
decisions. Session IDs and physical wall-clock timestamps are excluded.
