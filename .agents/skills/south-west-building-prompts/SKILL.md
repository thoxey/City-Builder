---
name: south-west-building-prompts
description: Resolve, validate and compile consistent South West England-influenced building or building-family image prompts for a UK city builder, especially when outputs must be isometric and suitable for image-to-mesh reconstruction. Do not use for unrelated architecture research or final 3D modelling.
---

# South West Building Prompts

Treat each request as a prompt-compilation task, not free-form architectural improvisation.

## Workflow

1. Resolve the request in this order: `place -> typology -> expression -> render contract`.
2. Separate `use`, physical `typology`, and `occupancy_expression`, but assign every catalogue asset a unique `model_id` and unique geometry. Shared geometry always means an entry is missing a model.
3. Read [references/design-code.md](references/design-code.md) for architectural vocabulary and compatibility rules.
4. For a family or multiple variants, also read [references/family-generation.md](references/family-generation.md).
5. Surface the full resolved specification and any assumptions before the canonical image prompt.
6. Validate combinations. Correct soft conflicts; stop on hard conflicts unless the user explicitly overrides them.
7. In generative mode choose only from allowed weighted options and expose every choice. Use a seed when repeatability matters.
8. Compile concise visual instructions. Do not substitute vague labels such as “Victorian” for geometry, façade, roof, material and ground-condition fields.
9. Never propose a retexture, relabel or shared mesh as a completed catalogue asset. Related buildings may share grammar, but not exact geometry or model paths.

Use `scripts/compile_prompt.py` when a repeatable machine-readable result is useful:

```bash
python3 scripts/compile_prompt.py "Victorian industrial residential background building" --mode generative --seed 7
python3 scripts/compile_prompt.py "Georgian formal residential family" --mode generative --seed 12 --family-size 8
python3 scripts/compile_prompt.py --spec @building.json --mode deterministic
```

## Output order

Return:

1. `Resolved specification` as YAML or JSON.
2. `Validation` with corrections, warnings and explicit overrides.
3. `Canonical image prompt` using the fixed render contract.
4. For families, a `Variant manifest` naming every variant and its controlled differences.

Every family variant must identify a unique model candidate. If auditing existing assets, classify every duplicate-geometry entry after the first appropriate owner as `missing`.

The prompt must require sunny clear daylight, an orthographic 3/4 elevated view, the entire unobscured building, consistent shadows, a plain background, no people/cars/unnecessary text, and clean component separation for mesh generation.

## Modes

- **Deterministic:** require a complete specification or fill omissions with the single canonical default. The same input produces the same output.
- **Generative:** fill omissions from constrained options. Never invent outside the design code; surface the seed and selected values.

Do not generate an image until the resolved specification and prompt are available. When generating a project asset, save the selected image into the repository and retain the exact compiled prompt beside it.
