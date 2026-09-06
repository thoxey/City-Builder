# Implementation Plan: Live Placement Consequences

## Technical context

**Engine**: Godot 4.x / GDScript

**Authority**: `scripts/builder.gd` validates and commits placement; `CommunityEffectEvaluator` evaluates resident effects; `Attractiveness` owns tile scoring; `RoadNetwork` owns rooted/access evidence.

**UI**: `PlayerUI` forwards placement context to a dedicated consequence panel. The existing palette/build-menu model remains the intrinsic projection.

**Testing**: GUT unit/integration tests, headless import, a bounded micro-benchmark, and normal-renderer screenshot review where feasible.

## Constitution check

- One authority per rule: pass. Domain plugins expose read-only quotes; Builder composes them.
- Preview/commit parity: pass by sharing placement validation, effect evaluation, and tile scoring functions.
- No speculative mutation: pass. Before/after inputs and outputs are detached.
- Plugin independence: pass. Builder calls optional quote methods; Community and Attractiveness do not reference the UI or one another.
- Workstream boundary: pass. Intrinsic authored details remain outside this feature.

## Design

### 1. Canonical placement envelope

Add `Builder.evaluate_placement_consequences(...)`. It first calls `evaluate_placement`. If overlap represents a permitted replacement it repeats the same evaluation with `replace=true`, preserving the confirmation flag. No domain consequence is evaluated for a rejected envelope.

### 2. Community before/after quote

Refactor Community source-record construction so normal hourly evaluation and a hypothetical candidate share the same builder. Produce detached before/after source arrays, remove replaced source IDs, add the candidate, and evaluate residents with `CommunityEffectEvaluator.evaluate`. Only residents with a changed aggregate or removed home are retained in the bounded presentation list. Participant effects and assignment-dependent operation remain explicit uncertainties.

### 3. Attractiveness before/after quote

Extract the existing tile calculation into a helper accepting emitter and receiver indexes. Normal recompute and hypothetical placement call that helper. The quote copies emitters/categories, applies removals/candidate footprint, and returns aggregate and bounded changed-tile evidence.

### 4. Presentation and invalidation

Add a dedicated `PlacementConsequencesPanel` attached beside the bottom dock. It receives only the `location_consequences` projection and renders status, access/replacement notes, four signed qualities, affected counts, Beauty/attractiveness, and uncertainties. Builder emits on cell/rotation/selection and uses a lightweight revision increment on placement, demolition, demand/cash/community/attractiveness updates, map load, and clear.

### 5. Verification

Add pure formatter/UI tests, Builder envelope/no-mutation/rotation/replacement tests, Community and Attractiveness parity tests, and a benchmark. Run focused suites, broader affected suites, headless import, and rendered capture if the environment supports it.

## Files

```text
scripts/builder.gd
plugins/community/community_plugin.gd
plugins/attractiveness/attractiveness_plugin.gd
plugins/player_ui/player_ui_plugin.gd
plugins/player_ui/tool_dock.gd
plugins/player_ui/placement_consequences_panel.gd
test/unit/placement_consequences/
test/integration/placement_consequences/
specs/018-live-placement-consequences/
```

## Risks and mitigations

- Full resident/source evaluation could exceed an interaction frame. Measure the quote boundary and retain only changed presentation rows; emission is event-driven rather than per-frame.
- Hypothetical network allocation could create a second road authority. Report it as uncertain until RoadNetwork gains a canonical hypothetical-topology quote.
- Concurrent workstream 4 may modify the dock. Keep this feature in a dedicated panel and pass it a separate nested projection.
