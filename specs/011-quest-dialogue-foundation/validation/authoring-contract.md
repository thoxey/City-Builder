# Authoring Contract Validation

Validated on 2026-09-06.

The headless manifest exporter completed successfully:

```text
[DataEditorTools] headless export OK: chars=5 patrons=1 buildings=31 events=6 flags=7
```

The two authored-data validation tests and two manifest regression tests all passed.
All production dialogue records normalize without diagnostics, including the migrated
Baba arrival event. The exporter preserves participants, entry node, ordered speech and
narration beats, node/option effects, semantic expression names, default expressions,
and legacy `body` content without rewriting it.

Validated fallback diagnostics are stable and ordered:

- omitted beat expression: `missing_dialogue_expression`, then declared default;
- unknown expression: `unknown_expression`, then declared default;
- legacy portrait-only character: `unknown_expression`,
  `missing_default_expression`, then the legacy portrait;
- missing portrait art: `unknown_expression`, `missing_default_expression`,
  `missing_portrait_resource`, then the intentional missing-portrait asset;
- invalid graphs: contextual participant/beat/node/destination diagnostics, including
  `missing_dialogue_destination`, `missing_dialogue_node`, and
  `dialogue_cycle_limit`.

The content validator includes stable file, event, node, and beat context. The semantic
authoring and migration rules are documented in `docs/quest-dialogue-authoring.md`.
