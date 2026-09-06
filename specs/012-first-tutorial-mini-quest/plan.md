# Implementation Plan: First Tutorial Mini-Quest

**Branch**: `codex/009-performance-foundation` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/012-first-tutorial-mini-quest/spec.md`

## Summary

Add a focused `OpeningTutorial` observer plugin with a versioned `DataMap` record,
monotonic semantic receipts, ordered placement observations, detached canonical
evidence, and one exactly-once completion handoff. Dashboard gives its projection
priority while incomplete and reuses CompactGuidanceView. Four causal milestones use
existing EventSystem/Dialogue records. All runtime text is the literal user-approved
`AMBROSE PLACEHOLDER: <beat purpose>` form; no final prose is inferred.

## Technical Context

**Language/Version**: GDScript 4.x on Godot 4.6.x

**Primary Dependencies**: PluginBase/PluginManager/GameEvents; BuildingCatalog,
RoadNetwork, Attractiveness, Demand, Community, Dashboard, EventSystem,
Dialogue, Playtest, `DataMap`, and existing semantic building profiles

**Storage**: One `DataMap.opening_tutorial_state` Dictionary with schema version 1;
existing EventSystem pending IDs/counts continue to own full-dialogue recovery

**Testing**: GUT 9.3 unit/integration suites, cold ResourceSaver/ResourceLoader boundary
matrix, deterministic playtest scenario, normal-renderer captures and manual in-game QA

**Target Platform**: Godot desktop at 1280×720, 1920×1080, and 3840×2160

**Performance Goals**: One coalesced reconciliation per invalidation frame; evidence
scan below one 16.7 ms frame at current catalogue scale; zero idle per-frame work

**Constraints**: Observational only; no balance tuning; no placement mutation; no new
decoration category; no Workstream 2 quest content; placeholder text must stay visibly
labelled; compact dismissal remains presentation-only

**Scale/Scope**: One opening tutorial, nine objective receipts, eighteen presentation
beats/variants, four full-dialogue event records, one deterministic fresh-town scenario,
and one legacy/out-of-order matrix

## Constitution Check

*GATE: Passed before implementation and re-checked after design.*

- **I. One Gameplay Truth — PASS**: The tutorial observes committed registry entries and
  public canonical queries. It never places, demolishes, spends, or simulates.
- **II. Deterministic, Controllable Simulation — PASS**: Stable sorting, semantic
  receipts, explicit placement observations, and the existing manual clock make replay
  deterministic.
- **III. Observable and Explainable State — PASS**: State, evidence, projection,
  diagnostics, blockers, measured deltas, and handoff payloads are detached and exposed
  through the plugin and Playtest snapshot.
- **IV. Data-Driven Balance, Narrative Separation — PASS**: Gates read authored profiles
  without changing them. Headless completion does not require dialogue presentation.
- **V. Small Interfaces and Layered Verification — PASS**: One observer plugin and one
  Dashboard dependency replace the existing Town Hall override. Unit, integration,
  scenario, persistence, and visual seams are declared below.
- **Project constraints — PASS**: Godot 4.6.x and plugin boundaries are retained;
  `builder.gd` receives no tutorial logic.
- **Quality gates — PASS BY DESIGN**: Baseline, focused/full GUT, deterministic replay,
  full opening scenario, and normal-renderer QA appear in [quickstart.md](quickstart.md).

No architectural exception is required.

## Design Phases

### Phase A — Freeze baseline and contracts

Preserve the focused pre-change result and known unrelated Community balance failure.
Add failing state normalization, gate, projection, handoff, and save/load tests against
the contracts before runtime implementation.

### Phase B — Persist and normalize tutorial state

Add `opening_tutorial_state` to `DataMap`. Implement `OpeningTutorial` with semantic
step order, record normalization, immutable receipts, stable diagnostics, detached
state/evidence/projection accessors, and no UI dependencies.

### Phase C — Build canonical evidence and ordered reconciliation

Scan `GameState.building_registry` through catalog identity/profile helpers. Query
RoadNetwork plus catalog identity for the Hall and rooted components/routes, Attractiveness
for city/tile scores, Demand for non-mutating affordability, and Community for
assignment/operation evidence. Coalesce ordinary invalidations but retain ordered
placement observations for home adjacency and repair causality.

Resolve legacy missing baselines conservatively: emit `baseline_unavailable` and wait
for one new observable placement. Nature is the current decorative mechanism. A stable
loop writes every currently satisfied receipt in order and stops at the first unmet
gate.

### Phase D — Integrate compact guidance and placeholder content

Make Dashboard depend on `OpeningTutorial`, prioritize its projection while incomplete,
and remove the one-off Town Hall override. Resolve B01–B18 copy keys only to the literal
approved placeholder strings in `dialogue-workshop.md`; unknown keys are blank with a
stable diagnostic. Preserve CompactGuidanceView layout, dismissal, suppression, and
portrait fallback behavior.

### Phase E — Integrate full milestone beats and completion handoff

Author B05, B09, B15, and B18 as valid dialogue events using the existing schema,
semantic expression vocabulary, and visibly labelled placeholder text. OpeningTutorial
uses EventSystem `fire()` and durable presentation receipts; EventSystem retains pending
recovery/effects/count ownership. Full dialogue completion never grants tutorial facts.

On first qualifying rooted shop, write shop/terminal/handoff receipts before emitting
`GameEvents.tutorial_opening_completed`. Reload publishes completed state without
re-emitting. Add the normalized tutorial summary to Playtest snapshots outside UI-only
data and include it in deterministic state hashes.

### Phase F — Verify release evidence

Run focused state, Dashboard, dialogue, event, road, attractiveness, demand, Community,
Playtest, and progression suites; cold-save every boundary; run fresh, out-of-order,
duplicate-signal, demolition, visible/headless, and deterministic scenarios. Capture all
compact/full states at three supported resolutions. Review mechanics, placeholder
visibility, clarity, pacing, and layout in game. Do not claim final prose/play-feel
approval while placeholders remain.

## Project Structure

### Documentation (this feature)

```text
specs/012-first-tutorial-mini-quest/
├── spec.md
├── dialogue-workshop.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
├── checklists/requirements.md
├── validation/
└── tasks.md
```

### Source Code (repository root)

```text
plugins/opening_tutorial/opening_tutorial_plugin.gd
plugins/dashboard/dashboard_plugin.gd
plugins/playtest/playtest_plugin.gd
plugins/event_system/event_system_plugin.gd
scripts/{data_map.gd,game_events.gd,plugin_manager.gd}
data/events/tutorial/{beauty_homes.json,home_adjacency.json,work_participation.json,opening_complete.json}
scripts/run_opening_tutorial_scenario.gd
scripts/capture_opening_tutorial_validation.gd
test/unit/opening_tutorial/
test/integration/opening_tutorial/
```

**Structure Decision**: One plugin owns tutorial state and projection. Existing systems
remain canonical; Dashboard and Dialogue remain presentation paths. No code is added to
Builder and no generic QuestSystem is introduced.

## Test Seams

- Pure state normalization and receipt idempotency with malformed/legacy dictionaries.
- Evidence fixtures for stable sorting, rooted-road union, category/pool identity,
  affordability, footprint distance, authored impact radii, routes, and assignments.
- Ordered placement observation tests for actual adjacency delta, no-penalty diagnosis,
  missing baseline, and subsequent nature improvement.
- Projection tests for every B01–B18 variant, approved placeholder mapping, progress,
  blockers, immutability, and unknown-copy rejection.
- Dashboard priority/dismissal/suppression tests and existing patron-guidance fallback.
- EventSystem/Dialogue dispatch, pending recovery, headless resolution, and exactly-once
  presentation receipt tests for B05/B09/B15/B18.
- Completion re-entry test proving receipt-before-signal, no reload re-emission, and
  independent B18 acknowledgement.
- Cold-save matrix for every semantic boundary and experiment evidence record.
- Deterministic fresh/out-of-order scenario plus full regression and visual captures.

## Complexity Tracking

No constitutional violation or complexity exception is required. The single structured
Dictionary save field is chosen because Godot Resource nested custom-resource migration
would add complexity without stronger guarantees at this scale.
