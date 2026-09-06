# Research: Opening Playtest Polish

## Decision 1: Filter presentation, not consequence calculation

The current location panel receives a canonical detached quote and renders up to ten
rows, including all four qualities at zero, routine valid access, zero affected counts,
and unchanged town appeal. The polish belongs in
`PlacementConsequencesPanel.presentation_rows`; Builder, Community, and Attractiveness
do not need to change.

**Why**: The playtest problem is information density and occupied screen area, not quote
correctness. Presentation filtering preserves preview/commit parity and the existing
performance envelope.

## Decision 2: Ten means ten Town Hall-rooted road cells

The existing tutorial already uses `RoadNetwork`'s rooted component count and ignores
disconnected roads. Only its threshold and progress total change from 4 to 10.

**Why**: This encourages a useful separation from the Town Hall without prescribing an
exact shape or creating a second distance/layout rule.

## Decision 3: Adjacent means any observable eligible pair

The lesson should select a deterministic pair from eligible tier-one homes when a new
placement creates adjacency. The exact pair is persisted with its score evidence.
Pre-built pairs without causal baseline remain diagnostic-only.

**Why**: The user's lesson is adjacency, not the historical identity of the first home.
Stable pair selection keeps save/load and deterministic replay reproducible while
retaining honest before/after claims.

## Decision 4: Tutorial/quest direction outranks patron grind

The `0/100 fulfilled` line comes from Dashboard's fallback for an unarrived character,
not from OpeningTutorial. Dashboard should consume the opening projection/handoff phase
and rank it ahead of the generic character ladder.

**Why**: The first rooted shop already completes the tutorial and emits an established
first-quest handoff. Changing direction priority fixes the misleading presentation
without adding or removing simulation milestones.

## Decision 5: Thresholds remain UniqueProfile data

Postwar Terrace changes from 25 to 40 lifetime Homes demand. Pub changes from 10 to 15
lifetime Shops demand. UniqueRegistry already evaluates these profiles against total
demand and StatusBar already projects positive lifetime targets.

**Why**: No code constant or new progression system is required. The same values drive
availability, explanation, automation, and UI.

## Decision 6: Palette exclusion preserves the plain grass ID

Add an explicit authored `palette_excluded` boolean to the plain grass building, carry it
through BuildingCatalog's summary/manifest path, and skip it only when Palette builds
entries.

**Why**: Deleting the JSON would remove a stable building ID and could break old maps.
Filtering only at Palette keeps save/catalog compatibility and gives the authoring intent
a reusable, testable name without a building-ID hard-code.

## Alternatives rejected

- Moving consequence details into the bottom bar: intentionally deferred with the full
  bottom-bar redesign.
- Adding world-space capsules: intentionally deferred as its own medium feature.
- Counting any ten roads anywhere: fails the rooted-town teaching goal.
- Measuring distance from the Town Hall in addition to road count: prescribes layouts
  beyond the request and duplicates spatial meaning already conveyed by rooted roads.
- Deleting `data/buildings/nature/grass.json`: risks stable-ID/save compatibility.
- Hard-coding `building_id == "grass"` in Palette: violates the data-driven authoring
  principle and creates an unexplained special case.
