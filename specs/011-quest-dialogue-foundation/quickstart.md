# Quickstart: Quest Dialogue Foundation

Run from `/Users/tom/Starter-Kit-City-Builder`.

## 1. Validate SpecKit context

```bash
SPECIFY_FEATURE_DIRECTORY=specs/011-quest-dialogue-foundation \
  .specify/scripts/bash/check-prerequisites.sh --json
```

## 2. Freeze pre-change compatibility

Run the current dialogue, inbox, event, character, playtest, and progression suites.
Record visible and headless normalized outcomes for a legacy body-only arrival event in
`specs/011-quest-dialogue-foundation/validation/baseline-before.md`.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-dialogue-baseline.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/dialogue,res://test/unit/inbox,res://test/unit/event_system,res://test/unit/character_system,res://test/unit/playtest \
  -ginclude_subdirs -gexit
```

## 3. Pure schema and reveal tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-dialogue-unit.log \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/dialogue \
  -ginclude_subdirs -gexit
```

Required cases: new/legacy normalization, participant and destination validation,
expression fallback, punctuation/instant reveal, one input/one transition, terminal
surface completion with no Continue button, choice gating, child-control precedence,
append-only rows, bottom-aware scrolling, NPC slot swapping, and traversal ceiling.

## 4. Dialogue integration suite

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-dialogue-integration.log \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/integration/dialogue \
  -ginclude_subdirs -gexit
```

Prove the complete EventSystem → Inbox → Dialogue flow, two- and three-person fixtures,
ordered node/option effects, selected-reply transcript row, terminal acknowledgement,
arrival transition, ignored duplicate completion, pre-commit interruption/reload, and
visible/headless normalized parity.

## 5. Adjacent regressions

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-dialogue-adjacent.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/inbox,res://test/unit/event_system,res://test/unit/character_system,res://test/unit/playtest,res://test/unit/builder,res://test/unit/player_ui \
  -ginclude_subdirs -gexit
```

Input suppression, pending IDs, progression, semantic `resolve_dialogue`, and shell
controls must remain passing.

## 6. Data and manifest validation

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://addons/data_editor_tools/export_manifest_headless.gd
```

Verify the manifest contains participants, ordered beats, expression mappings, and
legacy records without converting semantic expression names into sheet indices. Record
the result in `validation/authoring-contract.md`.

## 7. Deterministic narrative/gameplay scenario

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-dialogue-first-town.log \
  -s res://scripts/run_first_patron_scenario.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-dialogue-first-town-loop.log \
  -s res://scripts/run_first_town_loop.gd
```

Run the production arrival event visibly in an integration fixture and headlessly in
the scenario. Compare ordered effects, visited nodes, final character state, event
count, and pending IDs. Core first-town hashes must remain deterministic with narrative
presentation disabled.

## 8. Full regression

Use a writable Godot application-data location.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-dialogue-full.log \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/unit,res://test/integration \
  -ginclude_subdirs -gexit
```

## 9. Performance and visual validation

Run the normal renderer and capture deterministic states:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  -s res://scripts/capture_dialogue_validation.gd
```

Required 1280×720, 1920×1080, and 3840×2160 captures:

- player speaking, NPC inactive;
- NPC speaking, player inactive;
- narration, both inactive;
- three-way counterpart swap;
- choices visible;
- long text and scrollback with return-to-latest;
- missing-expression and missing-art fallbacks.

Confirm all interactive content stays inside the frame, portraits sit outside with only
about 5% overlap, no Continue button exists, and controls do not overlap. Store images,
manifest, timing, and review notes under `validation/`.

Run the 200-beat stress fixture and record worst reveal-update duration and proof that
prior row node identities remain unchanged.
