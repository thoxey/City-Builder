# Quickstart: Radial Build UI Acceptance

## Primary build path

1. Start `fresh_city` at 1280×720.
2. Confirm no M3 Debug strip, DevCommands, instruction bitmap, duplicate scene
   demand labels, old Palette list, or road overlay is visible.
3. Open Build with the dock and with `B`; confirm world interaction pauses.
4. Choose Roads & Paths → Road and paint three cells.
5. Reopen Build, choose Nature → Duck Pond, rotate, and place it.
6. Confirm the dock keeps Duck Pond active for repeat placement; cancel and
   verify no additional spend or placement.
7. Repeat steps 3–6 with keyboard only and gamepad only.

## Availability path

1. Use fixtures for insufficient cash, insufficient demand, unmet story
   prerequisite, and already-placed unique.
2. Confirm each item stays visible with icon, pattern/glyph, cost/requirement,
   and correct canonical reason.
3. Attempt confirmation and verify Palette rejects without changing preview,
   resources, or progression.
4. Satisfy the gate and verify the existing wedge updates without reopening or
   reconstructing the full interface.

## Paging, layout, and modal checks

- Test groups with 1, 8, 9, and 20 fixtures.
- Open at all four viewport corners and resize between 1280×720 and wide layout.
- Test long labels and supported text scale.
- Open Community, Inbox, Day/Night, Dialogue, overbuild confirmation, and
  Community inspect mode around radial/placement transitions; verify input
  ownership and non-overlap.
- Verify color-disabled screenshots retain all focus/block/state meanings.

## Asset acceptance

- Validate manifest completeness, dimensions, RGBA/alpha, and unique icon keys.
- Review 24/32/56/72 px proof on parchment and 56 px proof over
  `specs/003-community-ui/validation/screenshots/overview.png`.
- Reject ambiguous silhouettes, matte fringes, clipped padding, or states that
  differ by color alone.

## Release and regression checks

- Inspect a release export for inactive/absent QuestDebug, RoadDebug, and
  Playtest services.
- Run recursive GUT, deterministic replay, and one complete automated
  city-building scenario.
- Record performance, test totals, versions, screenshots, and failures under
  `specs/004-radial-build-ui/validation/`.

## Automated acceptance commands

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://test/integration/player_ui \
  -ginclude_subdirs -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://scripts/run_radial_build_scenario.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://scripts/profile_radial_ui.gd
```

Run `scripts/capture_radial_validation.gd` with the normal renderer (not the
headless dummy renderer) to refresh the 11 visual acceptance PNGs.
