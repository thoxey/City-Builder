# Tasks: Emotive World Reactions

**Input**: Design documents from `specs/021-emotive-world-reactions/`

**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`,
`contracts/world-reactions-contract.md`, `quickstart.md`

**Tests**: Required by the specification and project constitution. Add each focused
assertion before its implementation slice and confirm that the intended failure is
observed. Validation evidence belongs under
`specs/021-emotive-world-reactions/validation/` and is not runtime content.

## Phase 1: Baseline and failing contracts

**Goal**: Capture authority/performance baselines and pin every new ownership seam
before runtime code is connected.

- [ ] T001 Record source/runtime asset inventories, pre-feature save/state/ledger hashes,
  Community RNG state, current projection timings, renderer environment, supported
  workload, and existing Builder placement-feedback and Nameplate billboard behaviour in
  `specs/021-emotive-world-reactions/validation/baseline.md` and
  `specs/021-emotive-world-reactions/validation/baseline.json`.
- [ ] T002 [P] Add failing schema, enum, range, default-false reduced motion,
  fixed-invariant rejection, one following quiet bucket, speaker-equal cooldown key,
  56 px lane, exact schema-v1 cause-to-expression/target/priority map, structural
  missing-mapping fallback versus per-expression runtime-asset isolation, and
  safe-fallback contracts in
  `test/contract/reactions/test_world_reaction_config_contract.gd` for
  `data/presentation/world_reactions.json`.
- [ ] T003 [P] Extend the spike assertions in
  `test/unit/reactions/test_world_reaction_policy.gd` with failing fixtures for stable
  ordering, per-speaker and per-target ownership, cooldown, condition-over-ambient
  ownership/collision/cap replacement, fewest-victim admission plans, ascending-priority/
  latest-start/greatest-ID victim ties, priority-100 bypass and condition pre-emption, five-visible/eight-pool
  caps, canonical committed/blocked/wait/ambient candidate IDs, 8 px per-side padding,
  viewport culling, malformed input, and stable rejection codes.
- [ ] T004 [P] Add failing semantic-diff, silent-baseline, home-aggregation, cooldown,
  previous-presented-to-newest-coalesced version, and map-epoch fixtures in
  `test/unit/reactions/test_world_reaction_source.gd`.
- [ ] T005 [P] Add failing bounded detached facts assertions to
  `test/unit/community/test_community_reaction_projection.gd`, including the inert
  persisted `community_seed`, stable resident/building order, absence of verbose effect
  provenance, and absence of downstream map-epoch/source-version/absolute/local-hour fields.
- [ ] T006 [P] Add failing O(1) person-anchor, hidden-proxy, journey-binding, finite-copy,
  blocked-reason/episode, canonical route-reason allowlist, exactly-once blocked-start/
  clear on state and normalized-reason changes, ignored-to-canonical transition,
  exact `{ok:false,reason:"missing"}` collapse and downstream lifecycle-mismatch
  distinction, silent reconstruction, map-reset, purpose, and pooled-slot-reuse assertions to
  `test/unit/people/test_people_reaction_anchor.gd`.
- [ ] T007 [P] Add failing O(1) car-anchor and exactly-once waiting-episode transition
  assertions to `test/unit/traffic/test_car_reaction_anchor.gd`, covering the sorted
  at-most-256 active-journey subject list, once-per-new-bucket caller discipline,
  finite `wait_seconds`, movement resume, completion, cancellation, silent
  reconstruction, exact missing-failure shape, downstream lifecycle mismatch, and slot reuse.
- [ ] T008 [P] Add failing same-version map-load/map-clear cache and scheduler isolation
  assertions to `test/unit/presentation/test_projection_registry.gd` and
  `test/unit/presentation/test_presentation_scheduler.gd`, plus plugin dependency/
  activation assertions to `test/unit/plugin_manager/test_plugin_activation.gd` and
  failing eight-view/zero-post-warm-up-allocation, enter/hold/exit, direct pre-emption,
  large-delta, missing-texture, and exhaustive-reset assertions to
  `test/unit/reactions/test_world_reaction_view.gd`.

## Phase 2: Foundational projections, models, and lifecycle

**Goal**: Establish validated detached inputs and lifecycle-safe identity before any
marker can render.

- [ ] T009 Author the complete schema-version-1 defaults and canonical cause table in
  `data/presentation/world_reactions.json`, including the six expressions, priorities,
  exact speaker/target kinds, default-false reduced motion,
  8-point happiness threshold, 1.5-second wait threshold, 10-second cooldown, 625/1000
  hourly ambient opportunity, exactly one following quiet bucket, 8 px per-side padding,
  authoritative `{x,y,z}` target offsets of `(0,0.75,0)`, `(0,1.0,0)`, and
  `(0,3.0,0)` for person/car/building, 56 px bounded upward
  vertical lane, and 12 px
  viewport margin.
- [ ] T010 Implement one-time normalization, validation, immutable getters, and the
  built-in `conditions_only` safety fallback in
  `scripts/reactions/world_reaction_config.gd` until T002 passes.
- [ ] T011 [P] Define detached source rows, candidates, live anchors, active slots,
  strict source-kind/provenance unions, quiet buckets, compact deduplication,
  cooldown entries, ambient outcomes, asset entries, and diagnostic records in
  `scripts/reactions/world_reaction_types.gd` without adding DataMap fields.
- [ ] T012 Implement Community's sorted bounded resident/place reaction facts and inert
  seed in `plugins/community/community_plugin.gd` until T005 passes, excluding downstream
  epoch/version/hour fields; cache invalidation continues through the existing declared
  ProjectionRegistry domains and committed change-set revisions.
- [ ] T013 [P] Add transient blocked-episode state to `plugins/people/person_slot.gd`,
  centralize exactly-once generic blocked-start/clear notifications for state and
  normalized-reason changes plus silent reconstruction/reset in
  `plugins/people/people_plugin.gd`, and implement `get_reaction_anchor(resident_id)` as
  a detached O(1) lookup including visibility, state, blocked reason/episode, purpose,
  and journey binding until T006 passes without exposing `PersonSlot` or creating nodes.
- [ ] T014 [P] Implement `get_reaction_anchor(journey_id)`, sorted detached
  `get_reaction_subject_ids()`, monotonic wait-episode IDs, and generic
  wait-start/wait-clear notifications in `plugins/traffic/car_slot.gd` and
  `plugins/traffic/car_manager_plugin.gd`, including finite accumulated `wait_seconds`
  and silent reconstruction, until T007 passes; keep the 1.5-second reaction
  threshold out of traffic authority and never build a full traffic diagnostic snapshot.
- [ ] T015 Clear runtime projection records and reset pending/latest/per-presenter
  scheduler version state at boot, load, clear, and reconstruction in
  `plugins/presentation/projection_registry.gd`,
  `plugins/presentation/presentation_scheduler_plugin.gd`, and
  `scripts/presentation/presenter_registration.gd` until T008 proves that repeated
  GameState versions can neither reuse nor suppress records from a previous town.
- [ ] T016 Create the `WorldReactions` plugin lifecycle, dependency declarations, local
  `map_epoch`, and the registered projector wrapper that attaches the supplied source
  version plus distinct DayNight absolute and local hours to Community facts; add silent first baseline, teardown reset,
  lifecycle-event admission gate, silent scan/observation of pre-existing blocked and
  waiting episodes, an always-true semantic presenter visibility callback, and transient mode/reduced-motion API in
  `plugins/world_reactions/world_reactions_plugin.gd`, then register it in
  `scripts/plugin_manager.gd` without introducing a dependency cycle.
- [ ] T017 [P] Create and label 6–8 materially distinct speech-flag carrier explorations
  in `art/ui/world-reactions/review/`, recording reference lineage, the approved carrier,
  rejected directions, and asset-family usage in
  `art/ui/world-reactions/review/design-notes.md` and
  `art/ui/world-reactions/README.md`.
- [ ] T018 Create high-resolution masters for `pleased`, `concerned`, `frustrated`,
  `surprised`, `busy`, and `sleepy` at
  `art/ui/world-reactions/masters/pleased.png`,
  `art/ui/world-reactions/masters/concerned.png`,
  `art/ui/world-reactions/masters/frustrated.png`,
  `art/ui/world-reactions/masters/surprised.png`,
  `art/ui/world-reactions/masters/busy.png`, and
  `art/ui/world-reactions/masters/sleepy.png`, using
  parchment `#E7D3AD`, near-black `#171713`, semantic accents, irregular silhouettes,
  no baked text, and no literal pixel-art copy.
