# Implementation Plan: Gameplay Playtest MCP

**Branch**: `001-gameplay-playtest-mcp` *(planning identifier; no branch created)* | **Date**: 2026-09-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-gameplay-playtest-mcp/spec.md`

## Summary

Add a development-only `Playtest` plugin that exposes a deterministic semantic
interface over the live city simulation, refactor Builder and DayNight so UI
and automation share atomic gameplay commands, and expose those commands through
a separate six-tool MCP entry point. The interface returns structured snapshots,
stable rejection codes, available choices, idempotent outcomes, and local traces.
It reuses the installed Godot MCP connection and runtime IPC while keeping the
city-specific tool list small enough for routine AI play.

The first implementation milestone proves parity and determinism. Actual balance
tuning begins only after the bridge can replay a baseline scenario twice with
equivalent results.

## Technical Context

**Language/Version**: GDScript for Godot 4.6.2; TypeScript 5.7 targeting ES2022

**Primary Dependencies**: Existing Godot plugin architecture; existing Godot MCP Pro 1.14.1 WebSocket/editor/runtime bridge; `@modelcontextprotocol/sdk` 1.12.1; `ws` 8.18

**Storage**: Existing `DataMap` resources for game state; JSON building and pool data; development-only JSON traces under Godot `user://playtests/`

**Testing**: GUT 9.3.0 for gameplay units and integration seams; Vitest for MCP contracts and transport; live Godot MCP end-to-end scenarios

**Target Platform**: Local macOS development with Godot 4.6.x; design keeps the game-side contract platform-neutral

**Project Type**: Godot desktop game plus a local stdio MCP development service

**Performance Goals**: Snapshot response under 1 second; exact advancement of 100 simulation hours under 10 seconds on the development machine; bounded snapshots suitable for repeated agent calls

**Constraints**: Localhost only; deterministic seeds; no direct state cheating; no manual UI required; no narrative dependency; development-only activation; action requests idempotent

**Scale/Scope**: One local game process, one active playtest session, six MCP tools, approximately 36 current building definitions, three spendable demand buckets, and early/mid-game scenarios up to several hundred simulation hours

## Constitution Check

*GATE: Passed before Phase 0 research and re-checked after Phase 1 design.*

| Principle | Design evidence | Gate |
|-----------|-----------------|------|
| One Gameplay Truth | Builder receives public evaluate/commit commands used by mouse input and Playtest; automation never writes GridMap or resources directly. | PASS |
| Deterministic Simulation | Session seed, manual clock mode, exact `advance_hours`, ordered processing, and replay equivalence are explicit contracts. | PASS |
| Observable State | Snapshot and action-result schemas cover all balance-relevant values and stable reason codes. | PASS |
| Data-Driven / Narrative-Separate | Balance remains in building/pool data; baseline scenario suppresses presentation without changing city rules. | PASS |
| Small Interfaces / Layered Verification | A separate six-tool server fronts one semantic game command; GUT, Vitest, parity, replay, and end-to-end checks are planned. | PASS |
| Project Constraints | Godot 4.6.x, local-only transport, plugin architecture, debug-build gate, and current aristocrat-only content are preserved. | PASS |

Post-design re-check: the contract introduces no arbitrary script execution or
general scene editing, and the trace format is bounded. No violations require
complexity exceptions.

## Project Structure

### Documentation (this feature)

```text
specs/001-gameplay-playtest-mcp/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── contracts/
    └── mcp-tools.md
```

### Source Code (repository root)

```text
plugins/
└── playtest/
    ├── playtest_plugin.gd             # session, snapshots, choices, traces
    └── playtest_plugin.gd.uid

scripts/
├── builder.gd                         # shared evaluate/place/demolish commands
├── game_clock.gd                      # explicit tick stepping while paused
├── playtest_action_result.gd          # typed internal result helpers
└── plugin_manager.gd                  # debug-build Playtest registration

addons/godot_mcp/
├── commands/playtest_commands.gd      # editor-to-running-game IPC adapter
├── command_router.gd                  # registers playtest command adapter
└── mcp_game_inspector_service.gd      # delegates one operation to Playtest

server/src/
├── playtest-index.ts                  # separate six-tool stdio MCP server
└── tools/playtest-tools.ts            # schemas and command mapping

test/unit/
├── builder/test_builder_commands.gd   # UI/automation rule parity + atomicity
├── day_night/test_manual_advance.gd   # exact deterministic hour stepping
└── playtest/test_playtest_plugin.gd   # snapshots, reasons, idempotency, trace

server/src/tools/
└── playtest-tools.test.ts             # MCP contract/transport tests

test/scenarios/
├── fresh_city.json                    # story-neutral canonical start
└── early_city_baseline.json           # first balance replay fixture
```

**Structure Decision**: Keep the semantic domain implementation inside the
existing game plugin architecture. Extend the already-installed local Godot MCP
runtime adapter by one typed command, but expose it through a separate MCP server
entry point so the agent sees only city-play tools. The existing general Godot
MCP remains available for launching, screenshots, debugging, and editor work.

## Implementation Phases

### Phase 1 - Establish Shared Gameplay Commands

1. Introduce stable action-result and rejection-code dictionaries.
2. Split Builder placement into a non-mutating evaluation followed by an atomic
   commit. Validate land, footprint occupancy, unique rules, cash, and demand
   before spending either resource.
3. Expose `try_place_building(...)` and `try_demolish_cell(...)`; route existing
   mouse actions through them while retaining the player's replacement dialog.
