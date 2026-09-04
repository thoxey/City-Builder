# Verification Results

Date: 2026-09-04  
Godot: 4.6.2.stable.official.71f334935  
GUT: 9.3.0  
Node test runner: Vitest 4.1.2

## Focused community verification

The community suites cover resident serialization, personality generation,
effect math/scopes/schedules/stacking, authored catalog profiles, migration,
retention, persistence, legacy migration, composition, catalog-backed building
integration, bounded snapshots, compact snapshots, and the 500-resident
performance target.

## TypeScript server

```bash
cd server
npm run build
npm test -- --run
```

TypeScript compiles successfully. Vitest passes 8 files and 29 tests; 2 opt-in
live-connection tests are skipped offline. The existing six tools remain the
complete public interface, and full/compact Community snapshot contracts pass.

## Live AI outcome acceptance

The opt-in runtime suite in `server/src/tools/playtest-runtime-live.test.ts`
passes 8/8 tests against the running Godot game. It exercises the same semantic
start, state, place, demolish, and exact-hour operations exposed to an AI
playtester and verifies the intended player-visible outcomes:

- identical resident and quality records in 10/10 seeded replays;
- distinct responses by Identity-heavy and Freedom-heavy residents to the same
  night venue, including simultaneous venue benefit and noise harm;
- separate, structured park benefits and nightlife nuisances with source,
  anchor, quality, manifestation, scope, signed amount, and reason;
- successful migration into an amenity-supported neighbourhood;
- higher seven-day population in the matched town than the nuisance town under
  the same seed and equal housing capacity, with neither exceeding capacity;
- persistence through hour 23 of homelessness and departure only when the
  configured 24-hour relocation grace is reached.

Runtime IPC requests are written to a temporary file and atomically renamed
into place. This prevents the running game from observing partial JSON during
rapid deterministic replay. The direct runtime path also isolates outcome
validation from unrelated open Godot editor instances competing for an editor
WebSocket connection.

## Godot command

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --log-file /tmp/city-builder-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit -ginclude_subdirs -gexit
```

Result: 28 scripts, 207 tests, 207 passing, and 1,045 assertions in 3.534
seconds. GUT reported no failing, pending, or risky tests. Expected negative-path
warnings and the repository's pre-existing orphan/resource cleanup warnings are
not failed assertions.
