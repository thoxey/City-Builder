# Deterministic Replay

`scripts/run_opening_tutorial_scenario.gd` was run repeatedly with scenario
`first_town/opening_balance` and seed `12012`. Two recorded full runs exited 0
with the identical terminal state hash:

`616cca4fbba7b1c6cea5e87d8b5f561bde2785399c63479141c1898daf07ab79`

Both runs produced:

- nine ordered durable objective receipts;
- exactly one completion handoff;
- event counts of exactly one for B05, B09, B15, and B18;
- observed adjacent-home delta `-10` and repair delta `+20`;
- `early_action_reconciled=true` for a shop placed before nature/homes/work;
- `duplicate_reconcile_idempotent=true`;
- `demolition_non_regression=true` after removing the completed shop; and
- `cold_load_parity=true`, with no repeated event or handoff.

The GUT integration test invokes this runner in a child Godot process, parses
the terminal JSON record, and asserts these invariants without polluting later
singleton-backed tests.
