# Contract: People and Car Lifecycle

## Journey handoff

1. People resolves intent through RoadNetwork and walks to the canonical origin stop.
2. People submits a detached resolved route to CarManager.
3. A valid request returns a stable pending journey ID.
4. People maps it but keeps the resident visible in `WAITING_FOR_CAR`.
5. On matching `journey_started`, People hides the resident and enters `IN_CAR`.
6. On matching completion, People restores the resident at the destination stop and
   finishes the walk to the authoritative destination.

Start emission occurs after the request call returns so mapping exists first.

Waiting reasons distinguish `origin_capacity` and `car_pool_capacity`. Neither changes
purpose, destination, assignment, or outcome.

## Invalidation

Intent/plan changes cancel pending or active journeys. Equivalent route revalidation
may refresh revision; a changed route cancels and reconciles. Rehome, departure,
endpoint/route demolition, and map load retain targeted/full feature-008 semantics.
Late lifecycle signals for superseded plans are ignored and diagnosed.

## Pedestrian separation

Canonical waypoint cells remain unchanged. Spacing affects display interpolation and
pavement offset only. Resident ID breaks equal-progress ties. A walker may wait visually
but cannot select another route or alter authoritative arrival/effects.
