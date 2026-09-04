# Quickstart: Community Insight UI Acceptance

## Canonical acceptance path

1. Start `community_park_and_noise` with seed `22002`.
2. Open the Community tab from the HUD.
3. Confirm population/capacity and all four quality values match the same-tick
   Community snapshot.
4. Select a resident near the pond and night venue.
5. Confirm positive recreation/belonging and negative noise appear as separate
   signed effect rows with source and reason.
6. Inspect the night venue before, during, and at the exclusive end hour; verify
   schedule state and actual participants.
7. Run `community_personality_contrast` and compare the two residents’ activity
   choice or applied amount for the same place.
8. Run matched and nuisance `community_migration_week` layouts for 168 exact
   hours; verify equal capacity, bounded population, and higher matched-town
   population/composition.
9. Run `community_retention_failure`; verify the resident remains visible with
   progress at hour 23 and departs at hour 24.

## Layout and input checks

- Test 1280×720 and a wider desktop viewport.
- Traverse HUD button, Community/Patrons tabs, section controls, resident rows,
  filters, detail actions, programme choices, and back/close using keyboard only.
- Confirm visible focus, automatic scroll-to-focus, long-text wrapping, and no
  overlap with Palette, Inbox, DayNight, or Dialogue.
- Verify all positive/negative/trend meanings remain understandable with color
  removed.

## Performance check

Project a 500-resident snapshot, update one exact hour, scroll the complete list,
and record projection/update duration and maximum live row-Control count. The
projection target is under 16.7 ms and the simulation’s existing 168-hour
performance budget must remain unchanged.

## Regression commands

Run recursive GUT, the TypeScript contract suite, and the opt-in live AI outcome
suite. Record exact versions, totals, screenshots, failures, and scenario seeds
under `specs/003-community-ui/validation/` during implementation.
