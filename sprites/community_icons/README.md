# Community icon language

All icons use a warm parchment circle (`#E7D3AD`) with genuine transparency
outside it and a near-black structural ink (`#171713`). Shapes are chunky,
slightly irregular, asymmetric, and readable at 16–24 px.

## Asset layout and export format

- Root PNGs are the untouched 1254×1254 RGBA generation masters.
- `game/` contains the game-ready 128×128 lossless RGBA PNGs.
- The parchment disc remains opaque and everything outside it remains transparent.
- Game files are stripped of ancillary metadata and use PNG compression level 9.
- Downsampling uses Lanczos filtering; the specified display range is 16–24 px.
- `review/small-size/` contains exact 16, 20, and 24 px proofs and enlarged
  contact sheets for legibility review. These proofs are QA assets, not runtime
  textures.

Use `game/{slug}.png` as the runtime path. Keep aspect ratio and do not crop,
tint, recolour, or place another circular mask over the asset in the UI.

## Semantic colours

- House, building, place, neighbourhood: bottle green (`#58705A`)
- Capacity, quantity, growth, opportunity: burnt orange (`#C9743F`)
- Civic systems, programmes, information: teal (`#2E8290`)
- Active, available, positive attention: mustard (`#D3A526`)
- Happiness, belonging, care: dusty rose (`#B9516D`)
- Harm, warning, rejection, risk: muted red (`#A9473F`)
- Neutral, stable, inactive: olive-taupe (`#77745A`)
- Distinct residents: rotate orange, teal, mustard, rose, and olive

Recurring nouns keep their colour. A modifier supplies the second colour: a
house is always green; capacity is always orange. Use no more than two semantic
spot colours unless the icon deliberately represents several distinct people.

## Comic punctuation

Use at most two or three near-black emphasis marks at the active edge: speed
ticks for motion, rays for discovery, sweep lines for curves, impact ticks for
collision, and a spring curl for recoil. Meaning must remain clear without
colour or punctuation.

## Canonical generation prompt

> Finished circular UI icon in the locked city-builder system: warm parchment
> disc `#E7D3AD` with genuine transparency outside; thick, gently irregular
> near-black ink `#171713`; flat opaque muted vintage colours; bold asymmetric
> silhouette; generous even padding; crisp at 16–24 px. Recurring nouns retain
> their semantic colour and modifiers supply the second colour. Add at most two
> or three small comic-punctuation marks at the active edge. No text, letters,
> numbers, gradients, shadows, photographic texture, border rim, watermark, or
> signature. Concept and motif: use the corresponding entry in
> `icon_manifest.json`.
