# Implementation Plan: Emotive World Reactions

**Branch**: `021-emotive-world-reactions` *(planning identifier; no branch created)* | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/021-emotive-world-reactions/spec.md`

## Summary

Add a bounded, presentation-only `WorldReactions` plugin that turns committed
Community/building transitions plus transient People route-block and traffic wait episodes into
short-lived semantic reaction candidates. The plugin compares versioned,
lightweight source snapshots, resolves only selected live person/car/building
anchors, applies deterministic priority, cooldown, camera, collision, and
five-visible arbitration, then renders approved speech-flag art through a pool
of at most eight `Sprite3D` views.

Community remains the authority for resident and place conditions, People and
CarManager remain the owners of their MultiMesh presentation state, and Builder
remains the building command and placement-feedback owner. Reactions never feed
back into those systems. Sparse ambience is selected once per coarse absolute
simulation-time bucket from a town-wide deterministic budget using the existing
persisted Community seed; it never reads or advances gameplay RNG.

## Technical Context

**Language/Version**: GDScript 4.x on Godot 4.6.2; JSON presentation rules and
manifest metadata; 128 px RGBA PNG runtime art

**Primary Dependencies**: Existing `PluginBase`/`PluginManager` dependency
injection, `GameEvents`, `GameState`, Community, People, CarManager, DayNight,
SimulationTransaction, PresentationScheduler, ProjectionRegistry,
PerformanceMonitor, GUT 9.3.0, MultiMesh presentation, `Sprite3D`, `Camera3D`,
and the established Builder/Nameplate world-billboard techniques

**Storage**: No new authoritative or map-save fields. Reaction source caches,
candidates, cooldowns, wait episodes, active views, diagnostics, presentation
mode, and reduced-motion state are rebuildable transient presentation data.
Centralized tuning lives in `data/presentation/world_reactions.json`; art
metadata lives in a non-authoritative runtime manifest.

**Testing**: GUT contract, unit, and integration suites; pure policy fixtures;
fixed-step ten-run deterministic traces; full/conditions-only/off authority and
save parity; the existing automated town scenario; maximum-workload performance
profiling; normal-renderer capture and manual visual review

**Target Platform**: Local desktop game on Godot 4.6.x; current macOS host is the
reference performance and rendering environment

**Project Type**: Plugin-oriented Godot desktop application with data-authored
simulation content and programmatic 2D/3D presentation

**Performance Goals**: At 500 residents, 256 active/pending car journeys, 135
buildings, and five active reactions: reaction source projection p95 at or below
4,000 microseconds; arbitration p95 at or below 1,000 microseconds; live-anchor
following p95 at or below 500 microseconds; render submission p95 at or below
500 microseconds; no more than eight reusable views and zero view allocations
after warm-up. Preserve the existing rendered frame gates of 16,700 microseconds
median, 25,000 microseconds p95, and 50,000 microseconds maximum, with no more
than 5% regression in both median frame time and median FPS. Each of at least
three matched runs excludes 120 warm-up frames, measures at least 600 rendered
frames, and retains at least 120 samples for each feature boundary.

**Constraints**: Presentation must not mutate simulation, use gameplay RNG, add
a second clock, persist reaction history, allocate one node per possible target,
read private entity pools, call rich Community explanations in a frame loop,
show text, capture input, or add a gameplay mutation command. At most five
markers may be visible and at most eight marker views may exist. Load/reset,
suppression, missing art, and target loss must fail silently for the player while
remaining diagnosable.

**Scale/Scope**: Six semantic expressions; person, active-car, and placed-building
targets; approximately 500 resident subjects, 256 journey slots, and 135 building
subjects; three presentation modes; five focus-suppression contexts; 1280x720,
1920x1080, and 3840x2160 at minimum and maximum gameplay zoom

## Constitution Check

### Pre-research gate

| Principle | Plan evidence | Result |
|---|---|---|
| I. One Gameplay Truth | Reactions consume detached state owned by Community, People, CarManager, DayNight, and GameState. They never propose or commit gameplay changes. | PASS |
| II. Deterministic, Controllable Simulation | Condition diffs use committed versions; ambience uses persisted seed, stable identities, and absolute-hour buckets; traffic thresholds use explicitly stepped visual delta. No global RNG or wall-clock decision enters policy. | PASS |
| III. Observable and Explainable State | Every candidate, selection, pre-emption, suppression, target handoff, and rejection has stable semantic fields and a bounded detached diagnostic trace. | PASS |
| IV. Data-Driven Balance, Narrative Separation | Reaction thresholds and mappings are presentation configuration separate from Community balance and dialogue. The six flags contain no authored speech or narrative dependency. | PASS |
| V. Small Interfaces and Layered Verification | Community adds one bounded facts method; People and CarManager add O(1) anchor lookups and generic blocked/wait episode transitions; CarManager adds one bounded ambient-subject enumeration. Pure policy, contracts, integration, replay, performance, and rendering are tested separately. | PASS |

Project constraints also pass: the design targets Godot 4.6.x, extends the
plugin/event architecture, leaves Builder as the shared command seam, adds no
remote surface, and keeps all playtest mutation commands unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/021-emotive-world-reactions/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
├── contracts/
│   └── world-reactions-contract.md
├── checklists/
│   └── requirements.md
└── validation/
    ├── baseline.md
    ├── baseline.json
    ├── test-results.md
    ├── condition-matrix.md
    ├── deterministic-replay.json
    ├── frame-rate-equivalence.json
    ├── ambient-frequency.json
    ├── authoritative-parity.json
    ├── regression-scenarios.md
    ├── performance.json
    ├── performance-diagnostics.json
    ├── performance-investigation.md
    ├── focus-and-motion.md
    ├── scope-audit.md
    ├── visual-qa.md
    └── screenshots/
        └── manifest.json
```

### Source Code (repository root)

