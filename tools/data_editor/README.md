# Building UI metadata

The radial build menu is data-driven. Add these fields to each standalone
building JSON, or to the pool sidecar under `data/buildings/<category>/_pools/`:

```json
{
  "ui_group": "nature",
  "ui_order": 20,
  "ui_icon": "building_duck_pond"
}
```

`ui_group` must be one of `roads`, `homes`, `commerce`, `industry`, `nature`,
`civic`, or `landmarks`. `ui_order` is an integer used with the stable entry ID
as the deterministic tie-breaker. `ui_icon` names a PNG in
`sprites/ui/build-menu/entries/` without its extension. Pool sidecar metadata
takes precedence for the single pooled menu entry; individual members retain
their own metadata for catalog inspection. Invalid/missing values fall back to
`landmarks`, order `1000`, and `missing-artwork`, and emit a catalog warning.

Do not encode affordability or unlock rules in UI metadata. Economy, Demand,
and UniqueRegistry remain the authorities; Palette publishes their current
reason-bearing decision to PlayerUI.
