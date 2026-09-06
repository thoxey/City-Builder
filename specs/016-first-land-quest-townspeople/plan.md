# Implementation Plan: First Land Quest and Townspeople

**Branch**: `codex/009-performance-foundation` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/016-first-land-quest-townspeople/spec.md`

## Summary

Create one idempotent quest reconciler that consumes the opening tutorial's durable
handoff, dispatches an approved staged dialogue package, observes late-committed semantic
flags, and asks BuildableArea to apply a separate authored first-land grant. Add four
approved named townsperson profiles covering the canonical Community qualities once
each, without changing resident simulation or generating dialogue. All content-dependent
implementation pauses until the collaborative workshop package is approved.

## Technical Context

**Language/Version**: GDScript 4.x and JSON content on Godot 4.6.x

**Primary Dependencies**: Existing PluginBase/PluginManager, OpeningTutorial,
EventSystem, Dialogue, CharacterSystem, BuildableArea, Community constants, GameEvents

**Storage**: `DataMap.first_land_quest_state`, quest-specific
`DataMap.land_grants_applied`, authored JSON under `data/quests/`, `data/events/`, and
`data/characters/`

**Testing**: GUT unit/integration tests, headless Godot scenario scripts, ResourceSaver/
ResourceLoader cold round trips, manifest exporter, normal-renderer screenshot capture

**Target Platform**: Local desktop game at 1280×720, 1920×1080, and 3840×2160

**Project Type**: Godot plugin-oriented desktop game

**Performance Goals**: Reconcile only on semantic invalidations; no per-frame quest work;
activation/completion under 5 ms in representative saves; one land expansion proportional
to the authored parcel

**Constraints**: One Gameplay Truth, deterministic headless parity, maximum three
participants per dialogue event, unapproved prose prohibited from runtime content,
future patron donation must remain independent

**Scale/Scope**: One quest, one Sir William place association, one land outcome/follow-up,
four townsperson profiles, a small staged event set, and one opening-to-land scenario

## Constitution Check

### Pre-design gate

- **One Gameplay Truth — PASS**: BuildableArea remains the sole land-cell mutator;
  EventSystem/Dialogue remain the only narrative traversal/effect authorities.
- **Deterministic, Controllable Simulation — PASS**: Quest state uses semantic receipts
  and authored cells; visible/headless paths converge on the same flags/outcome.
- **Observable and Explainable State — PASS**: Playtest exposes phase, pending IDs,
  approach, grant counts, completion, and stable diagnostics.
- **Data-Driven Balance, Narrative Separation — PASS**: Geometry and profiles are data;
  the buildable simulation can run with presentation disabled and contains no prose.
- **Small Interfaces and Layered Verification — PASS**: One reconciler, one generic
  dialogue completion edge, and one grant method extend existing systems.

No implementation begins until user-selected content is known. Creating design artifacts
and recording a focused baseline are safe before that gate.

## Phase 0: Research outcome

Research is captured in [research.md](research.md). Existing foundations cover the
renderer, event graph, expressions, persistence, and land mutation. The missing seams are:

1. a versioned quest state/reconciler;
2. a generic semantic dialogue-completion notification for same-session reconciliation;
3. a quest-specific BuildableArea grant receipt;
4. approved place/cast/dialogue/grant data; and
5. snapshot/scenario coverage.

## Phase 1: Design

### A — Freeze the collaborative scene package

Use [dialogue-workshop.md](dialogue-workshop.md) scene by scene. Approve the place
association, four cast profiles, beat order, semantic choices/outcomes, expression per
speech beat, exact final prose, and grant/follow-up. Record approval; do not copy any
unapproved option text into JSON.

### B — Persistence and content validation foundation

Add the two DataMap dictionaries described in [data-model.md](data-model.md). Implement a
pure state normalizer and quest-definition validator first. Extend progression/content
validation for place association, four-quality coverage, event references, expressions,
approach flags, and land shape. Unknown fields remain forward-compatible; malformed
known fields cannot advance phase.

### C — Idempotent activation and completion

Register `FirstLandQuest` after OpeningTutorial, EventSystem, Dialogue, and BuildableArea.
On boot/map load and the live tutorial signal, reconcile the durable handoff. Persist
activation before direct event dispatch. A detached Dialogue completion signal triggers
same-session reconciliation; load recovery derives from pending IDs, event count, and
committed semantic flags. B18 is never consulted.

### D — Canonical land outcome

Add `BuildableArea.apply_land_grant(grant_id, area)` beside `apply_donation()`, using the
same parser and `_expand()` path but a separate persisted receipt map. Validate the full
area before mutation. Reconcile only after the terminal agreement is committed and the
dialogue is no longer pending. Write quest outcome/completion after the grant receipt is
observable, making re-entry idempotent.

### E — Approved content and recurring profiles

Add the quest definition, dialogue events, and four character profiles exactly as
approved. Keep semantic approach IDs/effect flags distinct from displayed labels. Stage
the four viewpoints across separate vignettes to respect participant limits. A profile
may select an authored later reaction by tag but must never synthesize prose.

### F — Observability and verification

Add normalized quest/grant projection to Playtest snapshots and hashes. Cover pure state,
activation, dialogue branches, land overlap/malformed data, interruption/load, visible/
headless parity, and no replay. Add an opening-to-land scenario and renderer captures.
Audit exported content for approval parity before in-game voice/pacing review.

## Project Structure

### Documentation (this feature)

```text
specs/016-first-land-quest-townspeople/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── dialogue-workshop.md
├── quickstart.md
├── contracts/
│   ├── activation-and-recovery.md
│   ├── land-outcome.md
│   └── townsperson-profiles.md
├── checklists/requirements.md
├── validation/
└── tasks.md
```

### Source Code (repository root)

```text
plugins/first_land_quest/first_land_quest_plugin.gd
plugins/dialogue/dialogue_plugin.gd
plugins/buildable_area/buildable_area_plugin.gd
plugins/playtest/playtest_plugin.gd
scripts/
├── data_map.gd
├── plugin_manager.gd
├── progression_content_validator.gd
├── run_first_land_quest_scenario.gd
└── capture_first_land_quest_validation.gd
data/
├── quests/first_land_quest.json
├── events/quests/first_land_quest/*.json
└── characters/<four-approved-townsperson-ids>.json
test/
├── unit/first_land_quest/
├── unit/buildable_area/
├── unit/dialogue/
├── unit/event_system/
└── integration/first_land_quest/
```

**Structure Decision**: Preserve the plugin/event architecture. Quest-specific phase
reconciliation lives in one plugin; dialogue traversal and cell mutation remain in their
existing plugins. Authored quest metadata gets a dedicated data record, while actual
prose stays in established event JSON.

## Test seams

- Pure `normalize_state(raw)` and `validate_definition(definition, lookup)` seams.
- Injected OpeningTutorial state, EventSystem, Dialogue, and BuildableArea test doubles.
- Public/detached `reconcile(reason)` projection and stable diagnostic codes.
- EventSystem pending/count/flag fixtures for every interruption boundary.
- Dialogue completion signal carrying event ID, visited nodes, ordered effects, and
  acknowledgement only after `_complete_semantics()`.
- BuildableArea grant method returning requested/added/overlap counts with an injectable
  map and canonical allowed-cell snapshot.
- ResourceSaver/ResourceLoader cold state fixtures.
- Visible/headless event traversal comparison using the same approved event records.
- Playtest snapshot/hash comparison before and after equivalent resolutions.

## Post-design Constitution re-check

All gates remain satisfied. The two new persisted dictionaries are narrow and versioned.
The completion signal is observational and cannot apply effects. The land entry point
reuses BuildableArea rather than creating a second mutation path. Townsperson metadata
does not affect core balance. No architectural exception is required.

## Complexity Tracking

No constitutional violations.

## Implementation authorization boundary

Phases B–F depend on approved semantic content IDs and/or final prose. The repository's
prior placeholder convention was feature-specific and user-approved; it cannot be
inferred for this workstream. Implementation tasks remain unchecked until the workshop's
approval record is complete. Independent documentation and baseline verification may be
completed now.
