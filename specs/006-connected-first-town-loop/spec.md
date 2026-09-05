# Feature Specification: Connected First-Town Loop

**Feature Branch**: `006-connected-first-town-loop` *(planning identifier; no branch created)*

**Created**: 2026-09-05

**Status**: Implementation in progress — core connected-town slice automated; matched-layout and human gates remain

**Input**: User description: "Make roads, employment, commerce, economy, demand, Community happiness, and spatial separation form one balanced and explainable first-town gameplay loop that incentivises spread-out, community-driven, beautiful layouts with a meaningful mix of nature and buildings."

## 1. Purpose

Turn the existing collection of city systems into one consequential early-game
loop. Where the player places homes, roads, workplaces, shops, and amenities
must determine who can participate, which buildings operate, how much the town
earns, how demand grows, and whether residents arrive or leave.

The loop must also reward deliberate use of space. A connected town that keeps
homes away from local nuisances and distributes neighbourhood benefits should
produce measurably better lived outcomes than an otherwise equivalent compact
layout, while paying an explicit road, distance, or land-use cost for doing so.

The simulation does not judge whether a silhouette is aesthetically correct.
Instead it rewards the explainable ingredients of a cared-for place: greenery
that serves homes, shared destinations people can reach, buffers that prevent
harm, distinct neighbourhood needs, and real choices between land, cash,
distance, capacity, and resident experience. Blind player review then verifies
that those rules actually produce intentional, varied, attractive towns rather
than amenity spam or one prescribed template.

The intended loop is:

```text
Build homes and connect places
→ residents can reach work, commerce, and activities
→ occupied places produce economic and Community outcomes
→ income funds amenities and mitigation
→ attractiveness and lived experience affect demand and migration
→ earned demand unlocks larger buildings and story progression
```

The milestone ends with a replayable, evidence-backed first-town balance, not a
complete long-game economy.

The complete test protocol and adversarial matrix are defined in
[layout-validation-strategy.md](layout-validation-strategy.md).

## 2. Scope Boundary

### In scope

- Canonical road access and route reachability for homes, workplaces,
  commercial places, and participant activities.
- Operational state derived from road connectivity, schedule, capacity, and
  actual resident participation.
- Employment and commerce allocation based on reachable residents.
- Industrial output, tax income, commercial demand, and participant effects
  based on operational outcomes rather than building presence alone.
- Starter demand, tier thresholds, building demand costs, tax rate, and amenity
  cost tuning for a deliberate early-game arc.
- Community effects for all starter residential, industrial, commercial, and
  amenity choices.
- Canonical local-effect exposure and coverage metrics that make separation of
  incompatible uses and distribution of neighbourhood amenities consequential.
- Nature-integrated neighbourhood comparisons that distinguish resident-serving
  green space from unserved decoration and repeated-item spam.
- Resident-composition comparisons proving that different Community outlooks
  can favour different place and programme choices.
- Matched compact-versus-spread layout scenarios with identical non-road
  buildings, capacity, seed, and simulated duration.
- Adversarial layouts covering blank sprawl, disconnected beauty, isolated
  nature dumping, duplicate amenity overlap, and repetitive checkerboards.
- Player-facing connectivity, operation, affordability, and consequence
  explanations in the existing HUD, radial details, notifications, and Town
  Insights surfaces.
- Removal or redefinition of the duplicate Satisfaction/Community happiness
  presentation.
- Matched deterministic scenarios and frozen before/after traces.

### Explicitly out of scope

- Traffic congestion changing production, journey duration, or happiness.
- Parking, deliveries, freight, goods inventories, production chains, public
  transport, road maintenance, or road hierarchy simulation.
- Pedestrian-only access networks beyond current visual walking behavior.
- Zoning, utilities, crime, education, healthcare, pollution diffusion, land
  value, or municipal debt systems.
- A hidden global density score, arbitrary minimum building separation, or a
  blanket penalty for compact towns independent of authored spatial effects.
- A hidden beauty score, fixed green-space quota, preferred town silhouette,
  automatic screenshot score, or bonus awarded merely for using different
  asset IDs.
- Final long-game balance, endless scaling, multiple patrons, or new campaign
  content.
- Save browser, autosave, title/pause screens, settings, and release export.
- New public playtest tools beyond fields and scenarios needed to observe this
  loop.

## 3. Gameplay Contract

### 3.1 Road access and route reachability

- A building is **road-accessible** when at least one cell of its footprint is
  orthogonally adjacent to a valid road-network stop.
- Two road-accessible buildings are **route-reachable** when their stops belong
  to the same connected road component.
- Multi-cell footprints consider every footprint edge and must not depend on
  which cell was selected or which cell is the anchor.
- Connectivity is derived from the authoritative placed road/building state.
  Player UI, simulation, visual agents, and automated playtests must query the
  same decision surface.
- Buildings may be planned and placed while disconnected, but they must expose
  a non-operational warning and may not generate outcomes that require access.
- Connectivity changes take effect at the next canonical simulation boundary.
  Render-frame movement and whether a visible person or car finishes an
  animation must never change simulation results.

