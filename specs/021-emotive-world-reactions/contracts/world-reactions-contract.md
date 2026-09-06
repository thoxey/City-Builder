# Contract: Emotive World Reactions

## Authority boundary

`WorldReactions` is a presentation consumer. It may read detached projections,
resolve live presentation anchors, maintain transient view/cooldown state, and
emit diagnostics. It must never submit simulation intents, write `DataMap`,
change GameState registries, consume gameplay RNG, or publish a reaction as a
gameplay fact.

The following must be byte-equivalent with mode `full`, `conditions_only`, and
`off`: normalized save payload, gameplay snapshot/hash, transaction ledger,
Community RNG state, resident assignments/qualities/happiness, car routes and
claims, cash/demand, and progression receipts.

## Plugin and projection contract

The downstream plugin is named `WorldReactions`. Its implementation dependencies
are:

```text
Community
People
CarManager
DayNight
ProjectionRegistry
PresentationScheduler
PerformanceMonitor
```

The list is exact; BuildingCatalog and Builder are not dependencies. `GameState`
remains a global autoload read for current building-registry lifecycle, not a
PluginManager dependency. WorldReactions listens to
`GameEvents.player_input_mode_changed` and map lifecycle events.

The plugin registers an operational projection named
`world_reactions.conditions` for `clock`, `structures`, `topology`, `occupancy`,
and `community`. Traffic waiting arrives through the generic episode transition,
not projection invalidation. The projection returns the normalized Reaction Source
Snapshot from `data-model.md`, with deterministic resident/place ordering and no
moving positions or verbose effect explanations.

Community exposes the raw-facts seam:

```gdscript
func get_world_reaction_source_facts() -> Dictionary
```

Its top-level record contains only `schema_version`, the inert persisted
`community_seed`, and sorted resident/place rows. Reading the seed does not read
or advance Community RNG state. The registered WorldReactions projector receives
`(source_version, dependency_revisions)` from ProjectionRegistry, calls this
Community method, and attaches WorldReactions' local `map_epoch`, the supplied
`source_version`, DayNight's `get_absolute_hour()` as `absolute_hour`, and
DayNight's `current_hour()` as `local_hour`. Community therefore
has no reverse dependency on WorldReactions or presentation lifecycle state.

First projection in a map epoch is baseline-only:

```text
previous == null -> store current; emit []
previous.map_epoch != current.map_epoch -> clear/store current; emit []
otherwise -> diff previous/current; store current; emit candidates
```

On boot, map load, map clear, and reconstruction, WorldReactions increments its
local epoch, releases every marker, clears candidates, cooldowns, blocked/wait
episode memory, and deduplication, then establishes the next projection silently.
ProjectionRegistry clears runtime projection cache and PresentationScheduler
resets its pending and latest-presented version state at the same boundary, before
the new epoch's deferred baseline, so repeating GameState versions cannot reuse
or suppress a new town's projection.

Lifecycle-event admission starts disabled on boot and closes as soon as the
authoritative `map_load` or `map_clear` change set is observed, before the
compatibility `map_loaded` signal. People and CarManager reset/reconstruct their
episode state without publishing start events. During the deferred silent source
baseline, WorldReactions reads all resident anchors and the bounded active-car
list once, marks any already-blocked/already-waiting episode observed, and starts
no timer or candidate. Event admission opens only after this baseline completes;
only a subsequent runtime episode can react. Direct reconstruction uses the same
gate and baseline procedure.

WorldReactions registers its scheduler presenter with an always-true semantic
visibility callable. Input mode and presentation mode suppress view admission,
not projection delivery, so committed snapshots continue to advance the silent
baseline while the feature is focused or `off`; the presenter must never enter
`DIRTY_HIDDEN` for those modes.

## Live anchor APIs

People exposes:

```gdscript
func get_reaction_anchor(resident_id: int) -> Dictionary
```

Successful shape:

```text
ok: true
target_key: "person:<resident_id>"
lifecycle_id: "person:<resident_id>"
visible: bool
world_position: finite Vector3 using current display_position
state: PersonSlot semantic state name
resident_id: int
journey_id: int | null
blocked_reason: stable String
blocked_episode: non-negative int
purpose: stable String
```

CarManager exposes:

