# Feature Specification: Community Insight UI

**Feature Branch**: `003-community-ui` *(planning identifier; no branch created)*

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Make a Spec Kit plan for the UI that displays all of the Community novelty, variety, happiness, migration, and explainability outcomes."

## 1. Purpose

Make the Community simulation legible and actionable to a player. The UI must
show not only whether the town is doing well, but who lives there, how residents
experience the same place differently, which buildings create each benefit or
nuisance, why population changes, and how neighbourhood character emerges.

The UI is an explanation layer over the existing Community simulation. It MUST
not recalculate happiness, invent population, or create a second set of gameplay
rules.

## 2. Information Architecture

The feature uses progressive disclosure across four connected surfaces.

### 2.1 Glanceable city HUD

Always visible during normal play:

- current population and residential capacity;
- average composite happiness;
- one compact population-change indicator when arrivals or departures occur;
- a clear entry point into Community details.

The HUD MUST remain readable without opening a panel and MUST not duplicate the
existing Satisfaction score as though the two values were interchangeable.

### 2.2 Community overview

The Community tab in the existing right sidebar displays:

- population, capacity, occupied/free homes, and occupancy percentage;
- average Opportunity, Liveability, Beauty, and Belonging;
- directional change since the prior authoritative community update;
- arrivals, departures, rejections, and net migration for the current save;
- personality composition by player-facing outlook labels and dominant lenses;
- the strongest current positive and negative effect reasons;
- warnings for no capacity, active homelessness, and residents approaching a
  departure grace boundary.

### 2.3 Resident details

A searchable/filterable resident list and selected-resident view displays:

- stable player label (`Resident #<id>`) until authored names exist;
- home location, current activity, and current programme if participating;
- composite happiness plus current and target values for all four qualities;
- player-facing outlook summary and per-quality Identity/Freedom/Care emphasis;
- noise, pollution, crowding, and travel sensitivities;
- positive and negative AppliedEffects grouped by quality;
- effect source building, signed contribution, scope, manifestation, reason,
  and active schedule/context when available;
- homelessness duration or consecutive below-threshold hours as a progress
  indicator against the applicable configured grace period.

Raw generation seeds and internal IDs are developer-only and MUST not appear in
the default player view.

### 2.4 Place and neighbourhood inspection

An inspect mode connects the panel to the map. Selecting a residential building
or amenity displays:

- building name, current programme, active/inactive state, and participant use;
- authored local radius and participant capacity where applicable;
- residents housed at the selected anchor;
- residents currently affected by or participating in the selected place;
- aggregate positive and negative contributions caused by the place;
- a residential-anchor neighbourhood summary: resident count, average four
  qualities, dominant outlook mix, and strongest local drivers;
- a map overlay for one selected quality or outlook lens, with a legend and
  numeric fallback labels.

“Neighbourhood” in this feature means an aggregation by residential home anchor
and authored effect radius. It is not a new district, faction, zoning, or
approval mechanic.

### 2.5 Programme display and selection

For buildings with multiple authored programmes, the place view displays the
active programme and its authored effect themes. A player may choose another
available programme through the existing authoritative `Community.set_programme`
path. The UI MUST preview authored effect categories and schedules without
promising a resident-specific outcome before the simulation evaluates it.

## 3. User Scenarios & Testing

### User Story 1 — Understand community health at a glance (Priority: P1)

As a player, I can see population pressure and the four Community qualities
without reading logs so I know whether to add homes, amenities, or mitigate a
nuisance.

**Why this priority**: This is the minimum useful player feedback loop.

**Independent Test**: Load the park-and-noise scenario, advance through an hour,
and verify the HUD and overview match the authoritative Community snapshot.

**Acceptance Scenarios**:

1. **Given** a town with residents, **When** Community state changes, **Then** the HUD shows population/capacity and composite happiness on the same update.
2. **Given** a Community overview, **When** a quality rises or falls, **Then** its score and direction update without presenting Satisfaction as the same metric.
3. **Given** zero residents, **When** the overview opens, **Then** it shows a purposeful empty state and housing/migration guidance rather than misleading zero-quality failure bars.
4. **Given** full housing, **When** candidates are rejected, **Then** the overview identifies capacity pressure separately from happiness-based rejection.

