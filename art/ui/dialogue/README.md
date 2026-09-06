# Quest Dialogue UI Asset Set

This directory preserves the provisional source, runtime, and review artifacts for
SpecKit feature 011. Dialogue text, speaker names, and choice labels remain engine
text; none is baked into these images.

- `masters/`: highest-resolution source retained for each asset.
- `game/`: 512 px Godot-ready RGBA derivatives.
- `review/`: actual-size 180 px and 260 px proofs plus 512 px inspection copies.
- `proofs/`: contact sheets, grayscale review, and noisy-gameplay context.
- `manifests/`: formatter output for each source/derivative pair.
- `manifest.json`: semantic role, provenance, display range, and integration notes.

Portraits are illustrative fixed-size UI art intended to display between 180 px and
260 px. The portrait frame and emphasis overlay are square fixed-size overlays. The
main dialogue frame, choice buttons, divider, and scrollbar reuse the established
build-menu component library through `themes/dialogue_theme.tres`.

Ambrose concerned, Baba surprised, and Flick concerned were generated from the
canonical character portraits and a talking-video reference frame. Other expression
crops use a canonical portrait or a frame extracted at 2.5 seconds from the existing
talking video. Those 512 px video-derived sources are deliberately provisional; the
runtime contract addresses semantic expressions so higher-resolution replacements do
not require quest-data or renderer changes. Existing `talking_videos` were not edited.
