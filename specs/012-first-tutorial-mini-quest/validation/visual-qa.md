# Visual QA

The normal macOS OpenGL renderer generated three actual-size compact-guidance
proofs through `scripts/capture_opening_tutorial_validation.gd`:

- `1280x720-town-hall.png`
- `1920x1080-home-adjacency.png`
- `3840x2160-first-shop.png`

All three were inspected at original resolution. The bubble remains in the
lower-left safe region, the portrait and close control remain legible, text
wraps without clipping, the background remains visible, and the literal
`AMBROSE PLACEHOLDER:` label is unmistakable. The existing compact-view tests
also verify 1280 bounds, 4K scaling, suppression, pointer consumption, and
dismissal stability. Full dialogue events use the already verified dialogue
surface and pass schema/expression/content validation.

Manifest: `art/ui/dialogue/line-art/reviews/opening-tutorial/manifest.json`.
