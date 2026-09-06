# Data Model: Emotive World Reactions

All records in this feature are detached presentation data. None is stored in
`DataMap`, submitted as a simulation intent, or included in gameplay hashes.

## World reaction configuration

Authored in `data/presentation/world_reactions.json` and normalized once by the
presentation plugin:

- `schema_version`: integer, initially `1`
- `default_mode`: `full | conditions_only | off`, initially `full`
- `default_reduced_motion`: boolean, initially `false`
- `visible_cap`: integer, exactly `5` in schema version 1
- `pool_size`: integer, exactly `8` in schema version 1
- `default_ttl_seconds`: float `1.6..2.4`, initially `2.0`
- `cooldown_seconds`: non-negative float, initially `10.0`
- `happiness_delta_threshold`: float, exactly `8.0` in schema version 1
- `vehicle_wait_threshold_seconds`: float, exactly `1.5` in schema version 1
- `ambient_chance_per_thousand_per_hour`: integer `0..1000`, initially `625`
- `ambient_quiet_buckets_after_condition`: exactly `1` in schema version 1
- `marker_screen_padding_px`: per-side integer at least `8`, initially `8`
- `vertical_lane_offset_px`: positive integer at least `8`, initially `56`, applied
  as screen-space translation `(0, -value)`
- `viewport_margin_px`: integer at least `12`, initially `12`
- `target_offsets`: authoritative finite runtime world-offset records with exact
  `{x, y, z}` float fields for `person`, `car`, and `building`; defaults are
  `person={x:0.0,y:0.75,z:0.0}`, `car={x:0.0,y:1.0,z:0.0}`, and
  `building={x:0.0,y:3.0,z:0.0}`. `x`/`z` must be `-2.0..2.0` and `y`
  must be `0.25..8.0`. The asset manifest may declare pivot/bounds compatibility
  but MUST NOT override these values
- `priority_by_cause`: complete cause-to-integer map exactly matching the
  schema-version-1 canonical table below
- `rule_by_cause`: complete cause-to-expression/eligibility map whose expression
  and speaker/target kind exactly match the schema-version-1 canonical table below
- `expression_assets`: complete expression-to-manifest/runtime map

Unknown keys are ignored for forward compatibility. Missing required keys,
unknown enum values, non-finite numbers, impossible ranges, missing cause
mappings, or asset keys outside the six-key vocabulary are content errors.
Runtime safety falls back to a built-in `conditions_only` configuration with
ambience disabled; release validation must not silently accept invalid content.
A missing expression key in `expression_assets` is a structural configuration
error and takes that fallback. Once all six mappings exist, a missing/unapproved
manifest entry or unreadable runtime PNG marks only that expression unavailable;
other expressions and ambience keep their normalized behavior and candidates for
the bad expression reject `missing_asset`.

`mode` and `reduced_motion` are mutable runtime preferences initialized from
`default_mode` and `default_reduced_motion`. They are not saved in town data or included in authoritative
state. A future general settings owner may persist them outside this contract.

## Community reaction facts and source snapshot

Community returns one sorted, bounded detached facts record containing
`schema_version`, `community_seed`, `residents`, and `places`. It does not know
the downstream presentation epoch, presenter version, or DayNight bucket.
WorldReactions wraps those facts at a committed presentation boundary to form the
Reaction Source Snapshot:

- `schema_version`: `1`
- `map_epoch`: monotonically increasing local epoch attached by WorldReactions
- `source_version`: committed gameplay state version supplied to the projector
- `absolute_hour`: canonical DayNight absolute hour attached by WorldReactions for
  bucket identity and hashing
- `local_hour`: DayNight `current_hour()` in `0..23`, attached for context only
- `community_seed`: persisted Community seed copied as inert hash material; reading
  it never advances Community RNG
- `residents`: ordered by `resident_id`
- `places`: ordered by `internal_id`

### Resident source row

- `resident_id`: stable positive integer
- `home_anchor`: nullable canonical `{x, z}`
- `composite_happiness`: finite `0..100`
- `purpose`: exact `unhoused | home | work | activity`
- `destination_anchor`: nullable canonical `{x, z}`

Moving position, proxy visibility, and journey binding are deliberately absent.
They are resolved only after a candidate survives semantic selection. Actual
route failure is a People-owned movement outcome and arrives through the blocked-
episode contract, not a guessed Community reachability field.

### Place source row