---

### User Story 2 — Explain why a resident feels this way (Priority: P1)

As a player, I can inspect a resident and trace every visible quality change to
specific positive and negative sources.

**Why this priority**: Explainability is the core promise of the simulation.

**Independent Test**: Select a resident exposed to a pond and active nightclub;
verify separate recreation, belonging, and noise rows with signed contributions.

**Acceptance Scenarios**:

1. **Given** simultaneous benefit and nuisance effects, **When** a resident opens, **Then** both remain visible as separate rows rather than one opaque modifier.
2. **Given** two residents exposed to the same venue, **When** each is selected, **Then** their differing applied amounts and outlook explanations are visible.
3. **Given** a participant-scoped effect, **When** a non-participant is selected, **Then** the UI does not claim that resident received the effect.
4. **Given** a scheduled nuisance outside its active window, **When** the place is inspected, **Then** the schedule is visible and the effect is marked inactive rather than applied.
5. **Given** any displayed quality change, **When** its explanation is expanded, **Then** source, quality, manifestation, signed amount, scope, reason, and time context are available.

---

### User Story 3 — Understand migration and retention (Priority: P1)

As a player, I can tell why the town is growing, why candidates are being
rejected, and which residents are at risk of leaving.

**Why this priority**: Population is now an outcome of happiness, not a capacity
multiplier, and the UI must teach that change.

**Independent Test**: Run the matched and nuisance towns for seven days and
verify the UI distinguishes capacity, arrivals, rejections, departures, and
at-risk residents.

**Acceptance Scenarios**:

1. **Given** free housing and a compatible town, **When** residents arrive, **Then** population, free capacity, arrivals, and composition update together.
2. **Given** no free housing, **When** migration is evaluated, **Then** the UI shows no-capacity pressure without implying low happiness.
3. **Given** a resident below the departure threshold, **When** fewer than the configured grace hours have passed, **Then** an at-risk indicator shows progress and does not claim departure is immediate.
4. **Given** a demolished occupied home, **When** the resident is not yet rehomed, **Then** the UI shows homelessness and relocation-grace progress.
5. **Given** a departure or rehome event, **When** it occurs, **Then** a concise notification links to the affected resident or resulting Community view where possible.

---

### User Story 4 — See personality-driven variety emerge (Priority: P2)

As a player, I can see that places attract and satisfy different kinds of people
without turning those people into factions with global approval scores.

**Why this priority**: This communicates the novelty/variety outcome after the
core health and explanation loop is usable.

**Independent Test**: Compare the same seeded resident stream in two differently
developed towns and verify the overview and neighbourhood views show measurably
different compositions.

**Acceptance Scenarios**:

1. **Given** Identity-heavy and Freedom-heavy residents using the same venue, **When** their details are compared, **Then** the relevant per-quality outlook differences are visible.
2. **Given** neighbourhoods with different resident mixes, **When** the composition view opens, **Then** counts and proportions differ without any diversity bonus, faction approval, or monoculture penalty.
3. **Given** a very small population, **When** composition is shown, **Then** exact counts accompany percentages so one resident is not presented as a stable trend.
4. **Given** no residents, **When** composition is shown, **Then** the UI displays an empty state rather than a fabricated general population.

---

### User Story 5 — Inspect places and choose programmes (Priority: P2)

As a player, I can inspect what a building contributes, see who it reaches, and
choose an authored programme when the building supports one.

**Why this priority**: It connects building decisions to resident outcomes while
preserving one gameplay truth.

**Independent Test**: Inspect a theatre, switch between authored programmes,
advance to an active hour, and verify the place and resident views update from
canonical Community results.

**Acceptance Scenarios**:

1. **Given** a place with local effects, **When** selected, **Then** its radius, affected homes, and current positive/negative contributions are visible.
2. **Given** a place with participant effects, **When** selected, **Then** capacity, current participants, and participant-only benefits are visible.
3. **Given** multiple authored programmes, **When** one is selected, **Then** the choice uses the canonical programme API and the UI waits for authoritative state before showing it as active.
4. **Given** an effect with an overnight schedule, **When** inspected before, during, and at the exclusive end hour, **Then** its active state follows the authored schedule exactly.

## 4. Display Inventoryw

