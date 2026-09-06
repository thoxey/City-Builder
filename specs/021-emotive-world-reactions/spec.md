# Feature Specification: Emotive World Reactions

**Feature Branch**: `021-emotive-world-reactions`

**Created**: 2026-09-06

**Status**: Draft

**Input**: Add compact reactions inspired by the supplied expression-bubble
reference, translated into the game's illustrated visual language, so people,
cars, and buildings visibly respond to changing conditions and occasionally
show contextual ambient personality.

## Scope and boundaries

This feature adds short-lived world-space reaction flags above visible people,
active vehicles, and placed buildings. Reactions explain a meaningful condition
transition or add a rare contextual ambient beat. They are derived presentation:
they never create, modify, or replace Community happiness, traffic state,
building operation, schedules, demand, progression, or dialogue.

The initial semantic vocabulary is `pleased`, `concerned`, `frustrated`,
`surprised`, `busy`, and `sleepy`. The supplied image informs the compact shared
carrier and readable variation, but its pixel treatment and literal sprite grid
are not copied. Runtime art uses the established warm parchment, irregular
near-black ink, muted semantic colours, strong silhouette, and limited comic
punctuation.

The feature includes condition reactions, sparse deterministic ambience, one
shared arbitration/lifetime policy, a dedicated reaction asset family, focus and
reduced-motion hooks, diagnostics, and verification. It does not add speech
text, conversations, new personality or building-mood simulation, vehicle AI,
audio barks, persistent reaction history, clickable reactions, or a general
notification framework. Dialogue portraits and existing placement feedback
retain their current contracts.

## User Scenarios & Testing

### User Story 1 - See the Town Respond (Priority: P1)

As a player watching the town, I see visible people, cars, and places briefly
react when their circumstances materially improve, worsen, or become blocked.

**Why this priority**: Condition-driven reactions make abstract simulation
changes legible and give the town emotional life without adding dialogue.

**Independent Test**: Drive canonical resident, traffic, home, and place state
across every declared trigger boundary and verify the correct expression appears
over the correct visible target exactly once.

**Acceptance Scenarios**:

1. **Given** a visible resident's committed happiness rises or falls by at least
   8 points, **When** the new state is presented, **Then** `pleased` or
   `concerned` respectively appears above that resident's current representation.
2. **Given** a resident becomes unhoused or People resolves their required route
   as impossible, **When** the committed diff or blocked episode is presented,
   **Then** a critical `concerned` or `frustrated` reaction appears exactly once.
3. **Given** a resident is currently hidden inside an active car, **When** their
   reaction is selected, **Then** the flag follows that car journey and never
   appears above the hidden person proxy.
4. **Given** a car has waited continuously for at least 1.5 real seconds,
   **When** it first crosses the threshold, **Then** one `frustrated` reaction
   appears above the car; continued waiting does not retrigger it every frame.
5. **Given** a home gains or loses occupancy, the signed mean happiness delta of
   residents continuously assigned to that home reaches at least 8 points in
   either direction, or it loses or regains road access, **When** the transition
   commits, **Then** the home emits the single
   highest-priority eligible building reaction from the canonical trigger matrix
   at its current registry anchor.
6. **Given** an operational place opens, closes, starts or stops activity, loses
   or regains access, or changes programme, **When** canonical operation state changes,
   **Then** it emits the exact cause, expression, and priority declared by the
   canonical trigger matrix without inventing new building state.
7. **Given** the reaction system establishes its first projection after boot,
   map load, or reconstruction, **When** existing conditions are observed,
   **Then** it records a silent baseline rather than presenting false changes.
8. **Given** several causes target one entity in the same committed version,
   **When** arbitration runs, **Then** only the highest-priority eligible reaction
   appears and its diagnostic cause identifies the canonical transition.

---

### User Story 2 - Read Reactions Without Losing the Town (Priority: P1)

As a player, I recognise reactions at normal play zoom without flags obscuring
one another, fighting existing UI, or turning a busy town into visual noise.

**Why this priority**: The feature only works when its expression is immediate,
restrained, and visibly part of the established game.

**Independent Test**: Force more eligible reactions than the cap in a dense
reference town at every supported viewport and camera zoom, then verify style,
priority, separation, following, lifetime, and cleanup.

**Acceptance Scenarios**:

1. **Given** any supported target, **When** a reaction is visible, **Then** it
   uses the approved wonky parchment speech-flag carrier, thick near-black ink,
   and existing semantic accent colours.
