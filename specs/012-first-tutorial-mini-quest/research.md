# Research: First Tutorial Mini-Quest

This research records only non-creative technical decisions. Runtime wording remains
the approved, visibly labelled `AMBROSE PLACEHOLDER: <beat purpose>` copy described in
`dialogue-workshop.md`; replacing those placeholders with final prose is a separate
creative pass.

## Decision 1: Add one focused opening-tutorial authority

**Decision**: Add an `OpeningTutorial` plugin that owns semantic tutorial state,
receipts, evidence capture, reconciliation, and a detached projection. It observes
existing systems and never calls placement, demolition, demand-spend, Community
mutation, attractiveness mutation, or progression mutation APIs.

**Rationale**: The current Dashboard projection is derived from patron progression and
contains a one-off Town Hall override; it cannot durably represent the opening sequence
or its experiment evidence. Builder, Demand, Attractiveness, RoadNetwork, Community,
UniqueRegistry, and EventSystem already own the facts and actions the tutorial needs.
A small observer plugin preserves those authorities and keeps orchestration out of
`builder.gd`.

**Alternative rejected**: Expanding Dashboard into a tutorial state machine would mix
presentation and progression. Encoding the sequence as EventSystem conditions alone
would not retain experiment baselines, monotonic receipts, or multi-step reconciliation.

## Decision 2: Persist one versioned tutorial record on `DataMap`

**Decision**: Persist a single `opening_tutorial_state` dictionary containing a schema
version, semantic current step, set-like completion and presentation receipts, durable
experiment evidence, and the terminal handoff receipt. Normalize missing or malformed
fields at boot/load.

**Rationale**: `DataMap` is the ordinary save authority and already persists similarly
shaped progression dictionaries. One versioned record is easier to migrate atomically
than several loosely related fields. The state contains semantic IDs and JSON-safe
values only; UI dismissal, viewport state, portraits, and dialogue cursors stay out of
it.

**Alternative rejected**: Inferring the entire sequence from current buildings after
every load regresses after demolition and cannot reproduce a historical attractiveness
experiment. Storing state in EventSystem flags obscures ownership and cannot represent
the required structured evidence cleanly.

## Decision 3: Reconcile monotonically from canonical detached evidence

**Decision**: Build one detached evidence snapshot from `GameState.building_registry`
plus public canonical queries, then advance in a stable `while` loop until the active
step is not satisfied. A receipt is written before moving to the next step; a receipt is
never removed because a later demolition or tuning change invalidates its original
fact.

**Rationale**: The registry is the committed placement record. BuildingCatalog resolves
stable IDs, categories, profiles, footprints, and tier-one pools; RoadNetwork proves
the Town Hall internal identity and rooted connectivity/access; Attractiveness
provides city and tile scores; Demand provides the non-mutating affordability quote;
Community provides resident assignment and operation records. This exactly matches the
repository's one-gameplay-truth rule.

**Alternative rejected**: Advancing only in individual signal handlers misses prebuilt
or loaded facts and creates ordering-dependent behavior. Re-running placement rules in
the tutorial would create a second legality implementation.

## Decision 4: Coalesce invalidation but retain ordered placement observations

**Decision**: Subscribe to map load, structure placement/demolition, demand,
attractiveness, Community summary, and road-affecting placement signals. Mark
reconciliation dirty and schedule one deferred pass. For placement-dependent
experiments, also append an ordered transition observation containing the last settled
snapshot and the post-commit snapshot after canonical listeners have run.

**Rationale**: Attractiveness and road state rebuild synchronously from the same
placement signal. Making `OpeningTutorial` depend on those plugins guarantees its
connection is registered later, so it can capture the settled post-placement state.
The ordered observation queue preserves two qualifying placements in one frame, while
the deferred reconciliation prevents redundant full scans.

**Alternative rejected**: Assuming signal connection order without dependency ordering
is brittle. A single deferred snapshot loses which placement caused an experiment
change when several commands commit in one frame.

## Decision 5: Resolve the Hall through RoadNetwork and count rooted components

**Decision**: Resolve the placed Hall from `RoadNetwork.get_town_hall_internal_id()` and
confirm `building_town_hall` through BuildingCatalog. Resolve
`RoadNetwork.get_rooted_component_ids()`, select those component
rows from `get_connectivity_snapshot()`, and count the union of their road cells.

**Rationale**: Town Hall is protected by rooted-town placement rules but has no
`UniqueProfile`, so UniqueRegistry is not its placement authority. RoadNetwork
intentionally allows more than one road component to touch
different edges of the 2x2 Town Hall even when those branches are not joined by a road
cell. All such components are canonically rooted and legal. Counting their union matches
the rooted-placement authority and avoids rebuilding graph connectivity.

**Alternative rejected**: Counting all roads admits disconnected painting. Selecting an
arbitrary first rooted component makes progress depend on component sort order.

## Decision 6: Identify qualifying buildings from stable catalog semantics

**Decision**: A placed early home/workplace/shop must have a `BuildingProfile` category
of `residential`/`industrial`/`commercial` and belong to a pool whose config has the
matching bucket and `tier == 1`. Nature distinctness uses the catalog `building_id` and
top-level `category == "nature"`. Committed buildings are already legal; wait guidance
uses `Demand.quote_placement()` for the deterministic cheapest qualifying candidate and
does not speculate about a tile.

**Rationale**: The live tier-one pools and the builder's spend gate use these exact
fields. Stable IDs distinguish Nature Patch from Duck Pond while duplicate copies of
one model collapse to one kind.