- `internal_id`: non-negative placed-building instance ID for the current map epoch
- `building_id`: stable authored catalogue ID
- `anchor`: canonical `{x, z}`
- `category`, `community_role`: authored semantic strings
- `occupied_resident_ids`: sorted unique resident IDs
- `resident_count`: non-negative integer
- `home_average_happiness`: nullable finite `0..100`
- `road_accessible`: boolean where operation uses road access
- `open_now`: boolean
- `operating`: boolean
- `capacity`, `fulfilled`, `available_capacity`: non-negative integers
- `primary_reason`: stable operation reason or empty
- `programme`: authored programme ID or empty

Residential rows may omit operation-only values through normalized defaults.
Commercial, industrial, and participant places may have zero occupants but still
carry operation state.

## Live reaction anchor

Narrow O(1) lookup result, never cached as committed state:

```text
{
  ok: bool,
  target_key: String,
  lifecycle_id: String,
  visible: bool,
  world_position: Vector3,
  state: String,
  resident_id: int | null,
  journey_id: int | null,
  blocked_reason: String | null,
  blocked_episode: int | null,
  purpose: String | null,
  waiting: bool | null,
  waiting_episode: int | null,
  wait_seconds: float | null
}
```

A failed lookup returns exactly `{ok:false, reason:"missing"}` and no success
fields. Invalid IDs and pending-only, removed, or pooled records deliberately
collapse to `missing`; the downstream resolver maps this to `target_missing`.
`target_lifecycle_mismatch` is reserved for a successful current lookup whose
source-owned lifecycle token or person/journey binding differs from the candidate
or active slot being validated.

- `People.get_reaction_anchor(resident_id)` uses the current `PersonSlot` and
  never exposes it directly.
- `CarManager.get_reaction_anchor(journey_id)` uses the current active `CarSlot`
  and never exposes pool indices or mutable waypoint arrays.
- Building anchors are derived from the current `GameState.building_registry`
  entry and rejected if its epoch/instance no longer exists.
- Every vector is finite and detached. A current People binding returns `ok: true`
  even when `visible: false`, allowing `IN_CAR` plus `journey_id` to resolve its
  car. Missing, removed, pooled, pending-only, or mismatched lifecycle records
  return `ok: false`; hidden non-car people are rejected by the downstream resolver.
- A successful People anchor supplies non-null `blocked_reason` (empty when clear),
  non-negative `blocked_episode`, and non-null `purpose`; its three waiting fields
  are null. A successful car anchor supplies non-null `waiting`, non-negative
  `waiting_episode` and `wait_seconds`; its blocked/purpose fields are null.

### People blocked episode

People increments a per-resident transient `blocked_episode` when the visual
state enters `BLOCKED` or its normalized blocked reason changes while still
blocked. A reason change publishes clear for the old episode followed by start
for the new episode; an identical repeated assignment publishes nothing. Only
the canonical route-failure reasons `disconnected`, `origin_has_no_road_access`,
`destination_has_no_road_access`, `missing_origin`, `missing_destination`, and
`route_invalidated` map to `resident_route_blocked`. Capacity/admission waiting
such as `car_pool_full` or `awaiting_traffic_admission` does not. WorldReactions
deduplicates by map epoch, resident, and episode; all episode state clears at a
map boundary.

### Ambient car subject index

`CarManager.get_reaction_subject_ids()` returns a detached ascending array of the
currently active journey IDs, with no more than the existing 256 journey slots. It
is requested at most once for each newly observed ambient hour and never from the
per-frame follow loop. Residents whose current People anchor is `IN_CAR` are
excluded from the person ambient set when their journey appears in this index, so
one visible car is not weighted twice.

## Reaction cause and default mapping

The initial finite cause set is centrally authored. This table records the
default intent; config validation prevents callers from inventing mappings.

| Cause | Expression | Priority | Speaker/target |
|---|---|---:|---|
| `resident_became_unhoused` | `concerned` | 100 | person / visible person or car |
| `resident_route_blocked` | `frustrated` | 100 | person / visible person or car |
| `vehicle_wait_threshold` | `frustrated` | 90 | car / car |
| `place_access_lost` | `frustrated` | 85 | building / building |
| `resident_happiness_rise` | `pleased` | 80 | person / visible person or car |
| `resident_happiness_drop` | `concerned` | 80 | person / visible person or car |
| `home_occupancy_gain` | `surprised` | 70 | building / building |
| `home_occupancy_loss` | `concerned` | 70 | building / building |
| `home_condition_rise` | `pleased` | 70 | building / building |
| `home_condition_drop` | `concerned` | 70 | building / building |
| `place_activity_gain` | `busy` | 70 | building / building |
| `place_activity_loss` | `concerned` | 70 | building / building |
| `programme_changed` | `surprised` | 70 | building / building |
| `place_access_gained` | `pleased` | 70 | building / building |
| `place_opened` | `busy` | 60 | building / building |
| `place_closed` | `sleepy` | 50 | building / building |
| `ambient` | contextual | 10 | eligible subject / live target |

