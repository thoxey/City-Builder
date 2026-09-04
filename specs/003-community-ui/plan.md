# Implementation Plan: Community Insight UI

**Branch**: `003-community-ui` *(planning identifier; no branch created)* | **Date**: 2026-09-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-community-ui/spec.md`

## Summary

Turn the existing Community simulation into a clear player decision loop. Add a
compact population/happiness HUD, refactor the right sidebar into Community and
Patrons tabs, provide overview/resident/place/neighbourhood views, expose
canonical migration and retention context, and support authored programme
selection. Presentation is driven by an immutable, deterministic view model
projected from Community state and BuildingCatalog content; no UI component
reimplements simulation formulas.

The visual hierarchy is deliberately progressive: answer “how is the town?” in
the HUD, “what needs attention?” in the overview, and “why exactly?” in resident
or place detail. Signed effects, labels, icons, and text always supplement color.

## Technical Context

**Language/Version**: GDScript, Godot 4.6.x

**Primary Dependencies**: Existing plugin/event architecture, Community,
BuildingCatalog, Residential, DayNight, Dashboard, HUD, Builder selection/input,
`DataMap`, GUT 9.3.0, development-only live Playtest bridge

**Storage**: Existing simulation fields remain authoritative. Add only
backward-compatible presentation preferences to `DataMap`; do not persist
derived aggregates or trends.

**Testing**: Pure GUT view-model/formatting units, Godot UI scene tests, plugin
integration tests, canonical scenario screenshots, keyboard/layout checks, and
the existing live AI outcome suite

**Target Platform**: Godot 4.6.x desktop; minimum supported layout 1280×720

**Project Type**: Plugin-based Godot desktop game

**Performance Goals**: Event-to-visible-update within one rendered frame;
aggregate projection under 16.7 ms at 500 residents; bounded/paged resident
rows; zero per-frame full-list reconstruction

**Constraints**: One gameplay truth; no hard-coded balance thresholds; no new
faction/district state; no UI overlap with HUD, palette, inbox, dialogue,
day/night controls, or Patron dashboard; narrative-independent; accessible
without color and by keyboard/gamepad

**Scale/Scope**: Four qualities, three outlook lenses, four effect scopes, up to
500 visible resident records, current building catalog, home-anchor derived
neighbourhoods, two right-sidebar top-level tabs

## Constitution Check

*GATE: Passed before design and re-checked against the design below.*

| Principle | Plan evidence | Gate |
|---|---|---|
| One Gameplay Truth | Views consume Community projections; programme changes call `Community.set_programme`; no UI calculation mutates simulation. | PASS |
| Deterministic Simulation | View rows use canonical resident/source ordering and stable tie-breaks; trends are explicitly presentation-only. | PASS |
| Observable State | Resident and place details retain signed AppliedEffect provenance and configured retention context. | PASS |
| Data-Driven / Narrative-Separate | Names, effect copy, programmes, schedules, thresholds, and cohorts come from existing authored data with non-narrative fallbacks. | PASS |
| Small Interfaces / Layered Verification | One read-only Community presentation projection and one canonical programme intent are sufficient; pure, UI, integration, and live tests are planned. | PASS |
| Project Constraints | Godot 4.6.x and plugin/event architecture are preserved; no remote or release playtest dependency is introduced. | PASS |

Post-design check: the right-sidebar shell changes ownership boundaries but does
not introduce a second simulation or a cross-plugin write path. No exception is
recorded in Complexity Tracking.

## Project Structure

### Documentation

```text
specs/003-community-ui/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── community-view-model.md
```

### Planned source changes

```text
plugins/community/
├── community_plugin.gd               # canonical read APIs + programme command
├── community_inspector.gd            # pure snapshot -> display projection
├── community_panel.gd                # overview/resident/place navigation
└── community_map_overlay.gd           # opt-in quality/outlook map overlay

plugins/dashboard/
└── dashboard_plugin.gd                # shared right-sidebar shell and tabs