```text
data/
└── presentation/
    └── world_reactions.json

art/ui/world-reactions/
├── manifest.json
├── review/
├── masters/
└── README.md

sprites/ui/world-reactions/
├── pleased.png
├── concerned.png
├── frustrated.png
├── surprised.png
├── busy.png
└── sleepy.png

plugins/
├── world_reactions/
│   ├── world_reactions_plugin.gd
│   └── world_reaction_view.gd
├── community/community_plugin.gd
├── people/
│   ├── people_plugin.gd
│   └── person_slot.gd
├── traffic/
│   ├── car_manager_plugin.gd
│   └── car_slot.gd
├── presentation/projection_registry.gd
├── presentation/presentation_scheduler_plugin.gd
└── playtest/playtest_plugin.gd

scripts/
├── performance/performance_sample.gd
├── reactions/
│   ├── world_reaction_config.gd
│   ├── world_reaction_types.gd
│   ├── world_reaction_source.gd
│   └── world_reaction_policy.gd
├── presentation/presenter_registration.gd
├── plugin_manager.gd
├── run_world_reaction_scenario.gd
└── capture_world_reactions_validation.gd

test/
├── contract/reactions/
│   ├── test_world_reaction_config_contract.gd
│   └── test_world_reaction_diagnostics_contract.gd
├── contract/performance/test_performance_evidence_contract.gd
├── unit/reactions/
│   ├── test_world_reaction_policy.gd
│   ├── test_world_reaction_source.gd
│   ├── test_world_reaction_layout.gd
│   ├── test_world_reaction_ambient.gd
│   ├── test_world_reaction_view.gd
│   └── test_world_reaction_runner_contract.gd
├── unit/community/test_community_reaction_projection.gd
├── unit/people/test_people_reaction_anchor.gd
├── unit/traffic/test_car_reaction_anchor.gd
├── unit/presentation/test_projection_registry.gd
├── unit/presentation/test_presentation_scheduler.gd
├── unit/plugin_manager/test_plugin_activation.gd
├── unit/playtest/test_playtest_plugin.gd
├── integration/reactions/
│   ├── test_condition_world_reactions.gd
│   ├── test_world_reaction_placement_coexistence.gd
│   └── test_world_reaction_focus_modes.gd
└── integration/performance/
    └── test_world_reaction_budget.gd
```

**Structure Decision**: Extend existing domain owners only at narrow read or
generic lifecycle seams. Put cross-domain reaction projection, policy, lifetime,
camera arbitration, and rendering in one downstream presentation plugin. Keep
pure value/policy code under `scripts/reactions/`, scene-tree presentation under
`plugins/world_reactions/`, authored art/tuning in existing data/art/sprite layers, and
verification in the established test/runner layout. No entity controller,
notification framework, mood simulator, or alternate persistence model is added.

## Architectural Design

### Ownership boundaries

| Owner | Continues to own | New narrow responsibility | Explicitly does not own |
|---|---|---|---|
| Community | Resident happiness, qualities, homes, assignments, roster, place operation/programmes | Produce a sorted bounded reaction-source projection without rich effect provenance | Expression choice, cooldown, marker lifetime, or rendering |
| People | PersonSlot lifecycle, visible person transforms, resident-to-person binding | Resolve one resident's current live anchor/state in O(1) and publish generic blocked-episode transitions | Reaction rules or marker nodes |
| CarManager | CarSlot lifecycle, waiting, routes, claims, transforms | Resolve one journey in O(1), enumerate sorted active journey IDs once per ambient bucket, and publish generic wait-episode transitions | The 1.5-second reaction threshold or expression choice |
| GameState/Builder | Building instances, anchors, commands, placement feedback | No new reaction authority; newly placed building subjects are silently baselined | Candidate generation or speech-flag rendering |
| PresentationScheduler | Coalesced committed invalidation | Invoke the reaction source presenter once at the latest coherent state | Per-frame target following or lifetime clocks |
| ProjectionRegistry | Detached versioned operational projection caching | Reset caches at map epoch boundaries and cache reaction source state | Moving transforms or active view state |
| WorldReactions | Semantic diffs, lifecycle event normalization, policy, ambience, modes, trace, pool | All feature-specific derived presentation | Any gameplay or save mutation |

This dependency direction is one-way. In particular, Community must not depend
on People or CarManager; `WorldReactions` is the downstream join point and can
depend on all three without creating a plugin cycle.

### Runtime flow

```text
authoritative hour/building commit
        │
        ├── Community updates resident/place facts
        ├── People reconciles visible resident state
        └── PresentationScheduler coalesces changed domains
                         │ deferred flush
                         ▼
       versioned reaction source projection (no live positions)
                         │ compare with silent/previous baseline
                         ▼
              semantic condition candidates
                         │
People blocked episode ──┤
CarManager wait episode ─┤
absolute-hour ambient  ──┤ stable candidate IDs and total order
                         ▼
 camera/target resolve → cooldown → collision → cap/pre-emption
                         ▼
          bind at most five of eight pooled marker views
                         │ each rendered frame
                         ▼
        O(1) live-anchor follow, lifetime, release, trace
```

The source projection is change-driven. Only active views and outstanding wait
timers receive per-frame work; blocked episodes are event-driven. Moving positions never enter ProjectionRegistry
because caching a person or car transform against an authoritative state version
would make it stale between commits.

The scheduler presenter reports semantically visible at all times so projection
delivery and baseline advancement continue in focused and `off` modes. Those modes
gate candidate admission/view visibility inside WorldReactions; they never park
the presenter in `DIRTY_HIDDEN` and later replay accumulated changes.

### Source projection and committed diffs

Community adds `get_world_reaction_source_facts()`. During its own setup,
WorldReactions registers `world_reactions.conditions` with ProjectionRegistry for
`clock`, `structures`, `topology`, `occupancy`, and `community`; traffic waiting
arrives through its generic episode transition. ProjectionRegistry calls the
projector with `(source_version, dependency_revisions)`. The projector calls only
the Community facts method, then attaches WorldReactions' local map epoch, that
supplied source version, and DayNight's absolute hour. Community therefore has no
knowledge of downstream epoch/version state. The wrapper also attaches
DayNight's distinct `current_hour()` as local context; absolute hour remains the
bucket/hash identity. The result is detached,
schema-versioned, bounded to the supported population/building scale, and sorted
by numeric resident/building identity before return.

