# Hourly listener inventory

Captured 2026-09-06 after the transactional migration.

The normal runtime has one authoritative hourly entry point: `DayNight` calls `SimulationTransaction.run_hour`. Economy, Demand, Community, People, CityStats, and Satisfaction register contributors/reducers and publish compatibility signals only after commit.

Five direct `hour_changed` connections remain in Economy, Demand, Community, People, and CityStats. Each is guarded by the absence of `SimulationTransaction`; they are cold compatibility fallbacks and cannot mutate gameplay in the normal 34-plugin graph. Satisfaction observes the post-commit `stats_ticked` adapter. No live normal-runtime gameplay mutation remains driven by `hour_changed`.

Verification:

- `test/integration/simulation/test_hourly_compatibility.gd`
- `test/integration/simulation/test_hourly_transaction_determinism.gd`
- `test/integration/player_ui/test_status_bar_committed_hour.gd`
- Full recursive GUT suite: 736/736 tests passed.
