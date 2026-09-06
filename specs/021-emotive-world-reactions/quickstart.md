# Quickstart Validation: Emotive World Reactions

This guide is the required validation sequence for the production feature. The
runner, capture script, tests, and evidence paths named below are delivery
contracts; they become runnable as their implementation tasks land. Run every
command from the repository root with a writable Godot `user://` directory.

## Prerequisites

- Godot 4.6.x at `/Applications/Godot.app/Contents/MacOS/Godot`.
- A debug build for headless contracts, fixed-step scenarios, and parity checks.
- A normal Forward+ display for visual capture and rendered performance evidence.
- The same reference seed, town fixture, renderer, build mode, viewport, warm-up,
  and sample rules for enabled-versus-off performance comparisons.
- Evidence written only under
  `specs/021-emotive-world-reactions/validation/`; reaction diagnostics and
  timings must not enter gameplay saves or hashes.

## 1. Import and focused reaction gates

Import all scripts and assets before running GUT:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit --path .
```

Run the reaction contracts, pure policy/projection tests, and live integration
tests:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/contract/reactions,res://test/contract/performance,res://test/unit/reactions,res://test/integration/reactions \
  -ginclude_subdirs -gexit
```

Expected: all six semantic expressions and every declared condition boundary
pass; first projection and map-epoch changes are silent; malformed candidates
fail safely; ordering, priority, five-visible cap, per-speaker ownership,
cooldown, pre-emption, screen separation, target handoff, pooled cleanup,
suppression, reduced motion, and missing-asset diagnostics are deterministic.

Run the affected authority and anchor regression suites:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-regression.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/community,res://test/unit/people,res://test/unit/traffic,res://test/unit/presentation,res://test/unit/plugin_manager,res://test/unit/playtest,res://test/unit/builder,res://test/unit/player_ui,res://test/integration/community,res://test/integration/traffic_flow,res://test/integration/simulation \
  -ginclude_subdirs -gexit
```

Expected: the new detached Community facts, downstream source wrapper, O(1) live
anchors, and once-per-ambient-bucket car subject enumeration preserve existing
Community, People, CarManager, Builder, input-mode, and presentation contracts
without requesting full diagnostics on routine frames or changing Builder.

## 2. Deterministic fixed-step replay

Run ten isolated copies of the canonical reaction scenario:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-replay.log \
  -s res://scripts/run_world_reaction_scenario.gd -- \
  --seed=21021 --runs=10 --fixed-step --mode=full \
  --evidence-path=res://specs/021-emotive-world-reactions/validation/deterministic-replay.json
```

Expected: normalized candidate, selected, pre-empted, rejected, cooldown, active
slot, and ambient traces are byte-equivalent across all ten runs. Source
versions, absolute time buckets, and stable target order must match; wall-clock
timings and rendered coordinates are excluded from the normalized trace. No
reaction path may read or advance gameplay RNG.

Compare equal elapsed visual time at 30 Hz and 60 Hz:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-rate-equivalence.log \
  -s res://scripts/run_world_reaction_scenario.gd -- \
  --seed=21021 --fixed-step-rates=30,60 --assert-semantic-equivalence \
  --evidence-path=res://specs/021-emotive-world-reactions/validation/frame-rate-equivalence.json
```

Expected: wait-threshold admissions, condition candidates, ambient decisions, and
normalized semantic traces are identical. Animation sample frames may differ;
admission and release times normalized to presentation-clock microseconds may not.

Run the ambient-rate matrix separately:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-ambient.log \
  -s res://scripts/run_world_reaction_scenario.gd -- \
  --scenario=quiet-town --seed-start=21021 --seed-count=10 \
  --warmup-seconds=60 --duration-minutes=30 --fixed-step --mode=full \
  --evidence-path=res://specs/021-emotive-world-reactions/validation/ambient-frequency.json
```

Expected: for each seed, exclude exactly 60 fixed-step presentation seconds, then
measure exactly 1,800 presentation/real seconds (`--duration-minutes=30`, not
simulation-clock minutes; 15 automatic simulation days). Sum measured seconds only while mode is `full`,
input mode is `world`, no condition quiet period applies, and at least one subject
passes the exact pre-rank eligibility filter. Divide that aggregate across all ten seeds by accepted ambient beats;
zero accepts fails and the inclusive result must be 6.0–10.0 seconds. Record
suppressed, no-opportunity, no-eligible, per-reason rejection, and acceptance
counts. Ambience never contradicts target
context, accumulates while suppressed, or wins over a condition reaction.

## 3. Authoritative-state parity

Compare the same seed, ordered actions, and fixed time steps in all three
presentation modes:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-parity.log \
  -s res://scripts/run_world_reaction_scenario.gd -- \
  --seed=21021 --runs=1 --fixed-step \
  --scenarios=normal,save-load,map-clear,target-removal,full-town \
  --modes=full,conditions_only,off --assert-authority-parity \
  --evidence-path=res://specs/021-emotive-world-reactions/validation/authoritative-parity.json
