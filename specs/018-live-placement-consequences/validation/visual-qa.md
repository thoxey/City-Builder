# Visual QA

Completed on 2026-09-06 against the normal renderer captures listed in
`screenshots/manifest.json`.

## Coverage

- 1280×720: valid location and replacement/uncertain location.
- 1920×1080: valid, replacement/uncertain, and invalid location.
- Intrinsic/authored details remain in the build-menu dock while the separate
  `THIS LOCATION` panel contains only tile- and town-state-dependent outcomes.
- Positive, negative, unchanged, replacement, invalid, and uncertain rows use
  distinct text and colour treatment.
- Community values, affected residents/homes, similar neighbours, effect reach,
  access, and town appeal remain bounded to ten rows.

## Findings and refinements

The first 1280×720 review found the 13 px consequence rows marginally small and
the fixed-height invalid panel too empty. Rows were increased to 15 px with
20 px icons, panel height was changed to fit the active row count within a
72–310 px bound, and uncertainty copy was shortened for the compact layout.

The recaptured matrix confirms readable text without overlap at 1280×720,
clear separation from intrinsic information, a compact one-row invalid state,
and no held-footprint obstruction in the staged layouts. Replacement and
uncertainty remain visible together without flooding the screen.

## Evidence

- `screenshots/1280x720-valid-location.png`
- `screenshots/1280x720-replacement-uncertain.png`
- `screenshots/1920x1080-valid-location.png`
- `screenshots/1920x1080-replacement-uncertain.png`
- `screenshots/1920x1080-invalid-location.png`

The capture script stages deterministic UI states through the same panel model;
domain parity and no-mutation behavior are established by the automated suite,
not inferred from screenshots.