2. **Given** the six initial meanings, **When** viewed in colour or grayscale at
   24, 32, 40, and 48 apparent pixels, **Then** each remains distinguishable by
   silhouette or internal mark rather than colour alone.
3. **Given** more candidates than available slots, **When** arbitration runs,
   **Then** no more than five reactions are visible, no target owns more than
   one, and higher-priority condition reactions win.
4. **Given** two non-critical markers would overlap at the current camera and
   viewport, **When** they are admitted or followed, **Then** the lower-ranked
   marker tries the single configured vertical lane and is rejected or released
   if the rectangles, each expanded 8 px on every side, still overlap.
5. **Given** a person or car moves, **When** its reaction remains active, **Then**
   the flag follows the current live anchor without changing movement or
   requiring an individual scene node for every simulated entity.
6. **Given** a target disappears, becomes hidden, is demolished, completes a
   journey, or has its pooled slot reused, **When** the presenter next updates,
   **Then** the old reaction is released rather than transferred or stranded.
7. **Given** a required expression asset cannot be resolved, **When** presentation
   is attempted, **Then** no broken or misleading marker appears and a stable
   diagnostic is recorded.

---

### User Story 3 - Let Quiet Moments Feel Alive (Priority: P2)

As a player watching a stable town, I occasionally see a contextually appropriate
everyday reaction that adds personality without suggesting a gameplay event that
did not occur.

**Why this priority**: Ambient beats provide the requested “somewhat randomly”
flavour, but they must remain subordinate to trustworthy condition feedback.

**Independent Test**: Run the same seeded town and ordered clock advances twice,
compare the complete ambient trace, then repeat with a different seed and with a
competing condition reaction.

**Acceptance Scenarios**:

1. **Given** an eligible quiet on-screen target and no condition reaction in the
   current or immediately preceding absolute-hour bucket,
   **When** its deterministic ambient bucket is selected, **Then** it may show a
   contextually valid low-priority expression.
2. **Given** identical persisted seed, target identities, state, and absolute
   simulation-time buckets, **When** the scenario is replayed, **Then** the same
   ambient decisions occur in the same stable order.
3. **Given** a different seed or time bucket, **When** ambient selection runs,
   **Then** the outcome may vary without reading or advancing any gameplay RNG.
4. **Given** a person is travelling, resting, working, blocked, or unhoused,
   **When** ambience is considered, **Then** only compatible expressions are
   eligible and a serious condition is never contradicted.
5. **Given** a car is moving or waiting, or a building is open, closed, occupied,
   or inactive, **When** ambience is considered, **Then** its expression matches
   the visible context.
6. **Given** presentation mode is `conditions_only`, **When** the town runs, **Then** no
   ambient candidate becomes visible while condition reactions continue.
7. **Given** there is no eligible visible target or the presentation is
   suppressed, **When** ambient buckets pass, **Then** beats do not accumulate and
   burst later.

---

### User Story 4 - Preserve Focus and Comfort (Priority: P2)

As a player using focused interfaces or reduced-motion presentation, I am not
distracted by decorative world reactions.

**Why this priority**: Reactions should enrich observation and yield whenever the
player is reading, choosing, placing, demolishing, or inspecting.

**Independent Test**: Inject candidates while cycling every input mode and
presentation preference, then inspect visibility, stale-queue behaviour, input,
and motion.

**Acceptance Scenarios**:

1. **Given** modal dialogue, radial navigation, placement, demolition, or
   Community inspection is active, **When** candidates arrive, **Then** no new
   flag becomes visible and active flags release by the next
   presenter/frame update.
2. **Given** the game returns to normal world mode, **When** presentation resumes,
   **Then** historical suppressed candidates are not replayed in a burst.
3. **Given** reduced motion is enabled, **When** a reaction displays, **Then**
   necessary target following remains but decorative bob, bounce, and scale
   motion are removed.
4. **Given** presentation mode is `off`, **When** simulation changes occur,
   **Then** no reaction renders and gameplay results remain identical.
5. **Given** a world reaction is visible, **When** the player clicks or uses the
   keyboard/gamepad, **Then** the marker never captures or changes input handling.

---

### User Story 5 - Explain and Verify the System (Priority: P3)

As a developer or playtester, I can explain why a reaction appeared or was
suppressed and prove that the feature does not alter gameplay or exceed budgets.

**Why this priority**: Deterministic diagnostics make visual tuning trustworthy
and prevent a flavour feature from obscuring simulation or performance defects.

