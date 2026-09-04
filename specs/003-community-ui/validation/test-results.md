# Community Insight UI verification

Date: 2026-09-04  
Godot: 4.6.2 stable  
GUT: 9.3.0  
Vitest: 4.1.2

## Automated results

| Gate | Result | Exact total |
|---|---|---|
| Community UI GUT suite | PASS | 7 scripts, 30/30 tests, 117 assertions, 3 warnings |
| Full recursive GUT suite | PASS | 35 scripts, 237/237 tests, 1,162 assertions, 17 warnings, 3.732 s |
| TypeScript default suite | PASS | 8 passed + 5 opt-in skipped files; 30 passed + 23 opt-in skipped tests; 346 ms |
| Live Community AI suite | PASS | 1 file, 9/9 tests; 4.72 s |
| Live rendered acceptance | PASS | 1 file, 2/2 tests; 4.06 s |
| Godot editor parse/import | PASS | Exit 0; CommunityInspector and CommunityPanel class registration completed |

The full GUT run reports pre-existing teardown noise: 17 expected warning categories, 681 total orphan observations, four leaked `GodotBody3D` RIDs, and four resources still in use at process exit. No test or assertion failed. The focused Community UI run reports three fixture/control cleanup warnings and 11 total orphan observations; again, no failures.

## Deterministic live outcomes

- Canonical scenario load/parity passed for `community_personality_contrast` seed 22001, `community_park_and_noise` seed 22002, `community_migration_week` seed 22003, and `community_retention_failure` seed 22004. Every UI population, capacity, happiness, and ordered quality aggregate matched the authoritative Community snapshot.
- Identical personality/resident replay passed 10/10 times.
- Seven-day matched town: 5 residents / 5 capacity.
- Seven-day nuisance town: 0 residents / 5 capacity, 28 rejected candidates.
- Relocation boundary: hour 23 retained 2 residents, each at 23 homeless hours; hour 24 produced population 0 and 2 departures.
- The park-and-nightlife scenario retained simultaneous positive and negative effect rows with source, quality, manifestation, scope, reason, schedule, and signed amount.

## Performance

- Pure view-model projection for 500 residents: 15.445 ms (acceptance limit: 100 ms).
- Resident controls instantiated per page: 16 maximum; no per-frame projection or list rebuild.
- Community simulation for 500 residents over 168 exact hourly ticks: 2.9260 s (acceptance limit: 10 s).

## Commands

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit --path /Users/tom/Starter-Kit-City-Builder
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tom/Starter-Kit-City-Builder -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/community_ui -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tom/Starter-Kit-City-Builder -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit
npm test
RUN_LIVE_GODOT=1 ... npx vitest run src/tools/playtest-runtime-live.test.ts --silent=false --reporter=verbose
RUN_VISUAL_GODOT=1 ... npx vitest run src/tools/community-ui-visual-live.test.ts
```