plugins/hud/
└── hud_plugin.gd                      # compact population/happiness summary

scripts/
├── data_map.gd                        # presentation-only saved preferences
└── game_events.gd                     # bounded Community UI refresh/selection events

test/unit/community_ui/
├── test_community_view_model.gd
├── test_community_overview.gd
├── test_resident_detail.gd
├── test_place_inspector.gd
├── test_community_navigation.gd
├── test_community_accessibility.gd
└── test_community_ui_performance.gd

test/scenarios/                        # reuse all four Community scenarios
server/src/tools/
└── playtest-runtime-live.test.ts      # retain outcome assertions; add UI parity probes only if needed
```

**Structure Decision**: Keep simulation authority in `Community`, pure display
projection in `CommunityInspector`, and Control construction/navigation in a
dedicated `CommunityPanel`. The existing Dashboard remains the single owner of
the right-side CanvasLayer and becomes a tab shell, preventing competing panels.
HUD retains the always-visible summary. Map overlay rendering is isolated from
both simulation and panel layout.

## Display Architecture

```text
Community snapshot + catalog + clock + configured thresholds
                         |
                         v
             CommunityInspector projection
                 /          |          \
                v           v           v
          compact HUD   sidebar tabs   map overlay
                         /   |   \
                  overview residents places