- [ ] T019 Export and verify individual 128×128 lossless sRGB RGBA files under
  exact paths `sprites/ui/world-reactions/pleased.png`,
  `sprites/ui/world-reactions/concerned.png`,
  `sprites/ui/world-reactions/frustrated.png`,
  `sprites/ui/world-reactions/surprised.png`,
  `sprites/ui/world-reactions/busy.png`, and
  `sprites/ui/world-reactions/sleepy.png` with
  `.agents/skills/city-builder-ui-assets/scripts/format_ui_asset.py`, then author exact
  runtime paths, pivots, bounds/target-offset compatibility, dimensions, alpha, and
  proof metadata in `art/ui/world-reactions/manifest.json`; create the referenced
  asset-only 24/32/40/48 px, grayscale, and composited noisy-context proof files in
  `art/ui/world-reactions/review/`, record review approval, and keep config
  `target_offsets` as the sole runtime offset authority.
- [ ] T020 Productionize `scripts/reactions/world_reaction_policy.gd` so validated
  candidates use immutable IDs, stable total ordering, declared priorities,
  bounded deduplication, expired/dead-speaker cooldown eviction, per-target ownership,
  first-applicable rejection codes, bounded two-lane/five-slot admission plans, and
  the five-visible/eight-view bounds, until every pure-policy assertion in T003 passes.
