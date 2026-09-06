# Feature Specification: Automated Opening Balance Playtest

**Feature Directory**: `specs/014-opening-balance-playtest`
**Created**: 2026-09-06
**Status**: Complete and verified
**Input**: Workstream 3 in `NEXT_IDEA_PROMPTS.md`

## Scope

Create a deterministic, state-directed opening playtest that starts from the ordinary
rooted fresh-town fixture, reads normalized state and legal choices, and acts only
through the existing Playtest command surface. It establishes repeatable evidence for a
later balance pass; it does not tune starting demand, growth ratios, costs, thresholds,
or other balance content.

The default endpoint is the first moment when `building_postwar_midblock` becomes
unlocked after lifetime residential demand reaches 75 and its terrace prerequisite has
been placed. The strategy must also exercise the opening Homes, Work, and Shops loop,
maintain city attractiveness at or above 200 after its initial greening phase, and use a
documented reusable rooted road grid.

## User Scenarios & Testing

### User Story 1 - Run a State-Directed Opening (Priority: P1)

As a designer, I can run one command that starts a fresh city and makes legal opening
decisions from the current snapshot until the declared milestone is reached.

**Independent Test**: Run the primary seed from a fresh session and confirm every
mutation is a Playtest `place` or `advance` command, every placed item was selected from
live availability, and the run reaches the endpoint within its action/hour bounds.

**Acceptance Scenarios**:

1. **Given** a fresh rooted-town session, **When** the agent starts, **Then** it places
   the Town Hall first and builds only road cells connected to its rooted component.
2. **Given** attractiveness is below 200, **When** legal nature placement exists,
   **Then** the next non-infrastructure action raises or protects attractiveness rather
   than waiting arbitrarily.
3. **Given** an intended Homes, Work, Shops, or prerequisite choice is affordable and a
   legal candidate cell exists, **When** the agent decides, **Then** it acts before
   advancing time.
4. **Given** no intended action is currently legal or affordable, **When** progress
   requires simulation, **Then** the agent advances exactly one hour and records the
   blocking resource or rule.
5. **Given** lifetime Homes demand is at least 75 and the terrace prerequisite exists,
   **When** the mid-block unlock is observed, **Then** the run stops successfully.

### User Story 2 - Explain Every Wait and Milestone (Priority: P1)

As a balance designer, I can inspect a machine-readable trace and answer where the
opening waits, what caused each wait, and which hypothetical introductory boost a later
balance experiment should compare.

**Independent Test**: Validate the generated report schema and derive the total idle
hours plus wait reasons exclusively from its action and milestone records.

**Acceptance Scenarios**:

1. Every record contains the absolute hour, decision reason, action/outcome, demand
   totals/fulfilled/unserved, cash, attractiveness, placed-building count, and state hash.
2. Placement records contain the selected choice/building, anchor, resource cost/delta,
   and structured rejection when an evaluated candidate unexpectedly fails.
3. Wait records contain exactly one elapsed hour and a stable list of blockers derived
   from current state and choice reasons.
4. Milestones record first Town Hall, rooted grid, Beauty 200, first home, first work,
   first shop, terrace placement, Homes total 75, and mid-block unlock times when reached.
5. The summary reports elapsed and idle hours, demand earned/spent, unlock times,
   placement rejections, Beauty minimum/history, resource constraints, and final state.

### User Story 3 - Reproduce and Compare Runs (Priority: P1)

As a developer, I can replay the primary seed and a small declared seed set and receive
stable diagnostic evidence when results diverge.

**Independent Test**: Run the primary seed from the declared seed set twice and compare
normalized decision traces and final hashes for the duplicate primary run.

**Acceptance Scenarios**:

1. Identical seed/config/content produces the same semantic trace hash, milestone hours,
   concrete variants, and final state hash.
2. The declared seed set completes under the same hour/action bounds and reports its
   seed on every run.
3. A failure writes the partial trace, last snapshot, unmet endpoint, decision blockers,
   and bounded-execution reason before returning a non-zero status.
4. Observability and report generation do not change canonical deterministic results.

### User Story 4 - Preserve Ordinary Gameplay Parity (Priority: P1)

As a maintainer, I can trust that the automated agent has no privileged balance path.

**Independent Test**: Contract tests prove the runner invokes only existing semantic
commands and that each applied placement matches Builder-owned outcomes.

**Acceptance Scenarios**:

1. The runner never mutates `GameState`, GridMap, demand buckets, cash, unlocks, clock,
   or progression directly.
2. Choice selection is derived from `get_choices`; placement and waiting use
   `handle_command("place"|"advance")`.
3. Rejections preserve state and are recorded rather than bypassed.
4. Narrative presentation remains disabled and does not gate the balance run.

## Edge Cases

