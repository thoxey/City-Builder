# Visual language

## Character

The target is a mid-century British comic illustration translated into compact
game UI: jaunty, economical, witty, slightly wonky, and human. It should suggest
inked print art without copying a named living artist or a specific protected
character. The humour comes from pose, silhouette, visual punctuation, and
objects behaving with personality—not from facial features or written jokes.

## Structural recipe

- Near-black ink: `#171713`. Use for the main contour, internal joins, and small
  comic punctuation.
- Paper: `#E7D3AD`. This is the established icon disc and the default light UI
  ground, not a mandatory background for every component.
- Draw broad, continuous masses with a slightly variable hand-inked edge.
- Join related parts where possible. At small sizes, one strong silhouette beats
  several accurate but disconnected details.
- Use generous negative space and a consistent optical centre. Dynamic forms may
  lean or overshoot without looking accidentally off-centre.
- Simplify repeated details into rhythms: three windows, two crowd heads, three
  rays. Avoid visual grit that disappears at delivery size.
- Use at most two or three emphasis marks: speed ticks, impact ticks, discovery
  rays, sweep lines, or one spring curl.

## Semantic palette

| Token | Hex | Meaning and recurring nouns |
|---|---:|---|
| paper | `#E7D3AD` | parchment disc, panel ground, quiet negative space |
| ink | `#171713` | structure, contour, punctuation |
| building | `#58705A` | houses, buildings, places, neighbourhoods |
| capacity | `#C9743F` | capacity, quantity, growth, opportunity, directional action |
| civic | `#2E8290` | programmes, civic systems, information, tools |
| active | `#D3A526` | active, available, positive attention, discovery |
| care | `#B9516D` | happiness, belonging, care, residents when rose is appropriate |
| danger | `#A9473F` | harm, warning, rejection, risk |
| neutral | `#77745A` | stable, inactive, secondary structure |

Recurring nouns retain their colour. A modifier supplies the second colour: a
house remains green while capacity remains orange. Distinct residents rotate
orange, teal, mustard, rose, and olive when individuality matters.

Do not assume these colours meet accessible contrast in every pairing. Test the
actual foreground/background pair. The near-black ink is the primary shape and
contrast carrier; semantic fills are secondary.

## Shape grammar

### People

- Faceless head plus a distinctive hair/hat shape and a compact shoulder/torso
  mass.
- Use lean, stride, recoil, huddle, reach, or shelter to communicate action.
- A crowd is a staggered rhythm, not duplicated busts in a perfect grid.
- Distinct people can use different fills; do not add eyes or mouths by default.

### Buildings and places

- Bottle-green main mass, near-black joined roof/door/window structure.
- Use an irregular roofline, lean, chimney, awning, or doorway to avoid a generic
  corporate house glyph.
- Preserve the green noun when an orange capacity arrow, teal programme, or red
  warning is added.

### Arrows and motion

- Broad hand-inked shaft, blunt energetic head, gentle curve or springy bend.
- Avoid ruler-straight chevrons. Let the arrow swell slightly through the turn.
- Add two or three marks at a collision, arrival, or lift-off point—not evenly
  around the entire arrow.

### Status and polarity

- Positive: lift, opening, radiating, supported, upright.
- Negative: drop, recoil, pinch, fracture, lean, blocked passage.
- Stable: balance, level baseline, paired symmetry with a slight human wobble.
- Warning: red wedge or exclamation silhouette plus impact/burst geometry.

### Containers and controls

- Frames and panels should feel inked and printed, but their functional edge and
  corner zones must be simple enough to slice or tile cleanly.
- Keep decoration clustered at corners, headers, tabs, or intentional anchors;
  do not scatter noise through text/content zones.
- Selected/focused states may add an ink outline, mustard tab, rays, or a small
  positional lift. Disabled states use structure/pattern as well as lower colour.

## Reference assets

Browse `../assets/shape-library/` by semantic family. Particularly useful anchors:

- `housing-capacity.png`: compound noun + modifier colour.
- `increasing.png`, `decreasing.png`, `rejected-migration.png`: arrow grammar.
- `community.png`, `population.png`, `resident.png`: people and crowd grammar.
- `warning.png`, `positive-effect.png`, `negative-effect.png`: punctuation.
- `neighbourhood.png`, `place-inspection.png`, `effect-radius.png`: place shapes.
- `expand-details.png`, `search.png`, `filter.png`: compact controls.

The canonical full-resolution references remain in
`sprites/community_icons/`; never replace them with the compact shape-library
copies.