- [ ] T021 Build a reset-safe eight-view `Sprite3D` pool and lifecycle-safe
  camera-facing marker primitive in `plugins/world_reactions/world_reaction_view.gd`,
  with zero post-warm-up allocations and no input handling, until T008's view
  assertions pass.

**Checkpoint**: Detached facts, live anchors, wait episodes, epoch reset, config,
approved runtime assets, generic arbitration, and the bounded view pool are testable
with no condition or ambient source enabled and no save/hash changes.

## Phase 3: User Story 1 - See the town respond (P1)

**Goal**: Emit exactly one canonical condition reaction above the correct live target.

**Independent Test**: Run the canonical trigger matrix through resident, travelling
resident, car, home, and operational-place fixtures, including silent hydration and
lifecycle invalidation.

- [ ] T022 [US1] Add failing end-to-end trigger, route-block episode/reason filtering and
  ignored-to-canonical reason changes, recovery, silent pre-existing episodes,
  person/car handoff and follow-time ownership convergence, wait-threshold, demolition, journey completion/
  cancellation, pooled reuse, first-baseline, missing-asset, and
  large-frame-delta coverage in
  `test/integration/reactions/test_condition_world_reactions.gd`.
- [ ] T023 [US1] Implement sorted before/after condition derivation, exact 8-point
  happiness boundaries, stable conflicting-home aggregation including zero contributors
  and same-count swaps, exact occupancy/access/
  activity/programme/open-state transitions, cooldown re-trigger boundaries, and
  previous-presented-to-newest-version coalescing in
  `scripts/reactions/world_reaction_source.gd` until T004 passes.
- [ ] T024 [US1] Resolve resident speakers once at arbitration to the current visible
  person or exact active journey target, rebind an active slot by the next update on a
  verified later handoff, and discard invalid handoffs in
  `plugins/world_reactions/world_reactions_plugin.gd` without transferring
  identity to reused slots.
- [ ] T025 [US1] Connect committed Community diffs, canonical People blocked episodes,
  CarManager wait-episode threshold tracking, building-registry lifecycle, candidate
  arbitration, live-anchor following, and immediate invalidation in
  `plugins/world_reactions/world_reactions_plugin.gd` until T022 passes.
- [ ] T026 [US1] Record the canonical cause/expression/priority matrix results and a
  short `conditions_only` demonstration in
  `specs/021-emotive-world-reactions/validation/condition-matrix.md`.

**Checkpoint**: User Story 1 is independently acceptance-testable in
`conditions_only` mode with manifest-valid approved assets and focused assertions
that no reaction path writes authority; full cross-mode authority parity remains T046.

## Phase 4: User Story 2 - Read reactions without losing the town (P1)

**Goal**: Prove the shared six-expression art family stays legible in dense play.

**Independent Test**: Force more than five candidates across supported viewports and
zooms, then verify style, grayscale meaning, separation, following, pooling, and cleanup.

- [ ] T027 [P] [US2] Add failing camera-projection fixtures to
  `test/unit/reactions/test_world_reaction_layout.gd` for nonintersection after 8 px
  per-side expansion, expanded-rectangle containment inside the 12 px viewport margin,
  one bounded vertical lane adjustment, condition-over-ambient collision pre-emption,
  fewest-victim/tie order, priority-100 overlap, resize,
  zoom, and behind-camera/off-screen rejection.
- [ ] T028 [US2] Implement stable screen-space admission and follow-time conflict release
  in `scripts/reactions/world_reaction_policy.gd` and
  `plugins/world_reactions/world_reactions_plugin.gd` until T027 passes without jitter;
  release the lower-ranked slot immediately on follow-time speaker/target convergence.