```

### Shared visual language

- Opportunity: upward-arrow icon and label.
- Liveability: home/heart icon and label.
- Beauty: sparkle/landscape icon and label.
- Belonging: linked-people icon and label.
- Positive/negative: explicit `+`/`−`, words, and icons in addition to color.
- Identity/Freedom/Care: “Rooted”, “Independent”, and “Civic” player labels;
  technical lens terms remain available in help/developer detail.
- Scores are numeric and bar-backed; bars never carry meaning alone.
- Effect rows sort by quality, sign, absolute amount, source, then effect ID.

## Implementation Phases

### Phase 0 — Freeze display contract and test fixtures

Define the view-model contract in
`contracts/community-view-model.md`. Add pure fixture builders for zero
population, full capacity, personality contrast, park-and-noise, migration week,
retention hour 23/24, stale selection, missing metadata, and 500 residents.

**Exit gate**: every field in the spec’s Display Inventory maps to an
authoritative source or is explicitly marked presentation-only.

**Test seams**: schema completeness, stable ordering, fallback copy, no raw IDs
or seeds in default projections, and snapshot immutability.

### Phase 1 — Compact HUD and tabbed sidebar shell

Extend HUD with `population/capacity`, composite happiness, and coalesced recent
population change. Refactor Dashboard’s right panel into a shared shell with
Community and Patrons tabs while preserving collapse behavior, quest cards, and
screen-edge tab access. Add backward-compatible selected-tab preference.

**Exit gate**: at 1280×720, HUD, sidebar, palette, inbox, and clock have no
overlap; Patrons remains functionally unchanged.

**Test seams**: initial state, event refresh, collapse/tab persistence, zero
residents, map load, focus order, 1280×720 bounds, and existing Dashboard tests.

### Phase 2 — Community overview

Build cards for Housing, Four Qualities, Migration, Composition, Drivers, and
Warnings. Cache only the previous authoritative aggregate snapshot to show
directional deltas. Use empty-state guidance when population is zero and
explicitly distinguish full-capacity rejection from happiness rejection.

**Exit gate**: a player can identify population, free housing, weakest quality,
and strongest nuisance without opening resident detail.

**Test seams**: computed display values against canonical snapshots, no-resident
semantics, exact counts beside percentages, tied driver ordering, warning
priority, and event coalescing.

### Phase 3 — Resident list and explainable detail

Add deterministic, paged rows; search by player label; filters for home/risk,
dominant outlook, and weakest quality; selection that survives refresh when the
resident remains. Detail shows current/target qualities, outlook, sensitivities,
activity, retention state, and grouped positive/negative effects.

**Exit gate**: park-and-noise visibly retains simultaneous benefits and harm,
and personality contrast visibly explains differing responses.

**Test seams**: effect provenance, participant/non-participant truth, signed
same-quality effects, selected resident departure, filter combinations, capped
snapshots, and keyboard navigation.

### Phase 4 — Place, neighbourhood, and programme inspection

Add Community inspect mode to select a canonical placed-building anchor. Build
place impact projections from the catalog plus current resident AppliedEffects.
Show programme, active schedule, reach, capacity, participants, affected homes,
and signed aggregate contributions. Add home-anchor neighbourhood aggregation
and one opt-in quality/outlook overlay with numeric legend. Route programme
selection through `Community.set_programme` and refresh only after the canonical
event.

**Exit gate**: selecting an amenity, nuisance, home, or multi-programme venue
correctly connects map location, people, and effects without inventing district
state.

**Test seams**: building demolition while selected, radius boundary, overnight
schedule/end-hour, programme success/failure, actual participant lists,
home-anchor aggregation, overlay cleanup, and Builder input suppression only
while inspect interactions consume the click.

### Phase 5 — Migration, retention, and notifications

Surface no-capacity, rejection, arrival, departure, rehome, homelessness, and
below-threshold grace information. Coalesce same-tick batches into one
notification and retain no unbounded event history. Deep-link notifications to
resident detail when the resident still exists, otherwise to the overview.

**Exit gate**: migration-week and retention-failure can be understood from UI
alone at all acceptance boundaries.

**Test seams**: same-tick batch arrivals, departed resident link fallback,
hour-23/hour-24 boundary, recovery reset, rehome, no-capacity vs below-threshold
copy, and map reset.

### Phase 6 — Accessibility, performance, and visual acceptance

Complete keyboard/gamepad focus paths, visible focus styling, tooltips/help,
non-color encodings, text scaling, long-copy wrapping, and row paging/reuse.
Capture fixed scenario screenshots at 1280×720 and a wider desktop viewport.
Profile projection and update cost with 500 residents.

**Exit gate**: SC-001 through SC-010 pass; all existing gameplay and live AI
outcome suites remain green.

**Test seams**: focus traversal, Escape/back behavior, contrast/non-color
assertions, minimum viewport clipping, 500-resident frame budget, screenshot
baselines, GUT regression, and live scenario parity.

## Refresh and Ownership Rules

- Community emits authoritative change signals; the panel requests one fresh
  projection per coalesced simulation update, never per rendered frame.
- The view model returns new dictionaries/arrays and never mutates resident,
  building, catalog, or map state.
- UI-only selection and filtering remain local. Collapse and selected top-level
  tab may persist; transient resident/building selections do not.
- Programme selection is the only Community UI gameplay intent. The visible
  active programme changes only after `community_programme_changed`.
- Builder placement/demolition remains authoritative. Inspect mode consumes a
  map click only when explicitly active and never changes GridMap state.
- Resident and effect rows are bounded by the existing snapshot limits and use
  paging/reuse rather than constructing all Controls on every update.

## Verification Plan

1. Run pure view-model and existing Community GUT suites headlessly.
2. Run UI scene/plugin tests at 1280×720 and a wide viewport.
3. Replay `community_personality_contrast`, `community_park_and_noise`,
   `community_migration_week`, and `community_retention_failure` with exact
   seeded hours.
4. Assert rendered values against same-tick canonical snapshots.
5. Capture and review overview, resident, place, empty, full-capacity, and
   at-risk screenshots.
6. Run 500-resident projection/scroll performance verification.
7. Run the entire GUT, TypeScript, and live AI outcome suites.

## Complexity Tracking

No constitution violation is planned. The added view-model projection is a
read-only presentation boundary, not a second domain model. The map overlay is
isolated because it has materially different rendering and input lifetime from
the sidebar, while both consume the same projection contract.

