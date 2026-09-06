# Quickstart: First Tutorial Mini-Quest

Run from `/Users/tom/Starter-Kit-City-Builder` with a writable temporary home.

## 1. Validate Spec Kit context

```bash
SPECIFY_FEATURE_DIRECTORY=specs/012-first-tutorial-mini-quest \
  .specify/scripts/bash/check-prerequisites.sh --json --require-tasks
```

## 2. Focused tutorial suites

```bash
mkdir -p /tmp/city-builder-tutorial-user
HOME=/tmp/city-builder-tutorial-user \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-tutorial-focused.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/opening_tutorial,res://test/unit/dashboard,res://test/unit/dialogue,res://test/unit/event_system,res://test/unit/playtest,res://test/integration/opening_tutorial \
  -ginclude_subdirs -gexit
```

## 3. Persistence and adjacent-system regressions

```bash
HOME=/tmp/city-builder-tutorial-user \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-tutorial-adjacent.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/traffic,res://test/unit/attractiveness,res://test/unit/demand,res://test/unit/community,res://test/integration/progression,res://test/integration/dialogue \
  -ginclude_subdirs -gexit
```

## 4. Deterministic full opening scenario

```bash
HOME=/tmp/city-builder-tutorial-user \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-tutorial-scenario.log \
  -s res://scripts/run_opening_tutorial_scenario.gd
```

Run twice with the declared seed/actions and compare state hashes, nine receipts,
ordered observations, pending dialogue IDs, and exactly one handoff. The report must
also include out-of-order, duplicate invalidation, demolition, and legacy-baseline cases.

## 5. Full regression

```bash
HOME=/tmp/city-builder-tutorial-user \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-tutorial-full.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit,res://test/integration -ginclude_subdirs -gexit
```

Any pre-existing baseline failure must remain clearly separated from introduced
regressions; verification is not complete while a relevant new failure remains.

## 6. Manifest/content validation

```bash
HOME=/tmp/city-builder-tutorial-user \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://addons/data_editor_tools/export_manifest_headless.gd
```

Confirm all four tutorial events validate, B01–B18 resolve only to approved labelled
placeholders, and no draft alternative appears in runtime data.

## 7. Normal-renderer visual and in-game QA

```bash
HOME=/tmp/city-builder-tutorial-user \
  /Applications/Godot.app/Contents/MacOS/Godot --path . \
  -s res://scripts/capture_opening_tutorial_validation.gd
```

Capture every compact variant and B05/B09/B15/B18 at 1280×720, 1920×1080, and
3840×2160. Confirm protected HUD regions, dismissal/suppression, progress readability,
modal recovery, actual-result variants, and literal `PLACEHOLDER` visibility. Perform a
fresh in-game run for mechanical pacing and clarity. Record final prose/play-feel as
deferred, not approved.