- [ ] T029 [US2] Implement 1.6–2.4-second enter/hold/exit presentation, target-kind
  offsets, deliberate no-depth-test treatment, fixed 24–48 px apparent size, and complete
  pool reset in `plugins/world_reactions/world_reaction_view.gd`.
- [ ] T030 [US2] Produce normal-renderer quiet/dense-town gameplay proofs for all six
  expressions, cross-check the foundational actual-size/grayscale asset proofs, and
  record 1280×720, 1920×1080, and 3840×2160 review results in
  `specs/021-emotive-world-reactions/validation/visual-qa.md`.

**Checkpoint**: Both P1 stories pass independently; dense output remains capped,
recognisable, lifecycle-safe, and visually subordinate to the town.

## Phase 5: User Story 3 - Let quiet moments feel alive (P2)

**Goal**: Add sparse contextual personality with deterministic town-wide selection.

**Independent Test**: Replay identical seeds and absolute-hour commits, change one seed,
and compare quiet-town frequency with and without competing conditions.

- [ ] T031 [P] [US3] Add failing pure ambient fixtures to
  `test/unit/reactions/test_world_reaction_ambient.gd` for the 625/1000 opportunity roll,
  exact typed length-prefixed UTF-8/SHA-256 opportunity/subject/expression hashes,
  stable lexicographic expression sets, local-hour 21:00/06:00 night boundaries with
  absolute-hour-only bucket hashing, context matrix,
  one-town candidate limit, current-plus-
  next-bucket quiet period including hour-boundary episode stamps, exact outcome/
  reason/count precedence, eligibility population on false rolls, pre-rank cooldown/
  ownership filtering, post-rank revalidation with no fallback, serious-state
  exclusion-to-reason mapping, and missed-bucket discard.
- [ ] T032 [US3] Implement the gameplay-RNG-free absolute-hour ambient opportunity,
  subject prefilter/counting, outcome state machine, ranking, context mapping, and
  stable expression choice in
  `scripts/reactions/world_reaction_policy.gd` until T031 passes.
- [ ] T033 [US3] Integrate at most one ambient opportunity per newly committed absolute
  hour in `plugins/world_reactions/world_reactions_plugin.gd`, with condition, cooldown,
  cap, focus-mode, and `conditions_only` precedence; enumerate active cars only once for
  a new bucket, exclude their `IN_CAR` residents, stamp queued condition episodes from
  one batch hour before ambient evaluation, and keep no fallback or catch-up queue.
- [ ] T034 [US3] Create the fixed-step CLI harness in
  `scripts/run_world_reaction_scenario.gd` after first adding failing runner-contract
  assertions to `test/unit/reactions/test_world_reaction_runner_contract.gd`; cover
  normalized trace, quiet-town matrix, ten-replay support, ambient warm-up/measurement
  accounting, and 30/60 Hz equal-elapsed comparison.
- [ ] T035 [US3] Run the ten-replay, 30/60 Hz equivalence, and ten-seed thirty-minute
  ambient commands from `quickstart.md`, excluding exactly 60 fixed-step presentation
  seconds then measuring exactly 1,800 seconds per seed; record byte-equivalence, semantic-rate
  equivalence, eligible observation seconds divided by nonzero accepted beats, inclusive
  6.0–10.0 result, separate suppressed/no-opportunity/no-eligible counts,
  per-reason rejection counts, acceptance counts, exclusions, and any tuning decision in
  `specs/021-emotive-world-reactions/validation/deterministic-replay.json`,
  `specs/021-emotive-world-reactions/validation/frame-rate-equivalence.json`, and
  `specs/021-emotive-world-reactions/validation/ambient-frequency.json`.

**Checkpoint**: Ambient flavour is independently disableable, deterministic, bounded
per town rather than per entity, and never implies a contradictory condition.

## Phase 6: User Story 4 - Preserve focus and comfort (P2)

**Goal**: Yield immediately to focused play and support reduced motion and full disable.

**Independent Test**: Inject old and new candidates through every input mode and each
presentation preference while verifying no replay burst or input capture.

