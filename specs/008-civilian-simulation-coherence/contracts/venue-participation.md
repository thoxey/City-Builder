# Contract: Existing Venue Participation

## Purpose

Create more visible daily activity by assigning residents to suitable buildings that
already exist. This is a data and simulation pass, not an asset-production pass.

## Eligibility Rules

A building may receive a `participant` role only when all are true:

1. Its established identity describes a place residents physically attend.
2. It has a legible active schedule or programme.
3. Participant capacity can be stated using the existing Community effect schema.
4. The resulting effect does not duplicate a productive/work assignment.
5. The role is comprehensible using the current model, name, and UI data.

Otherwise it must be recorded as `local_only`, `productive`, or `cosmetic`.

## Initial Inventory Decision

| Building | Planned role | Rationale |
|----------|--------------|-----------|
| Pub | `participant` | Existing commercial venue, capacity 30, active 17:00-23:00; physical attendance is explicit. |
| Restaurant | `participant` | Existing commercial venue, capacity 40, active 12:00-23:00; physical attendance is explicit. |
| Private Members' Club | `participant` | Existing commercial venue, capacity 25, active 18:00-02:00; physical attendance is explicit. |
| Crazy Golf | `participant` | Existing leisure destination; needs an explicit schedule/capacity before assignment. |
| Town Hall | `local_only` initially | Existing civic-heart effect describes living nearby, not routine attendance; only change if a staffed public programme is specified. |
| Pirate Radio Station | `productive` or `cosmetic` initially | Broadcasting does not imply audience attendance; only change if a physical event programme is specified. |
| Theatre | `participant` | Existing programme-specific participant pattern remains the reference implementation. |

## Data Requirements

Participant venues use existing `CommunityEffectProfile` fields:

```json
{
  "type": "CommunityEffectProfile",
  "effects": [
    {
      "effect_id": "stable_unique_id",
      "quality": "belonging",
      "manifestation": "identity",
      "amount": 1.0,
      "scope": "participant",
      "capacity": 30,
      "schedule": {"start": 17, "end": 23},
      "stacking_group": "stable_group",
      "reason": "Visited an existing local venue"
    }
  ]
}
```

Rules:

- IDs and reasons are stable and player-explainable.
- Capacity agrees with the established BuildingProfile unless a documented lower
  participant cap is intentionally used.
- Schedule agrees with established opening hours; overnight ranges are supported.
- Effect values start conservatively and require before/after Community balance
  traces. Eligibility does not justify a large reward.
- Participant effects remain subject to canonical road reachability and Community's
  existing stable capacity allocation.
- No model path, texture, icon, animation, audio, or visual scale is changed by this
  feature.

## Programme Invalidation

When an existing venue changes programme:

1. Community persists the programme through its existing path.
2. The assignment cache/revision is invalidated immediately, even within the same
   simulation hour.
3. Re-evaluation uses the new schedule/effects/capacity.
4. People reconciles residents whose CivilianIntent changed.
5. Workplace/economy state remains governed by Community, not proxy arrival.

## Validation Evidence

For each evaluated building, store:

- before/after role and profile inventory;
- active-hour participant capacity;
- assigned resident count in connected and disconnected layouts;
- Community quality/effect deltas;
- demand/economy regression trace;
- confirmation that no runtime art asset was added or modified for this feature.

## Required Contract Tests

- Each initial inventory building has exactly one explicit role decision.
- Participant roles have positive capacity and a valid schedule.
- Local/productive/cosmetic roles do not enter activity assignment.
- Connected eligible venues receive no more residents than capacity.
- Disconnected eligible venues receive zero assignments.
- Overnight schedules behave correctly across midnight.
- Same-hour programme change replaces stale assignments deterministically.
- Building data passes the existing catalog/authoring validators.
