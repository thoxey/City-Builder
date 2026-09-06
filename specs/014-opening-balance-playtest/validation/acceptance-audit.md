# Acceptance Audit

All specification success criteria pass.

- **SC-001**: Seeds 14014, 14015, and 14016 reached the endpoint at hour 114
  using 161 actions, below the 240-hour/1000-action bounds.
- **SC-002**: Every run contains the Town Hall, all 32 declared rooted road
  cells, a home, workplace, shop, terrace, and final Beauty 242. The lowest
  Beauty observed after the floor was established was 204.
- **SC-003**: Primary and replay semantic hashes are identical, with no
  milestone-hour, concrete-variant, or final-state differences.
- **SC-004**: Every idle mutation advances exactly one hour and has blockers;
  the report contains zero unexplained or multi-hour waits.
- **SC-005**: The agent and runner contain no `GameState` mutation. Every
  placement/wait delegates to Playtest `handle_command`; there were zero
  placement rejections in the accepted cohort.
- **SC-006**: The report identifies the single 114-hour idle span, its
  residential threshold blockers, and later comparison boosts
  `[0, 5, 10, 15, 20, 25]`.
- **SC-007**: Focused tests, multi-seed execution, replay, complete GUT,
  server tests/build, and normal-renderer visual QA all passed.

No balance values were changed. The only strategy-only reserve is ten Beauty
points, used to keep the measured town above the authored 200 floor while
placing the mixed opening buildings.
