# US1 Assigned-Day Checkpoint

Captured 2026-09-06 with Godot 4.6.2 / GUT 9.3.0.

- `test/unit/people`: 3 scripts, 7 tests, 19 assertions — PASS.
- `test/integration/civilian_simulation/test_assigned_day.gd`: 1 test, 2 assertions — PASS.
- Exact work, activity, and home destinations are copied from Community intent.
- Resident ID, seed, and immutable home remain bound to the same proxy.
- Same resident seed/hour/purpose yields the same spawn and departure offsets.
- An arrived work/activity proxy stays at its destination until intent changes; no
  real-time roam timer is active.

US1 is independently green. Canonical route execution and disconnected-route
refusal are verified in the following US2 checkpoint.