**Independent Test**: Run a fixed-step reaction scenario twice, inspect selected
and rejected records, compare gameplay hashes, and profile maximum workload.

**Acceptance Scenarios**:

1. **Given** diagnostics are requested, **When** arbitration completes, **Then**
   stable records identify target, expression, cause, priority, source provenance,
   lifetime, and any rejection or suppression reason.
2. **Given** identical scenario inputs and visual time steps, **When** normalized
   traces are compared, **Then** condition and ambient records are identical.
3. **Given** reactions use `full`, `conditions_only`, or `off`, **When** gameplay
   state is saved or hashed, **Then** all three produce identical authority.
4. **Given** the maximum supported people, car, building, and reaction load,
   **When** profiling runs, **Then** work remains bounded and separately attributed
   to projection, arbitration, anchor following, and render submission.

### Edge Cases

- Happiness oscillates around a trigger threshold; the 10-second per-speaker
  cooldown prevents alternating spam, and only a fresh committed absolute
  8-point delta after expiry can trigger again.
- A resident enters or leaves a car after candidate creation; speaker identity is
  retained while the live render target is rebound or safely discarded.
- A car completes, is cancelled, or is pooled while its reaction is active.
- A car remains blocked beyond cooldown; it cannot retrigger until the wait
  episode clears and a later episode crosses the threshold.
- Several residents in one home have conflicting deltas in one commit; stable
  aggregation chooses one reaction and retains its cause evidence.
- A reacting building is replaced or demolished before expiry.
- Many places open or close on the same hour; stable priority and the global cap
  prevent a schedule-boundary burst.
- Manual advancement crosses many hours before one rendered frame; only the
  newest coalesced projection is eligible and stale ambience is discarded.
- Camera movement, zoom, or resize changes projected overlap while targets move.
- A target is inside the viewport but occluded by a tall building; the marker
  intentionally uses the same no-depth-test world-UI treatment as placement
  feedback and must pass the approved noisy-town proof.
- A large frame delta passes an entire remaining lifetime; cleanup still occurs
  on the next update.
- A candidate has an unknown expression, target kind, invalid anchor, negative
  priority, duplicate ID, stale version, or missing texture.
- Loading, clearing, or starting a map resets version epochs while projection
  caches still contain records from the previous epoch.
- A building is placed while Builder feedback is visible; the new building row
  hydrates silently, candidates created during placement are discarded, and a
  later committed world-mode condition change remains independently eligible.

## Requirements

### Functional Requirements

- **FR-001**: Reactions MUST remain derived presentation and MUST NOT mutate or
  become authority for happiness, traffic, assignments, schedules, buildings,
  demand, economy, progression, dialogue, randomness, or clock state.
- **FR-002**: Boot, map load, map clear, and reconstruction MUST establish a silent
  baseline and clear all candidates, active slots, cooldowns, blocked/wait episode
  memory, and prior versions. Already-blocked and already-waiting episodes MUST be
  marked observed without emitting or starting timers before runtime event admission
  reopens.
- **FR-003**: Every semantic candidate MUST contain candidate ID, speaker identity,
  render-target intent, semantic expression, canonical cause, priority, source
  version, lifecycle episode, or time-bucket provenance as applicable, its committed
  absolute-hour quiet bucket, bounded lifetime, and deduplication/cooldown keys; before
  admission a resolved candidate MUST add the concrete target identity, lifecycle
  token, finite world anchor, and projected screen rectangle.
- **FR-004**: Supported render targets MUST be `person`, `car`, and `building`;
  malformed, missing, hidden, stale, or unsupported targets MUST fail safely.
- **FR-005**: Source systems MUST expose the smallest bounded detached operational
  facts required; the feature MUST NOT read private pools or request full resident
  effect explanations every frame.
- **FR-006**: People MUST expose O(1) live reaction-anchor lookup containing
  resident identity, visibility, display position, visual state, blocked reason,
  blocked episode, purpose, and active journey ID, plus generic exactly-once
  blocked-start/clear transitions for state entry, state exit, and blocked-reason
  changes that do not know reaction semantics.
- **FR-007**: CarManager MUST expose O(1) live reaction-anchor lookup containing
  journey/resident identity, display position, waiting state/episode, and lifecycle
  validity, plus a sorted detached list of at most 256 active journey IDs evaluated
  only for a new ambient bucket, without building a full diagnostic traffic snapshot.
