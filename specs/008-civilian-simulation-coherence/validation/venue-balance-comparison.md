# Venue Balance Comparison

Date: 2026-09-06

## Authored delta

The four newly participating venue families use an intentionally small `0.5`
per-participant quality amount. This is below the established Theatre programme
amounts (`1.0`–`4.0`) and does not alter cash cost, productive capacity, demand
fulfilment, migration thresholds, or economy code.

| Venue | Before | After | Maximum participants |
|---|---|---|---:|
| Pub | no Community effect | +0.5 belonging while visiting | 30 |
| Restaurant | no Community effect | +0.5 liveability while visiting | 40 |
| Private Members' Club | no Community effect | +0.5 belonging while visiting | 25 |
| Crazy Golf | no participant profile | +0.5 beauty while visiting | 20 |

Town Hall retains its existing +2 local belonging effect. Pirate Radio remains
non-attendance. Theatre values are unchanged; only missing schedules were made
explicit so participation is bounded to plays (18–22), rock nights (20–02), and
community use (10–18).

## Automated trace evidence

- Connected allocation filled no more than authored capacity; the same source with
  connectivity disabled assigned zero residents.
- At 17:00, a connected resident selected the Pub as the exact Community activity
  destination. A Theatre programme change in the same hour incremented assignment
  revision and recomputed intents.
- The complete data-editor suite passed 76/76 tests and its production build passed.

## First-town regression

`scripts/run_first_town_loop.gd` completed with `success=true` and zero failures.
The resulting demand, economy, operation, and Community projections retained the
exact pre-feature hashes:

| Scenario | Before | After | Delta |
|---|---|---|---|
| Roadless | `12ab031246ca61174751ed7d1310fa1d41df5b7edf4258806550b56aff44f024` | same | none |
| Connected | `432ba1cf436cb67a3af8c6eba0458bb655720a3ddbb9d9c62b8f5f930bd0b0b3` | same | none |
| Disconnected | `5a8627adb672d001a59a126cfef82a7ac1a2c2b2596f3141982d6b80db827787` | same | none |

No further effect-value tuning was required. The new venue effects apply only to
residents actually allocated to those scheduled activities, so the established
first-town demand and economy trace remains unchanged.