**Alternative rejected**: Hard-coding `building_small_a`, `building_garage`, or
`building_small_b` would reject valid pool variants. Treating a palette label or pool as
the nature identity would collapse distinct models.

## Decision 7: Capture the home experiment at the canonical attractiveness seam

**Decision**: When the first-home step completes, persist its internal ID, building ID,
anchor, footprint, tile score, and city score as the experiment baseline. A subsequent
residential placement qualifies as adjacent when the minimum Chebyshev distance between
the two canonical footprints is at most one. Persist the post-placement scores and
actual deltas; classify the result as `penalty_observed`, `no_penalty`, or
`baseline_unavailable`. Never infer a negative delta from authored data alone.

After adjacency is receipted, only a later committed nature/decorative placement can
complete repair, and only when the anchored home's canonical tile score is greater than
the stored post-adjacency score. The repair receipt stores the source placement and
measured delta.

**Rationale**: `Attractiveness.get_score(anchor)` and `city_score()` are the same values
used by the live simulation and playtest snapshot. Canonical footprints avoid an
anchor-only error if a future early home occupies more than one cell.

**Alternative rejected**: Reading `AttractivenessProfile.residential` predicts content
intent but does not prove the actual before/after result with falloff and other emitters.
Using Community Beauty would fail before residents exist and is not the city Beauty
resource named by the brief.

## Decision 8: Derive workplace separation from authored negative effects

**Decision**: A tier-one workplace is separated only when it has a rooted route from the
Town Hall and no residential footprint lies within any authored negative residential
impact radius. Impact radii are the union of:

- `AttractivenessProfile.radius` when `residential < 0`; and
- negative `CommunityEffectProfile` effects with `scope == "local"`, evaluated at each
  effect's own radius and Community's Manhattan anchor-distance rule.

For attractiveness, overlap uses the emitter anchor and each residential footprint cell
with Attractiveness' Chebyshev rule. For Community local effects, overlap uses source
anchor to residential anchor with `CommunityConstants.manhattan`, matching the existing
prospective-home/effect path. The projection reports each offending home,
effect/radius source, metric, and distance. It does not undo a legal placement.

**Rationale**: These are the two existing data-driven systems that author local harm to
homes. `RoadNetwork.get_route_from_town_hall(internal_id)` proves rooted access even
after later road demolition.

**Alternative rejected**: A fixed tutorial radius would drift from content. Plain
`road_accessible` can be true on an isolated road component and therefore is not enough.

## Decision 9: Require an identified canonical work assignment

**Decision**: Complete participation only from a Community assignment record with
`purpose == "work"` whose `destination_internal_id` is a qualifying separated
workplace. Store the resident ID, workplace ID, assigned hour, and route evidence in the
receipt. Operation `fulfilled > 0` may support projection, but is not the sole receipt
proof.

**Rationale**: `Community.get_assignment_records()` exposes an actual resident and
destination, while `get_operation_records()` explains open/access/capacity blockers.
Elapsed simulation time alone proves nothing.

**Alternative rejected**: Workplace output or fulfilled capacity does not identify the
participant required by the feature brief.

## Decision 10: Reuse Dashboard compact guidance and EventSystem dialogue

**Decision**: `OpeningTutorial.get_projection()` returns presentation-neutral state,
progress, blocker evidence, Ambrose semantic expression, approved placeholder copy key,
and optional full-dialogue event ID. Dashboard consumes this projection before its
patron projection and sends a resolved model to the existing `CompactGuidanceView`.
Full exchanges remain authored dialogue events and are fired through EventSystem once,
guarded by durable presentation receipts/event counts.

**Rationale**: CompactGuidanceView already implements dismissal, modal/radial/inspection
suppression, portrait resolution, input consumption, and responsive layout. The
Dialogue/EventSystem path already supplies validation, late commit, pending recovery,
and headless resolution. Placeholder copy is explicitly approved, but copy keys keep a
later prose-only replacement out of state and tests.

**Alternative rejected**: A second tutorial bubble or modal would duplicate proven UI
and input behavior. Persisting display text would make saves depend on temporary prose.

## Decision 11: Make completion a durable fact plus an edge notification

**Decision**: On the first qualifying accessible shop, atomically write the shop step
receipt, terminal state, and `tutorial_opening_completed` handoff receipt, then emit one
`GameEvents.tutorial_opening_completed` signal with a detached semantic payload. A
consumer must reconcile the durable receipt on map load and may use the signal only as
an immediate edge notification. Loading an already completed save never re-emits it.

**Rationale**: Receipt-before-signal prevents re-entry and makes duplicate placement or
reconciliation harmless. A durable fact lets Workstream 2 start correctly even when its
plugin initializes later or the game loads after completion.

**Alternative rejected**: Event counts alone are narrative dispatch records, not the
opening quest's ownership state. Signal-only handoff is lost across load and startup
ordering.

## Feasibility resolutions

1. **Historical experiment recovery**: A legacy/prebuilt save without stored causal
   evidence records `baseline_unavailable`, forbids penalty prose, and requires one new
   observable qualifying placement. Post-feature saves resume from immutable receipts.
2. **Already-improved prebuilt neighbourhood**: Current facts alone do not prove a
   subsequent repair. The player is asked for one new nature placement that measurably
   improves the anchored home; no historical claim is synthesized.
3. **Lesson count wording**: The brief's eight narrative phases map to nine semantic
   objective receipts (Hall, roads, nature, first home, adjacent-home observation,
   repair, separated work, participation, shop). Tests assert both explicitly.
4. **Nature versus decoration vocabulary**: `category == "nature"` is the only current
   decorative mechanism. This slice uses “decoration” only as player-facing wording for
   a qualifying nature placement and adds no new category.
