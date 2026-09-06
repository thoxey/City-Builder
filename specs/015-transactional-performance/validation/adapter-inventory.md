# Compatibility adapter inventory

Captured 2026-09-06. Adapters were retained whenever a consumer remains.

| Adapter | Remaining consumers | Decision |
|---|---|---|
| `DayNight.hour_changed` | fallback hooks in Economy, Demand, Community, People, CityStats | Retain; inactive when `SimulationTransaction` is injected. |
| `CityStats.stats_ticked` | HUD, Economy compatibility, Satisfaction | Retain; emitted post-commit. |
| cash/demand GameEvents | HUD, Palette, Dashboard, Builder preview, tutorial/progression | Retain; emitted post-commit or canonical command commit. |
| Community population/quality/resident events | HUD, Dashboard, Builder preview, People, tutorial | Retain; publication is deferred until transaction commit. |
| `authoritative_change_committed` | PresentationScheduler, Community, RoadNetwork, Attractiveness | Retain; this is the canonical change-set boundary, not a legacy mutation path. |

No zero-consumer adapter was found, so none was removed. Presenter consumers are migrating through named projections while these compatibility publications remain safe and parity-covered.