Resident rows include only the facts needed to detect the specification's
transitions: resident ID, home, composite happiness, and purpose/destination.
Actual route failure is a People-owned movement outcome delivered as a blocked
episode, not inferred from Community intent availability. Building rows include instance
ID, anchor, category/role, occupancy and average resident happiness, road access,
open/operating state, programme, fulfilled activity, and capacity. They do not
contain rich `AppliedEffect` records, labels, textures, or moving positions.

At a scheduler flush, WorldReactions compares the new wrapped source snapshot with
the last coherent snapshot and emits at most one candidate per speaker/cause and
source version. Route-blocked semantics arrive from the exact People episode;
People and CarManager live anchors are otherwise resolved only for candidates
that survive semantic selection. A first observation of the whole map or a newly placed
building hydrates a baseline only. This also leaves Builder's existing
placement-effect feedback as the sole announcement of the placement commit;
there is no generic `building_placed` reaction to duplicate it.

Generic People-blocked and Car-wait episode events provide exactly-once lifecycle
inputs that are not recoverable from a committed before/after row. Handlers capture
the current map epoch plus subject/episode identity; their strict `blocked`/`wait`
source variants use null source version/time bucket, a populated source episode,
and the presentation batch's committed hour as `quiet_bucket`. Map reset, clear,
recovery, or subject invalidation discards them. Separately, committed condition projection
coalescing means manual multi-hour advancement cannot replay an hour-by-hour
condition burst on the next rendered frame.

### Live render targets and handoff

People exposes `get_reaction_anchor(resident_id)` backed by `_resident_index`.
Its detached result includes validity, resident ID, visibility, display position,
visual state, blocked reason/episode, purpose, and active journey ID. People also
publishes generic blocked-start/clear transitions and WorldReactions maps only
the contract's canonical route-failure reasons, excluding car-capacity/admission
waits. CarManager exposes
`get_reaction_anchor(journey_id)` backed by `_active`; its result includes
validity, journey/resident IDs, current display position, waiting state, wait
episode, accumulated `wait_seconds`, and source-owned lifecycle token. CarManager also exposes a detached,
ascending `get_reaction_subject_ids()` list of at most 256 active journey IDs;
WorldReactions requests it once per newly observed ambient hour, never from the
per-frame follow loop or through the full traffic diagnostic snapshot.

A candidate retains two identities:

- `speaker_key` is the semantic entity that owns deduplication and cooldown,
  such as `person:41` or `building:17`.
- `target_key` is the current drawable representation, such as `person:41`,
  `car:9`, or `building:17`.

When resident 41 is inside car journey 9, the candidate remains owned by
`person:41` but binds to `car:9`. The view re-resolves that target every frame.
It may rebind only when the same speaker and current lifecycle evidence prove the
handoff; otherwise it releases. Journey completion, cancellation, pool reuse,
resident removal, hidden state, demolition, or a generation mismatch cannot
transfer a marker to a different entity.

Building targets resolve their current instance record directly from
`GameState.building_registry` by numeric instance ID. Each kind applies a
validated height/lead offset from presentation rules; offsets move presentation
only and never affect entity transforms.

### People blocked and vehicle waiting episodes

People centralizes transitions into/out of `PersonSlot.VisualState.BLOCKED` and
blocked-reason changes while the state remains blocked, incrementing a transient
per-resident episode and emitting clear-old/start-new for a changed normalized
reason. WorldReactions emits at most one
`resident_route_blocked` candidate per map-epoch/resident/episode and only for
the canonical route-failure reason set. People remains unaware of expression and
priority; route recovery, reason change, removal, or map reset clears the episode.

CarManager centralizes its existing wait-state assignments in a generic helper
and emits a transition only on `false -> true` or `true -> false`. `CarSlot`
maintains a monotonic transient `wait_episode` counter for that journey. The
reaction plugin starts its own real-time accumulator for the episode, emits one
`vehicle_wait_threshold` candidate when explicitly stepped delta first reaches 1.5 seconds,
and marks that episode fired. Movement, cancellation, completion, map load, or a
new episode re-arms it. Continued waiting and cooldown expiry alone never do.

The threshold remains presentation tuning; CarManager reports facts and does
not know about expressions, priorities, or marker lifetime. Fixed-step tests call
the same accumulation path as normal `_process`, so replay never depends on
`Time.get_ticks_usec()`.

### Rules and condition mapping

`data/presentation/world_reactions.json` is parsed and validated once by
`WorldReactionConfig`. Invalid or incomplete configuration records a diagnostic
and switches to the built-in `conditions_only` safety configuration with ambience
disabled. A missing expression asset still suppresses only the affected marker.
Specifically, a missing mapping key is a structural config failure; after all six
keys validate, an absent/unapproved manifest entry or unreadable PNG is the
per-candidate `missing_asset` case and leaves other expressions operational.
Configuration cannot alter Community balance.
Schema version 1 rejects authored conflicts with the five-visible/eight-pool
caps, 8-point happiness threshold, 1.5-second wait threshold, or canonical cause
expression, speaker/target-kind, and priority mappings. It also fixes one following
quiet bucket and makes cooldown identity equal speaker identity. Reduced motion
defaults false. Lifetime remains authorable only within 1.6-2.4 seconds; the vertical
screen lane defaults to 56 px; other allowed spacing, offset, cooldown, and ambient
values use their declared validation ranges.
Changing a fixed invariant requires an explicit schema/contract revision.
The initial precedence is fixed by the specification:

| Priority band | Transition | Speaker / target | Expression |
|---|---|---|---|
| 100 critical | Resident becomes unhoused | Person / current person or car | `concerned` |
| 100 critical | People enters a canonical route-blocked episode | Person / current person or car | `frustrated` |
| 90 | Car wait episode reaches 1.5 seconds | Car / car | `frustrated` |
| 85 | Home or place loses road access | Building / building | `frustrated` |
| 80 | Happiness rises or falls by at least 8 points between committed snapshots | Person / current person or car | `pleased` / `concerned` |
| 70 | Home occupancy rises/falls | Building / building | `surprised` / `concerned` |
| 70 | Occupied-home average happiness rises/falls by at least 8 points | Building / building | `pleased` / `concerned` |
| 70 | Home or place regains road access | Building / building | `pleased` |
| 70 | Place activity starts/stops | Building / building | `busy` / `concerned` |
| 70 | Place programme changes | Building / building | `surprised` |
| 60 / 50 | Place opens/closes | Building / building | `busy` / `sleepy` |
| 10 | Compatible quiet contextual beat | Eligible semantic speaker / live representation | Contextual non-serious expression |