```gdscript
func get_reaction_anchor(journey_id: int) -> Dictionary
func get_reaction_subject_ids() -> Array[int]
```

Successful shape:

```text
ok: true
target_key: "car:<journey_id>"
lifecycle_id: "car:<journey_id>"
visible: true
world_position: finite current display position
state: "moving" | "waiting"
journey_id: int
resident_id: int | null
waiting: bool
waiting_episode: non-negative int
wait_seconds: non-negative float
```

Both successful shapes are normalized to the union in `data-model.md`: fields
owned by the other target kind are present as null. Required kind-specific fields
above are never null.

People returns `ok:true, visible:false` for a current hidden binding, including
`IN_CAR`, so the resolver can inspect its exact journey. A hidden person without a
valid current car is later rejected as `target_hidden`. Either API returns a
detached exact `{ok:false, reason:"missing"}` with no success fields for invalid,
pending-only, removed, or pooled records; this maps to `target_missing`.
`target_lifecycle_mismatch` occurs only after an `ok:true` lookup when its current
token or exact person/journey binding differs from the candidate/active binding.
The APIs never return mutable slots,
transforms, waypoints, pool indices, or internal dictionaries. Lookup is O(1).

`get_reaction_subject_ids()` returns ascending active journey IDs only, contains
at most 256 entries, and is called at most once per newly observed ambient hour.
It does not construct the full traffic diagnostic snapshot. When a listed journey
represents a resident whose People state is `IN_CAR`, the resident is excluded
from the person ambient set so that visible car has one ambient speaker.

Lifecycle IDs are source-owned tokens and do not contain the downstream reaction
epoch. WorldReactions validates them together with its own `map_epoch`, the exact
resident/journey binding, and the current lookup result. Journey IDs are monotonic
within a map; both source indexes are cleared at map boundaries.

A person speaker resolves in this order:

1. if People says `IN_CAR` with a valid journey, resolve that exact car;
2. else if People returns a visible person, use the person target;
3. else reject `target_hidden` or `target_missing`.

If the resident enters/leaves a car while active, the next update rebinds to the
exact matching representation while retaining speaker/cooldown identity. If no
exact current representation resolves on that update, release rather than hold a
stale anchor. Rebinding never changes `candidate_id`, restarts lifetime, or moves
cooldown ownership.

Buildings resolve from `(map_epoch, internal_id)` and the current registry
anchor. Missing or replaced instances fail lifecycle validation even when a new
building occupies the same cell.

## People blocked episode contract

People centralizes entry to and exit from `PersonSlot.VisualState.BLOCKED`. It
increments a transient per-resident episode on non-blocked -> blocked and whenever
the normalized blocked reason changes while remaining blocked, and emits generic
presentation transitions:

```text
blocked_started(resident_id, blocked_episode, blocked_reason)
blocked_cleared(resident_id, blocked_episode, blocked_reason)
```

On a reason change, People emits `blocked_cleared` for the old episode before
`blocked_started` for the incremented episode; assigning the same normalized reason
again emits nothing. WorldReactions maps a start to `resident_route_blocked` only when reason is one
of `disconnected`, `origin_has_no_road_access`,
`destination_has_no_road_access`, `missing_origin`, `missing_destination`, or
`route_invalidated`. It ignores capacity/admission waits including
`car_pool_full` and `awaiting_traffic_admission`. The tuple
`(map_epoch, resident_id, blocked_episode)` cannot fire twice. Clear, resident
removal, route recovery, reason change, load, or reset closes the episode; only a
later state/reason episode rearms it. This guarantees that a change from an ignored
capacity/admission reason to a canonical route-failure reason is observable without
teaching People the downstream allowlist. People owns movement truth but knows no
reaction expression or priority.

## Waiting episode contract

CarManager centralizes changes to `CarSlot.waiting` and exposes a generic
presentation transition:

```text
waiting_started(journey_id, resident_id, waiting_episode)
waiting_cleared(journey_id, resident_id, waiting_episode)
```

The episode increments only on `false -> true`. WorldReactions starts its own
presentation timer for that episode. At 1.5 continuous real seconds it creates
one `vehicle_wait_threshold` candidate. The tuple
`(map_epoch, journey_id, waiting_episode)` cannot fire twice. Clearing, completion,
cancellation, load, or reset discards the timer and rearms only a later episode.
Traffic owns the boolean; it does not know reaction thresholds or expressions.

