# Feature Specification: Opening Playtest Polish

**Feature Branch**: `019-opening-playtest-polish`

**Created**: 2026-09-06

**Status**: Complete and verified

**Input**: Apply the bounded mini-task pass from the 2026-09-06 narrated
playthrough: compact the existing location panel, improve opening tutorial pacing and
wording, retune two early unique unlocks, and remove the plain grass variant from the
player-facing nature pool.

## Scope and boundaries

This feature is a polish pass over existing systems and authored data. It does not add a
new simulation authority, quest framework, building category, or asset-production
workflow.

The pass explicitly excludes:

- floating or world-space placement-impact capsules above affected buildings;
- repairs, grass infill, scaling, Blender work, or other changes to building models and
  their bases;
- a broad progression sweep, new buildings, or new medical/service simulation; and
- relocation into, or redesign of, the expanded bottom bar.

The existing right-hand insights/dashboard direction is unchanged. The existing first
land quest remains the post-tutorial handoff. The 100 fulfilled-Shops character target
remains later progression state, but it must not appear to be an opening tutorial step
or displace the active tutorial/first-quest direction.

## User Scenarios & Testing

### User Story 1 - See Only Useful Location Changes (Priority: P1)

As a player positioning a held building, I see a small location panel containing only
consequences that change or require my attention, rather than a large list of stable
zeroes and routine confirmations.

**Why this priority**: The current panel obscures too much of the town during the game's
most spatially demanding interaction.

**Independent Test**: Feed the existing panel valid unchanged, valid changed, invalid,
replacement, failed-access, and uncertain quotes; verify only actionable rows remain and
the panel collapses or hides when no useful row exists.

**Acceptance Scenarios**:

1. **Given** a valid location whose four Community deltas and town-appeal delta are all
   zero, **When** the quote renders, **Then** zero-value quality, zero affected-count,
   zero effect-reach, and routine “access valid” rows are omitted.
2. **Given** one or more non-zero quality or attractiveness changes, **When** the quote
   renders, **Then** only those changed measures and their non-zero affected evidence are
   shown in the existing panel.
3. **Given** placement is invalid, replaces a building, lacks required access, or has a
   material uncertainty, **When** the quote renders, **Then** the relevant warning remains
   visible even if every numeric delta is zero.
4. **Given** no changed measure or actionable warning remains, **When** the quote renders,
   **Then** the location panel does not reserve its previous large empty footprint.

---

### User Story 2 - Learn the Opening at the Intended Pace (Priority: P1)

As a new player guided by Ambrose, I establish a useful ten-tile rooted road run before
housing, receive a truthful adjacency instruction, and leave the tutorial immediately
after placing the first qualifying shop.

**Why this priority**: The opening currently unlocks housing guidance too close to the
Town Hall, overstates which house must be adjacent, and allows an unrelated 100-demand
progression hint to read like the tutorial's next instruction.

**Independent Test**: Start a fresh rooted town, place connected and disconnected roads,
complete the nature and housing experiments with different eligible house pairs, then
place one rooted tier-one shop and verify the tutorial-to-first-quest handoff.

**Acceptance Scenarios**:

1. **Given** the Town Hall is placed, **When** the rooted component contains fewer than
   ten road cells, **Then** Ambrose continues to request roads and reports progress
   against ten; disconnected road cells do not count.
2. **Given** the rooted component reaches ten road cells, **When** reconciliation runs,
   **Then** the road receipt is written once and the tutorial may proceed toward nature
   and housing.
3. **Given** at least two eligible early homes exist, **When** a newly placed home is
   adjacent to any other eligible home, **Then** the adjacency lesson can use that stable
   pair; it does not require adjacency specifically to the first home ever placed.
4. **Given** the adjacency lesson is active, **When** Ambrose presents it, **Then** the
   direction says “another home” or equivalent and never claims it must be next to “the
   first house.”
5. **Given** the preceding opening lessons are complete, **When** the first tier-one shop
   with rooted road access is committed, **Then** the tutorial completes and emits its
   existing exactly-once first-quest handoff without any additional 100-demand tutorial
   objective.
6. **Given** the opening tutorial or its immediate first-quest handoff is active, **When**
   the Dashboard chooses its primary direction, **Then** that direction takes precedence
   over generic character-arrival text such as “Grow commercial: 0/100 fulfilled.”

---

### User Story 3 - Reach Early Uniques at Better Moments (Priority: P1)

As a player, I unlock the Postwar Terrace and Pub after enough play to make each feel
earned rather than seeing them available at or almost immediately after the starting
state.

**Why this priority**: These two premature unlocks undermine the intended opening rhythm
and make the build catalogue feel exhausted too quickly.