The previous-presented snapshot advances to the newest coalesced committed value even when a
candidate is suppressed, so old changes cannot accumulate into a post-focus
burst. The 8-point threshold is measured between those two coherent presented
snapshots, never from every skipped intermediate commit or rounded rendered text. Per-speaker cooldown damps threshold
oscillation; after expiry only a fresh absolute 8-point committed delta qualifies.

For home-condition aggregation, include only residents whose non-null home is the
same in the previous-presented and newest-coalesced snapshots, sort by resident ID, and divide their signed
happiness-delta sum by contributor count. A mean at least `+8.0` selects rise, a
mean at most `-8.0` selects drop, and the middle band emits no home-condition
candidate. Zero contributors means no division and no candidate. Occupancy changes
compare count only, so a same-count identity swap is not an occupancy cause. When causes share a building
and priority, ascending canonical cause key breaks the tie; evidence magnitude
never creates an undocumented ordering rule.

### Candidate arbitration and lifetime

`WorldReactionTypes` validates the semantic candidate ID, epoch, strict
`committed | blocked | wait | ambient` source discriminator and its exclusive
version/episode/time-bucket fields, mandatory committed-hour `quiet_bucket`,
speaker/cooldown/deduplication keys, target intent, expression,
cause, priority, and a lifetime within 1.6-2.4 seconds; an out-of-range lifetime
is rejected rather than clamped. Successful live-anchor
and camera resolution creates a separate immutable resolved candidate with
concrete target/lifecycle, finite world anchor, and screen rectangle. Neither
record contains an asset path or gameplay callback. The default lifetime is 2.0
seconds and final release applies a 10-second speaker cooldown.

Before consuming capacity, the controller rejects malformed, duplicate, stale,
unsupported, missing, hidden, behind-camera, and off-screen targets. Remaining
candidates use a total order of priority descending, then cause, speaker key,
target key, and candidate ID ascending. No Dictionary,
signal connection, node-tree, or frame iteration order participates.

The policy then enforces:

1. one active reaction per semantic speaker and one marker per render target;
2. speaker cooldown and one-shot wait-episode rules, with cooldown bypass only
   for priority-100 candidates and never for duplicate candidate IDs;
3. base and one screen-space `(0, -vertical_lane_offset_px)` upward-lane rectangle;
   expand each non-critical rectangle by configured per-side padding before both
   nonintersection and containment inside the configured viewport inset (defaults
   56, 8, and 12 px respectively);
4. a hard five-visible cap;
5. bounded admission-plan evaluation over two lanes and subsets of at most five
   active slots. A condition may evict ambience blocking ownership, both lane
   choices, or cap; a priority-100 condition may also evict lower-ranked
   non-critical conditions. Ambient evicts nothing;
6. the fewest-victim plan, then victims by ascending priority, latest start, and
   lexicographically greatest candidate ID, then base lane. This defines the same
   deterministic condition precedence for ownership, collision, and cap.

Only a priority-100 marker may overlap another priority-100 marker when no legal
separated plan exists; critical candidates never bypass ownership or the visible
cap. Pre-emption releases only the chosen victims and fully resets each old view
before binding the new one. During follow, the lower-ranked conflict—priority
ascending, latest start, greatest ID—tries its unused lane once, then exits if
still invalid. An active reaction uses explicit enter, hold, and exit phases; a
single large delta may cross all remaining phases and must release on that update.

If live person/car rebinding makes two active slots converge on one speaker or
render target, the lower-ranked slot releases immediately; the vertical lane is
only a geometric-overlap remedy and never relaxes ownership.

Deduplication retains only latest per-source/per-live-subject tokens plus the
current bounded batch, never every candidate ID. Every presenter/frame update
evicts expired cooldowns and cooldowns for removed speaker lifecycles; diagnostic
reads apply the same predicate before copying. Both stores clear at map
boundaries, so a long-lived map cannot accumulate presentation history.

### Ambient selection

Ambient evaluation occurs once for each newly committed absolute simulation hour,
using DayNight's absolute hour. Under the 120-second reference day, one hour is
five real seconds. The default stable town-level opportunity threshold is
`625 / 1000`, yielding an expected eight-second interval before suppression.

`WorldReactionPolicy` receives the persisted Community seed, bucket, and a
canonically sorted set of currently visible contextual subjects. People subjects
come from Community rows resolved through People anchors; car subjects come from
CarManager's once-per-new-bucket sorted active-journey list; placed-building
subjects come from the compact source rows. An `IN_CAR` resident is excluded from
the person set when its journey is represented, preventing double weighting.
The contract's typed length-prefixed UTF-8/SHA-256 function makes separate
opportunity, subject-rank, and context-expression hashes, selecting zero or one
subject and one compatible expression for the entire town.
Night context is derived exactly from DayNight `current_hour()` values 21–23 and
0–5; `get_absolute_hour()` remains the bucket/hash input.
The local map epoch is trace/lifecycle metadata, not ambient hash material; map
hydration marks the current bucket observed so it cannot replay immediately.
It does not roll once per entity, so density does not grow with population.
Blocked, unhoused, hidden, waiting, inaccessible, invalid-lifecycle, off-screen,
active-owned, cooling-down, or semantically contradictory subjects are removed
before hash ranking; deterministic per-reason exclusion counts remain in the
decision. The chosen subject is revalidated at arbitration, and a changed winner
is rejected without falling back to a second subject.

Every bucket records exactly one outcome in this order: non-world focus
suppression, non-`full` presentation suppression, condition quiet period, false
opportunity, no eligible subject, arbitration rejection, or accepted admission.
The finite outcomes are `suppressed`, `no_opportunity`, `no_eligible_subject`,
`rejected`, and `accepted`, with a first-applicable finite reason. Opportunity
counts include only true rolls after suppression; rejected counts are true rolls
without admission; acceptance means the marker actually bound visibly.