For a home-condition candidate, contributors are residents whose non-null home is
the same in the last presented coherent snapshot and the newest coalesced coherent
snapshot. Sort them by resident ID and calculate
`aggregate_delta = sum(happiness_delta) / contributor_count`. A result at least
`+8.0` selects rise; at most `-8.0` selects drop; otherwise no home-condition
candidate is created. Occupancy gain/loss is derived separately. Diagnostics
retain contributor count, sum, mean, and the largest absolute contributor with a
resident-ID tie-break.

When `contributor_count == 0`, no division occurs and no home-condition candidate
is created. Occupancy causes compare `resident_count` only; a same-count occupant
identity swap creates no occupancy cause, while each home whose count changes in
an arrival, departure, or rehome is evaluated normally.

## Reaction candidate

Immutable semantic request before final camera/collision/cap arbitration:

- `candidate_id`: stable
  `<map_epoch>:<source_token>:<speaker_key>:<cause>` where `source_token` is
  `v<source_version>`, `blocked:<resident_id>:<episode>`,
  `wait:<journey_id>:<episode>`, or `hour:<absolute_hour>`
- `map_epoch`: current presentation epoch
- `source_kind`: exact `committed | blocked | wait | ambient`
- `source_version`: non-negative state version only for `committed`; otherwise null
- `source_episode`: only for `blocked` or `wait`, as exact detached
  `{kind, owner_id, episode}` matching the candidate's source token; otherwise null
- `time_bucket`: non-negative absolute-hour identity only for `ambient`; otherwise null
- `quiet_bucket`: non-negative committed absolute hour stamped on every candidate;
  for ambience it equals `time_bucket`, for committed diffs it comes from that
  snapshot, and for blocked/wait events it is sampled once for their presentation
  batch before candidates or ambience in that batch are processed
- `speaker_key`: `person:<resident_id> | car:<journey_id> | building:<internal_id>`
- `speaker_kind`, `speaker_id`: normalized identity components
- `target_intent`: `current_person_representation | car_journey | building_instance`
- `target_hint_id`: journey/building ID when known, otherwise nullable
- `expression`: one of the six expression keys
- `cause`: one finite configured cause
- `priority`: configured integer `0..100`
- `ttl_seconds`: configured `1.6..2.4`
- `cooldown_key`: exactly equal to `speaker_key` in schema version 1
- `deduplication_key`: source transition plus speaker/cause
- `evidence`: at most 16 JSON-safe scalar transition values for diagnostics only;
  keys are unique Strings

No texture path, atlas coordinate, gameplay effect, mutable source record, raw
node/slot reference, or localized text is permitted.

The source discriminator is strict: exactly the fields named for `source_kind`
are populated. Stale-source-version checks apply only to `committed`; episode
deduplication applies only to `blocked` and `wait`; observed-bucket checks apply
only to `ambient`. `quiet_bucket` is presentation ordering metadata and never
changes candidate identity except that ambient identity already contains the same
hour.

## Resolved reaction candidate

Immutable result of joining a valid semantic candidate to current presentation:

- every semantic candidate field unchanged
- `target_key`: concrete person/car/building key
- `target_lifecycle_id`: source-owned token validated with current `map_epoch`
- `world_position`: finite detached live anchor
- `screen_rect`: finite projected marker rectangle before configured gap expansion

Resolution failure produces a rejection record, not a partially populated resolved
candidate. Textures are still resolved only after semantic/camera selection.

## Ambient decision

One town-level decision per absolute simulation-time bucket:

- `map_epoch`
- `time_bucket`
- `local_hour`: `0..23`, used for contextual eligibility but not opportunity hash
- `seed_material_hash`: lowercase SHA-256 diagnostic digest of the canonical
  opportunity material, null exactly when suppression skips hashing; never raw RNG state
- `outcome`: exact `accepted | no_opportunity | no_eligible_subject | suppressed | rejected`
- `reason`: null only for `accepted`; otherwise one finite reason below
- `opportunity`: nullable boolean; null when suppression precedes the hash, false
  only for `no_opportunity`, and true for the remaining non-suppressed outcomes
