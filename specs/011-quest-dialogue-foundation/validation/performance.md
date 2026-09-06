# Dialogue Performance Evidence

Validated on 2026-09-06 using the deterministic 200-beat fixture.

- All 200 transcript rows remained append-only.
- Prior row instance identities and text remained unchanged during later reveal updates.
- Worst observed reveal-prefix update across the validation runs: **70 microseconds**.
- Final focused run measurement: 66 microseconds.

The measurement is emitted by
`test/unit/dialogue/test_dialogue_performance.gd` as
`DIALOGUE_PERFORMANCE beats=200 ... prior_row_identity_unchanged=true`.
