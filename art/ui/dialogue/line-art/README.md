# Transparent dialogue line portraits

This package contains the approved seven-expression portrait sets for Ambrose,
Baba Soyink, and Sir William, split into individual transparent PNGs. Flick is
not included because her four-expression character pass and full sheet have not
yet been approved.

## Directory map

- `masters/<character>/<state>.png`: 627 x 627 transparent source crop retained
  from the approved 2508 x 1254 contact sheet.
- `res://data/characters/<character-folder>/expressions/line_art/<state>.png`:
  512 x 512 Godot-ready derivative for the dialogue UI.
- `review/contact-sheet-parchment-180px.png`: the exact 180 x 212 portrait-host
  crop used by the current dialogue view, composited over the UI parchment.
- `review/contact-sheet-alpha-checker-128px.png`: a transparency and edge-fringe
  proof at 128 px per portrait.
- `manifest.json`: character IDs, source sheets, crop regions, semantic state
  names, runtime paths, dimensions, and alpha policy.
- `HANDOFF_PROMPT.md`: copy-ready prompt for the dialogue-system integration
  task.

Character folders do not always match semantic IDs:

| Character | Character ID | Runtime folder |
|---|---|---|
| Ambrose | `ambrose` | `data/characters/ambrose` |
| Baba Soyink | `aristocrat_residential` | `data/characters/aristocrat_residential` |
| Sir William | `aristocrat_patron` | `data/characters/william` |

## Stable expression vocabulary

1. `neutral`
2. `pleased` (approving / happy)
3. `disapproving`
4. `angry` (character-specific frustration)
5. `surprised`
6. `concerned`
7. `thoughtful` (quizzical / thinking)

Use these semantic names in dialogue data. Do not address the original sheet by
row or column at runtime.

## Image contract

- PNG, sRGB, RGBA, straight alpha.
- Every RGB pixel is pure black (`#000000`); edge smoothing is encoded only in
  alpha.
- There is no white or parchment backing in any exported portrait.
- Runtime size is 512 x 512, intended to display at 180-260 px.
- The art therefore needs a light host surface. The existing dialogue parchment
  is suitable; a dark host will make the black linework disappear.
- The original contact-sheet masters were not modified.
- Integration updates only the semantic expression maps and defaults in character
  JSON. Legacy portraits and talking videos remain unchanged.

The source sheet order is recorded in `manifest.json`. White removal was done by
turning inverted source luminance into alpha, remapping the mask to discard pale
generation haze, and replacing all visible RGB with black. This prevents a white
matte fringe when composited in Godot.