## Condition derivation contract

All diffs compare the last presented coherent projection with the newest coalesced
coherent projection in stable ID order. Intermediate commits deliberately do not
create hidden candidates. Exactly equal source versions/rows emit no duplicate;
out-of-order source versions are rejected.

| Transition | Eligibility | Cause | Expression | Priority |
|---|---|---|---|---:|
| home becomes null / homeless begins | false -> true | `resident_became_unhoused` | `concerned` | 100 |
| People route-blocked episode | enters canonical route-failure reason | `resident_route_blocked` | `frustrated` | 100 |
| car waiting episode | first reaches 1.5 s | `vehicle_wait_threshold` | `frustrated` | 90 |
| place road access | true -> false | `place_access_lost` | `frustrated` | 85 |
| resident happiness delta | `>= +8.0` | `resident_happiness_rise` | `pleased` | 80 |
| resident happiness delta | `<= -8.0` | `resident_happiness_drop` | `concerned` | 80 |
| home occupancy count | increases | `home_occupancy_gain` | `surprised` | 70 |
| home occupancy count | decreases | `home_occupancy_loss` | `concerned` | 70 |
| occupied-home average happiness | `>= +8.0` | `home_condition_rise` | `pleased` | 70 |
| occupied-home average happiness | `<= -8.0` | `home_condition_drop` | `concerned` | 70 |
| place fulfilled/activity | `0 -> >0` | `place_activity_gain` | `busy` | 70 |
| place fulfilled/activity | `>0 -> 0` | `place_activity_loss` | `concerned` | 70 |
| programme | ID changes | `programme_changed` | `surprised` | 70 |
| place road access | false -> true | `place_access_gained` | `pleased` | 70 |
| open state | false -> true | `place_opened` | `busy` | 60 |
| open state | true -> false | `place_closed` | `sleepy` | 50 |

An initial row, a removed row, a value below threshold, or an unchanged transition
emits no condition candidate. Resident arrival, departure, or rehome may change a
home's occupancy and provide bounded evidence for that building transition, but
an initial or removed resident row never independently creates a person reaction
and no roster event bypasses source-version deduplication.

For a multi-resident home, contributors are residents whose non-null home is the
same in the last-presented and newest-coalesced snapshots, ordered by resident ID. Divide their signed
happiness-delta sum by contributor count. A mean at least `+8.0` chooses rise; a
mean at most `-8.0` chooses drop; any value between creates no home-condition
candidate. Occupancy gain/loss is derived separately. Diagnostics retain count,
sum, mean, and the largest absolute contributor with resident-ID tie-break.

If contributor count is zero, do not divide and emit no home-condition candidate.
Occupancy causes compare count only: a same-count resident-ID swap emits no
occupancy cause, while arrival, departure, or rehome evaluates every affected
home whose count actually changes.

Multiple candidates for one speaker/source version are sorted by priority then
cause. Only the highest eligible candidate enters arbitration; every other
candidate receives `rejected / lower_priority` in that canonical order so the
trace explains the complete derived set. A render target
may host only one marker even when different speakers (for example, a resident
and their car) resolve to it; the same total ordering chooses the winner.

## Candidate and deduplication contract

Every semantic candidate validates its pre-resolution schema and current
configuration before anchor lookup. Successful lookup and camera projection
produce the complete immutable Resolved Reaction Candidate from `data-model.md`;
resolution failure produces only a rejection record. Semantic IDs use:

```text
condition candidate_id = <epoch>:v<version>:<speaker_key>:<cause>
blocked candidate_id   = <epoch>:blocked:<resident>:<episode>:person:<resident>:resident_route_blocked
waiting candidate_id   = <epoch>:wait:<journey>:<episode>:car:<journey>:vehicle_wait_threshold
ambient candidate_id   = <epoch>:hour:<absolute_hour>:<speaker_key>:ambient
```

Candidate IDs are unique within the map epoch. Deduplication is applied before
cooldown and recorded as `duplicate_candidate`. Texture paths and atlas cells are
resolved only after semantic selection.

