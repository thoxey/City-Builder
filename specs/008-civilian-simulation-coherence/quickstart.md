# Quickstart: Coherent Civilian Simulation

Run commands from `/Users/tom/Starter-Kit-City-Builder`. Commands naming planned
files become runnable during implementation; the planning validation commands are
runnable now.

## 1. Validate the Spec Kit context

```bash
SPECIFY_FEATURE_DIRECTORY=specs/008-civilian-simulation-coherence \
  .specify/scripts/bash/check-prerequisites.sh --json
```

Expected now: the feature resolves to this directory and `plan.md` is present.
`tasks.md` is intentionally absent until `/speckit.tasks`.

## 2. Establish focused baselines before implementation

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-civilian-community.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/community -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-civilian-traffic.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/traffic -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-civilian-day-night.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/day_night -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-civilian-playtest.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/playtest -ginclude_subdirs -gexit
```

Research baseline: 69/69 focused tests passed (Community 38, traffic 7,
day/night 6, playtest 18). Freeze any changed baseline before evaluating the feature.

## 3. Run the planned focused behaviour suites

After implementation:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-civilian-people.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/people -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-civilian-integration.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/integration/civilian_simulation -ginclude_subdirs -gexit
```

Required cases:

- exact work and activity destination alignment;
- dwell until assignment end/change;
- disconnected journey refusal;
- walk/car route-threshold boundaries;
- resolved multi-stop route handoff;
- car-pool waiting without invalid walk fallback;
- unrelated-build continuity and targeted road invalidation;
- arrival, departure, rehome, proxy cap, programme change, and load reconstruction;
- diagnostics excluded from gameplay hash and persistence.

## 4. Run the planned deterministic full-day scenario

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-civilian-scenario.log \
  -s res://scripts/run_civilian_simulation_scenario.gd
```

The runner must use the existing playtest actions for authoritative changes and step
People/CarManager with a fixed delta between hour advances. It writes normalised
evidence under `specs/008-civilian-simulation-coherence/validation/`.

Expected checkpoints:

1. residents bind stably at home;
2. connected workers travel to their exact assignment;
3. short routes walk and long routes use cars;
4. workers dwell while the work assignment remains active;
5. scheduled activity destinations replace work/home at the correct boundary;
6. unrelated construction preserves active IDs, plan keys, and positions;
7. removing a used road affects only dependent residents;
8. disconnected residents start no journey;
9. residents return to their immutable homes;
10. final diagnostics contain no alignment violations.

## 5. Prove deterministic presentation

Run the canonical scenario ten times. Strip only explicitly volatile log timing, then
compare the ordered `civilian_simulation` trace byte-for-byte.

Expected: all ten traces match. Resident identity, purpose, destination, mode, route,
departure ordering, interruption response, and violation order must not vary.

## 6. Validate content and gameplay regressions

```bash
cd /Users/tom/Starter-Kit-City-Builder/tools/data_editor
npm run build
npm test

cd /Users/tom/Starter-Kit-City-Builder
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-civilian-unit.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://scripts/run_first_town_loop.gd
```

Expected: authored venue profiles validate; existing Community, traffic, day/night,
playtest, save/load, and first-town behaviour remains green. If sandboxed `user://`
fixture writes fail, rerun with a writable Godot user-data directory and record that
environment separately rather than accepting failed assertions.

## 7. Performance and normal-renderer evidence

- Measure per-frame People + CarManager update with 512 visible residents and
  diagnostics off; target an average below 16.7 ms on the reference machine.
- Request diagnostics at defined checkpoints and record projection cost separately.
- Run one full game day with the normal renderer and current assets only.
- Verify there are no mass home pops, unexplained car disappearances, cross-country
  walkers, arbitrary rapid destination churn, or visible/Community destination
  mismatches.
- Store performance output, normalised traces, content inventory, and observation
  notes under `specs/008-civilian-simulation-coherence/validation/`.

## 8. Asset-scope gate

Compare the implementation diff against runtime asset extensions (`.glb`, `.png`,
`.jpg`, `.webp`, `.wav`, `.ogg`). Expected: no new or modified runtime art/audio
assets attributable to this feature. Existing person, car, road, venue, and UI assets
are reused unchanged.
