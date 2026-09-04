# Research: Gameplay Playtest MCP

## Decision 1: Use a Separate Small MCP Entry Point

**Decision**: Add a `city-playtest` entry point that registers exactly six
semantic tools while reusing the installed server's Godot connection class and
the editor plugin's WebSocket/IPC path.

**Rationale**: The installed Godot MCP contains more than 170 general editor and
runtime tools, while the active Codex task currently surfaces only a small
selection. A purpose-built entry point keeps the gameplay vocabulary stable and
discoverable, avoids flooding the model with editor operations, and reuses the
working multi-port connection already supported by the Godot plugin.

**Alternatives considered**:

- Add six tools to the full server only: simpler build, but they may be obscured
  by the large general tool catalogue and cannot be permissioned independently.
- Create an unrelated TCP or HTTP server inside the game: clean separation, but
  duplicates connection lifecycle, framing, retries, and process discovery that
  the installed MCP already solves.
- Drive everything with screenshots and simulated mouse input: useful for final
  UX checks, but too slow, coordinate-fragile, and unable to provide exact state
  for balance comparison.

## Decision 2: Put Semantic Authority in a Game Plugin

**Decision**: Implement a `Playtest` plugin that owns sessions, snapshots,
choices, idempotency, and traces, but delegates placement/demolition and hourly
simulation to shared gameplay commands.

**Rationale**: The running game is the only reliable authority for plugin state
and signal ordering. Keeping the playtest domain in the plugin architecture
allows direct GUT testing and prevents the TypeScript MCP layer from learning or
duplicating economy rules.

**Alternatives considered**:

- Build snapshots in TypeScript from log parsing: existing logs are verbose,
  incomplete as a contract, and subject to wording changes.
- Let the MCP call arbitrary runtime scripts: powerful but unsafe, hard to
  validate, easy to cheat, and unsuitable for repeatable tool contracts.
- Put all playtest logic in Builder: Builder already has too many visual/input
  responsibilities and should expose commands rather than own experiment data.

## Decision 3: Refactor Builder Before Exposing Automation

**Decision**: Split placement into non-mutating evaluation and atomic commit,
then route both mouse input and Playtest through public Builder commands.

**Rationale**: Current `_do_build` spends cash before trying to spend demand. If
the later demand gate rejects, cash can already have changed. It also relies on
the Palette to hide unavailable unique buildings rather than expressing every
rule in the placement command. A shared command is necessary for parity and
creates a safer action boundary for both human and automated play.

**Alternatives considered**:

- Call private `_do_build` directly: bypasses selection semantics, exposes no
  result, and preserves partial-mutation risk.
- Reimplement validation in Playtest: violates one-gameplay-truth and would drift
  as balance rules change.
- Simulate the player's input actions: preserves rules but remains dependent on
  camera, selection, focus, confirmation dialogs, and frame timing.

## Decision 4: Treat Gameplay Rejection as Data

**Decision**: Define stable reason codes and return them in normal action
outcomes; reserve MCP/protocol errors for unavailable processes, malformed
requests, timeouts, and internal failures.

**Rationale**: Insufficient demand and occupied land are expected facts an agent
must reason about, not exceptional transport failures. Stable codes also make
parity tests and longitudinal comparisons independent of toast wording.

**Alternatives considered**:

- Return only `true/false`: too little information for strategy or diagnostics.
- Return toast/log text: understandable to humans but brittle and difficult to
  aggregate.
- Raise MCP errors for all rejections: conflates correct gameplay with broken
  infrastructure and encourages blind retries.

## Decision 5: Add Request Idempotency

**Decision**: Every state-changing MCP action carries a caller-provided
`request_id`; the Playtest plugin caches a bounded set of completed outcomes per
session and returns the cached outcome for duplicates.

**Rationale**: MCP calls can time out after the game has applied an action. A
retry without idempotency could place twice or advance twice and silently ruin a
balance trace.

**Alternatives considered**:

- Trust callers never to retry: unrealistic for process and IPC boundaries.
- Deduplicate by action content: prevents intentional repeated placements and
  repeated time advances.
- Keep an unbounded cache: unnecessary memory growth during long experiments.

## Decision 6: Advance the Existing Hour Boundary

**Decision**: Refactor DayNight around one hour-transition method, and make
manual advancement invoke that same method in chronological order while visual
time is in manual mode.

**Rationale**: CityStats, Demand, Economy, character triggers, and other systems
already subscribe to `DayNight.hour_changed`. Reusing that boundary preserves
signal ordering and avoids a second simulation pipeline.

**Alternatives considered**:

- Increase real-time speed greatly: nondeterministic under frame load and still
  wastes time.
- Emit `hour_changed` externally without updating DayNight state: produces
  inconsistent snapshots and rollover behaviour.
- Step `GameClock`: the current economic simulation is driven by DayNight rather
  than `GameClock.tick`, so this would not reliably advance gameplay.

## Decision 7: Normalize Snapshots for Comparison

**Decision**: Return JSON-safe values with sorted building records, explicit
coordinate objects, normalized rotations, rounded floats, and a schema version.
Exclude volatile presentation state and object instance identifiers.

**Rationale**: Godot dictionaries, integer registry identifiers, and unordered
iteration can introduce meaningless differences. Balance comparisons should
reflect gameplay changes rather than serialization accidents.

**Alternatives considered**:

- Serialize `GameState` directly: includes engine-specific values and unstable
  internal identifiers.
- Compare only a handful of KPIs: hides spatial and choice changes that may
  explain why a KPI moved.

## Decision 8: Keep Traces Local and Bounded

**Decision**: Keep the current trace in memory, optionally persist completed
traces as JSON under `user://playtests/`, and cap idempotency and trace entries.

**Rationale**: Local disposable artifacts are sufficient for balance work. A
database or hosted service adds no value at this stage.

**Alternatives considered**:

- Commit traces into the repository by default: creates noisy large diffs and
  conflates evidence artifacts with authored scenarios.
- Add a database: unjustified operational complexity for one local playtester.

## Decision 9: Separate Objective Evidence from Subjective Fun

**Decision**: The bridge records outcomes and comparisons but does not emit a
single “fun” or “balance” score. The AI and designer interpret several metrics
alongside periodic visual/human play review.

**Rationale**: A composite score would encode premature design values and invite
optimization against the metric rather than the intended experience.

**Alternatives considered**:

- Hard-code one utility function: useful later for a narrowly defined bot, but
  misleading before the fundamentals and desired play styles are understood.
- Rely only on human feel: preserves judgment but makes regression and iteration
  slow and difficult to reproduce.
