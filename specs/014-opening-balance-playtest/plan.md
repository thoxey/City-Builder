# Implementation Plan: Automated Opening Balance Playtest

**Spec**: [spec.md](spec.md)
**Constitution**: `.specify/memory/constitution.md`
**Target**: Godot 4.6.x, GDScript, debug-only Playtest plugin

## Technical Context

The repository already has the complete semantic command surface required by this
feature: `Playtest.start_session`, `get_snapshot`, `get_choices`, and canonical
`handle_command` operations for placement and exact-hour advancement. Existing runners
prove deterministic scenarios but use fixed action lists or large four-hour waits. The
new component is a reusable `RefCounted` decision agent plus a thin SceneTree suite
runner. No MCP schema expansion and no gameplay/balance change are needed.

## Constitution Check

| Principle | Design evidence | Result |
|---|---|---|
| I. One Gameplay Truth | Agent observes Playtest and mutates only through `place`/`advance`; Builder/Demand/Clock retain authority. | PASS |
| II. Deterministic, Controllable Simulation | Fixed seed, stable priorities/candidate order, manual one-hour waits, semantic hashes. | PASS |
| III. Observable and Explainable State | Each action stores before/after balance slices, rationale, blockers, outcome, and deltas. | PASS |
| IV. Data-Driven Balance, Narrative Separation | Uses authored data and presentation-disabled mode; changes no tuning values. | PASS |
| V. Small Interfaces and Layered Verification | Reuses existing interface; unit tests cover policy/reporting and an end-to-end scenario proves the loop. | PASS |

No architectural exception is required.

## Architecture

### `scripts/opening_balance_agent.gd`

A pure orchestration object receives a Playtest-like dependency. It owns deterministic
policy state (road cursor, candidate cursor, milestones, records) but no gameplay state.
Its public `run(playtest, seed, config)` method:

1. starts `first_town/opening_balance`;
2. places Town Hall and the stable road grid;
3. greens the town to the Beauty floor plus a small strategy-only reserve;
4. selects affordable intended growth choices from the live choice projection;
5. places the terrace prerequisite as soon as canonical availability permits;
6. advances one hour only when no intended placement is possible;
7. stops when the mid-block gate reports unlocked or a bound is reached;
8. returns a complete run report even on failure.

The policy uses explicit phases to avoid repeatedly spending Homes demand needed for the
terrace. After satisfying one early home/work/shop, it preserves residential unserved
demand for the terrace and then waits for lifetime Homes demand 75 while maintaining
Beauty. Candidate anchors are scanned using Builder's canonical placement result; an
unexpected rejection is recorded and the next candidate is tried without bypassing the
rule.

### `scripts/run_opening_balance_playtest.gd`

A SceneTree entry point loads the main scene, runs the primary seed twice and the
declared seed set, compares replay fields, writes `validation/baseline-report.json`, and
exits non-zero on any run or replay failure. Optional command-line arguments select a
single seed/evidence path for renderer capture and diagnostics.

### Fixture and evidence

`test/scenarios/first_town/opening_balance.json` declares rooted rules, ordinary starting
balances, endpoint, seeds, Beauty target, bounds, road cells, and stable candidate cells.
Validation documents summarize results without duplicating the JSON trace.

## Decision Priority

1. Town Hall.
2. Remaining rooted road-grid cells.
3. Nature while Beauty is below the 210 operating target that protects the
   authored 200 floor.
4. First tier-one home, workplace, or shop not yet present, in that order, when
   live choices and canonical placement allow it.
5. Postwar Terrace when live choices report it available.
6. Additional nature whenever Beauty recovery is required.
7. Advance exactly one hour with blockers explaining why no higher-priority action ran.
8. Stop immediately when the mid-block unlock is observed.

## Test Seams

- A fake Playtest dependency drives unit tests without GameState mutation.
- Static report helpers validate endpoint and summarize wait/resource data.
- Integration uses the real main scene, Builder, choice projection, manual clock,
  Demand, Attractiveness, UniqueRegistry, and normalized hashes.
- Existing Playtest and Builder suites remain the parity authority.

## Verification Plan

1. Focused GUT tests for the agent and Playtest parity.
2. Run the complete multi-seed baseline command; inspect report schema and failures.
3. Repeat the primary seed and compare semantic trace, milestone, variant, and state hashes.
4. Run full recursive unit/integration GUT.
5. Run server build/tests to confirm MCP contracts remain compatible.
6. Run the primary scenario with a normal renderer, capture the final town at 1280×720,
   and inspect Town Hall/rooted grid/nature/growth legibility.

## Complexity Tracking

None. The feature adds an orchestration/test layer and one fixture, with no new runtime
plugin dependency or public MCP operation.
