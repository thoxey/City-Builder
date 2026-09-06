# Quickstart: Performance Foundation Verification

## Prerequisites

- Godot 4.6.2 at `/Applications/Godot.app/Contents/MacOS/Godot`
- Repository root as the working directory

## Focused regression suites

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit/community,res://test/unit/day_night,res://test/unit/playtest,res://test/unit/traffic,res://test/unit/player_ui -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/integration/civilian_simulation,res://test/integration/player_ui,res://test/integration/performance -ginclude_subdirs -gexit
```

## Full automated suite

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

## Repeated realistic performance playthroughs

```bash
/usr/bin/time -lp /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://scripts/run_performance_playthroughs.gd
```

Expected evidence is written to `specs/009-performance-foundation/validation/playthrough-report.json`. The run passes only if all construction actions are legal, required roles are covered, deterministic replay holds, total time stays below the reference gate, and no hourly transition exceeds the stall threshold.

## Manual morning smoke test

1. Start a fresh city and confirm non-Town-Hall construction is rejected.
2. Place the Town Hall, extend a connected road, then place homes, workplaces, shops, civic venues and nature touching the rooted road.
3. Let time cross 05:00 to 06:00 with a populated town and confirm input/camera remain responsive.
4. Open and navigate the radial menu; confirm locked and available choices behave correctly.
5. Confirm the top bar updates cash, population, time and other canonical values.
6. Exercise build, demolish and cancel through the bottom tool bar and confirm a single active mode.

Expected result: no multi-second pause at 06:00, no illegal placement succeeds, locked radial entries remain visible but cannot be selected, and the three core HUD surfaces continue reflecting canonical game state. Side-panel testing is intentionally outside this checklist.
