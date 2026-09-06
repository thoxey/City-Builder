# Contracts: Opening Playtest Polish

## Location presentation contract

`PlacementConsequencesPanel.presentation_rows(quote)` remains a pure function over the
existing placement-consequence quote.

It returns rows only when at least one of these is true:

- a Community quality has a semantic non-zero delta;
- attractiveness has a semantic non-zero city delta or a non-zero affected-tile count
  attached to that change;
- affected resident/home/neighbour evidence is non-zero and supports a shown change;
- placement is invalid or a replacement;
- required access fails; or
- an uncertainty can materially change the committed outcome.

A routine valid-access confirmation, zero metric, zero affected summary, or empty reach
does not create a row. `show_quote` hides the panel when the returned array is empty.

## Opening tutorial contract

For a tutorial without `opening.rooted_roads_connected`:

```text
road_complete = RoadNetwork.rooted_road_count >= 10
progress = { current: rooted_road_count, required: 10, unit: "road_cells" }
```

Existing valid receipts remain complete. Disconnected road cells are absent from the
canonical count.

For the adjacency experiment, a qualifying new residential placement may pair with any
eligible existing early home at footprint distance `<= 1`. Candidate pairs are sorted
stably before one is chosen and both exact building records are persisted. No causal
claim is made without before/after evidence.

The existing first rooted tier-one shop writes `opening.first_shop_placed`, completes the
tutorial, and emits `tutorial_opening_completed` exactly once. There is no subsequent
tutorial step for fulfilled commercial demand.

## Dashboard direction priority contract

Primary direction is chosen in this order:

1. active OpeningTutorial projection;
2. pending/active established first quest after tutorial completion;
3. arrived character conversation;
4. revealed character building request;
5. patron landmark request;
6. unarrived-character fulfilled-demand progress, including the 100 Shops target;
7. generic fallback.

Dashboard reads state from the owning plugin projections/receipts. It does not duplicate
road, shop, quest, or character gates.

## Unique threshold contract

UniqueRegistry remains authoritative and evaluates:

```text
building_postwar_terrace: Demand.total(residential) >= 40
building_pub: Demand.total(commercial) >= 15
```

Current unserved and currently fulfilled balances do not substitute for the lifetime
totals. Existing prerequisite, character, patron, unique-placement, and removal behavior
is unchanged.

## Palette exclusion contract

Building JSON may declare `palette_excluded: true`. BuildingCatalog still loads and
indexes that building and includes the flag in its summary. Palette filters the building
before constructing entries and pool member arrays. Consequently, preview and commit can
never select the excluded item, while ID-based save loading remains valid.

For the `grass` pool the player-facing member IDs are exactly:

```text
grass_trees
grass_trees_tall
```
