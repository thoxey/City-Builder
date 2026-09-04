# Personality Contrast Validation

Date: 2026-09-04  
Scenario: `community_personality_contrast`  
Seed: `22001`

The pure evaluator and catalog-backed Community integration tests pass the
plays-versus-rock contrast. With a manifestation weight of `0.8`, the tagged
preference multiplier is `0.5 + 1.5 × 0.8 = 1.7`; with weight `0.1`, it is
`0.65`. An authored `+3` Belonging effect therefore contributes `+5.1` to its
strongly compatible resident and `+1.95` to the weakly compatible resident.

- Identity-heavy residents rank `plays_belonging` above `rock_belonging`.
- Freedom-heavy residents rank `rock_belonging` above `plays_belonging`.
- Neutral effects use a preference multiplier of exactly `1.0`.
- Noise sensitivity remains a separate multiplier after neutral preference.
- AppliedEffect records retain source building, anchor, quality, manifestation,
  scope, base amount, exposure, all multipliers, applied amount, and reason.

Covered by `test_effect_evaluator.gd` and the catalog-backed theatre integration
in `test_community_plugin.gd`.
