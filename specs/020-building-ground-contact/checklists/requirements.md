# Specification Quality Checklist: Building Ground Contact

- [x] Every live catalogue model is audited rather than relying on the playthrough's
  informal examples.
- [x] Town Hall is a mandatory first checkpoint with an explicit 2×2 result.
- [x] Bounds evidence is supplemented by four-rotation normal-renderer review.
- [x] The repair decision order prevents indiscriminate scaling or binary editing.
- [x] Grass underlay is data-driven, footprint-matched, depth-biased, and lifecycle-safe.
- [x] Roads, pavement, water/cut-outs, hardstanding, and z-fighting are covered.
- [x] Transform and mesh changes are reproducible through upstream model sources/tools.
- [x] Stable IDs, model paths, footprints, saves, gameplay hashes, balance, progression,
  simulation, UI, and narrative are protected explicitly.
- [x] Builder's first-mesh extraction constraint is documented and tested.
- [x] Save/load, replacement, demolition, clear, reset, rotations, zoom extremes,
  performance, and concurrent feature 019 changes are covered.
- [x] Conditional Blender work has an auditable gate and a CLI fallback when MCP is
  unavailable.
- [x] Success criteria are measurable and require both visual and automated evidence.
