# Feature Specification: Community Happiness Simulation

**Feature Branch**: `002-community-happiness-simulation` *(planning identifier; no branch created)*

**Created**: 2026-09-04

**Status**: Draft

**Input**: Build a deterministic, per-resident community simulation in which
Opportunity, Liveability, Beauty, and Belonging determine happiness, while
Identity, Freedom, and Care determine how each resident interprets the sources
of those qualities. Population growth is the primary systemic objective.

## 1. Product Intent

This is a **community builder**, not a conventional infrastructure optimizer.
Buildings matter because they change what residents can experience: work,
services, recreation, social contact, noise, nature, culture, and mutual
support. Different residents can experience the same development differently.

The core loop is:

```text
Build or configure places
→ places emit local and participant effects
→ residents interpret those effects through their personalities
→ happiness changes gradually
→ happy, compatible places attract and retain population
→ the population mix changes future development pressure
```

The internal model may be complex, but the player-facing result MUST remain
legible: four headline qualities with a short, numerical explanation of their
largest positive and negative contributors.

## 2. Scope Boundary

### In scope

- Persistent simulated residents with deterministic personalities.
- Four experienced qualities: Opportunity, Liveability, Beauty, Belonging.
- Three interpretive lenses: Identity, Freedom, Care.
- Data-driven effects from buildings and facility programmes.
- Spatial exposure, participation, schedules, capacity, and direct nuisances.
- Gradual happiness changes, migration into free housing, and resident departure.
- Statistical personality cohorts used to seed diversity and migration candidates.
- Structured, explainable state exposed through the existing Playtest plugin.
- Deterministic headless scenarios for balancing population composition.

### Explicitly out of scope

- Quest generation, quest rewards, quest-gated migrations, or authored story logic.
- Faction approval, elections, laws, political loyalty, or another ideology score.
- A universal town personality selected by the player.
- Individual friendship graphs, families, romance, ageing, births, or death.
- Detailed goods production chains or household finances.
- Manually painted districts. Neighbourhood character is spatial and emergent.
- Additional public city-playtest MCP tools.

Quests may read simulation facts in a later feature, but this system MUST remain
coherent and fully testable with narrative presentation disabled.

## 3. Conceptual Model

### 3.1 Experienced qualities

Every resident has a current and target score from `0..100` for four orthogonal
qualities.

| Quality | Player-facing question | Typical sources |
|---|---|---|
| `opportunity` | What can I do here? | Jobs, education, shops, culture, recreation, nightlife, useful roles |
| `liveability` | How easily can I live here? | Housing, civic services, access, safety, quiet, cleanliness, low pollution |
| `beauty` | How does this place feel? | Parks, nature, architecture, maintained streets, heritage, visual vitality |
| `belonging` | How connected am I to this place and other people? | Gathering places, familiar culture, social variety, participation, mutual support |

These are the only four headline happiness scores. Identity, Freedom, and Care
MUST NOT appear as additional happiness bars.

### 3.2 Interpretive lenses

For each quality, every resident has three manifestation weights that sum to
`1.0`:

- `identity`: tradition, continuity, recognisable local culture, rootedness.
- `freedom`: variety, experimentation, autonomy, enterprise, finding one's people.
- `care`: accessibility, fairness, shared provision, support, mutual responsibility.

Two residents may assign equal importance to Belonging while disagreeing about
what produces it. A resident may prefer Identity-oriented Beauty but
Freedom-oriented Opportunity; personalities are not limited to one global
ideological label.

### 3.3 Direct effects versus interpreted effects

Effects with a manifestation tag are interpreted through personality:

```text
Belonging / Identity: +8 from recurring local plays
Belonging / Freedom:  +8 from finding a compatible music scene
Belonging / Care:     +8 from a staffed community meeting place
```

Objective conditions use `manifestation: neutral` and are not ideological:

```text
Liveability / Neutral: -10 from night-time noise exposure
Liveability / Neutral: -12 from pollution exposure
Opportunity / Neutral: +15 from holding a suitable job
```

A resident can support what a venue represents while being harmed by its noise.
Both contributions MUST remain visible in the explanation.

## 4. User Stories and Acceptance Scenarios

### User Story 1 — Different people experience the same place differently (P1)

As a player, I can see residents respond differently to the same facilities so
that development choices create meaningful trade-offs rather than universal
bonuses.

**Independent test**: Create two residents with equal Belonging importance but
opposite Identity/Freedom manifestation weights. Expose both to the same plays
and rock-programme effects. Their Belonging targets MUST differ in the expected
directions, with source-level explanations.