Blocked/wait events are queued and stamped with one committed absolute hour at the
start of their next presentation batch. All condition candidates in the batch set
the inclusive `quiet_through_bucket` to at least `quiet_bucket + 1` before the
same batch evaluates ambience, so hour-boundary signal order cannot change the
result. A competing condition, focus suppression, `conditions_only`, or `off`
wins and discards the bucket; nothing queues for a later burst.

The frequency harness excludes exactly 60 fixed-step presentation seconds of
warm-up per seed, then measures 1,800 presentation seconds (30 real minutes, or
15 automatic simulation days). It divides eligible observation seconds using the
same pre-rank filter by accepted visible beats and runs the default 625/1000 gate.

### Camera, collision, and rendering

`WorldReactionView` is a non-interactive `Node3D` with a billboard `Sprite3D`.
The plugin creates at most eight views during initialization, preloads the six
manifest-approved textures, and performs no view allocation after warm-up. Views
use fixed apparent sizing, clean transparency, no text, no input Control, and
reset texture, modulation, offset, transform, phase, timing, and binding token on
every release.

Camera eligibility uses the active `Camera3D`, behind-camera rejection,
`unproject_position`, a 12 px viewport margin, and the manifest's apparent bounds.
Active rectangles are expanded 8 px per side and the expanded rectangles must
not intersect; they are recomputed in stable
priority/start/ID order while targets move or the camera/viewport changes. One configured
bounded upward vertical lane offset (`screen_y - 56` pixels by default) may resolve a
non-critical collision; there is no random or cumulative jitter. If it remains
unreadable or leaves the safe region, the lower-ranked marker releases, so a
condition survives ambience and a critical condition survives a non-critical one.
Two priority-100 markers preserve their allowed critical/critical overlap during
follow as well as admission.
Markers deliberately use the same no-depth-test
world-UI treatment proven by placement feedback; the noisy-town proof validates
render priority, asset pivot/bounds compatibility, and the config-owned target
offsets rather than leaving them to engine defaults. Manifest metadata cannot
override those offsets.

Normal motion may use a short scale/fade settle and tightly bounded decorative
bob. Reduced motion keeps only live target following and opacity phases. Neither
path moves or reparents the underlying person, car, or building.

### Focus and presentation modes

WorldReactions listens to the existing
`GameEvents.player_input_mode_changed(mode)` signal. `modal`, `radial`,
`placement`, `demolition`, and `inspection` stop admission and release/reset active
views with `mode_suppressed` by the next presenter/frame update; ordinary final-
release cooldown is written. Incoming candidates update the silent baseline and
are discarded. Presentation time, wait timers/fired bits, cooldown expiry, and
ambient bucket observation continue: a wait crossing while suppressed is derived
and discarded once. Returning to `world` starts from current state with no replay queue.

The plugin exposes a small non-authoritative preference API:

```gdscript
set_presentation_mode(mode: String) # full | conditions_only | off
set_reduced_motion(enabled: bool)
```

`full -> conditions_only` releases active ambience with `ambient_disabled` by the
next update while preserving active conditions; any transition to `off` releases
all active reactions with `mode_suppressed`. Re-enabling replays nothing. Invalid
mode strings return false and leave state untouched. Reduced-motion changes apply
to active views in place without restarting their phase, semantic lifetime, or
cooldown, and its default is false. `off` continues silent baseline hydration so
re-enabling cannot burst. These session presentation hooks deliberately do not add a map field or a
new Playtest mutation command. A future settings surface can bind to the same API
without changing reaction semantics.

New building rows hydrate silently and no `building_placed` reaction exists.
Placement mode advances the source baseline while discarding all candidates, so
Builder's existing 3.2-second feedback remains the sole placement announcement
without any new Builder API or dependency. A later condition transition first
observed after return to `world` is a distinct eligible event.

### Map epochs, cache safety, and cleanup

Builder resets authoritative state versions on load/clear, while current
presentation services may still hold cache keys or a greater latest version from
the previous map. On boot, map load, map clear, and reconstruction,
WorldReactions increments a local presentation epoch, releases all views, clears
candidates, condition memory, blocked/wait episode memory, cooldowns, and diagnostics tied to the
old map, and schedules a silent baseline. Candidate IDs always include that epoch
and never rely on state version alone.

ProjectionRegistry must clear its cached projections and dependency revisions,
and PresentationScheduler must clear pending flush state and reset its latest and
per-presenter version memory, at the same map boundary before the deferred
reaction fetch. A focused regression test covers two maps that both reach the
same numerical state version and proves the second map is neither cached nor
suppressed. This is a presentation-lifecycle correction, not a new gameplay epoch
or save field.

WorldReactions closes lifecycle-event admission on boot and on the authoritative
`map_load`/`map_clear` change set, before compatibility reconstruction signals.
People and CarManager rebuild episode state silently. The deferred source baseline
then scans resident anchors and the bounded active-car list once, marks existing
blocked/waiting episodes observed without starting timers, and opens event
admission only after reconstruction and baseline completion.

### Diagnostics and performance attribution

The plugin retains the latest 64 eventful presentation-update batches as a stable trace of source
snapshot identity, candidates, selected/pre-empted candidates, active slots,
cooldowns, and rejections. No-op updates append nothing; input/config releases,
active follow/lifecycle releases, expiries, conditions, and ambience share one
fixed category order and one batch-local ordinal sequence. Active summaries are
ordered by priority/start/ID and contain only semantic binding, expression/cause,
phase/lane, and microsecond-quantized presentation times—never pool index or raw
coordinates. The exact finite reason enum is `invalid_candidate`,
`stale_epoch`, `stale_source_version`, `duplicate_candidate`, `speaker_active`,
`target_active`, `speaker_cooldown`, `condition_quiet_period`, `ambient_disabled`,
`mode_suppressed`, `target_missing`, `target_hidden`,
`target_lifecycle_mismatch`, `target_offscreen`, `target_behind_camera`,
`screen_collision`, `visible_cap`, `lower_priority`, `no_opportunity`,
`no_eligible_subject`, `invalid_context`, `missing_asset`, `expired`,
`preempted`, and `map_boundary`. Disposition is exactly
`selected | rejected | released | preempted`; selected decisions use `reason: null`, and silent
baseline hydration is a batch event. Candidate and decision arrays share a cap of
128 canonically cross-ordered records per batch; overflow records stable per-kind
omitted counts and one contract-defined typed-field SHA-256 digest. Unexpired
cooldowns are speaker-key sorted, retain at most 128 summaries per batch, and have
separate omitted count/digest metadata using the same portable encoding. Diagnostic
reads are detached and never called by normal presentation.

