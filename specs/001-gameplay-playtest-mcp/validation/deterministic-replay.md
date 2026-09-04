# Deterministic Replay Evidence

Date: 2026-09-04

Twenty consecutive live `fresh_city` sessions used seed `77`, placed
`residential_t1` at `(0,0)`, and advanced exactly 24 hours.

- Runs completed: 20/20
- Infrastructure or gameplay failures: 0
- Emitted hours per run: 24
- Concrete variant in every run: `building_small_d`
- Unique final normalized hashes: 1
- Final hash: `2ba8b727a8680e9cc475d52430d1fbca8b075dab5f91bbc98cd6fc12d4994ac1`

The session id and wall-clock duration are intentionally excluded from state
hashing. Request ids and internal numeric registry ids are also absent from the
normalized city snapshot.
