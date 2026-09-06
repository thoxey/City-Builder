# Phase 5: Not Applicable

The frozen catalogue-wide audit classifies all 31 live definitions using the mandated
least-invasive order:

- `pass`: 15
- `grass_underlay`: 16
- `transform`: 0
- `mesh_repair`: 0

Every failing visual row is a correctly sized or intentionally asymmetric asset with an
incomplete ground plate. A footprint-matched grass underlay resolves that class without
changing a model transform or mesh. No row remains after the underlay decision that
could justify Blender work.

Therefore conditional tasks T020-T022 are not applicable. T023 is satisfied by the
approved decisions in `model-audit.json`, their four-rotation evidence, and the read-only
gate below:

```bash
python3 -B tools/model_ground_contact/verify_audit.py
```

The verifier checks exact live-definition and explicit after-review coverage against the
frozen catalogue baseline; unique 0°/90°/180°/270° passing verdicts; decision-to-authored
treatment parity; every frozen model, footprint, transform, category, pool, cost,
community-role, palette, tag, profile, and UI field; before/after runtime and upstream
SHA-256 equality; and recorded first-mesh, material, texture, and bounds/import facts. It
fails if any `transform` or `mesh_repair` decision appears. It does not write to GLBs,
model artifacts, catalogue data, or audit evidence.

## Blender control-surface check

`codex mcp list` contained no registered Blender server, but the already-open Blender
5.2.1 LTS instance was reachable through its add-on's raw TCP bridge at
`127.0.0.1:9876`. A null-delimited, read-only `execute_code` request returned the open
`Scene`, Blender 5.2.1 LTS, two objects, OBJECT mode, and an unsaved scene. This proves the
Blender-side bridge is live, but no mutation command was sent because the approved audit
contains no mesh-repair row.
