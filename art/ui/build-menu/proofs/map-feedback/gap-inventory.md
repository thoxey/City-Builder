# Radial UI visual gap inventory

Audit date: 2026-09-05

Scope reviewed:

- all 12 clean and annotated radial/HUD mockups;
- the approved build-menu icon wall and actual-size proofs;
- the complete scalable component kit and its nine-slice/state proofs;
- the Community UI reference screenshot and Community icon family;
- every source/runtime path in `art/ui/build-menu/manifest.json`;
- all new map-feedback masters, runtime derivatives, anchors, hotspots, modular regions, and proofs.

## Essential gaps demonstrated by the mockups

The placement and demolition mockups used temporary flat diamonds, hatching, and a solid red rectangle. They demonstrated missing reusable map-feedback art rather than a need to redesign the approved radial menu or HUD. The completed family now supplies:

- neutral, valid-placement, invalid-placement, demolition, and inspect/select cursors;
- affordable, blocked, replacement/overbuild, and demolition-target markers;
- a clockwise rotation indicator, matching the single Rotate action shown by the interface;
- 16-mask N/E/S/W connectivity sheets for affordable footprints, blocked footprints, and selected-building outlines, covering isolated cells, ends, straights, corners, T-junctions, and crosses;
- effect-radius edge, corner, and three-frame pulse accents without baking a fixed-radius circle;
- neutral, positive, warning, and destructive notification pins with a shared ground anchor;
- neutral, positive, and warning off-screen direction markers in one canonical upward orientation;
- restrained idle/emphasis/settle source sequences for the notification pin and effect-radius pulse.

## Existing-system audit

| Audit item | Finding | Resolution |
|---|---|---|
| Compact approved icons | Category and entry derivatives already exist at 256 px; control derivatives exist at 128 px; 24/32/56/72 px proofs are present. | No new compact icon variants required. |
| Focus states | General and radial-wedge focus overlays are present and use shape/ink as well as mustard. | No gap. |
| Disabled/destructive states | Disabled hatch, destructive warning, radial disabled, and radial destructive overlays are present. | No gap. |
| Panel corners/slice-safe edges | Nine-slice sources, margins, minimum/wide/tall proofs, and component metadata are present. | No gap. |
| Dividers/badges | Horizontal, vertical, ornamental, and section dividers plus neutral/active/warning badges are present. | No gap. |
| Line weight | Approved icons/components share the locked near-black contour. New runtime art was palette-quantized and reviewed on the asset wall. | Consistent. |
| Transparent padding | Existing shipped paths pass their prior proofs. Six new generated sources initially contained a baked transparency preview. | Deterministically extracted; all new production PNGs are RGBA with transparent exterior and zero RGB where alpha is zero. |
| Matte fringes | No new runtime matte fringe was found on parchment, dark, green, or detailed-building backgrounds. | Pass. |
| Building silhouettes | Approved build icons remain unchanged. Replacement and inspect feedback retain a compact green building noun but use distinct exchange/lens structures. | Pass. |
| State meaning without colour | Valid uses an open hand/door; blocked uses crossed barricades/hatch; replacement uses exchange arrows; demolition uses fracture/impact; inspect uses a lens. | Pass in grayscale proof. |
| Manifest coverage | Every shipped production source/runtime path is referenced. Three pre-existing files (`button-tab-base` source/runtime and `scroll-handle-source`) are construction intermediates superseded by approved state assets and are intentionally not shipped records. | No missing approved record. |

## Deterministic repairs and formatting

- Removed baked white/checkerboard generation backgrounds from six source images.
- Quantized new production art to the locked semantic palette, removing generated gradients and colour drift.
- Preserved clean straight alpha and cleared RGB in fully transparent pixels.
- Repaired footprint connectivity so interiors meet edge-to-edge and only exterior borders draw.
- Extended exterior border endpoints to remove multi-cell join gaps.
- Rebuilt selected-building feedback as an open modular outline rather than a filled ground tile.
- Built modular sheets, animation strips, colour-vision simulations, labels, hotspot dots, and anchor dots outside the production artwork.

## Closure

No essential reusable visual asset remains unresolved. The image-production pipeline is complete. Human art direction should approve or reject the new family as a whole; implementation may then consume the documented runtime files without further asset invention.