**Independent Test**: Drive lifetime Homes and Shops demand across the exact boundaries
39/40 and 14/15 while varying current spendable and fulfilled values; verify the two
unlocks use lifetime totals only.

**Acceptance Scenarios**:

1. **Given** lifetime Homes demand is below 40, **When** availability refreshes, **Then**
   the Postwar Terrace remains locked even if starting/current Homes demand is sufficient
   for an ordinary house.
2. **Given** lifetime Homes demand reaches 40, **When** availability refreshes, **Then**
   the Postwar Terrace unlocks under its existing prerequisite and uniqueness rules.
3. **Given** lifetime Shops demand is below 15, **When** availability refreshes, **Then**
   the Pub remains locked.
4. **Given** lifetime Shops demand reaches 15, **When** availability refreshes, **Then**
   the Pub unlocks under its existing prerequisite and uniqueness rules.
5. **Given** either threshold is displayed in demand hover or structured progression
   state, **When** the value is read, **Then** it is labelled and sourced as lifetime
   demand rather than current spendable or fulfilled demand.

---

### User Story 4 - Build Nature Without the Plain Grass Variant (Priority: P2)

As a player selecting the existing Grass nature pool, I receive only its planted/tree
variants and never spend a placement on the plain grass tile.

**Why this priority**: The plain tile adds little visual or gameplay value and makes the
small opening nature selection feel less intentional.

**Independent Test**: Enumerate and repeatedly select/place the `grass` palette pool with
declared random seeds; verify the plain `grass` building is never previewed or committed,
while its existing save/catalog identity remains readable.

**Acceptance Scenarios**:

1. **Given** the catalogue contains `grass`, `grass_trees`, and `grass_trees_tall`,
   **When** Palette builds the player-facing `grass` pool, **Then** only the two planted
   variants are selectable pool members.
2. **Given** any declared placement seed, **When** the player previews or places from the
   `grass` pool, **Then** the result is never the plain `grass` building.
3. **Given** an older map already contains the plain `grass` building ID, **When** the map
   loads, **Then** that building remains resolvable, visible, and demolishable; this pass
   changes build availability rather than deleting catalogue/save content.

### Edge Cases

- A location quote contains a non-zero delta rounded from a small float; semantic
  non-zero status, not formatted text, determines whether its row is shown.
- A quote has no deltas but includes multiple warnings; warnings remain bounded and use
  the existing priority/order rules.
- A save already contains the durable four-road tutorial receipt from the previous
  version. Monotonic progress is preserved; existing receipts are not revoked, while new
  games and incomplete saves use ten.
- The player places more than ten rooted roads in one action or connects a previously
  disconnected component that takes the rooted total past ten.
- Several homes were pre-built before the adjacency step; pair selection is stable and
  records the exact two homes used for the observation.
- An adjacent pair predates observable baseline evidence. The tutorial preserves the
  existing “baseline unavailable” honesty and asks for a new observable qualifying
  action instead of fabricating a penalty.
- A shop was placed early, demolished, replaced, or exists in a loaded save. Existing
  monotonic receipts and exactly-once handoff behavior remain intact.
- The Dashboard has an active tutorial direction, pending first quest, character arrival,
  character want, and patron milestone at the same time; the documented priority order
  is deterministic.
- Filtering the plain grass variant changes seeded pool selection. Updated deterministic
  fixtures record the intentional new concrete variants rather than preserving an
  obsolete random sequence.

## Requirements

### Functional Requirements

- **FR-001**: The location panel MUST derive presentation rows from the existing detached
  placement-consequence quote and MUST NOT introduce a second simulation calculation.
- **FR-002**: The location panel MUST omit zero Community-quality deltas, zero
  attractiveness deltas, zero affected counts, empty effect reach, and routine valid
  access confirmations.
- **FR-003**: The location panel MUST retain invalid-placement, replacement, failed-access,
  and material-uncertainty rows regardless of numeric deltas.
- **FR-004**: The location panel MUST collapse or hide when its filtered row model is
  empty and MUST size itself from the remaining row count.
- **FR-005**: This pass MUST NOT move placement consequences into the bottom dock, change
  the dock's information architecture, or add world-space impact indicators.
- **FR-006**: A fresh or incomplete opening tutorial MUST require at least ten road cells
  in the Town Hall-rooted component before completing `connect_rooted_roads`.
- **FR-007**: Disconnected roads MUST NOT count, and progress MUST expose current rooted
  cells against the required ten.
- **FR-008**: Previously valid durable road receipts MUST remain honored after upgrade;
  tutorial progression MUST remain monotonic across save/load.
- **FR-009**: The adjacent-home lesson MUST accept a newly observed adjacency between any
  two eligible early homes and persist the exact stable pair used as evidence.