Pavement remains decorative in this milestone unless planning identifies an
existing authored network contract that can support deterministic pedestrian
access without expanding scope.

### 3.2 Reachable participation and operation

- Residents may occupy housing without a road connection, avoiding a fresh-game
  chicken-and-egg condition.
- A resident can fill a workplace slot only when their home and that workplace
  are route-reachable during the workplace's active schedule.
- A resident can fill a commercial or participant-activity slot only when their
  home and that destination are route-reachable during its active schedule.
- Allocation is deterministic. It uses stable resident, priority, distance, and
  building-order tie-breaks and never depends on scene-tree order or frame rate.
- A workplace's output and budget contribution are calculated from its actually
  fulfilled reachable workers.
- Commercial activity and participant-scoped Community effects are calculated
  from actually fulfilled reachable participants.
- Local, resident, and city effects retain their authored spatial/scope rules;
  they do not silently become participant effects merely because roads exist.
- Demolishing or disconnecting a road cannot leave stale workers,
  participants, output, income, or activity assignments after the next update.

### 3.3 Early economy and demand arc

The tuned opening must satisfy all of these product outcomes:

1. Each growth bucket has at least one useful tier-one choice on a fresh map.
2. Tier two is not selectable at simulation hour zero.
3. Placing disconnected workplaces cannot create output, income, or downstream
   commercial demand.
4. A modest connected mixed town can become economically positive without
   immediately removing all cash pressure.
5. Amenity spending has a meaningful recovery time and competes with other
   useful early choices.
6. Residential, industrial, and commercial-only openings do not all settle into
   equally static or equally optimal outcomes.
7. Tier-two availability is earned through play and occurs within the canonical
   successful first-town scenario.
8. The progression route established by milestone 005 remains reachable after
   tuning.
9. A connected layout that deliberately separates homes from incompatible local
   nuisances can outperform an equivalent compact layout on resident outcomes,
   without receiving free output or income merely for occupying more space.

The exact tuning mechanism may use existing data fields or narrowly extend
them. A new debt, loan, maintenance, or taxation subsystem is not required to
meet these outcomes.

### 3.4 Community consequence coverage

Every player-selectable starter T1/T2 growth or amenity choice must either:

- author at least one meaningful Community effect with source, quality, scope,
  amount, manifestation, schedule where relevant, and a player-readable reason;
  or
- explicitly declare that it has no direct Community effect so the absence is
  intentional and visible to content validation.

At minimum:

- housing provides the secure-home effect to its actual occupants;
- reachable employment can improve Opportunity for its workers;
- reachable commerce or leisure can provide appropriate Opportunity,
  Liveability, Beauty, or Belonging outcomes for participants;
- industry creates spatial nuisance trade-offs appropriate to its authored
  type; and
- nature/amenities provide local benefits that can improve migration and
  retention when placed well.

Effects remain data-driven. The connectivity layer decides who can participate;
it does not duplicate Community effect calculations.

### 3.5 Spatial layout incentives

“Spread out” is defined by gameplay exposure and coverage, not by the raw size
of the town's bounding box. The canonical spatial comparison holds the
non-road building set, capacities, starting resources, random seed, and elapsed
hours constant, then changes only anchors and the roads required by those
anchors.

- Moving homes beyond an industrial or other negative local effect's authored
  radius must reduce the number of residents exposed to that effect.
- Distributing local amenities across occupied neighbourhoods must be capable
  of covering more distinct residents than clustering the same amenities in one
  location.
- Separation does not waive connectivity. Remote homes, workplaces, shops, and
  amenities still need canonical routes before access-dependent outcomes apply.
- The spread layout must expose its cost through additional road cells, route
  distance, land consumption, or a combination of those existing quantities.
  At least one recorded cost must affect a scarce player choice such as cash,
  remaining buildable land, a forgone placement, or milestone timing. A larger
  number with no gameplay consequence is not a trade-off.
- Spatial benefits come from authored effect scope, radius, participation, and
  actual resident locations. There is no separate hidden “good layout” score.
- Compact layouts remain viable when their shorter routes and lower land or
  network footprint outweigh local nuisance or coverage disadvantages.

The comparison trace records residential exposure counts per negative effect,
distinct-resident coverage per positive local effect, road-cell count, route
distance, occupied land, fulfilled assignments, Community qualities, migration,
and economic outcomes.

### 3.6 Community-shaped and nature-integrated places

Automated tests measure lived spatial outcomes; they do not assign a universal
score to visual taste.

- A nature source is **resident-serving** when a named local effect reaches an
  occupied home or a residential slot currently being evaluated for migration,
  or when a reachable resident fulfils its participant activity.
- A **nature-integrated neighbourhood** contains occupied homes, at least one
  resident-serving nature source, and at least one reachable work, commercial,
  civic, or social destination. Incompatible industry may sit at its connected
  edge rather than being mixed beside homes.
- Empty or unserved decoration may remain available for expression, but it must
  not accelerate residential demand, migration, unlocks, or progression merely
  because an object with a positive base value exists somewhere on the map.
- Every player-selectable nature item must declare either a named Community
  role or an explicit cosmetic-only role. Cosmetic-only items cannot feed a
  balance or progression total.