- **FR-008**: Community MUST expose sorted detached resident
  identity/home/happiness, placed-building occupancy/operation/access/programme,
  and the persisted Community seed without per-frame provenance materialization;
  WorldReactions MUST attach its local map epoch, the presenter-supplied committed
  source version, and DayNight's absolute hour when constructing the projection.
- **FR-009**: Condition candidates MUST be derived from stable before/after
  projections or exactly-once canonical People-blocked/Car-wait lifecycle
  transitions.
- **FR-010**: The initial condition map MUST cover material happiness rise/fall,
  blocked/unhoused residents, prolonged vehicle waits, resident-driven home
  occupancy count gain/loss (including those caused by arrival, departure, and
  rehome), building access/activity start or stop/open or closed state, and programme change; roster events
  MUST NOT independently create a person reaction for an initial or removed row.
- **FR-011**: Happiness change MUST use an absolute 8-point trigger threshold;
  continuous vehicle waiting MUST use a 1.5-second trigger threshold.
- **FR-012**: A waiting reaction MUST fire once per wait episode and re-arm only
  after movement resumes or the journey ends.
- **FR-013**: A resident currently represented by a car MUST keep `person:<id>` as
  semantic speaker/cooldown identity while using `car:<journey_id>` as render target.
- **FR-014**: A building MUST react only for observable occupancy, fulfilled
  activity, access, programme, or schedule-derived open/closed state; it
  MUST NOT receive an invented private mood or react to an authored schedule edit
  that produces no declared observable transition.
- **FR-015**: Rule mappings and presentation thresholds MUST be centralized,
  validated, and deterministic. Schema-version-1 invariants—five visible views,
  eight pooled views, the 8-point happiness threshold, the 1.5-second wait
  threshold, one following quiet bucket, per-speaker cooldown identity, and the
  canonical cause-to-expression, speaker/target-kind, and cause-to-priority
  mappings—MUST reject rather than normalize a
  conflicting authored value; changing an invariant requires a schema and
  contract revision and MUST NOT change simulation balance.
- **FR-016**: Candidate arbitration MUST use a stable total order independent of
  dictionary, node, signal, or frame iteration order.
- **FR-017**: Canonical priority MUST be: critical unhoused/impossible-route `100`;
  traffic wait `90`; access loss `85`; material resident happiness `80`;
  home/activity/programme/access-gain `70`; place open `60`; place closed `50`;
  and ambience `10`.
- **FR-018**: At most five reactions may be visible, at most one may speak for a
  semantic entity, at most one may occupy a render target even when person and
  car speakers converge on it, and every admitted reaction's final release MUST
  apply a default 10-second per-speaker cooldown.
- **FR-019**: Any condition candidate MUST pre-empt ambient reactions that block
  its speaker, target, unresolved post-lane screen rectangle, or the visible cap.
  A priority-100 condition MUST similarly pre-empt lower-ranked non-critical
  conditions when required. Victims MUST be chosen by ascending priority, then
  latest start, then lexicographically greatest candidate ID; only the smallest
  required victim set may yield. All other candidates MUST respect existing
  ownership, separation, and the hard visible cap.
- **FR-020**: Off-screen, behind-camera, hidden, and unresolved targets MUST be
  removed before consuming the cap.
- **FR-021**: Non-critical marker screen rectangles expanded outward by the
  configured per-side padding (at least 8 px) MUST NOT intersect and those
  expanded rectangles MUST remain at least
  12 px inside the viewport; conflicts MUST use at most one configured upward
  screen-space adjustment `(0, -56 px)` by default and no unbounded jitter.
- **FR-022**: Active reactions MUST follow only their live resolved anchors using
  target-specific height/lead offsets; on a matching person/car representation
  handoff they MUST rebind by the next update, otherwise they MUST release by that
  update rather than remain attached to stale or reused lifecycle state.
- **FR-023**: Rendering MUST use a reusable pool of at most eight marker views for
  the five-visible cap and MUST NOT create a persistent node per possible entity.
- **FR-024**: Each reaction MUST use a 1.6–2.4 second bounded enter/hold/exit
  lifetime, defaulting to 2.0 seconds, and reset all pooled view state on release.
- **FR-025**: Modal, radial, placement, demolition, and inspection modes MUST
  suppress new reactions and release active markers by the next presenter/frame
  update without preserving a stale replay queue or capturing input; ordinary
  final-release cooldown applies, except map reset clears all cooldown state.
