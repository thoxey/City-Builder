# Research: Emotive World Reactions

## Decision 1: Reactions are a downstream presenter, not a mood system

Community already owns resident happiness, effects, assignments, occupancy, and
building operation. People and CarManager already own visible movement state.
Reactions should compare or observe those facts and produce transient semantic
candidates in a new `WorldReactions` presentation plugin.

**Rationale**: This preserves one gameplay truth and lets `full`,
`conditions_only`, and `off` modes produce identical simulation, saves, and hashes.

**Alternatives rejected**:

- Add emotion values to residents, cars, or buildings: duplicates or invents
  simulation authority and makes a visual feature balance-relevant.
- Emit reactions directly from every gameplay plugin: spreads priority, cooldown,
  deduplication, and art knowledge across unrelated systems.
- Add more reaction code to Builder: Builder already proves the rendering
  primitive but should not become a general presentation orchestrator.

## Decision 2: Snapshot semantics; resolve movement only for selected targets

People can represent up to 512 residents through one `MultiMeshInstance3D`, and
CarManager can represent up to 256 car slots. Their existing rich diagnostic
snapshots sort, copy, and validate more information than a per-frame marker needs.
Community effect explanations are also intentionally non-routine projections.

**Decision**: Add one lightweight, sorted Community reaction-facts method for
committed semantic facts and inert persisted seed. The downstream projector—not
Community—attaches map epoch, presenter-supplied source version, and DayNight hour.
Add O(1) detached live-anchor getters on People and CarManager plus one ascending,
at-most-256 CarManager active-journey list fetched once per newly observed ambient
bucket. Resolve only the at-most-five active render targets each frame. Buildings
resolve directly from their stable session instance and registry anchor.

**Rationale**: Candidate generation stays versioned and explainable while moving
markers remain smooth without copying every entity every frame or breaking GPU
instancing.

**Alternatives rejected**:

- Attach a child marker to every person/car: slots are `RefCounted` records, not
  scene nodes, and per-entity nodes would discard the current scaling strategy.
- Call `get_resident_records(true)` or `get_traffic_flow_snapshot()` every frame:
  unnecessarily builds explanations, diagnostics, sorted arrays, and deep copies.
- Cache moving world positions in ProjectionRegistry: positions would become
  stale between committed state versions.

## Decision 3: Diff committed state with a silent map-epoch baseline

PresentationScheduler already coalesces authoritative changes after simulation
owners commit, and ProjectionRegistry caches detached operational projections.
However, GameState versions reset on a cold map boundary while current
presentation caches may retain records from the previous epoch.

**Decision**: Condition candidates compare the last-presented and newest-coalesced
sorted source projection only after a silent initial baseline. WorldReactions increments a
local presentation epoch and clears active/cooldown/wait state on boot, map load,
and clear. Candidate IDs include the epoch. ProjectionRegistry clears its runtime
cache and PresentationScheduler resets its coalesced/latest-version state at the
map boundary so same-version keys cannot return or present a previous town.

**Rationale**: Existing state never looks like a new change, many manually
advanced hours coalesce without a stale burst, and save/load cannot leak reactions
between towns.

**Alternatives rejected**:

- Key only by GameState version: version zero and early versions repeat after load.
- Persist the last reaction projection in DataMap: reaction history is not
  authoritative and would create migration/hash work.
- Replay every intermediate change after a long presentation gap: produces stale
  bursts and fights the scheduler's deliberate coalescing contract.

## Decision 4: Separate semantic speaker from live render target

A resident remains the subject of a happiness or route reaction even while their
person proxy is hidden in a car. The visible marker must then follow the active
journey, while deduplication and cooldown must still belong to the resident.

**Decision**: Semantic candidates carry `speaker_key` plus `target_intent` and an
optional target hint, but no concrete target. Live-anchor resolution creates a
separate immutable resolved candidate with `target_key` and lifecycle token. A
resident semantic candidate uses `person:<resident_id>` as speaker; resolution may
bind it to `person:<resident_id>` or `car:<journey_id>`. Car-operational reactions
use the journey as speaker and car intent. Buildings use their placed internal
instance as speaker and building intent.

**Rationale**: The correct visible object emotes without duplicating a resident
reaction during entry/exit or transferring cooldown to a recycled car slot.

**Alternatives rejected**:

- Treat speaker and target as one ID: loses resident continuity while travelling.
- Show the hidden resident at the car position: misrepresents People visibility
  and can create both a person and car marker for one subject.

## Decision 5: Treat route blocking and vehicle waiting as episodes

Person slots already track `BLOCKED` plus a reason, and car slots track `waiting`
and `wait_time`, but their full diagnostics are inappropriate for per-frame use
and no narrow transition signals currently exist.

**Decision**: Centralize People blocked-state/reason and CarManager waiting-state
transitions, increment transient episode IDs (including clear-old/start-new when
a normalized blocked reason changes), expose them in detached anchors,
and notify the downstream presenter when an episode begins or clears.
WorldReactions maps only the contract's route-failure reason allowlist to a
critical reaction, owns the 1.5-second vehicle presentation threshold, and emits
at most once per subject episode.

**Rationale**: People and Traffic remain owners of physical/visual operational
state while reaction mapping stays presentation-only. Episode identity makes
exact-once behaviour testable without polling every slot.

**Alternatives rejected**:

- Put “frustrated after 1.5 seconds” inside CarManager: couples traffic mechanics
  to an optional visual vocabulary.
- Infer route failure from Community's destination availability: the actual route
  outcome is resolved downstream by People and would be misclassified.
- Poll every active car every rendered frame: work scales with traffic rather
  than the bounded active reaction set.

## Decision 6: Use a town-wide deterministic ambient budget

Independent per-entity random rolls make a larger town emit more reactions and
are easy to couple accidentally to Community's RNG sequence.

**Decision**: At coarse absolute simulation-time buckets, use the contract's
typed length-prefixed UTF-8/SHA-256 function over the persisted Community seed and
bucket to decide whether the town receives zero or one ambient opportunity. If
unsuppressed, prefilter context-compatible on-screen subjects for lifecycle,
camera, ownership, and cooldown before ranking them with a separate subject hash
and select among lexicographically sorted compatible expressions with a third
context hash. Cars come from the bounded active-journey list; a resident currently
represented by one of those cars is excluded from the person set. Ambient
candidates always have the lowest priority and yield to condition activity,
cooldowns, focus suppression, and the hard cap. A post-rank invalidation rejects
the bucket without a fallback, and each bucket records one finite outcome.

**Rationale**: Density remains stable as population grows, repeated scenarios are
byte-equivalent, and gameplay RNG state is untouched. With the current 120-second
day and hourly commits, authored bucket probability can target one beat every
6–10 real seconds under automatic progression without wall-clock randomness.

**Alternatives rejected**:

- Sample the global or Community RNG: changes replay-sensitive sequences.
- Roll once per subject per frame: frequency scales with frame rate and town size.
- Save ambient history: unnecessary when seed, state, time bucket, and cooldown
  policy already determine presentation.

## Decision 7: Centralize stable arbitration and pre-emption

All sources compete for the same visual space. Selection order cannot depend on
dictionary order, signal timing, or scene-tree iteration.

**Decision**: One pure policy validates and stably orders candidates by priority,
cause, speaker, target, and candidate ID. It enforces one active reaction per
speaker/target, ten-second default cooldown, camera eligibility, two exact screen
lanes, five visible markers, fewest-victim condition-over-ambient replacement for
ownership/collision/cap, and priority-100 pre-emption of lower-ranked non-critical
conditions. Victims order by ascending priority, latest start, and greatest ID.
The existing unregistered spike policy is input and must be productionized
to include speaker/target separation, town-wide ambience, screen geometry, and
active-slot pre-emption.

**Rationale**: Every selected or rejected candidate can be reproduced and given
one stable diagnostic reason.

**Alternatives rejected**:

- Let each entity type own a quota: wastes slots and creates inconsistent rules.
- First-come/first-served signals: nondeterministic under concurrent changes.
- Unlimited critical markers: makes the cap meaningless at mass transitions.

## Decision 8: Pool a small world-space marker view

Builder's placement feedback already proves `Sprite3D` billboarding,
no-depth-test rendering, deterministic fading, and bounded cleanup. Nameplate
proves world billboards above building anchors.

**Decision**: WorldReactions owns a warm pool of at most eight marker views and
never more than five visible. A view contains the reaction flag sprite and only
the minimal animation state. Config-owned `{x,y,z}` target-kind offsets and camera
projection are updated centrally; the manifest owns pivot/bounds compatibility,
not runtime offsets. Reduced motion disables decorative scale/bob but retains
following and a simple opacity transition.