If appended to non-compact Playtest state, the reaction projection is added only
after canonical `state_hash` calculation, matching existing civilian diagnostics.
No public mutation command is added.

PerformanceMonitor records separate boundaries:

- `world_reactions.source_projection`
- `world_reactions.arbitration`
- `world_reactions.anchor_follow`
- `world_reactions.render_submit`

Each sample includes source subject count, candidate count, eligible count,
active count, anchor resolutions, collision attempts, and pool usage as relevant.
Timing and trace fields never enter reaction selection, save payloads, gameplay
hashes, or transaction-ledger hashes.

## Contracts and Data Design

Detailed field rules live in [data-model.md](data-model.md). The consolidated
[world-reactions-contract.md](contracts/world-reactions-contract.md) freezes the
Community facts/wrapped projection; O(1) People and CarManager anchors;
speaker-to-car handoff; blocked/wait episodes; candidate identity and lifecycle; canonical condition matrix;
ambient selection; arbitration, cooldown, pre-emption, and active phases;
diagnostics and performance boundaries; and the six-entry asset manifest.

All contract values returned across plugin boundaries are detached. Candidate and
diagnostic schemas are versioned. Runtime node references, Texture resources,
Callables, tweens, raw CommunityResident/PersonSlot/CarSlot instances, and private
dictionaries never cross these boundaries.

## Explicit Test Seams

| Seam | Focused proof |
|---|---|
| Candidate and rules contract | Reject malformed IDs, target kinds, expressions, priorities, durations, stale epochs, duplicate IDs, and incomplete configuration; prove detached values and total ordering |
| Projection diff | Silent first/load baseline; exact +/-8 threshold; no sub-threshold output; previous-presented to newest-coalesced behavior; one highest cause per speaker/version; home conflict aggregation; new/removed building handling |
| People anchor/blocked episode | O(1) visible lookup, hidden/in-car result, blocked reason/episode, route-reason allowlist, exactly-once start/clear, purpose, journey handoff, missing resident, and detached position |
| Car anchor/wait episode | O(1) active lookup, bounded sorted ambient-subject enumeration, continuous 1.5-second crossing, one fire per episode, resume re-arm, cancellation/completion, and pooled generation reuse |
| Arbitration | Five cap, one speaker/target, priority/tie order, cooldown, screen separation, off-screen prefilter, strict pre-emption, critical cap behavior, and no unbounded offset jitter |
| Ambient sampler | Same-seed equivalence, different bucket variability, zero/one town budget, population-size invariance, contextual compatibility, condition precedence, and unchanged gameplay RNG state |
| Pool/view lifecycle | Eight-view ceiling, zero post-warm-up allocation, enter/hold/exit, large delta cleanup, full reset, missing texture isolation, target-follow and target-loss release |
| Modes/focus | Full/conditions-only/off, all five suppressed input modes, no stale resume burst, reduced-motion animation removal, and no input capture |
| Map lifecycle | Boot/load/clear/reconstruction silence, repeated numeric versions across maps, projection-cache reset, active/cooldown/blocked/wait cleanup, and no orphan views |
| Authority boundary | Equal DataMap serialization, gameplay state hash, transaction ledger hash, Community RNG state, resident outcomes, routes, economy, demand, and progression in all three modes |
| Performance | Separate source/arbitration/follow/render samples at 500/256/135/5, stable workload counts, view allocation assertion, existing frame gates, and <=5% median regression |
| Visual contract | All six expressions at 24/32/40/48 apparent px, colour/grayscale, quiet/dense, day/night, both zoom extremes, motion, focus, depth, safe edges, and all three resolutions |

Tests use pure dictionaries and fake cameras/domain providers where possible.
Normal-renderer pixel evidence supplements semantic assertions and never replaces
them.

## Delivery Phases

### Phase 0 - Freeze evidence and decisions

1. Record current source/runtime asset inventories, authoritative hashes, Community
   RNG state, existing rendered performance, and Builder/Nameplate billboard
   behavior in `validation/baseline.md` and `validation/baseline.json`.
2. Finalize the semantic mapping, screen-space safe region, depth policy proof,
   ambient bucket probability, and per-kind offsets in research/contracts.
3. Preserve the existing unregistered `WorldReactionPolicy` spike and its focused
   tests as evidence; do not register provisional runtime behavior.

**Gate**: Baseline commands, workload, seed, renderer, viewport, zoom, and source
hashes are reproducible before implementation.

### Phase 1 - Foundational contracts and pure policies

1. Add versioned source snapshot and candidate value types plus validated rule
   loading.
2. Extend the pure policy for speaker/target identity, stable total order,
   cooldown, screen rectangles, hard cap, and strict priority pre-emption.
3. Write contract and unit tests first, including malformed input and copy safety.
4. Start the art exploration/master/manifest track in parallel after the six
   semantic keys and apparent-size contract are frozen.

**Gate**: Pure policy and value tests pass without a scene tree, domain plugin, or
runtime texture.

### Phase 2 - Bounded domain seams and map lifecycle

1. Add Community's sorted compact reaction facts, including inert persisted seed,
   and prove no rich explanation path is called; assemble epoch/version/hour only
   in the downstream projector.
2. Add People and CarManager O(1) live anchor methods plus CarManager's bounded
   once-per-ambient-bucket active-journey enumeration with detached contracts.
3. Add generic People blocked-episode and CarManager wait-episode transitions,
   canonical route-reason filtering, and fixed-delta episode tests.
4. Reset ProjectionRegistry runtime caches on map load/clear and cover repeated
   numerical state versions.