- `eligibility_evaluated`: false only when an earlier suppression gate skips the
  subject scan; otherwise true even when `opportunity` is false
- `eligible_speaker_keys`: canonical ascending identity list after
  context, lifecycle, camera, active-ownership, and cooldown filtering and before
  hash ranking
- `subject_rejection_counts`: canonical reason-key order with non-negative counts
  for subjects excluded before ranking
- `selected_speaker_key`: nullable
- `context_key`: nullable exact ambient context key from the contract table
- `expression`: nullable context-compatible expression
- `candidate_id`: nullable

All ambient hashes use the contract's typed length-prefixed UTF-8 encoding and
SHA-256 definition. The opportunity roll uses only the Community seed and time
bucket. Subject ranking uses the same function with each canonical speaker;
expression selection additionally includes the normalized context key. Eligible
expressions are sorted lexicographically before applying the expression-hash
index. `map_epoch` is trace/lifecycle metadata and never hash material.
One bucket is exactly one committed absolute simulation hour. At most one ambient
candidate is produced per bucket, regardless of town size. A semantically valid
condition candidate suppresses ambient selection for its `quiet_bucket` and the
following bucket, even if camera/arbitration later rejects it. Cooling, active,
hidden, off-screen, lifecycle-invalid, and context-invalid subjects are removed
before subject ranking, so a lower-ranked eligible subject may win. The selected
subject is revalidated at arbitration; if it changed after ranking, the bucket is
rejected without a fallback selection or catch-up.

## Active reaction slot

Transient state owned by the renderer:

- `pool_index`: integer `0..pool_size-1`
- `candidate_id`, `speaker_key`, `target_key`, `target_lifecycle_id`
- `expression`, `cause`, `priority`
- `started_at`, `hold_until`, `expires_at`: presentation-clock values
- `phase`: `free | enter | hold | exit`
- `lane`: `base | up`; `up` is the one configured negative-screen-y translation
- `last_world_position`, `last_screen_rect`
- `preemptible`: false only for configured critical causes
- `release_reason`: nullable stable reason

Allowed transitions:

```text
free -> enter -> hold -> exit -> free
enter|hold -> exit -> free       (ordinary suppression or expiry)
enter|hold|exit -> free          (pre-emption, invalid target, map boundary, large delta)
```

Returning to `free` resets texture, modulation, transform, timing, target,
diagnostics, and visibility before the pool index is reused.

No two active slots may share a `speaker_key` or `target_key`; this prevents a
resident reaction and a vehicle-state reaction from drawing two markers on the
same visible car.

## Deduplication state

Deduplication does not retain every historical candidate ID. It consists of the
latest committed source version, one latest blocked episode per current resident,
one latest wait episode per active journey, the latest observed ambient hour, and
the current bounded arbitration batch. Resident entries are removed with their
source row; journey entries are removed on completion or cancellation; everything
clears at a map boundary. This preserves one-shot semantics without growth over a
long-lived map.

## Cooldown state

Transient dictionary keyed by `cooldown_key`:

- `until`: presentation-clock value
- `last_priority`
- `last_cause`
- `last_candidate_id`

Every candidate is rejected until expiry except a priority-100 condition. During
an atomic condition-over-ambient replacement, cooldown created by releasing the
ambient does not retroactively reject the replacing condition; the condition's
own final release writes the later cooldown. Deduplication still fires once, and
all cooldown state is cleared at map-epoch boundaries. On every presentation
update, entries with `until <= now` and entries whose speaker lifecycle no longer
exists are evicted before diagnostics or arbitration.

## Rejection and release reasons

Finite diagnostic enum:

- `invalid_candidate`
- `stale_epoch`
- `stale_source_version`
- `duplicate_candidate`
- `speaker_active`
- `target_active`
- `speaker_cooldown`
- `condition_quiet_period`
- `ambient_disabled`
- `mode_suppressed`
- `target_missing`
- `target_hidden`
- `target_lifecycle_mismatch`
- `target_offscreen`
- `target_behind_camera`
- `screen_collision`
- `visible_cap`
- `lower_priority`
- `no_opportunity`
- `no_eligible_subject`
- `invalid_context`
- `missing_asset`
- `expired`
- `preempted`
- `map_boundary`

Unknown reasons are rejected from normalized release/trace output. The exact
decision disposition enum is `selected | rejected | released | preempted`.
A `selected` decision has `reason: null`; every other disposition must use exactly
one finite reason above. Silent baseline
hydration is a batch event, not a candidate decision reason.