| Surface | Required display | Default visibility |
|---|---|---|
| City HUD | population/capacity, composite happiness, recent net change, Community button | Always |
| Overview / Housing | occupied/free/capacity, occupancy, homelessness, capacity warning | Panel |
| Overview / Qualities | Opportunity, Liveability, Beauty, Belonging, score, direction | Panel |
| Overview / Migration | arrivals, departures, rejections, net migration, latest event | Panel |
| Overview / Composition | outlook counts/proportions, dominant Identity/Freedom/Care counts | Panel |
| Overview / Drivers | strongest positive and negative current reasons | Panel |
| Resident list | label, home status, composite, risk state, dominant outlook | Panel |
| Resident profile | current/target qualities, outlook weights, sensitivities, activity/programme | Detail |
| Resident effects | signed amount, source, quality, lens, scope, reason, current time context | Detail |
| Place profile | programme, active window, radius, capacity, participants, affected residents | Detail |
| Neighbourhood | residents at home anchor, averages, composition, top local drivers | Detail/map |
| Map overlay | selected quality/outlook, legend, values, selected anchor/source radius | Opt-in |
| Notifications | arrival, departure reason, rehome, capacity/full and at-risk transitions | Event-driven |

## 5. Edge Cases

- Zero residents, zero capacity, and capacity with zero residents.
- Population exactly equal to capacity and migration rejection for no capacity.
- More residents than the list virtualization/page size, including the existing
  500-record snapshot cap.
- A selected resident departs, is rehomed, or disappears after map reset.
- A selected building is demolished or changes programme while its detail is open.
- Positive and negative effects on the same quality in the same hour.
- Equal effect amounts and deterministic display ordering.
- Overnight schedules whose start is later than their end, including the
  exclusive end-hour boundary.
- Residents without homes or current activities.
- Missing display names, reasons, programmes, source buildings, or optional
  schedule data; stable readable fallbacks are required.
- Save files created before Community UI preference fields exist.
- Window resizing, 1280×720 minimum layout, text scaling, long localized copy,
  keyboard/gamepad focus, and color-vision deficiencies.
- Narrative presentation disabled or placeholder character content.

## 6. Requirements

### Functional Requirements

- **FR-001**: The UI MUST consume authoritative Community snapshots and events; it MUST NOT independently calculate quality, migration, retention, participation, or stacking outcomes.
- **FR-002**: The always-visible HUD MUST show population/capacity and average composite happiness.
- **FR-003**: The detailed overview MUST show all four average qualities with labels, numeric values, and non-color direction cues.
- **FR-004**: The overview MUST separately show housing capacity, occupied homes, free homes, active homelessness, arrivals, departures, rejections, and net migration.
- **FR-005**: The overview MUST show personality composition as descriptive outlook counts/proportions and dominant-lens counts, never as faction approval.
- **FR-006**: The resident list MUST support deterministic ordering plus filters for home status, risk status, dominant outlook, and lowest quality.
- **FR-007**: Resident detail MUST show current and target four-quality values, composite happiness, home, activity/programme, outlook, and sensitivities.
- **FR-008**: Every displayed applied effect MUST retain its source, quality, manifestation, signed amount, scope, reason, and active time context where authored.
- **FR-009**: Positive and negative effects MUST remain separate even when they affect the same quality or originate from the same building.
- **FR-010**: Retention displays MUST use the configured thresholds and grace periods supplied by Community presentation data; UI code MUST NOT hard-code balance values.
- **FR-011**: Place inspection MUST distinguish local, participant, resident, and city scopes and MUST show only actual affected residents/participants as such.
- **FR-012**: The neighbourhood view MUST derive groups from canonical home anchors and effect radii and MUST NOT add district/faction simulation state.
- **FR-013**: Multi-programme buildings MUST display their current programme and allow selection through the canonical Community programme command.
- **FR-014**: Programme previews MUST be described as authored themes/schedules, not guaranteed resident outcomes.
- **FR-015**: Arrival, departure, and rehome events MUST produce concise, non-blocking notifications; repeated batch events MUST be coalesced.
- **FR-016**: The existing right sidebar MUST become a non-overlapping tabbed shell for Community and Patrons, preserving collapse behavior and quest access.
- **FR-017**: Community presentation preferences MUST survive map save/load with backward-compatible defaults and MUST not affect deterministic simulation hashes.
- **FR-018**: All interactive controls MUST be keyboard and gamepad reachable, expose visible focus, and remain usable without color perception.
- **FR-019**: The panel MUST remain usable at 1280×720 and common wider desktop resolutions, with scrolling rather than clipped content.
- **FR-020**: UI refreshes MUST be event-driven and bounded; no full resident-list rebuild may occur every rendered frame.
- **FR-021**: Empty, stale-selection, missing-data, and capped-list states MUST be explicit and must not fabricate values.
- **FR-022**: Debug-only fields such as RNG seeds, internal building IDs, and raw multipliers MUST be hidden from the default view but may appear behind an explicitly marked developer-details toggle.