**Acceptance scenarios**:

1. A Freedom-oriented attendee gains Belonging from a rock programme.
2. An Identity-oriented attendee gains more Belonging from local plays than from rock.
3. A nearby resident exposed to rock noise loses Liveability even when they gain Belonging from attending.
4. A neutral nuisance affects equally exposed residents before personal sensitivity is applied.

### User Story 2 — Buildings create a complex but explainable happiness web (P1)

As a player, I can inspect why a resident or neighbourhood is thriving or
struggling so I can make an informed development choice.

**Independent test**: Place a park and a night venue beside occupied housing,
advance through day and night, and inspect all four qualities and their source
breakdowns.

**Acceptance scenarios**:

1. A park can contribute separately to Liveability and Beauty.
2. A night venue can contribute to Opportunity and Belonging while producing a timed Liveability nuisance.
3. Only residents inside a local effect radius receive its neighbourhood contribution.
4. Only actual participants receive participant-scoped benefits.
5. Explanations include source building, quality, manifestation, signed amount, scope, and active time.

### User Story 3 — Happiness grows or shrinks population (P1)

As a player, I grow the town by creating places that potential residents expect
to enjoy, while sustained poor experiences can cause existing residents to
leave.

**Independent test**: Run two otherwise identical towns with equal housing
capacity. Give one compatible amenities and the other persistent nuisances.
The first MUST attract more residents over seven days using the same candidate
stream and seed.

**Acceptance scenarios**:

1. No arrival occurs without free residential capacity.
2. A candidate chooses the available home with the highest predicted personal happiness.
3. A candidate below the configured migration threshold does not arrive.
4. A resident does not leave after a single bad hour.
5. A resident below the departure threshold for the full grace period leaves and frees their home slot.
6. Population totals equal the count of persistent resident records, not housing capacity multiplied by a global score.

### User Story 4 — Population composition emerges without faction mechanics (P2)

As a player, developments attract compatible personalities, causing
neighbourhoods to become distinctive without selecting a district type or
managing faction approval.

**Independent test**: Offer one Identity-heavy and one Freedom-heavy
neighbourhood to the same deterministic candidate stream. After seven days,
their resident personality distributions MUST differ measurably.

**Acceptance scenarios**:

1. General candidates contain broad individual variation.
2. Authored cohort prototypes seed some residents near personality extremes.
3. Cohorts affect generation only; there is no cohort happiness or approval score.
4. Individual noise, access, and participation still override a cohort prototype where applicable.
5. Specialisation remains viable; the simulation MUST NOT apply an arbitrary diversity bonus or monoculture penalty.

## 5. Data Model

All persisted and playtest-visible values MUST be JSON-safe. Floating-point
balance values are rounded to four decimal places in snapshots.

### 5.1 CommunityResident

| Field | Type | Description |
|---|---|---|
| `resident_id` | integer | Persistent, deterministic identity within a map |
| `seed` | integer | Personal generation seed |
| `cohort_id` | string/null | Generation prototype only; not faction membership |
| `home_anchor` | coordinate/null | Owning residential building; null while homeless |
| `quality_importance` | quality map | Non-negative weights summing to `1.0` |
| `manifestation_weights` | quality → lens map | Identity/Freedom/Care weights, each row summing to `1.0` |
| `sensitivities` | map | V1: `noise`, `pollution`, `crowding`, `travel`; default `1.0` |
| `current_qualities` | quality map | Smoothed `0..100` experienced values |
| `target_qualities` | quality map | Current effects evaluated to `0..100` |
| `composite_happiness` | float | Weighted result used for migration/retention, not the only UI explanation |
| `below_departure_hours` | integer | Consecutive hours below departure threshold |
| `activity_assignment` | object/null | Current workplace, venue, or service participation |

Resident records MUST persist across save/load, map reconciliation, and building
changes. Demolishing an occupied home makes its residents homeless for the
configured relocation grace period; it MUST NOT silently delete them.

### 5.2 PersonalityCohort

A data-authored statistical prototype:

| Field | Type | Description |
|---|---|---|
| `cohort_id` | string | Stable identifier |
| `display_name` | string | Debug/design label only |
| `quality_importance_centre` | quality map | Mean importance vector |
| `manifestation_centre` | quality → lens map | Mean lens matrix |
| `variation` | float | Deterministic deviation around the prototype |
| `candidate_weight` | float | Relative frequency in the migration pool |

Initial content SHOULD include moderate general residents plus Identity-heavy,
Freedom-heavy, and Care-heavy prototypes. Generated residents MUST vary around
the prototype and MUST NOT be identical.