- Positive effects in the same stacking group use a data-driven finite default
  sequence of `1.0`, `0.5`, `0.25`, then `0.0` for further overlapping sources
  affecting the same resident. A copy distributed to a previously unserved
  resident still contributes normally. An unlimited non-zero duplicate tail is
  not permitted.
- Distinct functions may combine through distinct authored effects and stacking
  groups. The simulation does not award an abstract variety bonus merely for
  placing different building IDs.
- Positive greenery and negative nuisance remain separate explained effects.
  Greenery can improve life near industry but cannot erase or relabel a
  resident's actual pollution, noise, or visual exposure.
- Identity-, Freedom-, and Care-oriented residents must not all rank every
  neighbourhood or programme in the same order. Community composition should
  alter which viable response is best without creating cohort approval scores.
- At least two materially different successful town forms must survive final
  tuning. A compact connected neighbourhood may win on land and network cost;
  a distributed or buffered town may win on coverage, exposure, Beauty,
  Liveability, or Belonging.

### 3.7 Player explanation

The game must distinguish these concepts:

- **Available**: the building may be selected and placed under current resource
  and progression rules.
- **Connected**: the placed building has road access and at least one relevant
  reachable counterpart where required.
- **Open**: its authored schedule is currently active.
- **Operating**: it is open, connected, and has fulfilled participants or
  workers where required.
- **Contributing**: it produced a named economic, demand, or Community outcome
  in the latest simulation update.

Building inspection exposes the applicable state and reason, such as no road
access, isolated road component, no reachable residents, outside active hours,
or no free capacity. Placement may warn about likely disconnection but must not
predict an outcome using a separate rule implementation.

Before confirming a nature source or nuisance, placement feedback exposes its
authored effect categories and radius plus the homes currently inside that
radius, distinguishing newly served homes from overlapping coverage. After
placement, inspection exposes the authoritative affected residents and actual
contributions. Predictions remain clearly labelled and never replace canonical
post-simulation results.

The top HUD must not display Satisfaction and Community happiness as two labels
for the same value. It may replace the legacy Satisfaction value with a distinct
economic/service coverage measure, or remove it if no useful distinct measure
survives planning.

## 4. User Scenarios & Testing

### User Story 1 — Build a town whose roads matter (Priority: P1)

As a player, I must connect homes to workplaces and destinations before those
places can generate their full outcomes.

**Why this priority**: Roads are a primary construction tool but currently can
be ignored by the economy. Connectivity is the missing spatial decision in the
core loop.

**Independent Test**: Build matched mixed towns with identical structures and
seed, connect one town and leave the other roadless, then advance 48 hours and
compare operation, output, income, participation, and demand.

**Acceptance Scenarios**:

1. **Given** a workplace with no adjacent road, **When** its active hours pass, **Then** it reports no road access and produces no worker-derived output or income.
2. **Given** homes and a workplace beside roads in different components, **When** work begins, **Then** the workplace reports no reachable residents and produces no worker-derived output.
3. **Given** a continuous route between occupied homes and a workplace, **When** work begins, **Then** reachable residents fill deterministic slots and output reflects the fulfilled count.
4. **Given** an operating route, **When** a critical road is demolished, **Then** the next simulation update clears invalid assignments and removes their downstream output and income.

---

### User Story 2 — Make meaningful opening trade-offs (Priority: P1)

As a player, I can choose between growth, income, amenities, and space without
tier-two buildings or runaway cash making the opening decisions irrelevant.

**Why this priority**: Connectivity alone adds chores unless the surrounding
resource curve makes different layouts and build orders consequential.

**Independent Test**: Run residential-only, industrial-only, roadless mixed,
connected mixed, and amenity-supported openings with matched seeds for 48 hours
and compare milestones and final state.

**Acceptance Scenarios**:

1. **Given** a fresh town, **When** choices are inspected before any action, **Then** tier-one growth options are usable and tier-two options show an earned requirement.
2. **Given** a connected mixed opening, **When** two days pass, **Then** it has generated positive daytime output and income without exceeding the agreed early cash ceiling.
3. **Given** an amenity purchase, **When** the same opening is replayed with and without it, **Then** its economic cost and Community benefit are both visible in the trace.
4. **Given** a single-purpose opening, **When** two days pass, **Then** its limiting factor and lack of complementary outcomes are visible rather than silently reading as a fully healthy town.

---

### User Story 3 — See residents experience connected places (Priority: P1)

As a player, I can see which residents reached work or activities and how those
experiences affected their happiness and migration.

**Why this priority**: The Community simulation is the game's distinctive layer;
connectivity should create human consequences rather than only alter a cash
counter.

**Independent Test**: Inspect two otherwise equivalent residents, one connected
to a workplace/venue and one isolated, across the relevant active schedule.

**Acceptance Scenarios**:

