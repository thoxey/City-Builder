# Data Model: Community Insight UI

All structures below are read-only presentation projections unless explicitly
marked as UI preference state. Simulation records remain owned by Community.

## CommunityUIModel

| Field | Type | Meaning |
|---|---|---|
| snapshot_key | String | Stable key/hash for deduplicating refreshes |
| hour | int | Current canonical simulation hour |
| summary | CommunityHUDModel | Always-visible values |
| overview | CommunityOverviewModel | Aggregate panel values |
| residents | Array[ResidentUIModel] | Stable resident-id ordered, bounded records |
| places | Dictionary | Building anchor key to PlaceImpactUIModel |
| neighbourhoods | Dictionary | Home anchor key to NeighbourhoodUIModel |
| config | CommunityDisplayConfig | Canonical thresholds and grace values |

## CommunityHUDModel

- `population: int`
- `capacity: int`
- `composite_happiness: float`
- `recent_population_delta: int` (presentation-only, coalesced)
- `has_warning: bool`

## CommunityOverviewModel

- `occupied_homes`, `free_homes`, `capacity`, `occupancy_percent`
- `homeless_count`, `at_risk_count`
- `qualities`: four `QualityUIModel` records
- `migration`: arrivals, departures, rejections, net, last day, latest event
- `composition`: exact cohort/outlook counts, proportions, dominant-lens counts
- `positive_drivers`, `negative_drivers`: bounded `EffectSummaryUIModel` arrays
- `warnings`: ordered `CommunityWarningUIModel` array
- `empty_state`: optional player-facing title/body/action hint

## QualityUIModel

- `quality_id`: opportunity/liveability/beauty/belonging
- `label`, `icon_key`
- `current: float`
- `target: float?` (resident/neighbourhood contexts)
- `delta: float` (presentation-only previous-authoritative-update delta)
- `direction`: rising/stable/falling/unknown
- `status`: good/watch/poor/empty, using presentation thresholds distinct from
  simulation migration/departure logic

## ResidentUIModel

- `resident_id: int` and `label: String`
- `cohort_id` (internal projection key) and `outlook_label`
- `dominant_lens`, `dominant_lens_label`
- `home_anchor: Coordinate?`, `home_label`, `is_homeless`
- `activity`: building, anchor, programme, or null
- `composite_happiness`
- `qualities`: four `QualityUIModel` records
- `lens_weights_by_quality`: normalized Identity/Freedom/Care values
- `sensitivities`: noise/pollution/crowding/travel display records
- `retention`: ResidentRetentionUIModel
- `positive_effects`, `negative_effects`: `AppliedEffectUIModel` arrays

## ResidentRetentionUIModel

- `state`: stable/at_risk/homeless/rehoming
- `below_threshold_hours`, `departure_grace_hours`
- `homeless_hours`, `relocation_grace_hours`
- `progress`, `hours_remaining`
- `message`

The projector receives configured values from Community. UI Controls never
hard-code 24 hours or happiness 30.

## AppliedEffectUIModel

- canonical effect identity and source building/anchor
- source display name
- quality and manifestation IDs plus player-facing labels
- scope and scope label
- base amount and applied signed amount
- exposure, preference, sensitivity, and stacking multipliers (developer detail)
- reason
- schedule label and `active_now`
- participant truth for the selected resident

Positive and negative effects are never netted into one row.

## PlaceImpactUIModel

- building identity, display name, anchor
- current programme and available programme summaries
- active state and active schedule
- local radii and participant capacities by effect
- housed, participating, and affected resident IDs
- positive and negative aggregate effects
- linked neighbourhood anchor keys

## NeighbourhoodUIModel

- canonical home anchor and display label
- resident IDs/count
- four current averages
- outlook composition and dominant lenses
- strongest positive/negative local drivers
- affecting place anchors

This is derived state and is never persisted.

## CommunityUIState (persisted presentation preference)

- `sidebar_collapsed: bool` (reuse/migrate existing Dashboard value)
- `selected_top_tab: String` (`community` or `patrons`)
- `community_section: String` (`overview`, `residents`, `places`)
- `overlay_mode: String` (`off`, a quality, or an outlook lens)

Transient resident/building selection, filters, search text, previous-snapshot
deltas, and notifications are not persisted.

## Stable ordering

- Residents: resident ID ascending.
- Neighbourhoods/places: anchor x, then z, then building ID.
- Effects: quality order, positive before negative within section, absolute
  applied amount descending, source display name, effect ID.
- Warnings: homeless, departure risk, no capacity, rejection pressure, then
  informational notices.