**Rationale**: Runtime allocation is bounded, moving anchors are cheap, and pool
state can be reset and leak-tested.

**Alternatives rejected**:

- Instantiate/free a new scene for every beat: creates avoidable churn during
  mass transitions.
- Reuse Builder's placement host directly: prevents independent priority,
  suppression, following, and diagnostics.
- Render as fixed HUD notifications: loses the spatial connection to the subject.

## Decision 9: Suppress focused modes and baseline placement commits

`GameEvents.player_input_mode_changed` already exposes world, radial, placement,
demolition, inspection, and modal modes. Existing placement feedback can show
the same quality direction that might create a world reaction.

**Decision**: New reactions appear only in ordinary world mode. Entering a focused
mode releases active flags by the next presentation update; candidates created
while suppressed advance the silent baseline and are discarded. Newly observed
building rows are baseline-only, so Builder's existing 3.2-second feedback remains
the sole placement announcement without a new Builder API or dependency. A later
condition first observed in world mode is distinct and eligible. Reaction views
ignore input.

**Rationale**: This protects reading and building tasks, avoids delayed bursts,
and preserves the current input-priority contract.

**Alternatives rejected**:

- Pause lifetimes and replay afterward: surfaces stale information out of context.
- Display above modal UI with a higher render layer: competes directly with
  dialogue and inspection.

## Decision 10: Create a dedicated speech-flag asset family

Existing Community icons use a parchment disc and semantic colours, while the
reference gains recognition from a repeated speech-like carrier. Reusing circular
metrics unchanged would make reactions look like placement or dashboard data.

**Decision**: Explore 6–8 materially different speech-flag silhouettes, then
approve one carrier for six symbolic expressions. Use parchment `#E7D3AD`, ink
`#171713`, established muted accents, asymmetry, and at most two or three comic
marks. Keep text out of the bitmap. Retain a high-resolution master, export
individual 128×128 RGBA runtime PNGs, and verify at 24–48 apparent pixels in
colour, grayscale, and noisy town context. Build an atlas only if later profiling
justifies it.

**Rationale**: Reactions read as a new but related family, remain accessible
without colour, and follow the repository's asset-production contract.

**Alternatives rejected**:

- Copy the supplied pixel faces: conflicts with the game's illustrated language.
- Generate a production atlas in one image-model call: cell order, padding, alpha,
  and consistency would not be deterministic.
- Use engine emoji or font glyphs: platform-dependent appearance and weak visual
  integration.

## Decision 11: Keep tuning and preferences outside gameplay authority

Thresholds, priorities, durations, cooldowns, cap, target offsets, ambient rate,
and cause mappings need one validated authored source. Player-facing settings
infrastructure is not yet generalised.

**Decision**: Store validated authored defaults in
`data/presentation/world_reactions.json`. Schema version 1 fixes the visible/pool
caps, happiness and wait thresholds, exactly one following ambient quiet bucket,
per-speaker cooldown identity, and canonical cause-to-expression,
speaker/target-kind, and priority mappings; conflicts are rejected rather than
normalized, while lifetime and other declared tuning
fields remain authorable only within their contract ranges. WorldReactions exposes transient
`full | conditions_only | off` and default-false reduced-motion setters/getters for current UI,
tests, and future settings integration. These values do not enter DataMap,
gameplay snapshots, transaction ledgers, or hashes.

**Rationale**: Designers can tune expression without modifying simulation balance,
and optional presentation cannot alter a save.

**Alternatives rejected**:

- Put reaction thresholds in Community balance data: suggests that presentation
  thresholds influence simulation.
- Add a full settings/save subsystem in this feature: materially expands scope.

## Decision 12: Instrument and verify the visual feature as a bounded system

**Decision**: Add separate performance boundaries for projection, arbitration,
live-anchor following, and render submission; expose a detached diagnostic trace;
compare fixed-step normalized reaction traces; and compare authoritative state
with the feature in all presentation modes.

**Rationale**: A five-view renderer should be cheap, but the dangerous work is
unbounded source projection or explanation-building. Separate measurements catch
that mistake directly.

**Alternatives rejected**:

- Rely only on aggregate FPS: can hide source work and provides no selection
  explanation.
- Include wall-clock timestamps or raw unsnapped transforms in replay traces:
  makes equivalent runs compare unequal for non-semantic reasons.