1. **Given** a reachable workplace with capacity, **When** a resident is assigned, **Then** their current activity and employment Opportunity effect identify that workplace.
2. **Given** an isolated resident, **When** the same workplace is active, **Then** the UI does not claim participation or apply its participant effect.
3. **Given** a connected amenity-supported neighbourhood and a matched nuisance neighbourhood, **When** migration runs for seven days, **Then** their differing arrivals, rejections, departures, and effect reasons are explainable.
4. **Given** an overnight venue, **When** its end hour is reached, **Then** participation and scheduled effects stop on the authored exclusive boundary.

---

### User Story 4 — Shape healthier neighbourhoods with space (Priority: P1)

As a player, I can separate homes from industrial nuisance and distribute local
amenities across connected neighbourhoods to improve residents' lived outcomes.

**Why this priority**: Spatial composition is the core promise of a city
builder. If an equally connected packed block always dominates, roads and land
become drawing chores rather than strategic resources.

**Independent Test**: Run compact and spread connected towns with the same
non-road buildings, capacities, seed, starting resources, and 168 simulated
hours. Compare exposure, effect coverage, assignments, output, income,
Community qualities, migration, road use, and occupied land.

**Acceptance Scenarios**:

1. **Given** equivalent connected towns whose homes are respectively inside and outside the same industrial nuisance radii, **When** 168 hours pass, **Then** the spread town exposes fewer residents, has higher mean Liveability, and does not lose employment solely because of separation.
2. **Given** the same count of local amenities, **When** one town clusters them and the other distributes them among occupied neighbourhoods, **Then** the distributed layout reaches more distinct residents and the trace identifies the affected residents and authored effects.
3. **Given** a spread layout whose remote component is not connected, **When** active hours pass, **Then** separation alone grants no participant, output, income, or migration benefit that requires access.
4. **Given** a beneficial spread layout, **When** it is compared with its compact pair, **Then** the extra road cells, route distance, and occupied land are visible alongside the Community benefit.
5. **Given** identical homes, workplaces, shop, nature sources, seed, and elapsed time, **When** the nature sources serve homes in one town and sit on unused edge land in the other, **Then** only the integrated town gains resident Beauty and the associated migration benefit.
6. **Given** four positive same-group sources overlapping one resident, **When** effects are evaluated, **Then** the fourth source contributes zero to that resident while a copy moved to an unserved neighbourhood contributes at full strength there.
7. **Given** a home inside both a green-space radius and an industrial nuisance radius, **When** inspected, **Then** the player sees both signed effects rather than a net label claiming the nuisance was removed.
8. **Given** a successful nature-integrated town and a matched built-only control, **When** both reach the comparison boundary, **Then** the integrated town has higher Beauty and at least one higher Liveability or Belonging outcome while its cash, land, or progression opportunity cost remains visible.

---

### User Story 5 — Let community needs shape the town (Priority: P1)

As a player, I can understand what residents value and use that evidence to
create green buffers, gathering places, and neighbourhood centres without
being forced into one optimal template.

**Why this priority**: The intended fantasy is not fulfilled when green space
is a cosmetic tax or a repeated-object exploit. Players must discover that
caring for residents and composing a town support one another.

**Independent Test**: Run the frozen Blind Neighbourhood Test with fresh players
who are asked only to reach tier two, remain solvent, and leave a town they
would continue playing. Do not prompt them to build nature, spread out, create
buffers, or make the town beautiful.

**Acceptance Scenarios**:

1. **Given** an unprompted fresh-town session, **When** the player makes a spatial edit for a resident or place reason, **Then** the next authoritative snapshot confirms the intended exposure, coverage, or participation change.
2. **Given** several viable nature and amenity choices, **When** fresh players finish the opening, **Then** successful towns include multiple layout families rather than converging on one repeated-item checkerboard.
3. **Given** an anonymised fixed-view screenshot set, **When** independent reviewers rate it without simulation scores, **Then** nature integration, intentional composition, visual variety, and readable neighbourhood centres meet the frozen acceptance rubric.
4. **Given** the accepted mixed-layout tuning, **When** optimisation-minded players continue for another hour, **Then** the dominant strategy does not replace useful green neighbourhoods with unserved decor spam or a packed block that ignores local effects.

---

### User Story 6 — Diagnose why a building is idle (Priority: P2)

As a player, I can inspect a placed building and understand the next action that
would make it useful.

**Why this priority**: Requiring roads without explaining operation would turn a
strategic rule into hidden failure.

**Independent Test**: Create each non-operational state and verify the map,
building inspector, HUD notification, and automated snapshot agree on one
canonical reason.

**Acceptance Scenarios**:

1. **Given** a disconnected placed building, **When** selected, **Then** it identifies the nearest applicable missing connection without claiming that placement itself was illegal.
2. **Given** a connected but closed building, **When** selected, **Then** its schedule and next active period are visible.
3. **Given** a connected and open workplace with no reachable residents, **When** selected, **Then** it distinguishes worker shortage from road disconnection.
4. **Given** multiple issues, **When** a summary reason is shown, **Then** canonical priority is stable and detailed inspection exposes all applicable reasons.

---

### User Story 7 — Compare balance changes with evidence (Priority: P2)

As a designer, I can replay unchanged opening strategies before and after each
tuning hypothesis and retain objective evidence for the decision.

**Why this priority**: Several interdependent values will change. Matched traces
are needed to avoid tuning by anecdote.