### Key Entities

- **Community HUD Summary**: Population, capacity, composite happiness, and a transient net-change indicator.
- **Community Overview**: Aggregate qualities, housing, migration, composition, drivers, and warnings for one authoritative snapshot.
- **Resident View**: Player-facing projection of one persistent resident and their current/target qualities, outlook, sensitivities, status, activity, and applied effects.
- **Applied Effect View**: One signed, explainable contribution linked to a source place and current time context.
- **Place Impact View**: Programme, schedule, scope/radius/capacity, participants, affected residents, and aggregate contribution for one building.
- **Neighbourhood View**: Read-only aggregation around a residential anchor.
- **Community UI State**: Collapsed/tab/selection/filter/overlay preferences that never affect simulation results.
- **Community Notification**: Coalesced arrival, departure, rehome, capacity, or retention-risk presentation event.

## 7. Success Criteria

### Measurable Outcomes

- **SC-001**: In the four canonical Community scenarios, every HUD and panel aggregate matches the same-tick authoritative snapshot in automated tests.
- **SC-002**: A player can identify population, free housing, weakest average quality, and strongest current negative driver within 10 seconds of opening Community.
- **SC-003**: In personality contrast, the UI visibly presents the differing applied amount or activity choice for both residents exposed to the same place.
- **SC-004**: In park-and-noise, a resident view simultaneously shows at least one positive and one negative structured effect without merging them.
- **SC-005**: In migration-week, the UI shows the matched town ending with a larger population than the nuisance town while both visibly remain within equal capacity.
- **SC-006**: In retention-failure, the at-risk resident remains present through grace hour 23 and the UI reflects departure at hour 24.
- **SC-007**: Every effect row rendered in acceptance tests can be traced to a canonical source record and includes all required explanation fields.
- **SC-008**: With 500 residents, an aggregate update completes within one frame budget target of 16.7 ms and list scrolling remains responsive through row reuse/paging; the simulation performance budget remains unchanged.
- **SC-009**: All primary Community workflows are completable by keyboard alone at 1280×720 with no clipped required controls.
- **SC-010**: Existing HUD, Patron dashboard, palette, inbox, dialogue, time controls, and Community live outcome tests remain passing and non-overlapping.

## 8. Assumptions

- Godot 4.6.x desktop is the target; touch/mobile layouts are out of scope.
- Resident authored names and portraits are unavailable, so stable numeric labels
  and outlook descriptions are the v1 presentation.
- The existing right sidebar is the correct home for detailed Community UI and
  will be refactored into Community/Patrons tabs.
- Current Community snapshots remain the simulation truth; a narrow read-only
  presentation projection may add schedules, configured thresholds, and place
  impact indexes that are currently absent from compact snapshots.
- Trends are presentation deltas between authoritative updates, not persisted
  historical analytics.
- A neighbourhood is derived from home anchors and effect reach; district
  painting, zoning, factions, diversity scores, and approval systems are out of
  scope.
- Programme selection is in scope because it is necessary to make authored
  personality trade-offs legible and actionable.

## 9. Out of Scope

- New happiness formulas, balance tuning, cohorts, or building effects.
- Resident needs/quests, relationships, families, pathfinding, or named biographies.
- Global faction approval, diversity rewards, monoculture penalties, or district governance.
- Historical charts beyond the current-session directional delta and counters.
- Mobile/touch-specific UI, multiplayer state, or remote analytics.
- Exposing debug MCP controls or arbitrary simulation mutation to players.
