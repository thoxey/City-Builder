# Buildable Boundary Visual QA

Captured in the running main scene with the Forward+ renderer on Apple M2 Max,
at 1280×720 and the standard gameplay starting zoom of 60.

| State | Clear buildable cells | Veiled non-buildable cells | Perceptual / linear opacity | Result |
|---|---:|---:|---:|---|
| Normal play | 256 | 261,888 | 5% / 0.0125 | PASS |
| Placement active | 256 | 261,888 | 8% / 0.02 | PASS |

The normal frame communicates the full square by leaving it untouched while a
5%-opacity white veil covers the surrounding rendered terrain. The placement
frame uses the same authoritative transparent holes with a stronger white veil.
Roads, the Town Hall, homes, nature, the placement grid/radius, and selection
feedback remain readable because the overlay is depth-tested and lies just
above the ground. Grass colour and texture remain clearly visible on both sides.

The transient compact tutorial-guidance bubble was suppressed for these proof
frames so it could not cover the boundary; the standard top HUD, bottom
build palette, and clock remain visible for real layout-pressure verification.

- `boundary-normal.png`: normal gameplay presentation
- `boundary-placement.png`: emphasized nature-placement presentation
- `screenshots/manifest.json`: captured viewport, camera, renderer, and exact presentation metrics