**Independent Test**: Freeze the current early-city trace, apply one tuning
fixture, replay the same seeds/actions, and generate the existing structured
comparison report.

**Acceptance Scenarios**:

1. **Given** a connectivity change, **When** matched roadless and connected traces are compared, **Then** operation, output, income, demand, population, Community, and milestone differences are visible.
2. **Given** a balance-data change, **When** compared with its unchanged baseline, **Then** the report identifies the exact changed outcomes without a fabricated composite fun score.
3. **Given** a candidate tuning that breaks the milestone-005 progression route, **When** the regression scenario runs, **Then** the change fails the release gate.

## 5. Edge Cases

- A building footprint touches multiple stops or multiple road components.
- A road auto-tiles into a different visual road item while retaining the same
  semantic connection.
- Roads connect diagonally but not orthogonally.
- A route exists at assignment time and is demolished before the next hour.
- Several workplaces compete for fewer reachable residents.
- A resident can reach multiple equal-distance destinations with equal benefit.
- A resident is rehomed into a different road component while assigned.
- A building opens or closes across midnight.
- A commercial venue is connected to homes but there is no industrial output or
  spendable commercial demand.
- A building is connected and open but has zero authored capacity.
- A multi-cell building gains access along a satellite footprint cell.
- A disconnected building has local nuisance effects that do not require
  participation; those local effects remain applicable when authored.
- A home lies exactly on a local effect's radius boundary.
- Positive local effects overlap and must count each affected resident once per
  authored stacking rule rather than once per tile or route.
- Two layouts have the same bounding box but very different nuisance exposure,
  proving raw footprint size is not the incentive metric.
- A spread neighbourhood is connected only through one bridge road and loses
  both access and its access-dependent benefits when that road is removed.
- The starter plot cannot express the full comparison until earned donated land
  is available; the test must distinguish early land pressure from the later
  spatial choice rather than silently enlarging a normal fresh map.
- A nature source sits beside a vacant residential building whose slot is being
  evaluated by a migration candidate; its local effects count for that home
  without becoming a global nature bonus.
- Nature is dumped on unused edge land with no home or participant in range.
- Four or more duplicate positive effects overlap the same resident.
- A varied functional green mix is compared with a repeated-item layout under
  the same nature-cell and cash envelope.
- Greenery and nuisance overlap the same home; neither signed effect disappears.
- A visually attractive destination is disconnected and therefore retains only
  genuinely local effects, not participant benefits.
- A route is longer on paper but consumes no scarce resource and changes no
  outcome; its raw length cannot satisfy the spatial trade-off gate.
- Map load, clear, overbuild replacement, and mass road painting update many
  components in one frame.
- Visible pedestrian or car movement fails while deterministic simulation state
  remains valid.
- Narrative presentation is disabled during the core balance scenarios.

## 6. Requirements

### Functional Requirements