5. Add plugin fixtures for cameras, buildings, moving targets, and source versions.

**Gate**: Domain-focused tests prove the new reads are bounded, deterministic,
detached, non-authoritative, and reconstructable.

### Phase 3 - P1 condition and dense-presentation vertical slice

1. Register `WorldReactions`, its source projection/presenter, and the eight-view
   pool through PluginManager dependency injection.
2. Implement silent hydration, committed diffs, candidate normalization, newest
   version coalescing, and the initial person/car/building condition matrix.
3. Implement live person-to-car target handoff, 1.5-second car waiting, missing or
   reused target cleanup, and strict one-shot lifecycle semantics.
4. Implement camera culling, safe rectangles, deterministic offsets, five cap,
   cooldowns, pre-emption, target following, and bounded lifetime.
5. Integrate only manifest-valid production expressions; a missing/unapproved
   mapped asset suppresses that marker rather than substituting a false meaning.

**Independent P1 proof**: The canonical condition matrix produces the declared
target/cause/expression/priority exactly once, while a dense camera fixture never
exceeds five readable markers or leaves a stale target.

### Phase 4 - P2 ambient personality

1. Derive the absolute-hour ambient bucket from DayNight and build a canonical
   eligible subject set from current visible context.
2. Apply one town-wide stable gate/selection, contextual expression filtering,
   recent-condition quieting, and condition precedence.
3. Exclude exactly 60 fixed-step presentation seconds per seed, then tune against
   ten 1,800-second automatic reference-town traces until
   aggregate eligible observation seconds divided by accepted beats is inclusively
   6.0-10.0, with nonzero acceptances and opportunity/rejection/acceptance counts.

**Independent P2 proof**: Identical seed/state/hour traces are byte-equivalent;
different inputs may vary; no bucket produces more than one ambient admission and
no ambience contradicts or beats a condition.

### Phase 5 - P2 focus, modes, and comfort

1. Wire existing input-mode suppression and discard candidates while focused.
2. Add `full`, `conditions_only`, and `off` preference hooks with silent baseline
   maintenance.
3. Implement reduced-motion view phases while retaining necessary target follow.
4. Prove views do not capture mouse, keyboard, or gamepad input.
5. Prove new building rows hydrate silently, placement-mode candidates are
   discarded, Builder remains unchanged, and later world-mode transitions qualify.

**Independent P2 proof**: Every suppressed mode and preference combination shows
the expected zero/subset output, returns to world mode without a stale burst, and
preserves identical gameplay state.

### Phase 6 - P3 diagnostics, replay, and performance

1. Add the bounded detached diagnostic snapshot and optional non-compact Playtest
   projection after canonical hash calculation.
2. Instrument all four feature boundaries and add the maximum-scale performance
   integration fixture.
3. Extend the US3 fixed-step scenario runner with full/conditions-only/off
   authority matrices and tagged maximum-profile probes.
4. Run focused suites, full Godot suite, existing deterministic town scenarios,
   save/load reconstruction, and rendered performance comparison.

**Independent P3 proof**: Every admission/rejection is explainable, ten traces are
byte-equivalent, all authority artifacts match across modes, and every declared
budget passes.

### Phase 7 - Final art QA and release evidence

1. Re-verify the foundational labelled exploration, approved high-resolution
   masters, individual 128 px exports, manifest, actual-size sheets, grayscale
   proof, and noisy-town proof against their recorded hashes and review gates.
2. Run `capture_world_reactions_validation.gd` at all three viewports, both zoom
   extremes, quiet/dense towns, day/night, motion, suppression, reduced motion,
   and depth/occlusion cases.
3. Record test, replay, parity, performance, visual, asset, and acceptance evidence
   under this specification; re-audit every FR and SC.

**Release gate**: SC-001 through SC-012 pass; at least three reviewers meet the
90% expression-identification threshold and every expression is identified by
two reviewers at every size; there are no orphan views or authority diffs; and
the complete normal-renderer QA is approved.

## Deterministic Replay and Authority Verification

`scripts/run_world_reaction_scenario.gd` uses the existing authoritative playtest
actions and explicitly stepped visual delta. For each run it records a normalized
semantic trace containing epoch, state version or absolute-hour bucket, candidate
ID, speaker/target, expression, cause, priority, disposition/rejection code,
pre-emption, and presentation-clock admission/end microseconds. Wall-clock microseconds, object IDs,
resource instance IDs, and unsnapped transforms are excluded.

Required comparisons:

1. Ten equivalent runs with seed `21021`, identical actions, clock advances, and
   fixed visual steps produce byte-equivalent candidate, rejection, selection,
   active, and ambient traces.
2. Equivalent elapsed fixed-step sequences at 30 Hz and 60 Hz produce the same
   semantic wait-threshold and ambient decisions; animation sample frames may
   differ but admissions may not.
3. A different persisted seed or absolute-hour bucket may change ambience but may
   not change any condition candidate or gameplay output.
4. `full`, `conditions_only`, and `off` produce identical canonical gameplay state
   hashes, transaction-ledger hashes, serialized DataMap payloads, Community RNG
   state, resident records, routes, economy, demand, progression, and clock state.
5. Save/load and fresh-map reconstruction produce a silent first projection, no
   prior-map candidate/cooldown leak, and deterministic output from the new epoch.
6. Existing civilian, traffic-flow, first-town, opening, and transactional
   performance scenarios remain green.

## Performance Verification

The maximum fixture contains 500 Community residents, 512 available person proxy
capacity with 500 bound residents, 256 active/pending car journeys including wait
episodes, 135 placed buildings, more eligible candidates than the cap, and five
active markers. Each run excludes exactly 120 scene/view-pool warm-up frames,
then measures at least 600 rendered frames. Load, asset import, capture readback,
and requested diagnostics are excluded from normal frame gates.

