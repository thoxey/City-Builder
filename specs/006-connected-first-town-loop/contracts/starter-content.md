# Contract: Starter Content Consequences

Every player-selectable starter T1/T2 growth, road, or nature entry must declare
one of:

- a `CommunityEffectProfile` with complete effect ID, quality, scope, amount,
  manifestation, stacking group, schedule where applicable, and readable
  reason; or
- an explicit `community_role: "cosmetic_only"` declaration.

Functional nature declares `community_role: "functional"`. Cosmetic-only
entries may retain visuals and cash cost but contribute no housing demand,
migration, unlock, or progression total.

Validation rejects:

- missing role/effect declaration;
- participant effects without capacity;
- local effects without a non-negative radius;
- missing/blank reason or stacking group;
- cosmetic content with Community effects;
- positive nature effects entering a global uncapped progression signal;
- non-zero fourth-and-later same-group stacking in the default policy.

The starter inventory and validation result are emitted into milestone evidence
so an intentionally neutral item is distinguishable from missing authoring.
