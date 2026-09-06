# Dialogue-system integration handoff prompt

Use the prepared transparent line-art expression portraits in
`art/ui/dialogue/line-art/manifest.json`. Do not regenerate, recolour, crop, or
remove backgrounds from them; the runtime files are already 512 x 512 sRGB RGBA
PNGs with pure-black RGB and straight alpha.

Integrate all seven stable semantic expressions for these definitions:

- Ambrose: `data/characters/ambrose.json`, assets at
  `res://data/characters/ambrose/expressions/line_art/<state>.png`
- Baba Soyink: `data/characters/aristocrat_residential.json`, assets at
  `res://data/characters/aristocrat_residential/expressions/line_art/<state>.png`
- Sir William: `data/characters/aristocrat_patron.json`, assets at
  `res://data/characters/william/expressions/line_art/<state>.png`

The state keys are exactly `neutral`, `pleased`, `disapproving`, `angry`,
`surprised`, `concerned`, and `thoughtful`. Set `default_expression` to
`neutral`. Update each character's `expressions` map to these files while keeping
its existing `portrait` as the legacy fallback. Do not modify or reinterpret
`talking_videos`.

Keep dialogue authoring semantic: beats should name an expression key, never a
sheet index or filename inferred from position. Preserve the current resolution
order in `DialoguePlugin`: authored expression, declared default expression,
legacy portrait, then missing-art fallback. Ensure the portrait TextureRect
respects transparency and places the black-only line art over a light dialogue
surface; do not add a white rectangle inside the texture itself.

After updating character definitions, regenerate `data/events/_manifest.json`
with the documented headless exporter at
`res://addons/data_editor_tools/export_manifest_headless.gd`. Update relevant
dialogue expression tests so all three characters resolve every new semantic
state, unknown states fall back to `neutral`, and all referenced resources exist.
Run the dialogue and event-system test suites. Do not include Flick in this
integration yet; her full approved expression sheet has not been produced.

Use `art/ui/dialogue/line-art/README.md` for the directory and rendering contract
and `art/ui/dialogue/line-art/manifest.json` as the machine-readable source of
truth.