- **FR-001**: One canonical connectivity service MUST derive road access, connected components, and route reachability from authoritative placed state.
- **FR-002**: Connectivity queries MUST consider every footprint cell and MUST return stable evidence and reasons.
- **FR-003**: Road placement, demolition, replacement, reset, and map load MUST invalidate and refresh affected connectivity before the next simulation update.
- **FR-004**: Buildings MAY be placed while disconnected, but disconnected state MUST be visible and MUST suppress access-dependent operation.
- **FR-005**: Worker and participant allocation MUST use route-reachable residents and deterministic tie-breaks.
- **FR-006**: Simulation allocation MUST NOT depend on visual path completion, render frames, or wall-clock timing.
- **FR-007**: Industrial output and budget supply MUST be based on fulfilled reachable workers rather than registered workplace capacity alone.
- **FR-008**: Tax income MUST be based on canonical operational output and MUST be zero when that output is zero.
- **FR-009**: Commercial-demand growth MUST use canonical operational industrial output.
- **FR-010**: Participant-scoped Community effects MUST apply only to canonically assigned, reachable participants.
- **FR-011**: Local, resident, and city effects MUST retain authored scope and schedule behavior independent of participant connectivity.
- **FR-012**: Stale work and activity assignments MUST clear after disconnection, demolition, closure, departure, or rehoming.
- **FR-013**: A fresh town MUST expose useful tier-one choices and MUST keep tier-two choices locked at hour zero.
- **FR-014**: The successful connected baseline MUST earn tier-two availability through simulated play.
- **FR-015**: Every tuning change MUST be data-driven where the existing schema supports it and compared against the same scenario, seed, and actions.
- **FR-016**: Starter T1/T2 growth and amenity entries MUST author Community consequences or an explicit validated declaration of no direct effect.
- **FR-017**: Effect records MUST remain explainable through source, quality, scope, amount, manifestation, schedule, and reason.
- **FR-018**: Player inspection MUST distinguish availability, connectivity, open state, operation, and latest contribution.
- **FR-019**: Non-operational reasons MUST include at minimum `no_road_access`, `isolated_road_component`, `no_reachable_residents`, `outside_active_hours`, and `no_free_capacity` where applicable.
- **FR-020**: Radial details and placement feedback MAY warn about expected access but MUST query canonical connectivity rather than recreate graph rules.
- **FR-021**: The HUD MUST NOT present the same Community-derived value simultaneously as both Satisfaction and Community happiness.
- **FR-022**: Connectivity and operation fields MUST be included in playtest snapshots and state hashes where they affect gameplay.
- **FR-023**: Existing deterministic replay and exact-hour advancement guarantees MUST remain intact.
- **FR-024**: The complete first-patron route from milestone 005 MUST remain reachable after final tuning.
- **FR-025**: Core balance scenarios MUST complete without consuming narrative dialogue or depending on authored story copy.
- **FR-026**: Connectivity recomputation and hourly allocation MUST remain within the existing simulation performance budgets at the supported 500-resident test scale.
- **FR-027**: Positive and negative local Community effects MUST derive exposure from canonical resident and source positions using their authored scope and radius.
- **FR-028**: Spatial layout incentives MUST arise from canonical exposure, coverage, connectivity, road, route-distance, and land-use outcomes; the game MUST NOT use an unexplained global density or spread score.
- **FR-029**: The canonical compact-versus-spread comparison MUST hold non-road buildings, capacity, seed, starting resources, and elapsed simulation time constant and MUST record all differing anchors and required road cells.
- **FR-030**: Separation alone MUST NOT grant access-dependent operation, output, income, participation, or migration effects when the separated component is disconnected.
- **FR-031**: Player and playtest inspection MUST expose negative-effect resident counts, positive local-effect resident coverage, road-cell count, route distance, and occupied-land evidence used to explain spatial outcomes.
- **FR-032**: Final tuning MUST preserve at least one viable compact opening and one viable spread opening, with neither layout strictly dominating across Community benefit, network footprint, land use, and economic progression.
- **FR-033**: Residential demand, migration, unlocks, and progression MUST NOT use an uncapped city-wide total that rises from unserved nature or decorative object count; nature may influence those outcomes only through placed residential receivers, candidate-home evaluation, or actual resident/participant outcomes.
- **FR-034**: Every player-selectable nature item MUST declare a named Community role or an explicit cosmetic-only role, and cosmetic-only content MUST be excluded from balance and progression totals.
- **FR-035**: Positive same-group effects affecting one resident MUST use the authored finite stacking policy, defaulting to `1.0`, `0.5`, `0.25`, then `0.0`; moving the same source to a previously unserved resident MUST restore its normal first-source contribution.
- **FR-036**: Positive nature effects MUST coexist with rather than cancel, absorb, or relabel independently applicable pollution, noise, crowding, or visual nuisance effects.
- **FR-037**: Nature and nuisance placement feedback MUST preview authored effect category, radius, homes in range, newly served homes, and overlapping coverage, then reconcile with canonical affected-resident evidence after simulation.
- **FR-038**: Every spatial comparison MUST carry a machine-readable pair manifest declaring the held constants, deliberate differences, nature and non-road building multisets, cash envelope, capacity, resident/cohort stream, seed, and duration; the comparator MUST reject a pair whose declared invariants do not match its actual traces.
- **FR-039**: A spatial cost counts as a trade-off only when it changes cash, remaining buildable land, an available useful placement, fulfilled capacity, or milestone timing; an inert route-distance or extent metric alone MUST NOT pass review.
- **FR-040**: Final tuning MUST preserve materially different successful layout families and MUST NOT require a fixed green quota, asset-diversity bonus, preferred silhouette, or hidden beauty score.
- **FR-041**: Release acceptance MUST include an unprompted player-behaviour gate and an anonymised fixed-view visual review using a frozen protocol, rubric, seeds, and thresholds.
- **FR-042**: A fresh game MUST offer a zero-cost Town Hall as its only first functional placement; the Town Hall is unique and protected from ordinary demolition.
- **FR-043**: The Town Hall MUST be the root of the canonical road network. New road cells MUST extend the Town Hall-rooted component, and every later home, shop, workplace, civic building, and functional nature source MUST touch that rooted component when placed. Cosmetic ground tiles remain exempt.
- **FR-044**: Rooted placement decisions MUST come from RoadNetwork and expose stable `town_hall_required`, `town_hall_already_placed`, and `not_connected_to_town_hall` reasons to gameplay, UI, and playtests.
- **FR-045**: Town Hall proximity MUST use deterministic shortest road-route distance. At distance `0..5`, shops receive `+20%` activity and incremental income while occupied homes receive `-8` Liveability; at distance `6..10`, shops receive `+10%` and homes receive `-4`; beyond `10` there is no proximity effect.
- **FR-046**: Shop bonuses and housing penalties MUST expose the Town Hall route, band, multiplier or signed amount, and player-facing reason. Disconnection MUST remove both on the next canonical boundary.
- **FR-047**: A meaningful placement is a home, shop, workplace, civic building, or functional nature source. Individual road cells, pavement, cosmetic-only nature, replacements, and rejected actions MUST NOT count toward the pacing target.
- **FR-048**: Rebalance tuning MUST support at least three successful meaningful placements per real minute at the normal 120-second day cycle, without negative cash, exhausted useful choices, or counting pre-scripted/free duplicate placements.
- **FR-049**: Pacing evidence MUST preserve checkpoints at 5, 10, and 20 real minutes (60, 120, and 240 exact simulation hours) and include successful/rejected placement counts, category mix, road cells, rooted access, cash, demand, population, operation, Community outcomes, and occupied/remaining land.

