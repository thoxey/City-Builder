# Quickstart: Validate Reachable First-Patron Progression

Run commands from the repository root unless a command changes directory.

## 1. Import and parse

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit --path /Users/tom/Starter-Kit-City-Builder
```

Expected: exit 0 with no new parse or missing-resource errors.

## 2. Focused progression tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tom/Starter-Kit-City-Builder --log-file /tmp/city-builder-m005-progression.log -s addons/gut/gut_cmdln.gd -gdir=res://test/integration/progression -ginclude_subdirs -gexit
```

Expected: all tier, gate parity, full-route, persistence, donation, and
deterministic replay assertions pass.

## 3. Complete Godot gates

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tom/Starter-Kit-City-Builder --log-file /tmp/city-builder-m005-gut.log -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tom/Starter-Kit-City-Builder --log-file /tmp/city-builder-m005-player-ui.log -s addons/gut/gut_cmdln.gd -gdir=res://test/integration/player_ui -ginclude_subdirs -gexit
```

Expected baseline before implementation: 256 unit tests and 5 Player UI
integration tests. Final totals will be higher; every test must pass.

## 4. Canonical scenario

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tom/Starter-Kit-City-Builder -s res://scripts/run_first_patron_scenario.gd
```

Expected: exit 0, ordered required milestones, three contributed characters,
completed Howarth Players patron, placed Theatre, and 192 newly granted cells.
The runner writes normalized evidence under
`specs/005-reachable-first-patron/validation/`.

## 5. TypeScript contracts and authored-data editor

```bash
cd /Users/tom/Starter-Kit-City-Builder/server
npm run build
npx vitest run src

cd /Users/tom/Starter-Kit-City-Builder/tools/data_editor
npm run build
npm test
```

Expected: source-only server tests pass with opt-in live suites skipped; all
data-editor validation tests pass.

## 6. Direct runtime contract

Launch a headless game, then run:

```bash
cd /Users/tom/Starter-Kit-City-Builder/server
RUN_LIVE_GODOT=1 GODOT_PLAYTEST_USER_DIR="/Users/tom/Library/Application Support/Godot/app_userdata/Starter Kit City Builder" npx vitest run src/tools/first-patron-runtime-live.test.ts --silent=false --reporter=verbose
```

Expected: semantic placement, resolve-arrival, progression projection, and
final patron/donation assertions pass through the runtime file bridge.

## 7. Determinism and visual evidence

Repeat the canonical scenario ten times and compare normalized milestone and
final hashes. Then run the normal-renderer capture script at 1280x720 and inspect
the first arrival, request revealed, patron ready, landmark complete, and land
expanded frames. Headless dummy-renderer screenshots do not count as visual
evidence.
