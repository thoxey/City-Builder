# Starter Kit City Builder Constitution

## Core Principles

### I. One Gameplay Truth

Every player-facing and automated action MUST pass through the same gameplay
rules for affordability, unlocks, footprints, land access, placement,
demolition, and simulation effects. Test or MCP interfaces MUST NOT mutate the
GridMap, demand buckets, cash, or progression state behind those rules. Shared
commands may expose the rules, but may not create a second implementation of
them.

### II. Deterministic, Controllable Simulation

Balance experiments MUST be reproducible from a declared starting state, random
seed, ordered action list, and number of elapsed simulation ticks. Automated
play MUST be able to pause wall-clock progression and advance the game clock
explicitly. Given identical inputs and content data, gameplay snapshots MUST be
equivalent.

### III. Observable and Explainable State

The game MUST expose enough structured state to explain the result of every
balance-relevant action. Snapshots include resources, demand totals and
fulfilment, population and employment, attractiveness, buildable land,
structures, and currently available actions. Rejected actions MUST report a
stable reason rather than only failing silently or emitting prose logs.

### IV. Data-Driven Balance, Narrative Separation

Balance values and building definitions MUST remain in the existing authored
data wherever the current schema supports them. Core city-building experiments
MUST NOT depend on unfinished dialogue, portraits, character names, or story
copy. Narrative may create goals over the simulation, but the simulation must
remain testable as a coherent game without narrative content.

### V. Small Interfaces and Layered Verification

New interfaces MUST be the smallest surface that completes the playtest loop.
Prefer a handful of semantic commands over a general remote-control API.
Gameplay logic requires unit coverage; each command contract requires
integration coverage; and representative balance scenarios require end-to-end
playthrough verification in a running game. Visual verification supplements,
but does not replace, state assertions.

## Project Constraints

- Runtime compatibility remains Godot 4.6.x.
- The live content scope currently contains one aristocrat patron; older
  three-patron specifications are historical unless deliberately restored.
- Local playtesting is the initial deployment scope. Remote access,
  authentication, hosted multiplayer, and public network exposure are out of
  scope.
- Building models remain in one named subdirectory per model under `models/`.
- Changes should extend the plugin/event architecture and avoid coupling
  unrelated systems directly to `builder.gd`.
- A playtest bridge is development infrastructure and MUST be absent or inert in
  release builds.

## Development Workflow and Quality Gates

- Each coherent milestone is reviewed before merge. Git staging, committing,
  branching, merging, and pushing occur only on explicit user request.
- The working project is `/Users/tom/Starter-Kit-City-Builder`; do not use a
  detached worktree for normal development or playtesting.
- A feature plan must identify its test seams before implementation.
- Completion requires: contract tests passing, Godot tests passing in an
  environment with writable `user://`, a deterministic replay check, and at
  least one full automated city-building scenario.
- Balance changes require a before/after trace using the same scenario and seed.
- Material architectural exceptions must be recorded in the feature plan's
  Complexity Tracking table before implementation.

## Governance

This constitution governs new project specifications and plans. Amendments must
state why a principle is changing, update affected feature artifacts, and use a
semantic version change: major for incompatible governance changes, minor for a
new principle or substantial expansion, and patch for clarification. Feature
reviews must check compliance before implementation and again after design.

**Version**: 1.0.0 | **Ratified**: 2026-09-04 | **Last Amended**: 2026-09-04