The `source_kind` validity matrix is exact:

| `source_kind` | `source_version` | `source_episode` | `time_bucket` |
|---|---|---|---|
| `committed` | non-negative | null | null |
| `blocked` | null | `{kind:"blocked", owner_id:resident_id, episode}` | null |
| `wait` | null | `{kind:"wait", owner_id:journey_id, episode}` | null |
| `ambient` | null | null | non-negative absolute hour |

Every candidate also has a non-negative `quiet_bucket`. A committed candidate
uses the wrapped snapshot's absolute hour; an ambient candidate uses its own
`time_bucket`. Blocked starts, wait starts/clears, and wait-threshold crossings are
queued as lifecycle facts. At the start of the next presentation batch,
WorldReactions samples the currently committed DayNight absolute hour once, stamps
every queued episode candidate in that batch with that hour, derives all condition
candidates, updates the quiet-through bucket, and only then evaluates ambience.
Thus an episode on an hour boundary always suppresses that batch's hour and the
following hour regardless of signal connection order.

Deduplication is compact rather than an unbounded candidate-ID set: retain only
the latest committed version, latest episode per current resident or active
journey, latest observed ambient hour, and IDs in the current bounded batch.
Remove resident/journey entries with their lifecycle and clear all entries at a
map boundary.

A newly observed building row hydrates silently and emits no `building_placed`
candidate. While input mode is `placement`, the source baseline still advances
but all derived candidates are discarded. Builder's existing 3.2-second feedback
remains unchanged and is the sole placement announcement; WorldReactions neither
depends on Builder nor consumes a placement claim. A distinct committed condition
transition first observed after return to `world` remains eligible.

## Arbitration contract

Given candidate array, live active slots, cooldown map, camera, mode, and config:

1. copy and base-sort input by safe String candidate ID (missing/non-String as
   empty), speaker key, then cause, so validation rejections ignore caller order;
   records tied on all three serialize to the same invalid summary;
2. apply rejection precedence exactly: `invalid_candidate`, `stale_epoch`,
   `stale_source_version` (committed only), `duplicate_candidate`,
   `mode_suppressed`, `ambient_disabled`, then `missing_asset`;
3. resolve each survivor once into a concrete current target/lifecycle and apply
   `target_missing`, `target_lifecycle_mismatch`, then `target_hidden`;
4. validate the finite world anchor and project the base rectangle, applying
   `invalid_candidate`, `target_behind_camera`, then coarse `target_offscreen`;
5. order survivors by descending priority, then cause, speaker key, target key,
   and candidate ID ascending;
6. apply per-speaker cooldown (critical priority 100 may bypass cooldown but not
   deduplication);
7. test the base rectangle, then exactly one rectangle translated by screen-space
   `(0, -config.vertical_lane_offset_px)` (upward in Godot viewport coordinates;
   default 56 px). Expand a non-critical rectangle by
   `config.marker_screen_padding_px` per side (default 8 px) before both
   intersection and viewport tests; that expanded rectangle must remain inside
   the viewport inset by `config.viewport_margin_px` (default 12 px);
8. build admission plans over the at-most-five active slots. An ambient candidate
   may evict none. A condition may evict active ambience that blocks speaker or
   target ownership, both lane choices, or a full cap. A priority-100 condition
   may additionally evict lower-ranked non-critical conditions. Other ownership,
   collision, and cap conflicts are ineligible plans;
9. choose a plan with the fewest victims; if tied, prefer the plan whose victim
   sequence is lowest-ranked, where victim order is ascending priority, latest
   `started_at`, then lexicographically greatest `candidate_id`; if still tied,
   prefer the base lane. Fully release/reset the chosen victims in that order and
   bind the candidate atomically;
10. a priority-100 candidate may overlap only a remaining priority-100 marker when
   no legal separated plan exists, but it never bypasses ownership or the cap;
11. if no plan exists, reject by exactly this precedence: unavoidable speaker
    ownership -> `speaker_active`; target ownership -> `target_active`; neither
    lane inside the safe viewport -> `target_offscreen`; unresolved geometric
    overlap -> `screen_collision`; full cap -> `visible_cap`. `lower_priority` is
    reserved for the same-speaker/source grouping losers defined above.