- **FR-026**: A newly observed placed-building row MUST hydrate silently, and all
  candidates created while placement mode is active MUST advance the silent
  baseline and be discarded. Builder's existing 3.2-second placement feedback
  MUST remain unchanged and be the sole placement announcement; WorldReactions
  MUST add no Builder dependency, while later committed world-mode transitions
  remain independently eligible.
- **FR-027**: Ambient selection MUST be a pure deterministic function of persisted
  Community seed, stable subject identity, current context, and a bucket equal to
  one committed absolute simulation hour, using the contract's typed length-prefixed
  UTF-8/SHA-256 hash definition; it MUST NOT read or advance gameplay RNG.
- **FR-028**: Ambient selection MUST make at most one town-wide opportunity per
  bucket using the default `625 / 1000` opportunity threshold, suppress the
  current and next bucket after any semantically valid condition candidate is
  created (including an episode candidate stamped with the presentation batch's
  committed absolute hour), and discard missed buckets
  so frequency does not increase linearly with population or later burst.
- **FR-029**: Ambient output MUST average one eligible town-wide beat every 6–10
  seconds under automatic reference-town progression and yield to any competing
  condition reaction, cooldown, quiet period, cap, or focus suppression.
- **FR-030**: Presentation modes MUST support `full`, `conditions_only`, and `off`;
  `conditions_only` MUST release active ambience, `off` MUST release all active
  reactions, and re-enabling MUST replay nothing. Invalid mode values MUST leave
  state unchanged. Reduced motion MUST default false, change in place without
  restarting semantic lifetime, preserve target following, and remove decorative
  motion.
- **FR-031**: Transient reaction state and presentation preferences MUST remain
  outside authoritative save fields, gameplay snapshots, and deterministic hashes.
- **FR-032**: The visual family MUST provide distinct `pleased`, `concerned`,
  `frustrated`, `surprised`, `busy`, and `sleepy` flags using parchment, near-black
  irregular ink, semantic accents, clean transparency, and no baked text.
- **FR-033**: Expression meaning MUST remain distinguishable without colour and at
  24–48 apparent pixels over quiet and noisy gameplay.
- **FR-034**: Art delivery MUST retain a high-resolution master, labelled 6–8
  silhouette exploration, individual 128 px RGBA runtime exports, manifest,
  actual-size proofs, grayscale proof, and noisy-town proof.
- **FR-035**: Missing or invalid art MUST suppress only the affected marker and
  emit a stable diagnostic without a broken or semantically false fallback.
- **FR-036**: A detached diagnostic trace MUST expose source version, candidates,
  selected/pre-empted records, active slots, cooldowns, and stable rejection codes;
  it MUST retain at most 64 arbitration batches and at most 128 combined,
  canonically ordered candidate/decision records per batch, with deterministic
  omitted-count/digest metadata on truncation. Deduplication and cooldown memory
  MUST compact to current source/episode tokens and unexpired live-speaker entries;
  each batch MUST expose at most 128 cooldown summaries with deterministic omission
  metadata.
- **FR-037**: Performance instrumentation MUST separately measure reaction source
  projection, arbitration, anchor following, and render submission.
- **FR-038**: Automated coverage MUST include policy, projection, anchors,
  target handoff/lifecycle, suppression, pool cleanup, ambient determinism, map
  epoch reset, malformed input, performance, and authoritative-state parity.
- **FR-039**: Normal-renderer QA MUST cover 1280×720, 1920×1080, and 3840×2160,
  minimum/maximum gameplay zoom, quiet/dense towns, day/night, motion, focus modes,
  reduced motion, the deliberate no-depth-test occlusion treatment, and all expressions.
- **FR-040**: Existing playtest diagnostics MAY expose reaction state, but the
  feature MUST NOT add a new gameplay mutation command.

### Key Entities

- **Reaction Source Snapshot**: Bounded detached resident and placed-building
  facts for one state version and absolute simulation-time bucket.
- **Reaction Candidate**: Immutable semantic possibility before camera,
  cooldown, collision, cap, and active-target arbitration.
- **Resolved Reaction Candidate**: Immutable semantic candidate joined to one
  currently valid target lifecycle, finite live anchor, and projected rectangle.
- **Reaction Speaker**: Stable person, journey, or building identity that owns
  deduplication and cooldown even if its render target changes.
- **Reaction Render Target**: Live person, active car journey, or placed building
  with a currently resolvable presentation anchor.
