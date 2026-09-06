# Acceptance and Scope Audit

## Requirement disposition

- FR-001–FR-004: pass. Decoration is Ambrose-only, repeatable,
  case-insensitive, punctuation/whole-word safe, exact-text preserving, and
  falls back cleanly when an icon is absent.
- FR-005–FR-007: pass. Homes, Work, and Shops expose current and lifetime facts
  with ordered, bucket-specific positive lifetime thresholds and catalog names.
- FR-008–FR-009: pass. `pow(1 - progress, 1.35)` is deterministic and monotonic
  over 3.2 seconds; tween completion frees the feedback host.
- FR-010–FR-013: pass. The dock presents signed non-zero cash, demand, base
  Beauty, and Community effects from the representative palette entry with
  readable icon/text fallback.
- FR-014: pass. Exact-size normal-renderer proofs cover 1280×720, 1920×1080,
  and 3840×2160, including the bounded 4K UI scale.

## Workstream boundary

Held rows are derived only from representative structure metadata projected by
Palette: cash/demand costs, `AttractivenessProfile.base`, and authored
`CommunityEffectProfile` entries. `PlayerToolDock.show_placement` deliberately
does not consume its live preview argument, and tests inject `+999 Beauty` plus
nearby counts to prove those values never enter intrinsic rows.

Hovered-cell validity, affected residents/homes, neighbour counts, exposure,
radius coverage, replacement outcomes, and per-location comparison remain in
workstream 5's separate placement-consequences panel. This workstream neither
duplicates nor pools those live consequences.

All four user stories and SC-001–SC-005 are satisfied.