- A seeded pool chooses a different valid concrete model or footprint.
- An intended category is globally available but no remaining candidate anchor fits.
- Nature is free but cash is too low for the road grid.
- Attractiveness falls below 200 after a residential, industrial, or commercial action.
- Total demand reaches a threshold while unserved demand remains too low to place.
- The terrace is unlocked but temporarily unaffordable.
- Several milestones occur in one command.
- A rejected placement consumes a sequence number but does not change state.
- The endpoint is reached exactly on the maximum hour or action boundary.
- The report path is unavailable; the runner must fail visibly rather than claiming a run.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST provide a documented one-command opening-balance runner.
- **FR-002**: The runner MUST start an ordinary rooted-town Playtest session with a
  declared seed and narrative presentation disabled.
- **FR-003**: The runner MUST observe normalized snapshots and `get_choices` before
  choosing actions.
- **FR-004**: All state changes MUST use the canonical `place` and `advance` Playtest
  commands; the runner MUST NOT mutate gameplay authorities directly.
- **FR-005**: The deterministic strategy MUST place the Town Hall first, establish a
  documented rooted road grid, and use legal candidate cells adjacent to that grid.
- **FR-006**: After the greening milestone, city attractiveness MUST remain at least 200;
  any drop MUST prioritize legal nature recovery before optional growth placement.
- **FR-007**: The strategy MUST place at least one residential, one industrial, and one
  commercial building before completion.
- **FR-008**: The strategy MUST place `building_postwar_terrace` when it is legal and
  affordable so the mid-block prerequisite is satisfied.
- **FR-009**: The default endpoint MUST be the observed unlocked state of
  `building_postwar_midblock` with lifetime residential demand at least 75.
- **FR-010**: If an intended action is currently possible, the runner MUST not advance
  time; otherwise it MUST advance exactly one hour.
- **FR-011**: Each wait MUST name stable current blockers, including relevant demand,
  cash, threshold, prerequisite, access, or land/placement constraints.
- **FR-012**: The machine-readable report MUST contain full semantic action records,
  milestone timestamps, demand earned/spent, idle hours, placed buildings, rejection
  details, Beauty history/minimum, resource constraints, and final normalized evidence.
- **FR-013**: The runner MUST enforce declared maximum hours and actions and preserve
  partial evidence on failure.
- **FR-014**: The primary seed MUST be replayed twice and compared for identical semantic
  trace hash, milestone hours, variants, and final state hash.
- **FR-015**: A declared set of at least three seeds MUST complete with per-seed reports.
- **FR-016**: Automated tests MUST cover decision priority, one-hour waits, endpoint
  detection, trace summarization, bounds, and canonical command delegation.
- **FR-017**: Verification MUST include focused and full GUT suites, server contract
  tests, deterministic replay, the complete multi-seed scenario, and normal-renderer
  inspection of the resulting town.
- **FR-018**: The workstream MUST NOT alter opening balance values or implement the
  introductory demand boost it is intended to measure.

### Key Entities

- **Strategy Configuration**: seed set, Beauty floor, endpoint, bounds, road cells,
  candidate anchors, and deterministic building priorities.
- **Decision Record**: before/after state slice, reason, blockers, command request,
  outcome, and balance deltas.
- **Milestone Record**: stable ID, first-observed hour/sequence, and state evidence.
- **Run Report**: configuration, action trace, aggregate waits/resources, milestones,
  final state, semantic trace hash, and failures.
- **Suite Report**: primary replay comparison plus results for the declared seed set.

## Success Criteria

- **SC-001**: Every declared seed reaches the mid-block unlock within 240 game hours and
  1000 semantic actions.
- **SC-002**: Every completed run contains Town Hall, rooted roads, at least one home,
  workplace, and shop, a placed terrace, and attractiveness of at least 200.
- **SC-003**: The duplicate primary runs have identical semantic trace hashes, milestone
  hours, concrete placed variants, and final state hashes.
- **SC-004**: Every simulated idle hour has an explicit blocker; there are zero
  unexplained multi-hour waits.
- **SC-005**: Every applied action goes through the Playtest command API and every
  rejection is represented in the report with an unchanged before/after hash.
- **SC-006**: A reviewer can identify the longest wait, its binding resource/rule, and
  candidate introductory-boost comparison values from the report without log scraping.
- **SC-007**: Focused/full automated suites, scenario execution, deterministic replay,
  and normal-renderer in-game inspection pass.

## Assumptions

- The current authored mid-block gate is 75 lifetime residential demand and requires the
  Postwar Terrace. The test reports a clear contract failure if content changes.
- “Beauty” maps to the canonical city attractiveness total used by existing opening-town
  balance tests.
- A fixed deterministic policy is appropriate for baseline comparison; “AI-directed”
  means state/choice-directed decisions, not nondeterministic model calls during replay.
- A later balance pass will compare at least no boost, +5, +10, +15, +20, and +25
  introductory Homes demand against the same trace measurements; this feature records
  the baseline only.

## Out of Scope

- Changing starting demand, demand generation, costs, thresholds, unlocks, or buildings.
- Completing tutorial or land-quest narrative workstreams.
- General-purpose planning, arbitrary code execution, remote hosting, or a new MCP tool.
- Optimizing the strategy for the fastest or highest-scoring city.
