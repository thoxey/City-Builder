# Research: Live Placement Consequences

## Existing seams

- `Builder.evaluate_placement` is already a non-mutating canonical envelope for land, footprint, overlap, rooted access, uniqueness, cash, and demand.
- `Community.get_placement_preview` is only a radius/coverage hint; it does not evaluate before/after stacking or provide commit parity.
- `CommunityEffectEvaluator.evaluate` is pure until `update_qualities` is called and therefore is safe to reuse for quotes.
- `Attractiveness._compute_tile` contains the committed scoring rule but is coupled to live indexes; extracting its inputs enables a detached quote without a second formula.
- Placement context is already emitted only on cell movement, selection, and rotation, so no per-frame job system is required.

## Decisions

1. Quote the next canonical evaluation at the current hour, not a promise about future simulation hours.
2. Aggregate community changes across affected current residents and retain a bounded resident/home list.
3. Mark participant allocation and hypothetical road reconnection uncertain; do not invent secondary solvers.
4. Treat replacement as a valid-but-confirmed state only if canonical `replace=true` validation passes.
5. Keep the panel compact and location-labelled; authored/base information stays in the intrinsic build entry.
