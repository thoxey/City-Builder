# Data Model: First Tutorial Mini-Quest

## Persisted OpeningTutorialState

`DataMap.opening_tutorial_state: Dictionary` is the single save field. Missing/empty
means a legacy or fresh save and normalizes to the defaults below.

```text
OpeningTutorialState {
  schema_version: 1
  tutorial_id: "opening_tutorial"
  current_step_id: OpeningStepId
  completed_receipts: Dictionary<String, TutorialReceipt>
  presentation_receipts: Dictionary<String, bool>
  experiment: HomeExperiment
  completion_handoff: CompletionHandoff
}
```

All coordinates are persisted as `{ "x": int, "z": int }`. All arrays that represent
sets are normalized to sorted unique values. Unknown future fields are retained by
migration where safe; invalid known fields fall back to a conservative empty value.

### OpeningStepId

Stable ordered values:

1. `place_town_hall`
2. `connect_rooted_roads`
3. `establish_nature`
4. `place_first_home`
5. `observe_adjacent_home`
6. `improve_home`
7. `establish_workplace`
8. `confirm_work_participation`
9. `place_first_shop`
10. `complete`

Ordering is defined in code, not by lexical comparison. `current_step_id` may only stay
the same or move right. A missing/unknown ID normalizes to the earliest step not covered
by a valid receipt.

### TutorialReceipt

```text
TutorialReceipt {
  receipt_id: String
  step_id: OpeningStepId
  evidence_kind: String
  evidence: Dictionary       # detached, JSON-safe canonical evidence
}
```

The dictionary key equals `receipt_id`; writing the same receipt again is a no-op.
Receipts have no wall-clock timestamp and do not affect deterministic replay. Relevant
semantic simulation time, such as Community `assigned_hour`, may be included as evidence.

Expected receipt IDs:

- `opening.town_hall_placed`
- `opening.rooted_roads_connected`
- `opening.nature_established`
- `opening.first_home_placed`
- `opening.adjacent_home_observed`
- `opening.home_improved`
- `opening.workplace_established`
- `opening.work_participation_confirmed`
- `opening.first_shop_placed`

## HomeExperiment

Durable causal evidence used by the adjacency and repair lessons:

```text
HomeExperiment {
  anchor_home: BuildingEvidence | null
  baseline: ScoreEvidence | null
  adjacent_home: BuildingEvidence | null
  adjacency_result: "pending" | "penalty_observed" | "no_penalty" |
                    "baseline_unavailable"
  after_adjacency: ScoreEvidence | null
  repair_source: BuildingEvidence | null
  after_repair: ScoreEvidence | null
}
```

`penalty_observed` means at least one of the anchored home score or city score decreased
and records both deltas. `no_penalty` means a real before/after pair was captured but no
decrease occurred. `baseline_unavailable` is a migration diagnostic only and can never
select copy that claims a loss.

`anchor_home` and `baseline` are immutable after `opening.first_home_placed` is written.
`after_adjacency` becomes immutable with `opening.adjacent_home_observed`.
`after_repair` must be from a later qualifying placement and must have
`home_tile_score > after_adjacency.home_tile_score`.

## BuildingEvidence

```text
BuildingEvidence {
  internal_id: int
  building_id: String
  category: String
  pool_id: String
  anchor: Coordinate
  footprint: Array<Coordinate>
}
```

`internal_id` identifies a placement during the current saved map. `building_id`,
anchor, and footprint remain the stable explanatory fields. If an internal ID is absent
after migration, identity may be re-resolved by exact anchor/building ID but never by UI
label.

## ScoreEvidence

```text
ScoreEvidence {
  home_tile_score: int
  city_score: int
  source_building_id: String
  source_anchor: Coordinate | null
  home_delta: int | null
  city_delta: int | null
}
```

The baseline has null deltas/source. Adjacency and repair evidence name the committed
placement that caused the observation.

## Derived TutorialEvidenceSnapshot

This record is rebuilt and detached on each reconciliation. It is not persisted.

```text
TutorialEvidenceSnapshot {
  rooted_town_rules: bool
  town_hall: BuildingEvidence | null
  rooted_component_ids: Array<String>
  rooted_road_cells: Array<Coordinate>
  rooted_road_count: int
  nature_building_ids: Array<String>
  city_attractiveness: int
  demand: Dictionary<String, DemandQuote>
  early_homes: Array<BuildingEvidence>
  early_workplaces: Array<WorkplaceEvidence>
  early_shops: Array<ShopEvidence>
  work_assignments: Array<AssignmentEvidence>
  road_revision: int
  diagnostics: Array<Diagnostic>
}
```

Collections sort by anchor x/z, then building ID, then internal ID. This stable order
selects experiment anchors and qualifying candidates deterministically.

### DemandQuote

Projection of `Demand.quote_placement()` for a deterministic tier-one candidate:

```text
DemandQuote {
  bucket_id: String
  affordable: bool
  have: float
  cost: float
  threshold: float
  reason: "" | "below_threshold" | "insufficient"
  candidate_building_id: String
}
```

### WorkplaceEvidence

Extends `BuildingEvidence` with:

- `rooted_accessible: bool`
- `route_reason: String`
- `rooted_route_distance: int`
- `open_now: bool`
- `operating: bool`
- `fulfilled: int`
- `operation_reasons: Array<String>`
- `negative_residential_impacts: Array<ResidentialImpactEvidence>`
- `separated: bool` (rooted accessible and impact list empty)

`ResidentialImpactEvidence` names the home, source profile/effect ID, radius, distance
metric (`attractiveness_chebyshev` or `community_manhattan`), measured distance, and
authored negative amount.

### ShopEvidence

Extends `BuildingEvidence` with rooted access/route evidence plus a detached list of
actual authored positive and negative Attractiveness/Community effects. This list is
explanatory only; the shop receipt gate is committed tier-one commercial identity plus
rooted access.

### AssignmentEvidence

Projection of the canonical Community assignment:

```text
AssignmentEvidence {
  resident_id: int
  purpose: "work"
  destination_internal_id: int
  building_id: String
  assigned_hour: int
  route_distance: int
  component_id: String
}
```

## TutorialProjection

Transient, presentation-neutral output described fully in
`contracts/tutorial-projection.md`. It contains no mutable gameplay object and is
excluded from saves and deterministic simulation hashes. A normalized tutorial summary
is separately included in playtest snapshots so visible and headless acceptance tests
can compare semantic state.

## CompletionHandoff

```text
CompletionHandoff {
  receipt_id: "tutorial_opening_completed"
  applied: bool
  shop: BuildingEvidence | null
}
```

`applied` is written before the corresponding signal is emitted. The handoff contains
no Workstream 2 quest state or dialogue.

## Presentation receipts and authored content

`presentation_receipts` is a set-like dictionary keyed by stable beat ID (`B01` through
`B18`). It means the beat was dispatched to its owning presentation path, not that a
compact bubble remains visible. Compact dismissal stays transient in
`CompactGuidanceView`; pending full dialogue recovery remains owned by
`DataMap.pending_dialogue_event_ids` and EventSystem.

Beat content stores approved copy keys, never prose, in tutorial state. During this
implementation slice those keys resolve only to the user-approved literal labelled
placeholder form. Later final prose replacement does not migrate saves or receipts.