- [ ] T036 [P] [US4] Add failing integration coverage for `world`, `radial`, `placement`,
  `demolition`, `inspection`, and `modal` transitions, stale-candidate discard, reduced
  motion in-place, exact active-release behavior for `full | conditions_only | off`,
  invalid-mode no-op, wait-threshold/ambient/cooldown advancement while suppressed,
  always-on baseline advancement without `DIRTY_HIDDEN`, and input transparency in
  `test/integration/reactions/test_world_reaction_focus_modes.gd`; also add failing
  placement/Builder coexistence assertions to
  `test/integration/reactions/test_world_reaction_placement_coexistence.gd`.
- [ ] T037 [US4] Subscribe to `GameEvents.player_input_mode_changed`, release/reset
  markers with `mode_suppressed` and ordinary cooldown by the next presenter/frame
  update, discard suppressed candidates, and resume only with new events in
  `plugins/world_reactions/world_reactions_plugin.gd` until T036 passes.
- [ ] T038 [US4] Apply transient mode and reduced-motion changes in
  `plugins/world_reactions/world_reactions_plugin.gd` and
  `plugins/world_reactions/world_reaction_view.gd`: release ambience on
  `full -> conditions_only`, release all on entry to `off`, replay nothing on
  re-enable, reject invalid mode strings without mutation, and preserve active
  phase/lifetime/anchor following while removing decorative scale, bounce, and bob.
- [ ] T039 [US4] Complete placement coexistence behavior until T036's dedicated test
  proves new building rows hydrate silently, placement-mode candidates advance baseline
  and are discarded, existing 3.2-second Builder feedback remains unchanged, no Builder
  API/dependency is added, and a later world-mode condition remains eligible.
- [ ] T040 [US4] Record a focus-mode/reduced-motion/off-mode normal-renderer review and
  the absence of a stale resume burst in
  `specs/021-emotive-world-reactions/validation/focus-and-motion.md`.

## Phase 7: User Story 5 - Explain and verify the system (P3)

**Goal**: Make every decision explainable and prove bounded work and zero gameplay drift.

**Independent Test**: Compare fixed-step normalized traces and gameplay hashes, then
profile the declared maximum workload with feature enabled and off.

- [ ] T041 [P] [US5] Add failing diagnostic-shape, bounded-history, stable-reason,
  exact disposition-enum, detached-copy, batch-local trace ordinals,
  exact candidate/decision/cooldown and five-slot active-summary shapes/order,
  frame-only release batches, no-op
  update omission, 64-batch/128-combined-record truncation
  with per-kind omitted counts and the contract's exact typed-field digest,
  128-cooldown truncation with separate omitted count/digest, and normalization contracts in
  `test/contract/reactions/test_world_reaction_diagnostics_contract.gd`, plus failing
  acceptance assertions for the four new boundary names in
  `test/contract/performance/test_performance_evidence_contract.gd`.
- [ ] T042 [US5] Implement the bounded detached diagnostic trace and
  `get_reaction_diagnostics()` in `plugins/world_reactions/world_reactions_plugin.gd`
  until T041 passes, excluding wall time, raw transforms, ObjectIDs, and memory addresses
  from normalized output.
- [ ] T043 [US5] Add the read-only reaction projection to
  `plugins/playtest/playtest_plugin.gd` in debug builds and cover it in
  `test/unit/playtest/test_playtest_plugin.gd` without adding a mutation command.
- [ ] T044 [US5] Instrument `world_reactions.source_projection`,
  `world_reactions.arbitration`, `world_reactions.anchor_follow`, and
  `world_reactions.render_submit` by adding them to
  `scripts/performance/performance_sample.gd`'s closed boundary list and recording them
  through the existing performance monitor in
  `plugins/world_reactions/world_reactions_plugin.gd` until T041's boundary-name
  validity assertions pass.
- [ ] T045 [US5] Add maximum-workload and enabled-versus-off gates to
  `test/integration/performance/test_world_reaction_budget.gd` for 500 residents, 256
  active/pending journeys, 135 buildings, five visible/eight pooled views, each declared
  p95 boundary, exactly 120 excluded warm-up frames, at least 600 measured frames and 120
  samples per feature boundary per matched run using tagged five-frame profile probes for
  event-driven boundaries, zero post-warm-up allocations, existing
  frame limits, ≤5% regression in both median frame time and median FPS, and failing
  max-profile CLI/probe scheduling assertions consumed by T047.
- [ ] T046 [US5] First extend
  `test/unit/reactions/test_world_reaction_runner_contract.gd` with failing authority-
  matrix assertions, then extend `scripts/run_world_reaction_scenario.gd` with authoritative
  hash outputs and the explicit `normal,save-load,map-clear,target-removal,full-town`
  matrix; run fixed-step `full`, `conditions_only`, and `off` parity for every case
  and store hashes and comparison results in
  `specs/021-emotive-world-reactions/validation/authoritative-parity.json`.