The active hard cap is always five and the warm pool cap is always eight for this
feature. Exhaustive admission-plan evaluation is bounded to two lane choices and
subsets of at most five active slots. It makes condition-over-ambient behavior the
same for ownership, collision, and cap conflicts and releases no unnecessary
victim. At follow time, active markers are ranked by descending priority, earliest
start, then lexicographically smallest candidate ID. The lower-ranked conflicting
marker tries its still-unused configured upward lane once for geometric overlap; if separation
remains invalid it exits, except that two priority-100 markers retain the same
allowed critical/critical overlap. If two active bindings converge on one speaker or target
after a representation handoff, the lower-ranked slot releases immediately because
a lane cannot repair ownership. A condition therefore survives an ambient follow conflict, and a
priority-100 condition survives a non-critical condition conflict. Lane choice
never oscillates or resets during one reaction lifetime.

Cooldown begins on final release and defaults to 10 seconds. Every candidate is
suppressed until expiry except a priority-100 condition. A new waiting episode has
a new candidate/deduplication identity but retains `car:<journey>` as its stable
speaker/cooldown key. During atomic condition-over-ambient replacement, cooldown
created by the ambient release does not retroactively reject the replacing
condition; that condition writes its own cooldown on final release.

On every presenter/frame update, cooldown storage evicts entries with
`until <= presentation_now` and entries for speakers whose source lifecycle no
longer exists. Diagnostic reads apply the same expiry/lifecycle predicate before
copying, even when no candidate batch ran. Storage clears at map boundaries and
never serves as historical reaction storage.

## Ambient contract

One bucket equals one committed absolute simulation hour. With the automatic
120-second day, a bucket is normally five real seconds. The default opportunity
probability is `625 / 1000`, giving an expected town-wide interval of eight real
seconds before context/quiet/cap suppression and satisfying the 6–10 second band.

`H(parts...)` is fully specified as follows. Encode each integer part as lowercase
type tag `i`, a colon, the byte length of its base-10 ASCII value (zero is `0`,
no leading zeroes), another colon, and those ASCII bytes. Encode each String part
the same way with type tag `s` and its unmodified UTF-8 byte length/content.
Concatenate encoded parts with no separator, calculate SHA-256, clear the high bit
of digest byte 0, and interpret digest bytes 0–7 as one non-negative big-endian
63-bit integer. Unsupported part types are invalid input; no locale, String hash,
ObjectID, map epoch, or random stream participates.

```text
opportunity_roll = H(community_seed, absolute_hour, "opportunity") % 1000
opportunity = opportunity_roll < config.ambient_chance_per_thousand_per_hour
```

The schema-version-1 default threshold is 625; values from 0 through 1000 remain
valid presentation tuning. The release frequency gate always runs the default.

Each newly observed bucket produces exactly one normalized `Ambient Decision`.
Apply this first-outcome order before creating a candidate:

1. non-`world` input -> `suppressed / mode_suppressed`;
2. presentation mode other than `full` -> `suppressed / ambient_disabled`;
3. `absolute_hour <= quiet_through_bucket` ->
   `suppressed / condition_quiet_period`;
4. otherwise compute both the opportunity hash and the eligible-subject scan;
5. false opportunity hash -> `no_opportunity / no_opportunity`;
6. opportunity true but no eligible subject ->
   `no_eligible_subject / no_eligible_subject`;
7. selected candidate fails revalidation or arbitration -> `rejected` with the
   first applicable finite reason;
8. visible admission -> `accepted / null`.

Suppression precedes hashing and records `opportunity: null`; `no_opportunity`
records false; every later outcome records true. Suppressed decisions set
`seed_material_hash: null`, `eligibility_evaluated: false`, and an empty eligible
list; every unsuppressed
decision sets it true and populates eligibility even when the roll is false.
Opportunity counts include only true rolls after the three suppression gates.
Rejected counts include every true opportunity not accepted, grouped by final
reason; suppressed and no-opportunity counts remain separate.