Each of at least three equivalent measured runs retains at least 120 raw samples
for every named feature boundary; a run below either minimum is invalid. In the
`max_supported` profile only, the harness requests one detached maximum-workload
source projection and one greater-than-cap arbitration batch every five measured
frames in both the `full` and matched `off` runs. This yields exactly 120 samples
of those event-driven boundaries in 600 frames without writing authority; follow,
render, and frame totals remain sampled each frame. Probe work is included in the
frame totals and clearly tagged in evidence. The harness never performs these
probes in ordinary play. It reports sample count, exclusions,
median/p95/max, workload counts, environment, seed, town ID, renderer, authoritative
hash, transaction-ledger hash, view allocation count, and pass/fail for:

| Boundary | Gate |
|---|---|
| `world_reactions.source_projection` | p95 <= 4,000 microseconds |
| `world_reactions.arbitration` | p95 <= 1,000 microseconds |
| `world_reactions.anchor_follow` | p95 <= 500 microseconds |
| `world_reactions.render_submit` | p95 <= 500 microseconds |
| Marker allocation | <=8 initialized views; zero view allocations after warm-up |
| `frame.total` | median <=16,700, p95 <=25,000, max <=50,000 microseconds |
| Rendered regression | median frame time degradation <=5% and median FPS degradation <=5% against matched baseline |

The test also asserts that normal per-frame work resolves only active views and
outstanding wait timers; People blocked episodes remain event-driven. Outside the
explicit performance profile, full resident/building projection runs only on a
committed invalidation or newest ambient bucket, and no full diagnostic snapshot
is invoked by `_process`.

## Risks and Mitigations

| Risk | Impact | Mitigation / proof |
|---|---|---|
| Projection/scheduler state survives a map whose version reset to the same number | Old-map conditions can appear, or the new map can be suppressed | Clear ProjectionRegistry and reset PresentationScheduler at the map boundary, add local reaction epoch to IDs, clear all runtime memory, and test two same-version maps |
| Scheduler/listener order exposes partially reconciled domain state | Wrong target or duplicate cause | Derive conditions only in deferred scheduler flush after commit; coalesce lifecycle hints to the newest version; test real plugin order |
| Moving transforms are cached by source version | Markers lag or strand between hourly commits | Keep positions out of cached snapshots and resolve at most five live anchors O(1) every frame |
| Community diagnostic APIs are reused for convenience | Per-frame effect materialization and large deep copies break budgets | Dedicated compact projection, invocation-count tests, and explicit prohibition in contract |
| Community depends on People/CarManager | Plugin dependency cycle and unclear authority | Keep the cross-domain join solely in downstream WorldReactions |
| Person enters/leaves a car between candidacy and admission | Bubble appears on hidden proxy or wrong pooled car | Separate speaker/target keys, validate epoch plus exact resident/journey lifecycle token on every follow, and release uncertain handoffs |
| Car wait assignments emit every frame | Reaction spam and signal overhead | Central transition helper, monotonic episode ID, 1.5-second controller threshold, one fired bit per episode |
| Per-entity ambient rolls scale with town size | Busy towns flood while small towns feel empty | One town-wide hash gate and at most one target selection per absolute-hour bucket |
| Dictionary or signal order breaks replay | Same seed chooses different candidates | Canonical arrays and explicit total-order tie-breaks at projection, grouping, sampling, and arbitration boundaries |
| Focus/off-screen candidates accumulate | Burst after returning to world view | Advance silent baseline and discard candidates during suppression; never retain ambient buckets |
| Active views overlap after targets/camera move | Previously readable markers become clutter | Recompute screen rectangles in stable priority order, try bounded fixed offsets, then release the lower-ranked marker |
| Pool slot is reused without full reset | Old texture/timing/binding leaks to another target | Binding generation token plus exhaustive release reset and lifecycle stress tests |
| Missing art falls back to the wrong symbol | Player receives false semantic information | Manifest validation and per-marker suppression with stable `missing_asset` diagnostic; no semantic fallback |
| Fixed building height or unchecked depth mode hides markers or shows through town | Poor readability at zoom/day/night | Config-owned per-kind offsets, manifest pivot/bounds compatibility, fixed no-depth-test policy, and quiet/noisy occlusion proofs at both zoom extremes |
| Building reactions imply fictional sentience or duplicate placement feedback | Misleading simulation explanation | Permit only the closed occupancy/activity/access/programme/open-state matrix; silently baseline new buildings; Builder retains placement feedback ownership |
| Real-time traffic threshold becomes frame-rate dependent | 30/60 Hz traces disagree | Accumulate passed delta, fire on first `>=1.5`, test split and oversized steps, never consult wall-clock ticks |
| Presentation fields leak into saves/hashes | Violates authority and deterministic simulation | Keep all fields plugin-local, append optional diagnostics after hash, and compare serialized payload/RNG/ledger/state across all modes |
| Art review lands after code assumptions harden | Rework in pivot, bounds, and collision | Freeze semantic keys/apparent-size/manifest contract first; integrate via metadata and keep renderer independent of artwork filenames |

## Post-design Constitution Re-check

| Principle | Final design evidence | Result |
|---|---|---|
| I. One Gameplay Truth | The final flow is strictly downstream of committed authority and transient presentation owners. No rule, candidate, mode, view, or diagnostic can invoke a gameplay mutation. | PASS |
| II. Deterministic, Controllable Simulation | Stable version/epoch IDs, canonical ordering, pure town-wide hashing, absolute simulation buckets, and fixed-delta wait timing cover every selection path. Presentation remains excluded from authoritative replay. | PASS |
| III. Observable and Explainable State | Versioned source/candidate/active/trace contracts and stable rejection codes explain both visible and suppressed results without exposing private runtime objects. | PASS |
| IV. Data-Driven Balance, Narrative Separation | Validated presentation JSON and asset manifest own only visual mappings/timing. Community balance, authored building effects, dialogue, and progression remain unchanged. | PASS |
| V. Small Interfaces and Layered Verification | One compact Community projection, two O(1) anchor methods, one generic wait transition, one downstream plugin, and pure value/policy types are covered by contract, unit, integration, scenario, performance, and visual gates. | PASS |

No constitutional or project-constraint exception is required.

## Complexity Tracking

No complexity violations. The added coordinator is a feature-specific
presentation plugin required to join three independently owned target types; it
does not create an additional gameplay service, clock, persistence layer, general
event framework, or per-entity node hierarchy.