- **FR-010**: Adjacency guidance MUST describe placing beside “another home” or equivalent
  and MUST NOT require “the first house” in player-facing copy.
- **FR-011**: The first rooted, eligible tier-one shop MUST remain the terminal opening
  tutorial gate and MUST produce the existing exactly-once
  `tutorial_opening_completed` receipt/signal.
- **FR-012**: The opening tutorial MUST contain no objective requiring 100 fulfilled
  Shops/commercial demand.
- **FR-013**: Dashboard direction priority MUST present the active opening tutorial and
  then its established first-quest handoff ahead of the generic unarrived-character
  demand target.
- **FR-014**: The Postwar Terrace's authored unique threshold MUST be 40 lifetime Homes
  demand.
- **FR-015**: The Pub's authored unique threshold MUST be 15 lifetime Shops demand.
- **FR-016**: Both unlocks MUST continue to use UniqueRegistry's canonical lifetime-demand
  evaluation and existing prerequisite, character, patron, and already-placed gates.
- **FR-017**: Demand/progression projections and tooltips MUST expose the new thresholds
  without hard-coded duplicate values.
- **FR-018**: Plain `grass` MUST remain catalogue- and save-resolvable but MUST be excluded
  by authored data from Palette entry construction, preview, random selection, and commit.
- **FR-019**: The player-facing `grass` pool MUST retain `grass_trees` and
  `grass_trees_tall` and MUST remain deterministic for a declared seed.
- **FR-020**: The build-data editor/validator and runtime manifest MUST preserve the
  authored palette-exclusion field or convention without silently dropping it.
- **FR-021**: Balance verification MUST record a before/after opening trace using the same
  seed and scenario, including terrace/pub unlock boundaries and first-shop handoff.
- **FR-022**: Automated coverage MUST include panel filtering, tutorial transition and
  persistence boundaries, Dashboard priority, exact unique thresholds, hidden pool
  membership, deterministic placement, and legacy plain-grass load compatibility.

### Key Entities

- **Filtered Location Presentation**: Transient ordered rows retained from the canonical
  consequence quote because they report a non-zero change or actionable warning.
- **Opening Tutorial Evidence**: Existing detached tutorial snapshot with a ten-road
  threshold and stable adjacent-home pair evidence.
- **Primary Direction**: The deterministic highest-priority active tutorial, first-quest,
  character, or patron instruction shown by the Dashboard.
- **Unique Unlock Profile**: Authored lifetime-demand threshold plus unchanged unique,
  prerequisite, character, and patron rules.
- **Palette-Excluded Building**: A catalogue-resolvable building marked in authored data
  as unavailable for player-facing pool construction and random placement.

## Success Criteria

### Measurable Outcomes

- **SC-001**: An all-zero valid location quote produces zero panel rows and occupies no
  visible panel footprint; every non-zero or warning fixture produces only its relevant
  rows.
- **SC-002**: In fresh-game and incomplete-save tests, 9 rooted roads do not complete the
  road lesson and 10 do; disconnected roads never change that count.
- **SC-003**: Every eligible adjacent-home pair order covered by the fixture completes
  with the same stable evidence, and 100% of rendered directions avoid “the first house.”
- **SC-004**: The first qualifying shop completes the tutorial and emits exactly one
  handoff in live, pre-built, duplicate-signal, and save/load scenarios; zero tutorial
  projections request 100 fulfilled Shops demand.
- **SC-005**: Postwar Terrace availability changes exactly at lifetime Homes 40 and Pub
  availability exactly at lifetime Shops 15, independent of current and fulfilled
  balances.
- **SC-006**: Across at least 100 declared seeded selections from the `grass` pool, plain
  `grass` is selected zero times and both retained planted variants remain reachable.
- **SC-007**: A legacy fixture containing plain `grass` loads with the same stable
  building identity and can be inspected/demolished normally.
- **SC-008**: Focused and full Godot suites, deterministic replay, a before/after opening
  balance trace, and normal-renderer review at 1280×720 and 1920×1080 pass without
  regressions outside the declared tuning changes.

## Assumptions

- “40 for the Postwar Terrace” means 40 lifetime residential/Homes demand, matching the
  UniqueRegistry authority already used by the building.
- “15 for the Pub” means 15 lifetime commercial/Shops demand, not current unserved or
  fulfilled demand.
- “Remove regular grass from the grass builder” means keep the content loadable for old
  saves but remove it from the player-facing pool; the pool's name and icon do not change
  in this pass.
- The existing `tutorial_opening_completed` handoff to the planned first land quest is
  the intended “first quest should start” boundary. This pass does not author or implement
  that quest.
- The 100 fulfilled-Shops threshold remains valid later character progression. Only its
  premature presentation as the primary opening direction is changed.
