# Implementation Plan: Reachable First-Patron Progression

**Branch**: `005-reachable-first-patron` *(planning identifier; no branch created)* | **Date**: 2026-09-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-reachable-first-patron/spec.md`

## Summary

Make the existing Howarth Players arc reachable and deterministic without a
second gameplay path. BuildingCatalog will derive attained bucket tiers from
the canonical placed registry. CharacterSystem will combine those tiers with
fulfilled demand, enforce monotonic request transitions, and expose a structured
gate projection. UniqueRegistry will remain the single story-building
availability authority by adding character and patron gates to its existing
prerequisite and demand decision. PatronSystem will synchronously apply an
idempotent BuildableArea donation receipt before publishing completion.

The debug-only Playtest surface will gain a semantic arrival-resolution action,
complete progression snapshots, and ordered milestone evidence. One authored
fresh-town scenario, boundary fixtures, and parity tests will prove the full
route. Provisional, trace-backed reachability corrections cover the impossible
industrial arrival threshold plus the neutral-home migration boundary, daily
candidate throughput, and commercial-output ratio revealed by the real route;
all are recorded against the unchanged baseline and remain subject to milestone
006's pacing work.

## Technical Context

**Language/Version**: GDScript for Godot 4.6.x; JSON-authored game and scenario data; TypeScript 5.6 for the data editor and playtest server contracts

**Primary Dependencies**: Godot 4.6.2, GUT 9.3, existing PluginManager/GameEvents architecture, Node.js with Vitest 2.1 and Zod-based server contracts

**Storage**: Godot `Resource` saves (`DataMap`/`DataStructure`) plus JSON content and scenario fixtures; no database

**Testing**: GUT unit/integration suites, headless Godot scenario runner, Vitest server and data-editor suites, direct runtime file-IPC tests, normal-renderer screenshot capture

**Target Platform**: Local desktop game, macOS development host; Godot 4.6.x compatibility retained

**Project Type**: Godot desktop application with local TypeScript authoring and playtest tooling

**Performance Goals**: Event-driven progression refresh below one 16.7 ms frame; canonical scenario completes within a three-minute local verification budget; no regression to the 500-resident/168-hour Community budget

**Constraints**: One gameplay truth; deterministic declared seed/actions/ticks; stable reason codes; narrative presentation optional; no direct test mutation of cash, demand, progression, GridMaps, or allowed land

**Scale/Scope**: One live patron, three quest characters, three unique chains, three wants, one landmark, one donation, and fixtures at every progression boundary

## Constitution Check

*GATE: Passed before research and re-checked after Phase 1 design.*

| Principle | Design evidence | Result |
|-----------|-----------------|--------|
| I. One Gameplay Truth | Builder, Palette, radial UI, and Playtest all consume `UniqueRegistry.evaluate_unlock`; Dialogue and Playtest call the same CharacterSystem transition command. | PASS |
| II. Deterministic, Controllable Simulation | The scenario declares seed, ordered semantic actions, manual hours, stable subject ordering, milestone observations, and normalized hashes. | PASS |
| III. Observable and Explainable State | Bucket, character, story-building, patron, donation, and milestone projections contain values, authored labels, evidence, and stable reasons. | PASS |
| IV. Data-Driven Balance, Narrative Separation | Thresholds remain JSON-authored; the scenario resolves arrival semantically while presentation is disabled; the single threshold correction is trace-backed and provisional. | PASS |
| V. Small Interfaces and Layered Verification | Existing plugin surfaces are extended with one semantic action and structured projections; unit, integration, runtime, replay, persistence, and visual seams are defined. | PASS |

No constitutional exception or new architectural subsystem is required.

## Project Structure

### Documentation (this feature)

```text
specs/005-reachable-first-patron/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── canonical-first-patron-scenario.md
│   ├── playtest-progression.md
│   └── progression-projection.md
├── checklists/
│   └── requirements.md
├── validation/
└── tasks.md
```

### Source Code (repository root)

```text
data/
├── buildings/
├── characters/
├── events/
└── patrons/
plugins/
├── buildable_area/
├── building_catalog/
├── character_system/
├── dashboard/
├── event_system/
├── palette/
├── patron_system/
├── playtest/
└── unique_registry/
scripts/
├── builder.gd
├── data_map.gd
├── game_events.gd
└── playtest_action_result.gd
test/
├── integration/
│   ├── player_ui/
│   └── progression/
├── scenarios/
└── unit/
    ├── buildable_area/
    ├── character_system/
    ├── dashboard/
    ├── event_system/
    ├── palette/
    ├── patron_system/
    ├── playtest/
    └── unique_registry/
server/src/tools/
tools/data_editor/src/
```

**Structure Decision**: Extend the existing Godot plugins that already own
catalog data, character state, unique availability, patron state, land, and
playtest projection. Tests live beside the existing domain suites, while the
single full route receives a dedicated progression integration directory and
data-driven scenario. No new application layer or parallel controller is added.

## Phase 0: Research Decisions

Research findings and rejected alternatives are recorded in
[research.md](research.md). The critical conclusions are:

1. The industrial threshold of 10,000 is mathematically unreachable before the
   donation; 100 is the minimal parity correction. Real-route traces also
   justify aligning neutral migration with quality 50, processing 20 daily
   candidates, and converting worker output to commercial demand at 0.75.
2. `arrival_requires_tier` needs a canonical placed-state projection, not a new
   stored counter.
3. UniqueRegistry is the existing choke point for all story-building gates and
   must remain the common decision consumed by Builder, Palette, and Playtest.
4. Resolving a pending arrival is a semantic dialogue command shared by visible
   Dialogue and Playtest, not a test-only state setter.
5. Patron completion requires a persisted donation receipt and synchronous
   donation application before the single completion event.
6. Pending dialogue IDs and accrued demand totals receive narrow DataMap
   persistence so a cold reload preserves both the unresolved story action and
   the unique-building decisions that surround it.

## Phase 1: Design and Contracts

- [data-model.md](data-model.md) defines bucket evidence, character and patron
  transitions, story gates, donation receipts, and milestone observations.
- [contracts/progression-projection.md](contracts/progression-projection.md)
  defines the one structured decision shared by runtime and UI consumers.
- [contracts/playtest-progression.md](contracts/playtest-progression.md) defines
  the semantic resolve action, snapshot additions, and trace behavior.
- [contracts/canonical-first-patron-scenario.md](contracts/canonical-first-patron-scenario.md)
  defines the versioned full-route scenario and acceptance matrix.
- [quickstart.md](quickstart.md) is the runnable verification guide.

### Post-design constitution re-check

PASS. The design uses only canonical registry, placement, event, dialogue,
demand, and land paths. New read models are derived and detached; no test or UI
surface receives a direct mutation path. All balance values remain authored
data, and every new state-changing path has unit plus integration coverage.

## Implementation Strategy

1. Establish failing unit and contract tests for tier gating, ordering,
   story-lock reasons, reconciliation, donation receipts, and projections.
2. Add BuildingCatalog tier evidence and restructure progression plugin
   dependencies to remove the two unused UniqueRegistry edges.
3. Harden CharacterSystem and PatronSystem transitions and load reconciliation.
4. Extend UniqueRegistry's canonical decision, then adapt Builder, Palette,
   Dashboard, and Playtest to consume it.
5. Add the semantic arrival-resolution command, progression-complete snapshot,
   milestone trace, and durable pending-arrival replay.
6. Capture an unchanged failing baseline, apply the threshold correction, and
   execute the full canonical route plus save/load boundary matrix.
7. Run all repository gates and capture deterministic and visual evidence.

## Complexity Tracking

No constitution violations require justification.
