# Final verification

- Engine: Godot 4.6.2 stable; GUT 9.3.0.
- Recursive unit suite: 41 scripts, 256/256 tests, 1618 assertions, 4.06 s.
- PlayerUI integration suite: 4 scripts, 5/5 tests, 19 assertions.
- PlayerUI asset/geometry/navigation/status suite: 11/11 tests, 427 assertions.
- UniqueRegistry focused suite: 10/10 tests, 28 assertions.
- Community UI performance suite: 3/3 tests; 500 residents in 15.787 ms.
- Deterministic replay unit: repeated seed/action traces and hashes match.
- Automated live build scenario: residential, industrial, commercial, and
  48-hour advance all `applied`; sequence 4; final hash
  `d1276e457dc0a28f88ce8c5c04d0f7dcc36a2613b4508ab1cee4d3dfb3537747`.
  A second independent live run produced the same hash.
- Visual acceptance: 11 PNGs under `validation/screenshots/`.

Godot reports pre-existing orphan/resource warnings at test process shutdown;
there are no failing, risky, or pending tests in the final unit/integration runs.
