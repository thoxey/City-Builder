# Quest Dialogue UI Asset Set

This directory preserves both the original provisional portrait pass and the
approved line-art portrait integration for SpecKit feature 011. Dialogue text,
speaker names, and choice labels remain engine text; none is baked into these
images.

- `masters/`: highest-resolution source retained for each asset.
- `game/`: 512 px Godot-ready RGBA derivatives.
- `review/`: actual-size 180 px and 260 px proofs plus 512 px inspection copies.
- `proofs/`: contact sheets, grayscale review, and noisy-gameplay context.
- `manifests/`: formatter output for each source/derivative pair.
- `manifest.json`: semantic role, provenance, display range, and integration notes.
- `line-art/`: approved seven-expression masters, runtime paths, and review
  proofs for Ambrose, Baba Soyink, and Sir William.

Portraits are illustrative fixed-size UI art intended to display between 180 px and
260 px. The portrait frame and emphasis overlay are square fixed-size overlays. The
main dialogue frame, choice buttons, divider, and scrollbar reuse the established
build-menu component library through `themes/dialogue_theme.tres`.

The approved runtime path for Ambrose, Baba Soyink, and Sir William is the
transparent black seven-state line-art set documented in
`line-art/README.md` and `line-art/manifest.json`. Their character JSON maps
those semantic expressions into full dialogue and compact guidance.

The older 512 px expression crops described by `manifest.json` remain
provisional reference and fallback material. Ambrose concerned, Baba surprised,
and Flick concerned in that earlier pass were generated from canonical
portraits and talking-video reference frames; other crops use a canonical
portrait or a frame extracted at 2.5 seconds. Flick remains on that provisional
set and is intentionally excluded from the approved line-art integration.
Existing `talking_videos` were not edited.
