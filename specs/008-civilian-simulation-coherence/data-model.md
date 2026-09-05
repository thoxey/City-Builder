# Data Model: Coherent Civilian Simulation

## Ownership Map

| Model | Owner | Persistence | Authoritative? |
|-------|-------|-------------|----------------|
| Community resident and assignment | Community | Existing save data | Yes |
| Building access and route | RoadNetwork | Derived from map | Yes for connectivity |
| Resident binding | People | Reconstructed | No |
| Civilian intent | Community projection | Derived per assignment revision | Yes as input, read-only to People |
| Journey plan | People/RoadNetwork projection | Transient | No |
| Visual civilian state | People | Transient | No |
| Car journey state | CarManager | Transient | No |
| Civilian diagnostic projection | People + CarManager + Playtest | Built on request | No |
| Venue participation role | Building JSON / CommunityEffectProfile | Content data | Yes for assignment eligibility |

## Entity: ResidentBinding

One stable association between a Community resident and a visible slot.

| Field | Type | Rules |
|-------|------|-------|
| `resident_id` | int | Required, unique among visible bindings, stable for binding lifetime |
| `resident_seed` | int | Required; copied from Community record |
| `home_anchor` | Vector2i | Authoritative current home; never reused as current location |
| `slot_index` | int | Unique occupied People MultiMesh index |
| `visible_rank` | int | Stable rank used when population exceeds the proxy cap |
| `intent_revision` | int | Last Community assignment revision reconciled |
| `journey_revision` | int | Last RoadNetwork revision used by the current JourneyPlan |

### Invariants

- One visible slot binds to at most one current resident.
- One resident binds to at most one visible slot.
- Bindings are selected by stable resident order up to the existing cap.
- Rehoming changes `home_anchor`; it does not change `resident_id` or reset an
  unrelated active segment without reconciliation.

## Entity: CivilianIntent

Detached Community projection of what a resident is authoritatively doing now.

| Field | Type | Rules |
|-------|------|-------|
| `resident_id` | int | Required |
| `assignment_revision` | int | Monotonic for any assignment-affecting change |
| `absolute_hour` | int | Hour for which the intent was derived |
| `purpose` | enum | `home`, `work`, `activity`, `unhoused` |
| `destination_anchor` | Vector2i or null | Exact assigned building/home anchor |
| `destination_building_id` | String | Empty only for `unhoused` |
| `source_effect_ids` | Array[String] | Stable IDs for activity reasons; empty for work/home |
| `active` | bool | Whether this intent should currently be projected |
| `valid_until_hour` | int or null | Earliest known schedule boundary; may be null if only revision-driven |
| `reachable` | bool | Community/RoadNetwork assignment result |
| `blocked_reason` | String | Empty when reachable; otherwise stable contract reason |

### Selection rules

1. Active work assignment wins where Community's existing allocation says it wins.
2. Otherwise active participant assignment is used.
3. Otherwise the resident's current authoritative home is the destination.
4. An unhoused resident has no destination until Community supplies a home.
5. People never substitutes a different work/activity destination.

## Entity: JourneyPlan

Transient, detached evidence for travel between two valid places.

| Field | Type | Rules |
|-------|------|-------|
| `resident_id` | int | Required |
| `purpose` | enum | Matches CivilianIntent |
| `origin_anchor` | Vector2i | Last valid place, not a mutable alias for home |
| `destination_anchor` | Vector2i | Exact CivilianIntent destination |
| `origin_stop` | Vector3i | RoadNetwork-selected stop |
| `destination_stop` | Vector3i | RoadNetwork-selected stop |
| `road_path` | Array[Vector3i] | Ordered canonical road cells, detached copy |
| `route_distance` | int | Derived from canonical path; never anchor Manhattan distance |
| `mode` | enum | `walk`, `car` |
| `road_revision` | int | Revision under which path was resolved |
| `dependency_cells` | Array[Vector3i] | Stable unique origin/destination footprint and route cells |
| `plan_key` | String | Stable digest of resident, intent revision, endpoints, mode, and path |

### Validation rules

- Plan exists only if RoadNetwork reports reachable endpoints.
- Stops must belong to `road_path` or be valid endpoints of that path.
- Walk mode is allowed only when `route_distance <= walk_route_threshold`.
- Car mode is used above the threshold when a car slot is available.
- A pool-full car request becomes a deterministic waiting state, not an invalid walk.
- A changed RoadNetwork revision requires dependency revalidation before the next
  segment begins.

## Entity: VisualCivilianState

Transient state held by People for one ResidentBinding.

### States

| State | Meaning |
|-------|---------|
| `AT_HOME` | Resident is visibly at the current authoritative home |
| `AT_DESTINATION` | Resident is visibly dwelling at the active work/activity destination |
| `WALKING_TO_STOP` | Resident is following valid waypoints to the resolved origin stop |
| `WAITING_FOR_CAR` | Long route is valid but no car slot is currently available |
| `IN_CAR` | Resident is hidden/attached to an active CarManager journey |
| `WALKING_FROM_STOP` | Resident is following valid waypoints from the destination stop |
| `WALKING_ROUTE` | Short route is traversed by existing pedestrian presentation |
| `BLOCKED` | No valid journey exists; resident stays at `current_place` with a reason |
| `UNHOUSED` | Community has no valid home for the resident |

### Fields

