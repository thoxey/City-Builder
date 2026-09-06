# Contract: Buildable Presentation and Early Community Balance

## Buildable presentation projection

For any current authoritative cell set `A`:

1. Every `cell ∈ A` inside the rendered ground extent has a fully transparent mask pixel.
2. Every rendered ground cell not in `A` has a white mask pixel shown at perceptual 5% opacity (0.0125 linear framebuffer alpha) in normal play.
3. `radial` and `placement` modes use the emphasized style; every other mode uses the normal style.
4. The emphasized white-overlay opacity is perceptual 8% (0.02 linear alpha), greater than the normal style.
5. A map load or successful expansion reconstructs the projection from `A`.
6. No projection method can add, remove, or legalize a cell.

## Rooted starter land

- Rooted: `Rect2i(-8, -8, 16, 16)` = 256 cells.
- Non-rooted: `Rect2i(-4, -4, 8, 8)` = 64 cells.
- Default aristocrat grant: `Rect2i(8, -8, 12, 16)` = 192 additional rooted cells.
- Reapplying a received donation: 0 additional cells.

## Early quality expectations

- Mixed connected fixed-seed town after convergence: Liveability > 50, Beauty > 50, Belonging > 50.
- Poor matched layout: at least Liveability and Beauty are lower than the mixed layout, with negative applied-effect reasons present.
- Four identical positive effects in one quality/stacking group total exactly `base × 1.75`; a fifth is unchanged.
- Save/load: resident current/target maps and composite happiness compare exactly; applied-effect diagnostics are re-derived on the next tick.