For every unsuppressed decision, derive current on-screen subjects and apply one
subject exclusion in this order: critical/blocked/unhoused/inaccessible/waiting or
unmatched semantic context -> `invalid_context`; missing target -> `target_missing`;
lifecycle mismatch -> `target_lifecycle_mismatch`; hidden -> `target_hidden`;
behind camera -> `target_behind_camera`; off-screen -> `target_offscreen`; active
speaker -> `speaker_active`; active target -> `target_active`; unexpired cooldown
-> `speaker_cooldown`. Record counts in finite-reason order. This prefilter
allows the next hashed eligible subject to win instead of losing a bucket merely
because a higher-ranked ineligible subject exists. Sort survivors by:

```text
H(community_seed, absolute_hour, speaker_key, "subject")
then speaker_key
```

and choose at most the first candidate. After rejecting blocked, waiting,
unhoused, inaccessible, hidden, or otherwise negative subjects, context mapping
uses the first applicable row in this finite table:

| Exact context key | Eligibility | Sorted expression set |
|---|---|---|
| `person_home_night` | state `at_home`, purpose `home`, during night | `pleased`, `sleepy` |
| `person_travelling` | state `walking_to_stop`, `walking_route`, or `walking_from_stop` | `busy`, `surprised` |
| `person_work_activity` | state `at_destination`, purpose `work` or `activity` | `busy`, `pleased` |
| `car_moving` | active car is moving | `busy`, `pleased` |
| `building_occupied_home` | category is residential and resident count > 0 | `busy`, `pleased` |
| `building_vacant_home` | category is residential and resident count == 0 | `sleepy` |
| `building_open_operating` | non-residential place is open and operating | `busy`, `pleased` |
| `building_closed_inactive` | non-residential place is closed or inactive | `sleepy` |

A contradictory or unmatched context has no ambient beat. `night` is the pure
derived predicate `local_hour >= 21 || local_hour < 6`. `absolute_hour` remains
the bucket/hash input; `local_hour` is context only, and neither creates a second clock.

For the selected subject, normalize the applicable context to the exact context
key used by the matrix above, sort its eligible expression keys lexicographically,
and choose:

```text
expression_index = H(community_seed, absolute_hour, speaker_key,
                     context_key, "expression") % eligible_expression_count
```

An empty expression set excludes that subject as `invalid_context`. This third
stable hash is not a random stream. Revalidate the chosen subject immediately
before arbitration. If its context, target, ownership, or cooldown changed, reject
the decision with the corresponding reason; do not fall back to another subject.

Every semantically valid condition candidate sets
`quiet_through_bucket = max(quiet_through_bucket, candidate.quiet_bucket + 1)`
before ambient evaluation, even if that condition is later rejected by camera,
cooldown, or cap. Ambient is disabled outside `full`, during focused modes, and
through that inclusive quiet bucket. Every observed or suppressed bucket is
discarded permanently; no fallback, catch-up queue, or resume burst exists.

At a map boundary, the current absolute-hour bucket is marked observed during the
silent baseline and cannot produce an immediate replay. Because `map_epoch` is
excluded from all three ambient hashes, the same seed, semantic context, target
identities, and future absolute hour produce the same opportunity, subject, and
expression after reload.

For each seed, the quiet-town frequency runner first advances exactly 60 seconds
of fixed-step presentation time as excluded warm-up, then measures exactly 1,800
seconds (`--duration-minutes=30`). These are elapsed presentation/real seconds,
not simulation-clock minutes; under the automatic 120-second day the measured
window spans 15 simulation days. The gate sums measured fixed-step seconds during
each recorded bucket's interval—from its commit to the next bucket commit or the
measurement boundary—only when that bucket decision has
`eligibility_evaluated:true` and a non-empty `eligible_speaker_keys` snapshot.
Partial first/final intervals contribute only their measured overlap. The runner
does not rescan residents or cars between buckets. The score is
`eligible_observation_seconds / accepted_ambient_count` across all ten seeds;
zero accepted beats fails. The aggregate must be between 6.0 and 10.0 seconds,
inclusive, and the report also records opportunity, rejection, and accepted counts.

## Presentation and input contract

World reactions render only in input mode `world`. Modes `radial`, `placement`,
`demolition`, `inspection`, and `modal` accept no new reactions. On entry, active
flags release and reset with `mode_suppressed` by the next presenter/frame update;
ordinary final-release cooldown is written. Map reset is the sole exception and
clears cooldowns. Candidate derivation, source baselines, episode fired state,
cooldowns, presentation time, and observed ambient buckets continue advancing
while suppressed. A wait episode that crosses 1.5 seconds is derived and discarded
exactly once, so it cannot appear on return. On return, only new candidates are eligible.

