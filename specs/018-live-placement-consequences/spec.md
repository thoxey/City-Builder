# Feature Specification: Live Placement Consequences

**Feature Branch**: `018-live-placement-consequences`

**Created**: 2026-09-06

**Status**: Implemented and verified

**Input**: Provide a non-mutating, location-dependent consequence quote while a building is held, using the same placement gates and simulation evaluators as commit.

## Scope boundary

The build-menu entry remains the authority for intrinsic/authored costs and effects (workstream 4). This feature owns only the consequence of the current anchor, rotation, footprint, overlap, access context, and affected live town state. The placement context joins those two projections without copying authored effect descriptions into the consequence quote.

## User scenarios and testing

### User Story 1 — Compare valid locations (P1)

As a player moving a held building, I can see the signed community and attractiveness changes, people/tiles affected, effect reach, and access result for the current location.

**Independent test**: Move a local-effect building between two anchors around occupied homes and verify that the quote changes, remains detached, and identifies unchanged outcomes explicitly.

**Acceptance scenarios**:

1. A valid location shows signed Opportunity, Livability, Beauty, and Belonging deltas produced by the canonical community effect evaluator.
2. The quote shows affected residents/homes and attractiveness tiles without listing every unaffected entity.
3. Zero deltas are labelled unchanged; participant/assignment results that cannot be known before allocation are labelled uncertain.
4. Authored/base effects stay in the intrinsic projection and are not duplicated as location consequences.

### User Story 2 — Understand invalid and replacement locations (P1)

As a player, I can distinguish blocked placement from a valid replacement and understand the footprint, removed buildings, and canonical rejection/access reason.

**Independent test**: Quote invalid land, occupied road, proper-building replacement, protected Town Hall, and a rotated multi-cell footprint.

**Acceptance scenarios**:

1. Invalid cells show the canonical placement reason and no speculative benefit.
2. Replaceable overlap is quoted only after the ordinary replacement validation path passes and is marked as requiring confirmation.
3. Rotation and multi-cell footprints use the same rotated cells as commit.
4. A replacement quote includes removed building identities and models residents made homeless by the canonical demolition event.

### User Story 3 — Trust preview parity and safety (P1)

As a player, I can trust that inspecting or cancelling a preview does not change the town, and that an exact quote matches the next committed evaluation when no simulation boundary intervenes.

**Independent test**: Snapshot authoritative state and signals before repeated quotes, then commit the same placement and compare exact pre/post aggregate deltas.

**Acceptance scenarios**:

1. Repeated quotes do not mutate cash, demand, map records, registries, residents, assignments, RNG, progression, road revision, attractiveness indexes, or durable events.
2. Exact community and attractiveness deltas match committed before/after values at the same hour and state.
3. Cursor updates occur on anchor/rotation/state invalidation, not every rendered frame.
4. Cancellation clears the consequence panel; load/clear invalidates a held quote and refreshes it from loaded state.

## Edge cases

- Participant-scoped effects and route allocations are reported as uncertain until canonical assignment runs.
- Scheduled effects use the current canonical clock hour and say when currently inactive.
- A road placement reports the rooted placement result, but downstream network reconnection is uncertain because the current road plugin has no hypothetical topology API.
- Pool entries quote their stable held representative; the actual randomly selected variant is revalidated at click time.
- Rapid cursor movement supersedes the earlier detached quote; quotes never enqueue durable work.
- If a simulation plugin is unavailable, its consequence section is omitted and an uncertainty reason is retained.

## Requirements

- **FR-001**: Builder MUST expose one detached placement-consequence quote composed from canonical placement validation and domain quote APIs.
- **FR-002**: Invalid quotes MUST use canonical placement reason codes.
- **FR-003**: Footprint, rotation, overlap, replacement, cash, demand, progression, and rooted-access inputs MUST come from `Builder.evaluate_placement`.
- **FR-004**: Community deltas MUST be calculated through `CommunityEffectEvaluator` against detached before/after source sets.
- **FR-005**: Attractiveness deltas MUST use the same tile scoring helper used by committed recomputation.
- **FR-006**: Quotes MUST identify exact, unchanged, invalid, replacement, and uncertain states.
- **FR-007**: Quotes MUST contain bounded affected-entity summaries and aggregate counts.
- **FR-008**: Quote generation MUST NOT write authoritative or derived state or emit durable gameplay signals.
- **FR-009**: The placement UI MUST keep intrinsic information separate from a labelled “This location” consequence region.
- **FR-010**: The UI MUST update for anchor, rotation, structure selection, placement-affecting state invalidation, load, and clear, and clear on cancellation.
- **FR-011**: The hot path MUST run only when the quote key/state revision changes and remain within a 16 ms representative large-town median budget.
- **FR-012**: Participant allocation, hypothetical downstream road topology, and pool random selection MUST never be presented as exact.

## Success criteria

- **SC-001**: Exact community quality and attractiveness aggregate deltas equal committed before/after values in parity tests.
- **SC-002**: A 100-call no-mutation test observes identical authoritative snapshots and zero durable placement/demolition emissions.
- **SC-003**: Valid, invalid, replacement, unchanged, and uncertain quote fixtures render distinct status text/colour.
- **SC-004**: Rotation/multi-cell/replacement tests use identical footprint and removed-building identities before and after commit.
- **SC-005**: A representative 500-resident/135-source benchmark has a median quote time below 16 ms on the reference machine, with the measured environment recorded.
- **SC-006**: Visual QA at 1280×720 and 1920×1080 shows readable, bounded content without covering the held footprint.
