# Catalog UI inventory

All 30 catalog definitions and the 9 logical pool entries carry validated
`ui_group`, `ui_order`, and `ui_icon` metadata. Pool sidecars exist for road,
pavement, and grass; six existing tier pools carry the same contract. Runtime
groups are roads, homes, commerce, industry, nature, civic, and landmarks.

Palette projects 22 exact-once logical choices: 6 ordinary pools plus road,
pavement, grass, and 13 standalone unique/story entries. Ordering is group,
`ui_order`, then stable ID. Invalid metadata falls back deterministically to
landmarks / 1000 / missing-artwork with a catalog warning.
