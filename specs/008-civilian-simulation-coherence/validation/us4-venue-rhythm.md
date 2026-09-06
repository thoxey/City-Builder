# US4 Existing Venue Rhythm Checkpoint

Date: 2026-09-06

- Authored participation tests: **13/13 passed**.
- Community connected/disconnected allocation test: **1/1 passed, 2 assertions**.
- Existing-venue integration test: **1/1 passed, 4 assertions**.
- Full data-editor suite: **76/76 passed across 7 files**.
- Data-editor TypeScript/Vite production build: **passed** (319 modules).

The participant validator requires a stable snake-case effect ID, explicit positive
capacity, valid scope, non-empty reason/stacking group, and a finite non-equal
schedule in the inclusive 0–24 range. Overnight ranges such as 18–02 are accepted.
Explicit `local_only`, `productive`, and `cosmetic` roles cannot declare participant
effects.

The only build warning was Vite's pre-existing advisory about large chunks; it did
not fail compilation or tests.