### 5.3 CommunityEffectProfile

Building JSON gains an optional profile containing effect definitions.

| Field | Type | Rules |
|---|---|---|
| `effect_id` | string | Stable within the source building/programme |
| `quality` | enum | `opportunity`, `liveability`, `beauty`, `belonging` |
| `manifestation` | enum | `identity`, `freedom`, `care`, `neutral` |
| `amount` | float | Signed target-score contribution before personalisation |
| `scope` | enum | `local`, `participant`, `resident`, `city` |
| `radius` | integer/null | Required for local effects; grid distance |
| `schedule` | object/null | Optional inclusive start and exclusive end hour |
| `capacity` | integer/null | Maximum simultaneous participants when applicable |
| `sensitivity` | string/null | Optional sensitivity multiplier, e.g. `noise` |
| `stacking_group` | string | Effects in the same group use diminishing stacking |
| `requires_active_building` | boolean | Inactive/unserved buildings may stop emitting benefits |

Facility programmes are named sets of effects attached to a building. Programme
selection is a normal gameplay setting, not a quest outcome. The first slice
may use fixtures if programme-selection UI is not yet present.

### 5.4 AppliedEffect

The evaluated, explainable contribution retained for a resident and hour:

```json
{
  "source_building_id": "building_nightclub",
  "source_anchor": { "x": 2, "z": 1 },
  "effect_id": "late_music_belonging",
  "quality": "belonging",
  "manifestation": "freedom",
  "scope": "participant",
  "base_amount": 8.0,
  "exposure": 1.0,
  "preference_multiplier": 1.3,
  "sensitivity_multiplier": 1.0,
  "applied_amount": 10.4,
  "reason": "Found people with similar interests"
}
```

The authored `reason` is concise UI copy. Simulation logic MUST NOT parse it.

## 6. Deterministic Simulation Rules

### 6.1 Personality generation

All random generation uses the active playtest/session seed or persisted map RNG
state. Global `randf`, wall-clock time, and array iteration order MUST NOT affect
results.

1. Select a cohort from authored candidate weights.
2. Perturb its quality-importance vector deterministically and renormalize.
3. Perturb each quality's three manifestation weights and renormalize each row.
4. Generate sensitivities within authored bounds and clamp them.
5. Assign the next persistent resident ID.

The exact sampling function MUST be unit tested and stable for a declared schema
version. Changing it later requires a personality-generation version field.

### 6.2 Effect personalisation

For a tagged effect with resident manifestation weight `w`:

```text
preference_multiplier = 0.5 + (1.5 × w)
```

An evenly weighted resident (`w = 1/3`) receives the authored amount, while a
strong preference amplifies it and a weak preference reduces rather than
completely erases it. For `manifestation: neutral`, the preference multiplier
is `1.0`.

```text
applied_amount =
  base_amount
  × exposure
  × preference_multiplier
  × sensitivity_multiplier
  × stacking_multiplier
```

V1 exposure is `1.0` when the scope condition is met and `0.0` otherwise.
Distance falloff may be added later only with tests and visible explanations.

### 6.3 Stacking

Within the same `stacking_group`, sort applicable effects deterministically by
absolute amount, source anchor, building ID, then effect ID. Apply multipliers:

```text
first source:  1.00
second source: 0.50
later sources: 0.25
```

Negative nuisances and positive amenities use separate stacking groups unless
content explicitly combines them. This prevents unlimited overlapping parks
from exploding a score while keeping additional sources useful.

### 6.4 Quality targets and smoothing

Each quality begins from an authored neutral baseline of `50`:

```text
target_quality = clamp(50 + sum(applied effects), 0, 100)
current_quality += (target_quality - current_quality) × hourly_response_rate
```

Default `hourly_response_rate` is `0.10`. Content may define a different rate
per quality only after the basic slice is balanced.

```text
composite_happiness =
  Σ(current_quality[q] × quality_importance[q])
```

Composite happiness drives migration and retention. The UI and MCP MUST retain
the four qualities and their contributors; the composite MUST NOT replace them.

### 6.5 Participation

At each simulation hour:

1. Determine which buildings/programmes are active.
2. Keep valid existing assignments where possible.
3. Assign unassigned residents to suitable work, service, or leisure capacity in
   stable resident-ID order.
4. Rank destinations by predicted personal benefit, then travel distance, then
   source anchor/building ID for deterministic ties.
5. Apply participant effects only to assigned residents.
6. Apply residential/local effects from the resident's home position.

