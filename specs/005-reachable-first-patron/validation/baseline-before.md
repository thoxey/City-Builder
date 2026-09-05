# Baseline Before Milestone 005

Captured 2026-09-05 before progression code or authored threshold changes.

## Verified regression baseline

- Godot 4.6.2 recursive unit suite: 256/256 tests, 1,618 assertions.
- Player UI integration suite: 5/5 tests, 19 assertions.
- Data editor: 56/56 tests and successful TypeScript/Vite build.
- Server source suite: 15 passed, 13 opt-in skipped.

## First unreachable transition

The Howarth Players route first becomes mathematically impossible at
`aristocrat_industrial` arrival:

- Authored fulfilled industrial demand required: 10,000.
- Buildable cells before the first patron donation: 64.
- Industrial chain contribution: Windmill 8 + Lumber Mill 20 + Pipe Factory 35
  = 63 fulfilled demand across three cells.
- Maximum remaining repeatable tier-one industrial contribution: 61 cells × 5
  fulfilled demand = 305.
- Absolute pre-donation upper bound: 63 + 305 = 368.

Because demolition removes fulfilled capacity and the donation is locked behind
this character, no legal sequence can cross 10,000. The unchanged runtime also:

- ignores `arrival_requires_tier`;
- permits request satisfaction from ARRIVED before reveal;
- exposes wants and the Theatre without character/patron gates;
- disables Dialogue/Inbox in Playtest without a semantic resolution action;
- omits character, patron, tier, event, and donation state from its hash; and
- can lose an unresolved arrival across save/load because Inbox is transient.

## Provisional correction selected

`aristocrat_industrial.arrival_threshold` will change from 10,000 to 100. This
matches the two other live characters and remains a reachability correction,
not final pacing balance. Milestone 006 owns later tuning.