- **Reaction Rule**: Authored mapping from transition/context to expression,
  priority, thresholds, lifetime, cooldown, and ambient eligibility.
- **Active Reaction Slot**: Pooled marker bound through enter, hold, exit,
  pre-emption, suppression, or invalidation.
- **Ambient Decision**: Town-budgeted deterministic selection for one time bucket.
- **Reaction Asset Entry**: Semantic key, source/runtime paths, dimensions, alpha,
  display range, pivot/offset, and proof metadata.
- **Reaction Diagnostic Trace**: Detached evidence explaining every selection or
  rejection without entering gameplay authority.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The canonical trigger matrix produces the declared target, cause,
  expression, and priority for 100% of covered threshold/polarity cases, with zero
  output below threshold or during baseline hydration.
- **SC-002**: Across at least three playtesters shown the randomized canonical
  condition matrix without cause labels, at least 80% of reactions are correctly
  associated with their source change.
- **SC-003**: Dense stress traces contain zero frames with more than five markers,
  more than one reaction per semantic speaker, more than one marker per render
  target, or an unresolved stale target.
- **SC-004**: All visible non-critical marker rectangles satisfy the approved
  non-intersecting 8 px expansion and 12 px viewport-safe margin at every
  supported viewport and zoom.
- **SC-005**: Ten same-seed, same-state, fixed-step replays produce byte-equivalent
  normalized candidate, selection, rejection, pre-emption, release, cooldown,
  active-slot, and ambient traces.
- **SC-006**: Across ten quiet-town seed traces, each with exactly 60 fixed-step
  presentation seconds of excluded warm-up followed by 1,800 measured seconds,
  the aggregate
  eligible observation seconds divided by accepted ambient beats is inclusively
  6.0–10.0 seconds, with at least one accepted beat; reports include opportunity,
  rejection, and acceptance counts, and ambience never wins over a condition.
- **SC-007**: At least three reviewers independently identify at least 90% of
  randomized expression proofs at 24, 32, 40, and 48 apparent pixels in colour
  and grayscale quiet/noisy contexts; every expression is identified by at least
  two reviewers at every size, with no alpha fringe or unreadable silhouette.
- **SC-008**: Lifecycle stress leaves zero orphaned markers after expiry,
  pre-emption, target removal, input suppression, load, or reset and allocates no
  more than eight reusable marker views, with zero marker-view allocations after
  warm-up.
- **SC-009**: At 500 residents, 256 active/pending car journeys, 135 buildings,
  and five active markers, source projection p95 is at most 4,000 µs,
  arbitration p95 at most 1,000 µs, anchor-follow p95 at most 500 µs, render-submit
  p95 at most 500 µs, rendered-frame median/p95/maximum at most
  16,700/25,000/50,000 µs, and both median rendered frame time and median FPS
  regress by no more than 5% versus the matched `off` run. Each of at least three matched
  runs excludes exactly 120 warm-up frames, measures at least 600 rendered frames,
  and contains at least 120 samples for each feature boundary; the dedicated
  maximum profile obtains event-driven source/arbitration samples with one tagged,
  detached, authority-neutral probe every five measured frames in both modes.
- **SC-010**: `full`, `conditions_only`, and `off` runs have identical save payloads,
  gameplay and transaction-ledger hashes, Community RNG state, resident
  assignments/happiness, traffic routes/completion order, building and clock state,
  economy, demand, and progression outcomes.
- **SC-011**: Modal, radial, placement, demolition, inspection, off-screen, and
  behind-camera fixtures display zero ineligible reactions and produce no stale
  post-suppression burst.
- **SC-012**: Focused and full Godot suites, deterministic replay, save/load
  reconstruction, the civilian/traffic/first-town/opening/transactional standalone
  scenario matrix, and normal-renderer QA pass.

## Assumptions

- A building reaction speaks for observable occupancy or operation, not a private
  building emotion.
- Condition reactions and sparse ambience are enabled by default; ambience can be
  disabled independently.
- Allowed lifetime, cooldown, spacing, offset, and ambient-frequency values are
  presentation tuning, not simulation balance; schema-version-1 safety invariants
  remain fixed unless their schema and contract are revised.
- Suppressed or off-screen historical reactions are discarded rather than replayed.
- Existing Community seed, absolute hour, state version, person identity, journey
  identity, and building instance identity are sufficient for deterministic input.
- Necessary target following remains under reduced motion; only decorative motion
  is removed.
- Six non-text expressions are sufficient for the first production vocabulary.
