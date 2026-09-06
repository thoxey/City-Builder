# Implementation Plan: Buildable Area and Community Quality Playtest Pass

**Branch**: `013-buildable-community-pass` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

## Summary

Add a derived ground overlay inside BuildableArea, fed only by its authoritative cell set and emphasized by Builder's canonical input-mode signal. Increase only the rooted seed to 16×16 and frame its full perimeter at the normal starting view. Tune existing early belonging sources while retaining current Liveability/Beauty sources, spatial negatives, and diminishing returns. Verify with deterministic unit/integration tests, the seed-6066 full town replay, and rendered normal-zoom captures.

## Technical Context

**Language/Version**: GDScript, Godot 4.6.x
**Primary Dependencies**: Godot `ImageTexture`, `PlaneMesh`, `ShaderMaterial`, existing plugin/event architecture
**Storage**: Godot `Resource` saves through `DataMap`
**Testing**: GUT unit/integration suites and SceneTree scenario runners
**Target Platform**: Desktop Forward+ renderer; headless test runner
**Project Type**: Godot desktop game
**Performance Goals**: Overlay rebuild remains O(buildable cells) and does no per-frame regeneration
**Constraints**: Preserve BuildableArea as sole legality authority; preserve unrelated worktree changes; no new simulation system
**Scale/Scope**: Hundreds of buildable cells and early-town resident cohorts

## Constitution Check

- **One Gameplay Truth — PASS**: overlay derives from `BuildableArea`; Builder legality is untouched.
- **Deterministic Simulation — PASS**: balance tests declare fixtures/seeds/hours; no new randomness.
- **Observable State — PASS**: tests assert exact geometry counts and applied-effect reasons/totals.
- **Data-Driven Balance — PASS**: tuning remains in building JSON where the schema already supports it.
- **Layered Verification — PASS**: unit, integration, replay, and visual gates are identified before implementation.

Post-design re-check: PASS. No architectural exception is required.

Post-implementation re-check: PASS. Placement still consults only
`BuildableArea`; the overlay is derived and event-refreshed, and the measured
quality changes remain authored data consumed by the existing evaluator.

## Project Structure

```text
plugins/buildable_area/buildable_area_plugin.gd
scripts/view.gd
data/buildings/generic/building_small_b.json
data/buildings/unique/building_town_hall.json
plugins/playtest/playtest_plugin.gd
test/unit/buildable_area/test_buildable_area.gd
test/unit/community/test_early_quality_balance.gd
test/integration/community/test_early_quality_playthrough.gd
scripts/run_town_rebalance.gd
scripts/capture_buildable_area_validation.gd
specs/013-buildable-community-pass/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/buildable-community-contract.md
├── tasks.md
└── validation/
```

**Structure Decision**: Extend the existing Godot plugin/content/test layout; keep presentation adjacent to BuildableArea and numeric balance in authored JSON.

## Complexity Tracking

No constitution violations.