### Key Entities

- **Road Component**: Deterministically identified set of mutually connected road cells.
- **Building Access State**: Building instance, footprint access cells, stops, component IDs, connected state, and reasons.
- **Reachable Pair**: Resident home and destination with canonical route evidence and distance.
- **Operational State**: Access, schedule, capacity, fulfilled count, contribution values, and all blocking reasons for one place at one simulation boundary.
- **Resident Assignment**: Resident, destination, purpose, schedule, route distance, and stable allocation order.
- **Spatial Exposure Record**: Effect source, authored radius and scope, resident ID, resident position, distance, stacking result, and applied amount.
- **Layout Comparison**: Matched town identity, non-road building multiset, changed anchors, road cells, route distances, occupied land, exposure and coverage counts, and terminal outcomes.
- **Layout Pair Manifest**: Pair identity, held constants, permitted differences, building and nature multisets, cash/land envelope, resident stream, seed, duration, and validation result proving the compared traces are admissible.
- **Resident-Serving Nature Record**: Nature source, named role, local homes or candidate slots reached, reachable participants, duplicate stacking ordinal, and applied amount.
- **Community-Driven Edit**: Unprompted player action, stated resident/place reason, prior evidence viewed, and next authoritative outcome used only as human-test evidence.
- **First-Town Balance Trace**: Matched opening strategy, seed, actions, milestone observations, outcomes, and terminal state.

## 7. Success Criteria

### Measurable Outcomes

- **SC-001**: At hour zero, all three growth buckets have at least one selectable tier-one choice and zero selectable tier-two choices.
- **SC-002**: In a 48-hour roadless mixed scenario, worker-derived industrial output, tax income, and reachable workplace participation remain zero.
- **SC-003**: In the matched connected scenario, daytime industrial output and tax income become positive and every filled slot is traceable to a reachable resident.
- **SC-004**: After 48 hours, canonical connected-baseline cash is positive but no greater than twice the starting grant unless a recorded design review deliberately amends this ceiling.
- **SC-005**: Tier two unlocks after at least one tier-one placement and simulated progression, and before the successful canonical scenario terminates.
- **SC-006**: Disconnecting one critical road changes all affected operational outcomes on the next simulation update with no stale assignments.
- **SC-007**: In the seven-day matched Community comparison, the amenity-supported connected town ends with a larger population than the nuisance/isolated town under equal housing capacity.
- **SC-008**: Every player-selectable starter T1/T2 growth and amenity entry passes Community-consequence content validation.
- **SC-009**: For every non-operational fixture, UI and playtest projections return the same primary reason and complete reason set.
- **SC-010**: Repeating each canonical scenario ten times yields equivalent milestone observations and final balance-relevant hashes.
- **SC-011**: A before/after report records connectivity, output, income, cash, demand, population, happiness, attractiveness, progression, and rejection differences for every accepted tuning pass.
- **SC-012**: The milestone-005 full patron scenario remains passing, and all existing Godot, server, Community, Player UI, and live deterministic suites remain passing.
- **SC-013**: After 168 matched hours, the connected spread layout has strictly fewer residents exposed to industrial nuisance and higher mean Liveability than the connected compact layout, while fulfilling no fewer required workplace assignments.
- **SC-014**: With the same count and type of local amenities, the distributed layout applies positive local effects to more distinct residents than the clustered layout.
- **SC-015**: The spread comparison records a greater road-cell count, total route distance, occupied-land extent, or more than one of these quantities, and at least one resulting change to cash, remaining buildable land, an available useful placement, fulfilled capacity, or milestone timing; a spatial benefit with no felt trade-off fails review.
- **SC-016**: Ten repeats of each compact/spread pair produce equivalent exposure sets, coverage sets, assignments, milestones, and final balance-relevant hashes within each layout.
- **SC-017**: In the 168-hour resident-serving-versus-unserved nature pair, the integrated layout has at least `+3.0` higher mean Beauty and at least `+2.0` higher mean Liveability or Belonging, while the unserved nature creates no residential-demand, migration, unlock, or progression gain solely from object count.
- **SC-018**: In the duplicate-overlap fixture, positive same-group stacking is exactly `1.0`, `0.5`, `0.25`, then `0.0` for the fourth and later sources affecting one resident; the same source moved to a previously unserved resident contributes at `1.0` for that resident.
- **SC-019**: Under the frozen equal nature-cell and cash envelope, a functional mixed-green layout is no worse than repeated-item spam on distinct-resident Beauty coverage and improves at least one of Liveability or Belonging; neither layout receives participant or progression benefit from unserved sources.
- **SC-020**: A compact connected opening and a distributed nature-integrated opening both reach tier two within the accepted opening window without negative cash, and each is better on at least one declared dimension so neither strictly dominates the other.
- **SC-021**: In the frozen 12-player Blind Neighbourhood acceptance cohort, at least 9 players make one unprompted functional nature or nuisance-buffering action, at least 7 use both positive coverage and nuisance separation, at least 8 make a correctly understood feedback-to-layout edit, at least 9 reach the economic/progression objective, and no more than 2 identify repeated single-item spam as the dominant strategy.
- **SC-022**: The same human cohort produces at least three materially different successful layout families; where the choices are simultaneously unlocked and affordable, at least 8 of 12 players use at least one functional nature source plus a second nature function or reachable shared place for different player-explained roles.
- **SC-023**: In anonymised fixed-view review, accepted towns achieve a cohort median of at least `3.5/5` for both nature integration and intentional composition with agreement from at least two of three reviewers; candidate towns win at least 65% of pairwise comparisons against the frozen pre-change baseline without scoring worse on road coherence.
- **SC-024**: Four returning acceptance players continue for one additional hour and at least three retain or extend functional mixed green neighbourhoods rather than replacing them with unserved decoration, repeated-item spam, or a packed layout that ignores local effects.
- **SC-025**: In the matched Community-composition fixture, changing only Identity, Freedom, and Care weights reverses the outcome ordering of at least two viable place or programme choices while preserving the same authored effect arithmetic and creating no cohort approval score.
- **SC-026**: On a fresh map, Town Hall is the only selectable functional choice, costs exactly zero cash and zero demand, and becomes the single rooted-network origin after placement.
- **SC-027**: An isolated first road, an isolated later road branch, and every disconnected functional building are rejected without mutation; a road adjacent to Town Hall and a functional building adjacent to its rooted component are accepted.
- **SC-028**: Canonical route fixtures prove exact shop bands of `+20%`, `+10%`, and `0%` and exact occupied-home Liveability penalties of `-8`, `-4`, and `0` at route distances `5`, `10`, and `11`; removing the connecting bridge clears the effects on the next hour.
- **SC-029**: The cadence scenario records at least 15 meaningful successful placements by 5 minutes/60 hours, 30 by 10 minutes/120 hours, and 60 by 20 minutes/240 hours; roads and cosmetic placements are reported separately and never satisfy these thresholds.
- **SC-030**: At every cadence checkpoint cash is non-negative, at least one useful choice in each unlocked functional category remains available, at least 90% of scripted meaningful attempts succeed, and no single repeated positive effect bypasses finite stacking.
- **SC-031**: The 20-minute evidence town contains at least 60 simultaneously placed meaningful structures across at least four functional categories, all rooted to Town Hall, with positive daytime operation and at least two resident-serving nature functions.
- **SC-032**: A normal-renderer fixed-view capture of the 20-minute town visibly distinguishes the Town Hall, connected road hierarchy, commercial centre, outer housing, and distributed functional nature; the screenshot manifest carries its exact checkpoint and counts.

