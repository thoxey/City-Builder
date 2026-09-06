# Implementation Plan: Opening Playtest Polish

**Branch**: `019-opening-playtest-polish` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from
`specs/019-opening-playtest-polish/spec.md`

## Summary

Polish the current opening without expanding its architecture: filter the existing
placement-consequence row model to actionable changes, retune the tutorial's rooted-road
and home-adjacency gates, prioritize the tutorial/first-quest direction over premature
patron grind text, update two data-driven lifetime thresholds, and keep plain grass in
the catalogue while excluding it from player-facing Palette pools.

## Technical Context

**Language/Version**: GDScript 4.x and JSON content on Godot 4.6.x

**Primary Dependencies**: OpeningTutorial, RoadNetwork, Dashboard, CharacterSystem,
UniqueRegistry, BuildingCatalog, Palette, PlayerUI, PlacementConsequencesPanel

**Storage**: Existing `DataMap.opening_tutorial_state`; building and pool JSON under
`data/buildings/`; no new save authority

**Testing**: GUT unit/integration tests, deterministic opening scenario, save/load
fixtures, data-editor tests, normal-renderer visual review

**Target Platform**: Local desktop game at 1280×720 and 1920×1080

**Project Type**: Godot plugin-oriented desktop game with JSON-authored content

**Performance Goals**: No new per-frame simulation; filtered panel formatting remains
negligible relative to the existing quote budget; tutorial/Dashboard work remains
event-driven

**Constraints**: Preserve canonical gameplay authorities, monotonic tutorial receipts,
stable building IDs, deterministic seeded pools, and the existing first-quest handoff

**Scale/Scope**: One panel formatter, one tutorial threshold and adjacency refinement,
one Dashboard priority rule, two unique-profile values, and one pool-member exclusion

## Constitution Check

### Pre-design gate

- **One Gameplay Truth — PASS**: The panel continues to consume Builder's existing
  detached quote. Road count comes from RoadNetwork; unlocks stay in UniqueRegistry;
  Palette remains the selection authority.
- **Deterministic, Controllable Simulation — PASS**: All gates use stable IDs, canonical
  evidence, and declared seeds. Pool filtering intentionally changes concrete seeded
  results and is captured in updated fixtures.
- **Observable and Explainable State — PASS**: Tutorial progress remains structured;
  Dashboard priority is deterministic; hidden palette content remains inspectable in the
  catalogue.
- **Data-Driven Balance, Narrative Separation — PASS**: Threshold and palette membership
  changes live in authored building data. No new narrative prose is invented beyond the
  already approved placeholder-purpose wording correction.
- **Small Interfaces and Layered Verification — PASS**: Existing projections and plugin
  seams are reused. Unit, integration, deterministic, balance, save/load, and visual
  checks are declared below.

### Post-design gate

PASS. No additional simulation authority, direct `GameState` mutation path, or material
architectural exception is introduced.

## Project Structure

### Documentation (this feature)

```text
specs/019-opening-playtest-polish/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── opening-polish-contracts.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
plugins/opening_tutorial/opening_tutorial_plugin.gd
plugins/dashboard/dashboard_plugin.gd
plugins/player_ui/placement_consequences_panel.gd
plugins/palette/palette_plugin.gd
plugins/building_catalog/building_catalog_plugin.gd
data/buildings/unique/building_postwar_terrace.json
data/buildings/unique/building_pub.json
data/buildings/nature/grass.json
tools/data_editor/src/
test/unit/opening_tutorial/
test/unit/dashboard/
test/unit/placement_consequences/
test/unit/player_ui/
test/unit/palette/
test/unit/demand/
test/integration/
test/scenarios/
```

**Structure Decision**: Extend the existing plugin/content/test layout. Add no plugin or
new top-level runtime directory.

## Design

### 1. Filter the existing location presentation

Keep `Builder.evaluate_placement_consequences` and its quote unchanged. Refine
`PlacementConsequencesPanel.presentation_rows` so valid-access confirmation, zero
qualities, zero attractiveness, zero affected counts, and empty reach are omitted. Keep
warnings in their current deterministic order. `show_quote` hides the panel when the
filtered model is empty and otherwise sizes from the retained count. This deliberately
does not change the bottom dock or add world-space UI.

### 2. Retune the opening tutorial without invalidating progress

Change the fresh/incomplete `connect_rooted_roads` gate and projection from 4 to 10,
still sourced from `rooted_road_count`. Existing durable road receipts remain accepted.

Generalize the observed adjacency candidate from one fixed anchor to any stable eligible
pair involving a newly placed early home. Sort candidate evidence by internal ID and
anchor before selecting a pair, then persist both exact homes and the real before/after
score evidence. Keep the existing baseline-unavailable diagnostic for legacy/pre-built
pairs. Update the B02/B08 approved placeholder-purpose strings and dialogue workshop
descriptions from four/first-home language to ten/another-home language.

The rooted first-shop gate, completion receipt, and handoff signal remain unchanged.

### 3. Make Dashboard direction phase-aware

Extend the Dashboard snapshot/step choice to recognize the existing opening tutorial
projection and durable completion/first-quest handoff state. While the tutorial is
active, its direction wins over generic unarrived-character progress. When it completes,
the established first-quest direction wins when available or pending. Only afterward may
the ordinary patron/character progression ladder show the 100 fulfilled-Shops target.
Do not copy tutorial rules into Dashboard; consume projections/receipts.

### 4. Keep balance values in authored data

Set Postwar Terrace `prerequisite_threshold` to 40 and Pub to 15. Let existing
BuildingCatalog → UniqueRegistry → Palette/status projections carry the values. Update
tests and opening balance expectations that currently encode 25/10. Record a same-seed
before/after trace as required by the constitution.

### 5. Exclude plain grass without deleting stable content

Use an explicit authored palette-exclusion flag on the plain `grass` definition. Preserve
it in BuildingCatalog's detached summary and data-editor/manifest handling. Palette skips
excluded structures when constructing solo entries and pool membership, so preview and
commit cannot choose them. Catalogue lookup and old-save resolution remain unchanged.
If all members of a pool are excluded, do not expose an empty player-facing entry.

## Test Seams

- Pure panel row-model tests for filtered and warning states.
- OpeningTutorial gate/projection tests for 9/10 roads, disconnected roads, stable
  adjacency pair selection, copy, legacy receipts, and first-shop completion.
- Dashboard snapshot/priority tests with active tutorial, completed tutorial, pending
  first quest, and unarrived 100-demand character combinations.
- UniqueRegistry/StatusBar/Palette boundary tests driven from the two JSON profiles.
- BuildingCatalog/Palette tests for catalogue visibility versus player-buildable pool
  membership and seeded selection.
- Save/load integration fixture containing plain grass and a legacy four-road receipt.
- Same-seed automated opening before/after trace and normal-renderer panel review.

## Risks and Mitigations

- **Legacy tutorial receipt ambiguity**: Do not recompute completed receipts. Only
  incomplete/new saves must satisfy ten roads.
- **Adjacency causal overclaim**: Require a newly observed placement and real score
  evidence; retain baseline-unavailable behavior for pre-existing pairs.
- **Dashboard coupling**: Read tutorial/quest projections or durable receipts through
  plugin seams rather than duplicating thresholds or progression logic.
- **Grass save compatibility**: Filter at Palette construction only; never remove the
  building definition or stable ID from BuildingCatalog.
- **Seeded fixture drift**: Treat new grass variants as an intentional content change and
  update explicit deterministic evidence rather than weakening determinism assertions.

## Complexity Tracking

No constitution violations or architecture exceptions are required.