## Reaction asset manifest entry

One entry per semantic expression:

- `slug`, `role`, `expression`
- `motif` and semantic accent tokens
- `source_path`: high-resolution master
- `runtime_path`: individual 128×128 RGBA PNG
- `width`, `height`, `colour_mode`, `alpha_policy`
- `display_min_px: 24`, `display_typical_px: 32..40`, `display_max_px: 48`
- `pivot` and per-target offset compatibility
- `actual_size_proof`, `grayscale_proof`, `noisy_context_proof`
- `approved`: boolean

Every configured expression must resolve to one approved manifest entry. Runtime
files remain individual sources of truth; any later atlas has separate generated
region metadata.

## Reaction diagnostic trace

Detached bounded record retaining the latest 64 eventful presentation-update
batches. A no-op update appends nothing. An update appends exactly one batch after
processing when it establishes a baseline, applies an input/presentation-mode
transition, semantically rebinds/changes lane/releases/expires an active slot,
derives a condition, or
observes an ambient bucket. `event_kinds` is an ordered unique array using this
exact order: `baseline`, `input_mode`, `presentation_config`, `active_follow`,
`active_expiry`, `condition`, `ambient`.

Ordinary position-only target following appends no batch. `active_follow` means a
semantic target rebind, lane change, ownership convergence, lifecycle invalidation,
or collision-driven release.

- `schema_version`, `map_epoch`, `source_version`, `absolute_hour`, `local_hour`
- `event_kinds`
- `config_digest`, `presentation_mode`, `reduced_motion`
- `source_counts`: residents, places, blocked episodes, wait episodes
- `candidates`: stable semantic summaries with canonical batch-local
  `trace_ordinal`, sharing the batch's combined record cap. Each contains exactly
  `trace_ordinal`, `candidate_id`, `map_epoch`, `source_kind`, nullable
  `source_version`, nullable normalized `source_episode`, nullable `time_bucket`,
  `quiet_bucket`, `speaker_key`, `target_intent`, nullable `target_hint_id`,
  `expression`, `cause`, `priority`, `ttl_usec`, `cooldown_key`,
  `deduplication_key`, and `evidence_fields`. `ttl_usec` uses
  `floor(ttl_seconds * 1_000_000 + 0.5)`. `evidence_fields` is key-sorted and each
  entry is exactly `{key, type, value}` where type is
  `int | string | bool | milli | null`; booleans encode as integer `0|1`, finite
  floats use signed thousandths rounded half away from zero, and null uses an empty
  String value
- `decisions`: ordered records sharing the same cap, each containing exactly
  `trace_ordinal`, `candidate_id`, `disposition`, `reason`, nullable `target_key`,
  and `decision_at_usec = floor(presentation_seconds * 1_000_000 + 0.5)`.
  Selection records admission time; rejection records rejection time; later
  `released`/`preempted` records preserve the final semantic end time after the
  active summary disappears
- `active_slots`: at most five normalized summaries ordered by priority descending,
  `started_at_usec` ascending, then candidate ID ascending. Each contains exactly
  `candidate_id`, `speaker_key`, `target_key`, `target_lifecycle_id`, `expression`,
  `cause`, `priority`, `phase`, `lane` (`base | up`), `started_at_usec`,
  `hold_until_usec`, and `expires_at_usec`; timestamps use
  `floor(seconds * 1_000_000 + 0.5)`. Pool index, texture/resource identity, world
  position, and screen rectangle are excluded
- `cooldowns`: at most the first 128 unexpired summaries in speaker-key order;
  each contains exactly `speaker_key`, `until_usec`, `last_priority`, `last_cause`,
  and `last_candidate_id`, with `until_usec = floor(until_seconds * 1_000_000 + 0.5)`
- `ambient_decision`: optional normalized record
- `timings_usec`: excluded from deterministic trace comparison
- `omitted_candidate_count`, `omitted_decision_count`, `omitted_digest`: deterministic
  truncation metadata; `candidates.size() + decisions.size()` is at most 128 and
  omitted records are digested in canonical cross-list order
- `omitted_cooldown_count`, `omitted_cooldown_digest`: deterministic metadata for
  cooldown summaries after the first 128

All omission digests use contract `D(parts...)`; no implementation-dependent JSON
or Dictionary ordering participates.

Normalized replay comparison excludes timings, raw unsnapped transforms, node
IDs, and wall-clock timestamps. It retains candidate/decision/target identity,
expression, cause, priority, map epoch, source version/bucket, and lifecycle phase.