| Field | Type | Rules |
|-------|------|-------|
| `resident_id` | int | Matches ResidentBinding |
| `state` | enum | One state above |
| `current_place` | Vector2i or null | Last building/home anchor safely reached |
| `display_position` | Vector3 | Presentation only |
| `intent` | CivilianIntent | Detached current desired state |
| `journey_plan` | JourneyPlan or null | Required for travelling states |
| `journey_id` | int or null | Required only while waiting/inside CarManager as applicable |
| `waypoint_index` | int | Presentation progress only |
| `blocked_reason` | String | Required in `BLOCKED`/`UNHOUSED` |
| `departure_offset` | float | Seeded, bounded presentation stagger |

### State transitions

```text
AT_HOME ──active intent──> WALKING_ROUTE / WALKING_TO_STOP
AT_DESTINATION ──intent ends──> WALKING_ROUTE / WALKING_TO_STOP
WALKING_TO_STOP ──arrive──> WAITING_FOR_CAR ──car allocated──> IN_CAR
IN_CAR ──arrive stop──> WALKING_FROM_STOP ──arrive──> AT_DESTINATION / AT_HOME
any stable/travel state ──invalid route──> BLOCKED
BLOCKED ──valid revised route──> WALKING_ROUTE / WALKING_TO_STOP
any state ──home removed and no replacement──> UNHOUSED
UNHOUSED ──rehomed──> AT_HOME or journey toward new home
```

An intent change during travel cancels or completes only the safe current segment,
then replans from `current_place` or the last valid road stop. It does not teleport the
resident to the old or new destination.

## Entity: CarJourneyBinding

Extension of current CarManager journey metadata.

| Field | Type | Rules |
|-------|------|-------|
| `journey_id` | int | Existing unique journey ID |
| `resident_id` | int or null | Required for civilian journeys; null allowed for other future types |
| `plan_key` | String | Matches People JourneyPlan |
| `origin_stop` | Vector3i | Supplied resolved stop |
| `destination_stop` | Vector3i | Supplied resolved stop |
| `road_path` | Array[Vector3i] | Supplied canonical path; copied before mutation |
| `road_revision` | int | Used for targeted invalidation |
| `waiting` | bool | Existing congestion state |
| `slot_index` | int | Existing pooled instance |

### Invariants

- A civilian `resident_id` has at most one active car journey.
- Completion echoes the resident/plan identity or allows People to resolve it from a
  stable journey index.
- Ordinary unrelated structure changes do not clear the pool.
- Map load may clear every transient journey.

## Entity: VenueParticipationRole

Authored interpretation of an existing building.

| Field | Type | Rules |
|-------|------|-------|
| `building_id` | String | Existing catalog ID |
| `role` | enum | `participant`, `local_only`, `productive`, `cosmetic` |
| `programme_id` | String | Stable ID when programme-driven |
| `schedule` | `{start, end}` or null | Handles same-day and overnight ranges |
| `capacity` | int | Positive only for participant roles |
| `effects` | Array[CommunityEffect] | Existing schema; participant scope for attendance |
| `decision_reason` | String | Planning/validation evidence, not runtime text |

Eligibility and effect amount are separate decisions. A building can be an eligible
destination without large happiness values; all numbers require before/after balance
evidence.

## Entity: CivilianDiagnosticProjection

Read-only diagnostic appended to non-compact Playtest state.

```json
{
  "schema_version": 1,
  "visible_count": 0,
  "simulated_resident_count": 0,
  "proxy_cap": 512,
  "active_car_count": 0,
  "waiting_car_count": 0,
  "road_revision": 0,
  "assignment_revision": 0,
  "residents": [],
  "violations": [],
  "counts_by_state": {},
  "counts_by_purpose": {},
  "blocked_by_reason": {}
}
```

Each resident record includes stable identity, home, current place, authoritative
purpose/destination, visible destination, state, mode, route distance/revision,
journey ID, waiting flag, blocked reason, and waypoint cells. Records and violations
are sorted by resident ID then stable reason code.

### Violation codes

- `duplicate_resident_binding`
- `orphan_proxy`
- `missing_visible_proxy_within_cap`
- `intent_destination_mismatch`
- `intent_purpose_mismatch`
- `unreachable_journey_started`
- `invalid_waypoint_cell`
- `stale_route_revision`
- `missing_car_binding`
- `unexpected_proxy_reset`
- `unexpected_car_cancellation`

Violations are observations, not gameplay state. Their presence fails targeted tests
but never changes Community outcomes.

## Revision and Invalidation Model

- `assignment_revision` increments when an hour boundary, roster/home change,
  structure eligibility change, capacity change, or programme change can alter an
  assignment.
- `road_revision` already represents or is extended to represent a rebuilt road
  projection.
- People reconciles when either revision changes or a resident-specific event occurs.
- Same revision + same resident intent yields the same `plan_key`; no reset occurs.
- A changed road revision does not automatically cancel a plan. Its dependency cells
  and endpoints are revalidated; unchanged valid paths continue.

## Persistence Rules

Persist through existing owners:

- resident identity, seed, home, cohort/personality;
- building placement and authored venue programme;
- authoritative Community assignment inputs already required by the save contract.

Do not persist:

- proxy slot, position, facing, bob time, or waypoint progress;
- journey/car IDs, car transforms, lane reservations, or waiting time;
- intent/route caches and revision-derived plan keys;
- civilian diagnostics or violation history.

After load, People reconstructs stable bindings and projects the current intent. This
is the one normal lifecycle where a full visual rebuild is expected.