```

Expected: `full`, `conditions_only`, and `off` produce identical save payloads,
authoritative state and ledger hashes, Community RNG state, resident identities,
assignments and happiness, traffic routes and completion order, building state,
economy, demand, progression, and clock state. Reaction preferences, candidates,
active slots, cooldowns, and traces remain absent from authority and save data.

The command's scenario matrix covers save/load reconstruction, map clear, target
removal, and a full automated town. A reload establishes a silent baseline and
must leave zero stale candidates or markers from the previous epoch.

## 4. Full Godot suite

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-full-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test -ginclude_subdirs -gexit
```

Expected: zero failures before the feature is considered complete. Record the
engine version, command, totals, failures, and environment in
`validation/test-results.md`.

## 5. Standalone scenario matrix

Run every non-GUT regression that exercises adjacent simulation and replay paths:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-civilian.log \
  -s res://scripts/run_civilian_simulation_scenario.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-traffic.log \
  -s res://scripts/run_traffic_flow_scenario.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-first-town.log \
  -s res://scripts/run_first_town_loop.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-opening.log \
  -s res://scripts/run_opening_tutorial_scenario.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-transactional.log \
  -s res://scripts/run_performance_playthroughs.gd
```

Expected: every runner exits zero; repeated semantic/state hashes and transaction-
ledger hashes retain their existing expectations. Record commands, hashes, and
results in `validation/regression-scenarios.md`.

## 6. Normal-renderer visual evidence

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --log-file /tmp/city-builder-world-reactions-visual.log \
  --script res://scripts/capture_world_reactions_validation.gd -- \
  --resolutions=1280x720,1920x1080,3840x2160 \
  --evidence-dir=res://specs/021-emotive-world-reactions/validation/screenshots
```

The capture manifest and `validation/visual-qa.md` must cover all three
resolutions at minimum and maximum gameplay zoom in quiet and dense towns,
day/night, stationary and moving people/cars, representative buildings, all six
expressions, enter/hold/exit, target handoff, focus suppression, reduced motion,
and depth/occlusion cases. Include actual-size 24, 32, 40, and 48 px proofs in
colour and grayscale plus a noisy-town proof.

Randomize the canonical condition clips and hide cause labels from at least three
playtesters; at least 80% of reactions must be associated with the correct source
change. Separately randomize every expression across 24, 32, 40, and 48 px colour
and grayscale quiet/noisy proofs for at least three reviewers; each reviewer must
identify at least 90% overall, and every expression at every size must be identified
by at least two reviewers. Record presentation order, raw responses, percentages,
misses, and reviewer count in `validation/visual-qa.md`.

Expected: meanings remain distinguishable without colour; parchment, irregular
near-black ink, semantic accents, transparency, offsets, and silhouettes match
the approved art family; no non-critical rectangles violate the approved
separation or viewport-safe region; no frame shows more than five markers; and
no marker captures input, transfers to a reused target, strands after cleanup,
or displays a broken fallback.

## 7. Performance budgets and evidence

Run the dedicated integration budget gate:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-world-reactions-budget-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/integration/performance/test_world_reaction_budget.gd \
  -gexit
```

Then collect at least three equivalent normal-renderer runs at 500 residents,
256 active/pending journeys, 135 buildings, and five active markers, comparing
`full` with `off` after the same 120-frame warm-up:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --log-file /tmp/city-builder-world-reactions-performance.log \
  -s res://scripts/run_world_reaction_scenario.gd -- \
  --seed=21021 --profile=max_supported --runs=3 \
  --warmup-frames=120 --measured-frames=600 --minimum-boundary-samples=120 \
  --mode=full --compare-mode=off \
  --evidence-path=res://specs/021-emotive-world-reactions/validation/performance.json
```

Each matched run must exclude exactly 120 warm-up frames, measure at least 600
rendered frames, and retain at least 120 samples for every named reaction
boundary; a short run fails. In this `max_supported` profile only, run one detached
maximum-workload source-projection probe and one greater-than-cap arbitration
probe every five measured frames in both modes, include their work in frame totals,
and tag all 120 probe samples; ordinary play must never schedule them. The report must use the repository's documented nearest-rank percentile rule,
include raw sample counts, exclusions, workload, seed, town/workload ID, renderer
and build environment, reproduce command, per-run authoritative state hashes,
transaction-ledger hashes, thresholds, and pass/fail reasons, and attribute the
following boundaries separately:

| Boundary or resource | Required gate |
|---|---:|
| `world_reactions.source_projection` | p95 ≤ 4,000 µs |
| `world_reactions.arbitration` | p95 ≤ 1,000 µs |
| `world_reactions.anchor_follow` | p95 ≤ 500 µs |
| `world_reactions.render_submit` | p95 ≤ 500 µs |
| Reusable marker pool | ≤ 8 views and zero post-warm-up allocations |
| Rendered frame total | median ≤ 16,700 µs; p95 ≤ 25,000 µs; max ≤ 50,000 µs |
| Enabled-versus-off frame cost | median frame time regression ≤ 5% and median FPS regression ≤ 5% |

Expected: every run passes every feature and existing frame gate, the cap keeps
anchor/render work bounded, and enabled/off authoritative hashes remain equal.
Store any automatic failing-gate diagnostic output in
`validation/performance-diagnostics.json` and investigation notes in
`validation/performance-investigation.md`;
never relax a gate or omit a failed sample without documenting the cause.
