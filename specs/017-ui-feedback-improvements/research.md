# Research: UI and Feedback Improvements

## Decision 1: Decorate presentation, never authored dialogue

Ambrose keyword icons are injected only into a `RichTextLabel` presentation
string. The row model, reveal clock, event data, transcript projection, and
accessibility text retain the exact authored string. The renderer matches whole
English keywords case-insensitively and inserts an icon after each match. If the
asset does not exist, it inserts nothing.

**Why**: This preserves authored meaning and all state contracts while allowing
repeat-safe inline images and native word wrapping. Decorating event JSON would
leak engine markup into localized content and change reveal lengths.

## Decision 2: Treat current and lifetime demand as separate facts

The status bar reads `unserved` as “Current available” and `total` as “Lifetime
earned.” UniqueRegistry profiles provide positive lifetime thresholds, while
BuildingCatalog provides names. Targets are grouped by the profile’s bucket and
sorted by threshold/name.

**Why**: Unique progression already consumes `DemandPlugin.get_total`; ordinary
placement consumes unserved demand. Showing the two labels mirrors those
authorities and makes 75-total Homes unambiguous.

## Decision 3: Use an explicit normalized opacity function

Placement feedback uses `alpha = pow(1 - progress, 1.35)` for a 3.2-second
lifetime. A tween samples the function and frees its host afterward.

**Why**: The curve loses opacity faster initially and its derivative eases toward
zero, while remaining partially visible well beyond the old 1.5-second effect.
An exposed pure function makes timing testable without renderer timing.

## Decision 4: Project intrinsic effects through Palette

Palette already owns the detached selected-entry model. It will expose a stable
`authored_effects` array for the representative structure: non-zero
`AttractivenessProfile.base` as Beauty plus every non-zero authored
`CommunityEffectProfile` amount. Each row carries quality, signed amount, scope,
reason, and source; it contains no anchor, neighbour, exposure, or evaluated
placement value.

**Why**: PlayerUI and the dock remain presentation-only, Builder stays out of
metadata formatting, and workstream 5 can independently consume live placement
evaluation without changing the base contract.

## Decision 5: Reuse existing raster families

No new art is required. Community qualities use
`sprites/community_icons/game/{quality}.png`; demand uses the existing status
icons; cash uses `sprites/ui/status/cash-purse.png`. Missing resources render a
text row without an empty-image placeholder.

## Decision 6: Scale authored HUD surfaces at high resolution

Dialogue, the status bar, hover proof, and held-building dock use the same
bounded authored-canvas policy already established by compact guidance: 1× at
1920 pixels wide and below, scaling up to 2× at 3840. The status bar recomputes
its pre-transform width so its two-percent safe margins remain intact; the dock
scales around its centre-bottom pivot so dashboard safe insets stay in physical
viewport coordinates.

**Why**: A raw fixed-pixel 4K layout was technically in bounds but physically
too small. Scaling the complete surfaces preserves their composition, text/icon
relationship, and clickable area without changing the compact 1280 layout.
