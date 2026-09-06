# Research: Automated Opening Balance Playtest

## Existing capability audit

- `Playtest.get_snapshot()` already exposes cash, population, attractiveness, demand
  totals/fulfilled/unserved, land, structures, progression gates, choices, and a stable
  state hash.
- `Playtest.get_choices()` already reports live availability and structured reasons.
- `handle_command("place")` routes through Builder; `handle_command("advance")` routes
  through the manual DayNight authority.
- Existing trace persistence is bounded, but its compact entries do not contain the
  decision rationale or before/after balance slices required by this workstream.
- `run_town_rebalance.gd` is a useful layout precedent but advances in four-hour chunks
  and follows a placement-count schedule rather than a live milestone-directed policy.

## Decisions

1. **No new MCP tool.** The six existing semantic tools are sufficient; richer evidence
   belongs in the scenario agent/report.
2. **Deterministic state-directed policy.** “AI-directed” is implemented as a transparent
   rules agent over normalized state, making every decision replayable and reviewable.
3. **One-hour waits.** Waiting is the fallback only after the current placement priority
   has no legal action, eliminating arbitrary time jumps.
4. **75-total endpoint.** The mid-block is the first meaningful lifetime-Homes wait after
   a prerequisite; stopping at its unlock isolates opening cadence without absorbing the
   later patron chain.
5. **Primary replay plus seed cohort.** The primary seed is duplicated inside the same
   suite and compared semantically; three declared seeds expose pool variation.
6. **Separate semantic trace hash.** Wall-clock durations and session IDs are excluded;
   decisions, variants, hours, outcomes, blockers, and state hashes remain included.

## Alternatives rejected

- Extending the public MCP with an `auto_play` command would put policy into the bridge
  and enlarge a stable interface without necessity.
- Reusing the 20-minute rebalance runner unchanged would hide forced waits and violate
  the one-hour responsiveness requirement.
- Calling a nondeterministic language model during replay would make baseline evidence
  irreproducible and obscure why actions differed.
