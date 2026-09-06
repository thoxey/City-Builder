# Contract: Opening Tutorial State and Reconciliation

## Ownership

- `OpeningTutorial` owns tutorial state, receipts, experiment evidence,
  reconciliation, and the detached tutorial projection.
- Builder remains the only placement/demolition command authority.
- BuildingCatalog owns stable building/profile/pool semantics.
- RoadNetwork owns Town Hall internal identity, components, access, and routes;
  BuildingCatalog confirms the stable `building_town_hall` content ID. Town Hall has no
  `UniqueProfile`, so UniqueRegistry is not used as its placement authority.
- Attractiveness owns tile and city Beauty scores.
- Demand owns affordability and demand-bank values.
- Community owns residents, work assignment, and operation truth.
- EventSystem owns authored dialogue dispatch, pending IDs, effects, and counts.
- Dashboard and Dialogue own presentation only.

OpeningTutorial must not mutate any of the observed gameplay systems.

## Public interface

Conceptual minimal API:

```text
reconcile(reason: String = "explicit") -> ReconcileOutcome
get_state() -> Dictionary
get_evidence_snapshot() -> Dictionary
get_projection() -> Dictionary
is_complete() -> bool
```

Every returned dictionary is detached. Test fixtures may inject dependencies and call
`reconcile`; no test-only gameplay mutation API is added.

## Invalidations

The authority observes:

- boot and `map_loaded`;
- `structure_placed` and `structure_demolished`;
- `unique_placed`/`unique_removed` where useful for immediate identity evidence;
- demand total/fulfilled/unserved changes;
- tile/city attractiveness changes;
- Community population/quality summary changes; and
- road revisions caused by placement, demolition, and map load.

Repeated invalidations before the deferred pass coalesce. Ordered committed placement
observations are retained separately so experiment causality is not coalesced away.

## Reconciliation algorithm

1. Normalize `DataMap.opening_tutorial_state` to the current schema.
2. Build one stable detached evidence snapshot from canonical sources.
3. Replay unconsumed ordered placement observations into experiment evidence.
4. Starting at the earliest step not covered by a valid receipt, evaluate its gate.
5. If satisfied, write its immutable receipt and continue in the same pass.
6. Stop at the first unsatisfied gate, or write terminal completion/handoff.
7. Publish one projection revision if semantic state/progress/blocker changed.

Receipts are authoritative for non-regression. Current facts may satisfy a missing
receipt, but current facts never invalidate an existing receipt.

## Gate table

| Step | Receipt gate |
|---|---|
| `place_town_hall` | RoadNetwork reports a Town Hall internal ID and its registry entry resolves through BuildingCatalog to `building_town_hall`. |
| `connect_rooted_roads` | Union of RoadNetwork components returned by `get_rooted_component_ids()` contains at least four unique road cells. |
| `establish_nature` | At least two distinct placed catalog IDs with top-level nature category and `Attractiveness.city_score() > 0`. |
| `place_first_home` | A committed tier-one residential pool member exists; deterministic first evidence becomes the experiment anchor/baseline. |
| `observe_adjacent_home` | A later committed tier-one residential footprint is within Chebyshev distance one of the anchor footprint and actual post-placement scores were captured; migration ambiguity follows the rule below. |
| `improve_home` | After adjacency receipt, a later nature/decorative placement raises the anchored home's canonical tile score above the stored post-adjacency score. |
| `establish_workplace` | A tier-one industrial placement has a rooted Town Hall route and zero authored negative-residential-radius overlaps. |
| `confirm_work_participation` | Community exposes a `purpose == "work"` assignment to a receipted/qualifying separated workplace. |
| `place_first_shop` | A tier-one commercial placement has a rooted Town Hall route. |
| `complete` | All prior receipts exist; terminal handoff receipt is applied. |

## Adjacency and radius geometry

Minimum footprint distance is:

```text
min(max(abs(a.x - b.x), abs(a.z - b.z)))
for every cell a in footprint A and b in footprint B
```

Adjacent means distance `<= 1` for distinct buildings, matching current Chebyshev/Moore
attractiveness semantics. Negative residential-impact overlap preserves each owning
system's exact geometry:

- Attractiveness: source/emitter anchor to residential footprint cells by Chebyshev
  distance, compared with `AttractivenessProfile.radius`.
- Community local effects: source anchor to residential anchor by
  `CommunityConstants.manhattan`, compared with that effect's radius.

The evidence always identifies its metric; the tutorial does not collapse the two
systems into a new shared radius rule.

## Experiment recovery rule

- A valid stored first-home baseline is never replaced after load.
- A valid stored adjacency/post-score receipt is never recalculated after demolition or
  tuning changes.
- If two adjacent homes predate the feature and no baseline exists, reconciliation may
  record `baseline_unavailable` evidence but must not claim an observed penalty.
- `baseline_unavailable` is not sufficient to complete the causal observation. The
  projection asks for one new qualifying observable placement and never substitutes
  authored intent for measured history.
- The same rule applies to a pre-improved neighbourhood with no stored post-adjacency
  baseline: current attractiveness cannot prove a subsequent repair, so one new nature
  placement with a measured improvement is required.

## Stable diagnostics

At minimum:

- `tutorial_state_malformed`
- `tutorial_unknown_step`
- `tutorial_catalog_identity_missing`
- `tutorial_root_component_missing`
- `tutorial_home_baseline_unavailable`
- `tutorial_adjacency_penalty_not_observed`
- `tutorial_repair_baseline_unavailable`
- `tutorial_negative_radius_contract_missing`
- `tutorial_work_assignment_missing`
- `tutorial_dialogue_event_missing`

Diagnostics explain blockers/content drift and do not mutate simulation state.

## Determinism and idempotency

- Registry and evidence collections use explicit stable sorting.
- One receipt ID may be written once.
- Duplicate signals yield the same state and no additional presentation/handoff event.
- Demolition after completion cannot move `current_step_id` backward.
- A single reconciliation pass may add multiple receipts when prebuilt facts satisfy
  consecutive steps.
- Visible and headless modes use the same state/reconciliation code.