## 8. Assumptions

- Milestone 005 has first established a reachable progression contract and
  canonical patron scenario.
- Roads, rather than visible people or cars, are the authoritative transport
  abstraction for this first balance pass.
- Town Hall placement precedes all other functional construction. Buildings
  may be previewed while disconnected, but placement is rejected until their
  footprint touches the Town Hall-rooted road component.
- Visible agents illustrate canonical assignments but do not determine them.
- Pavement remains decorative for this milestone.
- The existing aggregate Community qualities and migration model remain the
  player objective; this milestone supplies better inputs rather than replacing
  the model.
- The twice-starting-cash ceiling is an initial early-game guardrail and may be
  amended with recorded playtest evidence.

## 9. Test Seams

- **Unit**: footprint access, connected components, reachability, deterministic
  assignment, schedules, operation reasons, output calculations, exact radius
  boundaries, resident-serving nature, finite duplicate stacking, and content
  validation.
- **Integration**: RoadNetwork through Residential, Workplace, Commercial,
  Community, CityStats, Demand, Economy, HUD, placement preview, inspection,
  and Palette, including proof that unserved decoration cannot advance demand.
- **Scenario**: roadless mixed, connected mixed, single-purpose openings,
  amenity-versus-nuisance, matched compact-versus-spread, clustered-versus-
  distributed amenities, resident-serving-versus-unserved nature, functional
  mix-versus-spam, blank compact-versus-blank sprawl, cohort preference order,
  bridge removal, and the milestone-005 patron route.
- **Balance**: immutable before trace, one-hypothesis tuning fixtures, matched
  comparison manifests, rejected mismatches, explicit felt spatial trade-off
  metrics, exploit layouts, and recorded design decisions.
- **Performance**: road edits at representative city size and 168 hourly updates
  with 500 residents.
- **Visual**: disconnected placement warning, isolated component, operating
  workplace, resident assignment, tier-two unlock, land-pressure milestone, and
  matched compact/spread and nature-integrated maps with effect-radius evidence,
  plus the frozen anonymised Blind Neighbourhood review.

## 10. Dependency and Handoff

This specification depends on `005-reachable-first-patron`. Its final canonical
state becomes the gameplay payload that `007-save-lifecycle-release` must
preserve across save, load, quit, relaunch, and export.