The marker is a camera-facing `Sprite3D` using the approved texture, target-kind
offset, fixed apparent 24–48 px range, viewport margin of at least 12 px, and
the same deliberate no-depth-test UI treatment proven by placement feedback.
It does not receive input or alter mouse filtering.

Normal motion may use one bounded enter scale/settle, vertical ease, hold, and
opacity exit. Reduced motion uses only target following and opacity. Both share
the same semantic start/expiry and finish between 1.6 and 2.4 seconds, default
2.0. A large delta skips directly to the correct final release state.

Every pool release resets visibility, texture, modulation, transform, target,
timers, lane choice, and diagnostic metadata. Missing texture suppresses that
candidate with `missing_asset`; no substitute expression is allowed.

## Configuration API contract

WorldReactions exposes read-only normalized config plus:

```gdscript
func set_presentation_mode(mode: String) -> bool
func get_presentation_mode() -> String
func set_reduced_motion(enabled: bool) -> void
func is_reduced_motion() -> bool
```

Valid modes are `full`, `conditions_only`, and `off`. Setters change only
transient presentation config and invalidate `presentation_config`. They do not
write DataMap or create a new settings screen in this feature. A
`full -> conditions_only` transition releases active ambience with
`ambient_disabled` by the next
update while leaving active conditions alone. Any transition to `off` releases
all active reactions with `mode_suppressed` by the next update. Returning to a
more permissive mode replays nothing. `set_presentation_mode` returns false and
changes no state for an invalid string. Changing reduced motion updates each
active view in place without changing candidate identity, start/expiry, phase, or
cooldown; its authored default is false.

Schema version 1 requires exact values `visible_cap = 5`, `pool_size = 8`,
`happiness_delta_threshold = 8.0`, `vehicle_wait_threshold_seconds = 1.5`,
`ambient_quiet_buckets_after_condition = 1`, `cooldown_key == speaker_key`, and
the canonical cause-to-expression, speaker/target-kind, and priority mappings.
Candidate lifetime outside `1.6..2.4` is invalid,
not clamped. Invalid authored content activates the documented built-in
`conditions_only` fallback and must fail release validation.

That global fallback is limited to structural rule/config errors, including a
missing one of the six expression mapping keys. After those keys validate, a
missing or unapproved manifest entry or unreadable mapped PNG rejects only the
affected candidate as `missing_asset`; it does not switch mode or disable other
expressions/ambient contexts. Config `target_offsets` are the sole runtime offset
authority; manifest pivot/bounds compatibility may validate them but never
override them. Each is an exact `{x,y,z}` finite-float record; defaults are
`person={x:0.0,y:0.75,z:0.0}`, `car={x:0.0,y:1.0,z:0.0}`, and
`building={x:0.0,y:3.0,z:0.0}`, with the ranges declared in `data-model.md`.

## Diagnostic contract

`get_reaction_diagnostics()` returns the bounded detached trace from
`data-model.md`. Decision reason is exactly one of the declared finite codes.
It retains the latest 64 eventful presentation-update batches; a no-op update
appends none, and one update appends at most one after all work. Ordered
`event_kinds` use the data-model enum. Within an update, trace ordinals follow:
input/presentation releases; active target/ownership/follow releases; expiries;
condition candidates and their arbitration; then ambient decision/candidate and
arbitration. Each category uses active rank or candidate total order. A map
boundary clears old diagnostics after releasing old views, so its old-map release
records are not retained; the new epoch's silent baseline is the first retained
`baseline` batch.

Candidate and decision arrays share
one cap of at most 128 canonically cross-ordered records per batch; overflow
reports deterministic per-kind omitted counts and a digest of all omitted records
in that same order. Each normalized record has a batch-local `trace_ordinal` from
the canonical pipeline; combine and sort by ordinal, record kind (`candidate`
before `decision`), then candidate ID before retaining the first 128. Cooldowns
are independently sorted by speaker key and retain at most 128 summaries; overflow
reports `omitted_cooldown_count` and `omitted_cooldown_digest`.