V1 may use grid distance. Road-network travel may replace distance later, but
access and travel penalties MUST remain explainable.

### 6.6 Migration and retention

Migration evaluates once per simulation day at a fixed authored hour.

- Generate a bounded deterministic candidate batch.
- Evaluate each candidate against every free housing slot.
- Predicted happiness uses that home's current local conditions plus accessible
  city and participant opportunities without mutating resident state.
- The candidate selects the highest-scoring home using canonical tie-breaking.
- Arrival requires predicted composite happiness at or above `60`.
- At most one resident occupies one housing-capacity slot.

Departure evaluation occurs hourly:

- Below `30` composite happiness increments `below_departure_hours`.
- At or above `30` resets it to zero.
- A housed resident leaves after 24 consecutive below-threshold hours.
- A homeless resident receives a separate 24-hour relocation grace period.

All thresholds are balance data, not magic constants repeated across plugins.

## 7. Initial Content Slice

The first implementation MUST prove the model with existing content or test
fixtures representing:

### Park or natural space

- `liveability/care`: accessible recreation.
- `beauty/care`: maintained shared greenery.
- `beauty/identity`: preservation of local landscape.
- Optional `belonging/care`: informal meeting place when participated in.

### Night venue

- `opportunity/freedom`: entertainment and evening roles.
- `belonging/freedom`: finding a compatible crowd.
- `beauty/freedom`: vibrancy and novelty.
- `liveability/neutral`: scheduled local noise nuisance.

### Industrial workplace

- `opportunity/neutral`: suitable employment for participants.
- `liveability/neutral`: local noise or pollution nuisance.
- `beauty/neutral`: negative industrial visual effect where authored.

### Theatre programme fixture

| Programme | Effects |
|---|---|
| `plays` | Beauty/Identity +3, Belonging/Identity +3, Opportunity/Identity +1 |
| `rock_nights` | Opportunity/Freedom +3, Belonging/Freedom +3, Beauty/Freedom +2, local night noise |
| `community_use` | Belonging/Care +4, Liveability/Care +2, Opportunity/Care +1 |

Exact final values require balance traces; these are starting fixtures, not
accepted final tuning.

## 8. Integration with the Existing Project

### 8.1 Authority and plugin boundary

Add a dedicated community simulation plugin rather than placing this logic in
`builder.gd`. It listens to canonical building, map, and hour events and reads
catalog profiles through dependency injection.

The plugin owns resident persistence and IDs, personality generation, happiness
activity assignments, effect evaluation, migration, departure, and population
composition snapshots.

### 8.2 Existing population shortcut

The current Residential plugin reports population as:

```text
housing capacity × global satisfaction
```

That MUST be replaced as gameplay authority. Residential continues to own and
report housing capacity; current population becomes the count of
CommunityResident records. The legacy `get_current_population()` API may
delegate to the community plugin during migration so existing Workplace,
Demand, CityStats, and Playtest consumers continue to function.

The People plugin currently spawns visible people from full residential
capacity. It MUST instead render the persistent resident population, or a
deterministic bounded visual subset, without becoming the authority for
happiness or migration.

### 8.3 Existing Satisfaction and Attractiveness

- Satisfaction becomes a compatibility facade over community happiness. Its
  legacy `get_score()` may return normalized average composite happiness for
  existing systems, but the four-quality model remains authoritative.
- Existing AttractivenessProfile content should be translated or migrated into
  Beauty and Liveability effects rather than applied twice.
- Existing day/night `hour_changed` and exact manual advancement remain the only
  simulation-hour boundary.

### 8.4 Persistence

Extend the map/save schema with resident records, the next resident ID,
personality-generation version/state, home assignments, unhappiness and
homelessness counters, and selected facility programmes when implemented.

Loading older maps creates residents deterministically from occupied housing
using an explicit migration version; it MUST NOT use wall-clock randomness.

### 8.5 Playtest MCP

Do not add public MCP tools. Extend normalized snapshots returned by existing
tools with:

```text
community.population
community.capacity
community.average_qualities
community.personality_distribution
community.migration
community.residents[]
community.effect_summary[]
```

Each resident record includes personality, four current/target qualities,
composite happiness, home, activity, and top positive/negative AppliedEffects.
Compact state may omit full resident/effect arrays while retaining aggregates.

## 9. Functional Requirements

