# Scope audit

Feature 019 was implemented as a bounded presentation, tutorial, data-tuning, and
Palette-availability pass. The shared worktree already contained concurrent features,
so this audit records the feature-owned hunks rather than attributing every dirty path
to this pass.

## Feature-owned implementation surface

- `plugins/player_ui/placement_consequences_panel.gd` and its focused PlayerUI tests:
  screen-space row filtering, collapse, sizing, and safe-area composition only.
- `plugins/opening_tutorial/opening_tutorial_plugin.gd`,
  `plugins/dashboard/dashboard_plugin.gd`, and tutorial/Dashboard tests: ten rooted
  roads, stable observed-home evidence, exactly-once first-shop handoff, and primary
  direction priority.
- `data/buildings/unique/building_postwar_terrace.json` and
  `data/buildings/unique/building_pub.json`: only the feature-owned threshold values,
  40 and 15 respectively.
- `data/buildings/nature/grass.json`, BuildingCatalog, Palette, Builder/Playtest choice
  resolution, data-editor schema/store files, and their tests: preserve exact catalogue
  identity while excluding plain grass from player-facing choice construction.
- Feature-specific scenario/capture scripts and files under
  `specs/019-opening-playtest-polish/validation/`: verification and evidence only.

## Explicit exclusions rechecked

- No feature-019 code creates a world-space placement-impact capsule or adds a world
  feedback node. The consequence panel remains a `Control` in PlayerUI's screen-space
  canvas.
- No model, texture, base, grass-infill, Blender, or other building-art repair is part
  of the feature-owned surface.
- No new building, progression chain, medical/service system, or simulation authority
  is introduced.
- `plugins/player_ui/tool_dock.gd` is not a feature-019 implementation target; this
  pass composes the existing consequence panel with the current dock rather than
  redesigning it.

The dirty diff also contains ground-treatment/model work, world reactions, performance
work, and existing dock changes from separate concurrent efforts. In particular, the
Pub JSON's `ground_treatment` hunk and exported manifest ground-treatment fields are
not feature 019; the ordinary manifest exporter preserved them while refreshing the
feature's threshold and `palette_excluded` projections. Those changes were neither
reverted nor claimed by this feature.
