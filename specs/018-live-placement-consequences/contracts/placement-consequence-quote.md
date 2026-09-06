# Contract: Placement Consequence Quote

`Builder.evaluate_placement_consequences(structure_index, anchor, rotation)` returns a detached dictionary matching `data-model.md`.

Domain extension points are optional, read-only methods:

- `Community.quote_placement_consequences(structure_index, anchor, removed_ids, rotation)`
- `Attractiveness.quote_placement_consequences(structure_index, anchor, footprint, removed_ids)`

Consumers must treat `certainty != exact` as explanatory information, not authoritative applied state. A commit must always re-run `Builder.evaluate_placement`; a quote is never an authorization token.