- [ ] T047 [US5] Extend `scripts/run_world_reaction_scenario.gd` with the normal-renderer
  `--profile`, `--runs`, `--warmup-frames`, `--measured-frames`,
  `--minimum-boundary-samples`, and `--compare-mode` contract. In `max_supported`,
  schedule/tag one detached authority-neutral source projection and one greater-than-cap
  arbitration probe every five measured frames in both modes, include probe work in
  frame totals, and keep probes disabled outside the profile.

## Phase 8: Release evidence and scope audit

- [ ] T048 Create `scripts/capture_world_reactions_validation.gd` to capture the exact
  viewport, zoom, day/night, density, motion, handoff, focus, reduced-motion, and
  occlusion matrix declared by `quickstart.md`, including deterministic
  `specs/021-emotive-world-reactions/validation/screenshots/manifest.json`.
- [ ] T049 Run the focused reaction, affected regression, and full recursive GUT suites
  from `quickstart.md` and record commands, Godot version, totals, failures, and environment in
  `specs/021-emotive-world-reactions/validation/test-results.md`.
- [ ] T050 Run the civilian, traffic-flow, first-town, opening-tutorial, and
  transactional-performance standalone scenario matrix from
  `quickstart.md`; resolve every failure and record commands, hashes, ledger hashes, and
  results in `specs/021-emotive-world-reactions/validation/regression-scenarios.md`.
- [ ] T051 Run at least three normal-renderer maximum-workload comparisons and record raw
  samples (at least 600 rendered frames and 120 per feature boundary after exactly 120
  excluded warm-up frames), nearest-rank percentiles, workload, exclusions, seed, town/workload ID,
  renderer/build environment, authoritative state hash, transaction-ledger hash,
  per-boundary gates, frame gates, both enabled/off median regressions, and reproduce command in
  `specs/021-emotive-world-reactions/validation/performance.json`; store any automatic
  failing-gate diagnostic dump and investigation notes at
  `specs/021-emotive-world-reactions/validation/performance-diagnostics.json` and
  `specs/021-emotive-world-reactions/validation/performance-investigation.md`.
- [ ] T052 Complete the normal-renderer capture review; give a randomized canonical
  condition matrix without cause labels to at least three playtesters and require ≥80%
  source association, then give randomized colour/grayscale quiet/noisy proofs at every
  declared size to at least three reviewers and require each reviewer to achieve
  ≥90% identification plus two
  correct reviewers per expression/size; record protocol, presentation order, raw
  responses, reviewer count, percentages, individual misses, alpha/scale issues, and approval in
  `specs/021-emotive-world-reactions/validation/visual-qa.md`.
- [ ] T053 Audit the final diff and document in
  `specs/021-emotive-world-reactions/validation/scope-audit.md` that it adds no mood
  simulation, dialogue, audio, persistent reaction history/preferences, gameplay RNG use,
  per-entity scene nodes, click handling, general notification framework, or any Builder
  API/dependency/placement-feedback ownership change.

## Dependencies and execution order

- T001–T008 establish the baseline and failing contracts and can proceed in parallel
  where marked.
- T009–T021 are foundational. T012–T015 and T017 may proceed in parallel after their
  matching failing contract or visual-language gate; T016 and T020–T021 follow the
  public seams, normalized config, and approved asset manifest.
- User Story 1 (T022–T026) depends on Phase 2 and is the first production slice.
- User Story 2 (T027–T030) depends only on the foundational assets, pool, and policy
  and can use forced candidates independently of User Story 1 condition derivation.
- User Story 3 (T031–T035) depends on stable arbitration but not on focus diagnostics.
- User Story 4 (T036–T040) depends on the runtime plugin and marker view; its tests may be
  authored while User Story 3 is implemented.
- User Story 5 (T041–T047) depends on all selection paths so its trace and budgets cover
  production behaviour.
- T048–T053 are release gates and follow every selected story; T051 also depends on
  the profiling CLI in T047.

## Implementation strategy

Ship the smallest trustworthy slice first: detached source/anchor contracts, silent
baseline, canonical condition derivation, stable arbitration, and the bounded marker pool
in `conditions_only` mode. Complete and approve the six-expression art and dense-layout
proofs before enabling ambience. Add deterministic ambient flavour, then focus/reduced-
motion policy, diagnostics, and evidence. Keep every task presentation-only and stop if a
change would require new simulation state or a save-schema field.
