# Quickstart: Traffic Flow Coherence

Run from `/Users/tom/Starter-Kit-City-Builder`.

## 1. Validate context

```bash
SPECIFY_FEATURE_DIRECTORY=specs/010-traffic-flow-coherence \
  .specify/scripts/bash/check-prerequisites.sh --json
```

## 2. Freeze pre-change evidence

Run existing traffic, People, Playtest, and feature-008 suites. Capture fixed-step
traces for four same-origin departures, a backed-up straight route, opposing traffic,
a corner, and pedestrians sharing waypoints. Store traces/screenshots under
`specs/010-traffic-flow-coherence/validation/`.

## 3. Focused unit suites

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-traffic-flow-traffic.log \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/traffic -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-traffic-flow-people.log \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/people -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-traffic-flow-playtest.log \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/playtest -ginclude_subdirs -gexit
```

Required cases: pending-first admission, total capacity two, direction-aware origin
claims, two-phase crossing, FIFO, pool/road reasons, cancellation, no congestion
reroute/completion, bounded transforms, pedestrian separation, detached diagnostics,
and hash/save exclusion.

## 4. Integration suite

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-traffic-flow-integration.log \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/integration/traffic_flow \
  -ginclude_subdirs -gexit
```

Prove: four requests become two active/two pending; one release admits one FIFO request;
downstream blockage backs up on-road; opposing cars remain distinct under total capacity
two; long valid blockage never reroutes/disappears; targeted invalidation preserves
unrelated state; grouped pedestrians remain distinct and deterministic.

## 5. Deterministic runner

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-traffic-flow-scenario.log \
  -s res://scripts/run_traffic_flow_scenario.gd
```

Run ten same-seed fixed-step replays and compare pending order, active order, claims,
waiting, paths, and transforms byte-for-byte. Inject every fault and prove detection.
Reuse existing authoritative playtest actions plus internal visual stepping; add no
public command.

## 6. Full regressions

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-traffic-flow-unit.log \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://scripts/run_civilian_simulation_scenario.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://scripts/run_first_town_loop.gd
```

Use writable Godot application data for the full suite. Existing civilian replay and
first-town gameplay hashes must remain green.

## 7. Performance, visual, and assets

- At 512 visible civilians with cars, pending departures, queues, and walkers, keep
  average update below 16.7 ms; measure diagnostics separately.
- Run 1920x1080 normal-renderer observation. Verify only two cars at an origin, waiting
  residents stay visible, queues remain on-road through starts/corners/junctions,
  congestion causes no disappearance, and walkers remain distinct without jitter.
- Record screenshots and observer notes; visual review remains a manual gate.
- Compare runtime art/audio paths and digests with the pre-change inventory. Expected:
  zero feature-attributable additions or modifications.