- **FR-001**: Population MUST equal persistent resident count.
- **FR-002**: Housing buildings MUST provide capacity rather than population automatically.
- **FR-003**: Every resident MUST have deterministic quality importance, per-quality manifestation weights, and sensitivities.
- **FR-004**: The four quality scores MUST be Opportunity, Liveability, Beauty, and Belonging only.
- **FR-005**: Identity, Freedom, and Care MUST modify tagged manifestations and MUST NOT become independent happiness scores.
- **FR-006**: Buildings and programmes MUST author effects as data, not building-ID conditionals in the simulation plugin.
- **FR-007**: Effects MUST distinguish local, participant, resident, and city scopes.
- **FR-008**: Scheduled nuisances and benefits MUST activate only during their authored hours.
- **FR-009**: Every applied effect MUST preserve a source and numerical explanation.
- **FR-010**: Quality changes MUST be gradual and bounded `0..100`.
- **FR-011**: Migration MUST require free housing and sufficient predicted personal happiness.
- **FR-012**: Persistent severe unhappiness MUST allow departure after a grace period.
- **FR-013**: Personality cohorts MUST remain generation templates, not approval meters or mandatory factions.
- **FR-014**: The simulation MUST remain deterministic under explicit seed and exact manual time advancement.
- **FR-015**: Existing UI and automated building actions MUST trigger the same community effects.
- **FR-016**: Narrative presentation and quest state MUST not be required for community simulation.
- **FR-017**: Snapshot collections and resident/effect histories MUST be bounded.
- **FR-018**: Loading or resetting a scenario MUST completely reset community residents, counters, and RNG state.

## 10. Required Tests

### Unit tests

- Personality vectors normalize and reproduce from a declared seed.
- Different seeds vary meaningfully around cohort prototypes.
- Per-quality manifestation weights are independent.
- Neutral and tagged effect formulas match exact expected values.
- Stacking order and diminishing multipliers are deterministic.
- Radius, schedule, participant, capacity, and sensitivity rules apply correctly.
- Quality smoothing and clamping behave at `0`, `100`, and intermediate targets.
- Composite happiness uses quality-importance weights.
- Migration quote is non-mutating and selects the best legal home.
- No-capacity, below-threshold, arrival, relocation, grace-period, and departure cases.
- Save/load and map reset preserve or clear the correct state.

### Integration tests

- Park affects Liveability and Beauty as distinct explained contributions.
- Night venue benefits an attendee while harming a nearby non-attendee through noise.
- Two residents with equal Belonging importance but different lenses react differently.
- Residential capacity no longer creates population without migration.
- Community population feeds existing workplace, demand, satisfaction facade, and snapshots.
- UI placement and playtest placement produce identical community results.

### Deterministic scenarios

1. `community_personality_contrast`: fixed residents, plays versus rock effects.
2. `community_park_and_noise`: homes exposed to park and scheduled night venue.
3. `community_migration_week`: identical candidate stream across two differently developed neighbourhoods.
4. `community_retention_failure`: persistent nuisance and insufficient alternatives.

Every scenario records hourly quality aggregates, arrivals, departures,
population composition, and top effect reasons.

## 11. Success Criteria

- **SC-001**: Same scenario, seed, buildings, programmes, and hours produce identical resident records and quality snapshots in 10/10 runs.
- **SC-002**: The personality-contrast test produces opposite ranked Belonging responses for Identity-heavy and Freedom-heavy residents.
- **SC-003**: The park-and-noise scenario shows simultaneous positive and negative effects without collapsing either into one opaque modifier.
- **SC-004**: Over a seven-day migration comparison, the better-matched town attracts more residents from the identical candidate stream.
- **SC-005**: Every quality change in acceptance scenarios traces to one or more structured AppliedEffects.
- **SC-006**: No resident arrives beyond housing capacity and no resident leaves before the configured grace period.
- **SC-007**: At least 500 residents can be simulated for 168 exact hours in under 10 seconds on the development machine.
- **SC-008**: Existing city-building tests and the six-tool playtest contract remain passing after population authority migrates.

## 12. Implementation Order for a Fresh Task

1. Write deterministic personality, effect-formula, and migration tests.
2. Add data classes and schemas for residents, cohorts, and community effects.
3. Implement a pure, headless effect evaluator with no UI dependencies.
4. Implement persistent resident population and deterministic migration.
5. Integrate the authoritative hour boundary and building events.
6. Migrate Residential, Satisfaction, and People compatibility APIs.
7. Add park, night venue, workplace, and theatre-programme fixtures.
8. Extend Playtest snapshots without adding tools.
9. Run deterministic week-long population comparisons and tune from traces.

The implementation is ready for review only when it can explain, for one
resident, both “I love what this venue brings to the town” and “I cannot sleep
because I live next to it” as simultaneous, independently traceable facts.
