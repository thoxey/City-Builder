---
name: city-builder-ui-assets
description: Create, extend, and format raster UI art for this game in its established vintage British comic language. Use for icons, controls, panels, windows, tabs, badges, frames, nine-slices, tileable UI textures, atlases, maps, portraits, and other interface assets; preserve high-resolution masters and produce verified Godot-ready derivatives.
---

# City Builder UI Assets

Create UI assets that look as though they belong to the same illustrated game,
remain legible in context, and arrive with enough technical information to be
implemented without reverse-engineering the artwork.

## Load the relevant guidance

- Always read [visual-language.md](references/visual-language.md) before making art.
- Read [asset-taxonomy.md](references/asset-taxonomy.md) when choosing an asset
  type or planning a broader UI kit.
- Read [sheets-and-scalables.md](references/sheets-and-scalables.md) for panels,
  nine-slices, tiled/repeating art, state sheets, component sheets, or atlases.
- Read [export-and-godot.md](references/export-and-godot.md) before formatting,
  exporting, importing, or handing assets to implementation.
- Read [prompt-recipes.md](references/prompt-recipes.md) when generating or
  editing raster artwork with an image model.
- Read [research-notes.md](references/research-notes.md) when planning a new UI
  family, revisiting pipeline decisions, or needing the underlying sources.
- Read [manifest-schema.md](references/manifest-schema.md) when adding a new
  family or machine-readable handoff metadata.
- Use the 52 files in `assets/shape-library/` as shape-language references.
  They are references, not a requirement to place every new design in a circle.

## Working method

1. Inspect the target screen, neighbouring assets, implementation constraints,
   and intended display sizes. If no implementation exists, state the assumed
   minimum, typical, and maximum display size.
2. Classify the deliverable before drawing: fixed-size symbol, resizable
   component, repeatable texture, compound sheet, or illustration. Do not turn a
   resizable component into one large fixed bitmap.
3. For a new asset family, make a labelled exploration sheet with materially
   different silhouettes. Choose a direction before producing a large batch.
   For established families, use the closest shape references directly.
4. Generate one coherent asset or exploration composition per image-model call.
   Do not ask an image model to create a production sprite atlas with exact cell
   order or exact margins; assemble and validate sheets deterministically.
5. Preserve the highest-resolution clean result as the immutable source master.
   Put runtime copies in a separate export directory. Never overwrite a master
   with a downsampled derivative.
6. Format derivatives with deterministic image tooling. For icon-like assets,
   use `scripts/format_ui_asset.py`; retain alpha and colour mode, strip
   incidental metadata, and record intended display sizes.
7. Verify at actual display size, on both a calm UI background and a noisy game
   screenshot when available. Check silhouette, state distinction, padding,
   alpha edges, seams/slices, contrast, and non-colour communication.

## Non-negotiable theme rules

- Use thick, gently irregular near-black structural ink and flat, opaque muted
  spot colours on warm parchment. Prefer joined silhouettes over loose detail.
- Favour characterful asymmetry, readable gesture, dynamic poses, expressive
  hair/clothing shapes, and two or three comic emphasis marks at an active edge.
- Faces are normally faceless: omit eyes and mouths unless the brief explicitly
  requires portrait-level expression.
- Never use text generated inside bitmap art. Keep labels as engine text so they
  remain localisable, scalable, and accessible. A deliberate logotype is the
  exception.
- Colour supports meaning but never carries it alone. Pair state and polarity
  with silhouette, sign, direction, pattern, or label.
- Preserve semantic colour assignments for recurring nouns. Do not recolour a
  house, capacity arrow, warning, or programme merely to add variety.
- Avoid glossy gradients, soft airbrush shading, drop shadows, photorealism,
  sterile vector geometry, modern corporate iconography, border rims on circular
  icons, watermarks, and signatures.

## Deliverable contract

Return or create:

- a high-resolution source master;
- game-ready derivative files, without destroying the master;
- a manifest entry containing slug, role, semantic motif, source path, runtime
  path, dimensions, intended display range, alpha policy, and slice/tile/state
  metadata where applicable;
- an actual-size proof for small or stateful assets;
- for nine-slices, the four slice margins and tested minimum dimensions;
- for tileables, a repeated 3×3 seam proof;
- for sheets, machine-readable cell/region metadata rather than coordinates
  documented only in prose.

When requirements conflict, preserve legibility and implementation behaviour
before decorative fidelity. Record intentional exceptions instead of silently
changing the system.