4. Add detailed, non-mutating placement quotes to Demand and Economy where the
   existing boolean checks omit reason/cost data.
5. Add parity tests for successful placement, every rejection category,
   demolition, pooled choices, footprints, and uniqueness.

**Exit gate**: Equivalent UI and direct commands return the same outcome and
state for the complete contract matrix. A failed downstream gate never consumes
cash or demand.

### Phase 2 - Deterministic Clock and Fresh Scenario

1. Add a single DayNight hour-transition method used by both real-time process
   updates and manual advancement.
2. Add manual mode and exact `advance_hours(count)` without emitting skipped or
   duplicate hours across day rollover.
3. Define the canonical `fresh_city` scenario as a clean `DataMap`, seeded
   starting resources, starter buildable mask, empty registry, and narrative
   presentation disabled.
4. Seed all gameplay randomness used by pooled selection and scenario execution.
5. Verify replay equivalence across repeated runs.

**Exit gate**: Two 100-hour runs with identical inputs produce equivalent
snapshots, and the requested hour count equals the emitted hour count.

### Phase 3 - Playtest Domain Plugin

1. Add the development-only Playtest plugin with dependencies on the catalog,
   demand, economy, residential, workplace, satisfaction, attractiveness,
   buildable area, palette, unique registry, and day/night systems.
2. Implement session lifecycle, readiness, idempotency cache, bounded trace,
   state snapshot, choice projection, and action dispatch.
3. Normalize coordinates, rotations, numeric values, dictionary ordering, and
   snapshot rounding for deterministic JSON comparison.
4. Disable only narrative presentation/input suppression during core scenarios;
   do not disable city-system events or progression calculations.
5. Add GUT coverage for every operation, state transition, failure class, and
   trace limit.

**Exit gate**: The plugin can complete the primary scenario entirely through its
semantic API with no arbitrary property writes or UI clicks.

### Phase 4 - Small MCP Surface

1. Add one editor/runtime IPC operation that delegates to the Playtest plugin and
   returns its structured response.
2. Add a separate MCP entry point registering exactly the six tools defined in
   [contracts/mcp-tools.md](contracts/mcp-tools.md).
3. Validate all incoming arguments at the MCP boundary; preserve gameplay
   rejections as successful protocol responses and transport/runtime failures as
   MCP errors.
4. Add the `city-playtest` server to `.mcp.json` alongside `godot-mcp-pro` and
   document that the MCP client must reconnect after the first build.
5. Add Vitest contract tests using a fake Godot connection, followed by a live
   connection smoke test.

**Exit gate**: A newly connected client sees only the six city-playtest tools and
can run start → state → place → advance → state.

### Phase 5 - Baseline Balance Harness

1. Create `early_city_baseline` with explicit start, success, soft-failure, and
   hard-failure criteria.
2. Record milestones such as first residence, first workplace, first commercial
   building, first positive industrial output, first tax income, first tier-two
   unlock, and exhaustion of usable starter land.
3. Add trace comparison that reports deltas rather than assigning a subjective
   balance score.
4. Run the baseline repeatedly and fix bridge defects until 20 consecutive runs
   complete without manual intervention.
5. Freeze the first baseline artifact before modifying balance values.

**Exit gate**: The tool is trustworthy enough to begin a separate, evidence-led
balance iteration; this feature does not claim the game is balanced yet.

## Verification Strategy

### Unit and Contract

- Builder evaluation is pure with respect to cash, demand, registries, and maps.
- Placement commit emits exactly one structure event and updates every footprint
  cell exactly once.
- All rejection codes preserve the pre-action snapshot.
- Duplicate `request_id` returns the cached result without reapplying an action.
- Manual hour advancement covers zero, one, day rollover, and upper-bound cases.
- Snapshot serialization is stable and contains no Godot-only Variant values.
- MCP schemas reject malformed input before dispatch.

### Integration

- UI placement and Playtest placement share the same command and match outcomes.
- Placement state is settled through synchronous signals before the response.
- The general Godot MCP can launch the game while the city-playtest MCP connects
  and acts through the editor/runtime bridge.
- A runtime crash or disconnect is reported separately from gameplay rejection.

### End to End

- Run the quickstart smoke scenario.
- Replay `early_city_baseline` ten times with one seed and compare normalized
  final snapshots.
- Run 20 consecutive sessions across a small declared seed set.
- Capture screenshots at initial, first positive economy, and tier-two milestone
  for human spatial review.
- Run GUT in an environment with writable Godot `user://`; the current sandbox
  can otherwise make building-catalog fixture tests fail for environmental
  reasons.

## Balance Work Enabled by This Feature

After the exit gate, balance changes proceed as their own iterative work:

1. Record an unchanged baseline trace.
2. State one hypothesis, such as “commercial demand arrives too late.”
3. Change the smallest relevant JSON or tuning value.
4. Replay the same scenario and seed.
5. Compare progression timing, resource pressure, choice diversity, deadlocks,
   recoverability, and spatial outcomes.
6. Keep, revise, or revert the tuning based on evidence plus human play feel.

The initial scenario suite should investigate early-game choice diversity,
dominant strategies, economic deadlocks, recovery after poor placement, useful
land pressure, and whether attractiveness creates understandable spatial
trade-offs.

## Complexity Tracking

No constitution violations or additional architectural layers require an
exception. The second MCP entry point is intentionally a smaller interface over
the existing connection, not a second gameplay or transport implementation.
