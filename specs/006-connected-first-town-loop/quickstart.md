# Quickstart: Connected First-Town Loop

## 1. Validate planning context

```bash
SPECIFY_FEATURE_DIRECTORY=specs/006-connected-first-town-loop \
  .specify/scripts/bash/check-prerequisites.sh --json --require-tasks
```

## 2. Run focused automated suites

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit -gexit
```

```bash
npm test --prefix tools/data_editor
```

## 3. Run first-town scenarios

Run the roadless/connected, bridge-removal, spatial matched pairs, unserved
nature, duplicate stacking, cohort, and milestone-005 patron fixtures through
the repository's deterministic scenario runner. Repeat each accepted matched
side ten times and compare balance hashes.

## 4. Capture evidence

Preserve baseline-before, candidate-after, admissibility report, deterministic
replay report, performance result, content inventory, and normal-renderer
screenshots under `validation/`. Do not overwrite the frozen baseline.

## 5. Human gate

Use [layout-validation-strategy.md](layout-validation-strategy.md) exactly. The
pilot, acceptance cohort, blind visual review, and durability continuation are
not complete until anonymised real-session evidence is stored. Automated
success must not mark these tasks complete.