Digest construction is portable. `D(parts...)` uses the same typed
length-prefixed integer/String encoding as ambient `H`, but returns the full
lowercase SHA-256 hex digest without clearing or truncating bits. Feed each omitted
candidate as (`"candidate"`, trace ordinal, candidate ID, map epoch, source kind,
source version or `-1`, episode kind or empty, episode owner/number or `-1`, time
bucket or `-1`, quiet bucket, speaker key, target intent, target hint or `-1`,
expression, cause, priority, TTL microseconds, cooldown key, deduplication key,
evidence-field count, then every key/type/value from the canonical evidence array);
each omitted decision as (`"decision"`, trace ordinal, candidate
ID, disposition, reason or empty, target key or empty, decision-at microseconds);
and each omitted cooldown
as (`"cooldown"`, speaker key, expiry microseconds, last priority, last cause,
last candidate ID). Expiry microseconds are `floor(until_seconds * 1_000_000 +
0.5)`. Concatenate those typed parts in the declared retained-order continuation;
an empty omitted sequence uses SHA-256 of zero bytes. No locale or JSON/dictionary
serialization participates.
Decision disposition is exactly `selected | rejected | released | preempted`.
`selected` uses `reason: null`; every other disposition uses exactly one declared
reason. Every decision contains `decision_at_usec`, rounded from presentation
seconds with the same microsecond rule as cooldown expiry; a later release or
pre-emption therefore retains semantic end time after its active slot disappears.
Baseline hydration is recorded as a
batch event rather than inventing a rejection reason.
Sorted normalized trace excludes wall-clock timestamps, raw timing samples, raw
transforms, ObjectIDs, and pool memory addresses.

The existing Playtest snapshot may include this diagnostic projection in debug
builds. No new mutation command is added, and release builds remain inert when
diagnostics are not requested.

## Performance contract

Instrumentation boundaries:

```text
world_reactions.source_projection
world_reactions.arbitration
world_reactions.anchor_follow
world_reactions.render_submit
```

At 500 represented residents, 256 active/pending car journeys, 135 buildings,
and five active markers on the declared reference environment:

- source projection p95 is at most 4 ms per committed projection or tagged profile probe;
- arbitration p95 is at most 1 ms per candidate batch;
- anchor following p95 is at most 500 µs per rendered frame;
- render submission p95 is at most 500 µs per rendered frame;
- no marker view allocations occur after warm-up; and
- rendered frame median/p95/maximum are at most 16,700/25,000/50,000 µs; and
- median rendered frame time and median FPS regress by no more than 5%.

Run at least three matched `full`/`off` comparisons. Each run excludes exactly
120 warm-up frames, measures at least 600 rendered frames, and retains at least
120 samples for every feature boundary; falling below any minimum invalidates the
run. Measurements use nearest-rank percentiles and include workload counts, raw
samples, exclusions, allocation counts, and authority hashes. Full resident
explanations and full traffic violation snapshots are forbidden inside these
boundaries.

In the dedicated `max_supported` profile only, the runner schedules and tags one
detached maximum-workload source projection and one greater-than-cap arbitration
batch every five measured frames in both `full` and matched `off`. Probe work is
included in frame totals, writes no authority, and produces exactly 120 samples of
each event-driven boundary over the minimum 600 frames. Every non-profile and
ordinary-play path disables these probes.

## Asset contract

The manifest contains exactly one approved runtime entry for each of:

```text
pleased
concerned
frustrated
surprised
busy
sleepy
```

Assets share a recognisable irregular speech-flag carrier; use parchment
`#E7D3AD`, near-black ink `#171713`, and established semantic accents. Meaning is
encoded by shape/gesture/mark as well as colour. No text, generated letters,
gradient, drop shadow, border rim, watermark, signature, or copied pixel face is
allowed.

Each entry retains a high-resolution source master and an individual 128×128
lossless sRGB RGBA runtime PNG with clean straight alpha. Proofs include exact
24/32/40/48 px sizes, grayscale, light/dark calm backgrounds, and noisy gameplay
at all declared viewports. Runtime atlas generation is out of scope unless
profiling produces recorded evidence that it is necessary.
