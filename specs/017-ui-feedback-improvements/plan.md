# Implementation Plan: UI and Feedback Improvements

**Branch**: `017-ui-feedback-improvements` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

## Summary

Add Ambrose-only inline Community icons without mutating dialogue text; enrich
Homes/Work/Shops hover details with current, lifetime, and lifetime-unlock data;
replace the short linear placement-feedback fade with a bounded easing curve;
and render signed, icon-labelled authored costs/effects in the placement dock.

## Technical Context

- **Language/Version**: GDScript, Godot 4.6.x
- **UI**: Programmatic Godot Control tree and established `.tres` themes
- **Testing**: GUT unit/integration suites plus normal-renderer capture scripts
- **Assets**: Existing game-ready Community, demand, and cash icons only
- **Supported resolutions**: 1280×720, 1920×1080, 3840×2160

## Constitution Check

- **One Gameplay Truth**: Pass. All additions read detached projections or
  canonical Demand/Unique metadata; none mutate simulation state.
- **Deterministic, Controllable Simulation**: Pass. The only timing change is a
  pure normalized presentation curve.
- **Observable and Explainable State**: Pass. Current and lifetime demand are
  labelled separately and intrinsic effects retain source/scope.
- **Data-Driven Balance, Narrative Separation**: Pass. No content values or
  dialogue strings are changed.
- **Small Interfaces and Layered Verification**: Pass. Changes stay within
  Dialogue, Palette, PlayerUI, and Builder presentation seams with focused tests.

## Project Structure

```text
plugins/dialogue/dialogue_thread_view.gd
plugins/dialogue/dialogue_plugin.gd
plugins/player_ui/status_bar.gd
plugins/player_ui/tool_dock.gd
plugins/palette/palette_plugin.gd
scripts/builder.gd
test/unit/dialogue/test_dialogue_thread_view.gd
test/unit/dialogue/test_dialogue_reveal.gd
test/unit/player_ui/test_status_bar.gd
test/unit/player_ui/test_tool_dock.gd
test/unit/palette/test_palette.gd
test/unit/builder/test_builder_input_modes.gd
scripts/capture_ui_feedback_validation.gd
specs/017-ui-feedback-improvements/validation/
```

## Implementation Sequence

1. Add detached projection helpers and contract-focused tests.
2. Add Ambrose inline decoration while preserving authored text/reveal state.
3. Add demand hover projection and lifetime target copy.
4. Add representative authored effects to Palette and icon rows to the dock.
5. Add the placement feedback curve and bounded cleanup.
6. Run focused and full relevant GUT suites.
7. Capture normal-renderer evidence at all supported resolutions and inspect it.

High-resolution surfaces follow a bounded 1920-wide authored-canvas scale,
reaching 2× at 3840 while compact 1280 layouts remain at 1×.

## Test Seams

- Dialogue row projection exposes exact text, decoration occurrences, and
  fallback state without requiring image-pixel assertions.
- StatusBar exposes deterministic tooltip text generated from stub providers.
- Palette projection proves only authored representative values are exported.
- ToolDock exposes detached row projections and ignores the optional live
  preview argument.
- Builder exposes a pure static alpha sampler; normal rendering verifies the
  actual presentation.

## Complexity Tracking

No constitutional exceptions are required. `RichTextLabel` is used only for
decorated Ambrose beat text; all other dialogue rows keep the established Label
path to minimize layout and reveal risk.
