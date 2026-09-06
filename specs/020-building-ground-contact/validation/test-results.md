# Release verification: building ground contact

**Date**: 2026-09-06
**Engine**: Godot 4.6.2 stable
**Normal renderer**: Forward+ / Metal / Apple M2 Max
**Spec Kit feature path**: `/Users/tom/Starter-Kit-City-Builder/specs/020-building-ground-contact`

## Contract-first evidence

Before catalogue support was implemented, the new ground-treatment contract suite failed
3/3 new tests while all 16 existing catalogue tests passed (19 tests, 105 assertions).
The failures were the missing `replace` default, missing `grass_underlay` projection, and
missing invalid-value fallback. After the catalogue change, the same run passed 19/19;
the invalid-value case also emitted its required content error before safely projecting
`replace`. The red run is retained at
`/tmp/city-builder-ground-contact-contract-red.log`.

## Automated verification

| Gate | Result | Evidence |
|---|---:|---|
| Spec Kit prerequisite resolution | pass: explicit feature directory selected | `SPECIFY_FEATURE_DIRECTORY=/Users/tom/Starter-Kit-City-Builder/specs/020-building-ground-contact` |
| Focused catalogue/Builder/save suite | pass: 50/50 tests, 487 assertions across 7 scripts | `/tmp/city-builder-ground-contact-gut.log` |
| Full Godot suite | pass: 739/739 tests, 7,389 assertions across 152 scripts | `/tmp/city-builder-ground-contact-full-gut.log` |
| Town Hall runtime checkpoint | pass: 16 captures, 4 GroundMap snapshots | `town-hall-checkpoint.json` |
| Repaired preview/commit/load alignment | pass: 64/64 asset/rotation rows | `alignment-after.json` |
| Final catalogue/GLB audit | pass: 31/31 catalogue rows, 124/124 rotations | `model-audit.json` |
| Audit integrity verifier | pass: 15 unchanged, 16 underlay, 0 transform, 0 mesh repair | `python3 -B tools/model_ground_contact/verify_audit.py` |
| Deterministic 20-minute replay | pass: baseline/final/repeat checkpoint hashes match | `deterministic-comparison.json` |
| Save/load compatibility | pass: stable ID only; treatment derived on cold load | focused suite plus `deterministic-after.json` |
| Reference-town performance | pass: paired timing/count deltas all within 5% | `performance-comparison.json` |

The focused suite was run with a writable `user://` exactly as required by the quickstart.
Its 16 feature-specific tests cover parsing, defaults, invalid content, both treatment
modes, rotated multi-cell placement, both replacement directions, ordinary and
satellite-cell demolition, adjacent replacement/demolition around the Town Hall, clear,
reset/idempotence, hard surfaces, startup background-fill ordering, Town Hall protection,
legacy serialization, and cold load. No save schema or save-record field was added.

GUT reports its existing orphan/RID/resource diagnostics during engine shutdown, but both
authoritative commands exit successfully and report zero failing tests.

## Deterministic and save/load result

Seed 6066 succeeds before and after with 60/60 meaningful placements. The canonical
checkpoint hashes are identical at 60, 120, and 240 hours:

1. `3bec0ccd0b56988661e323d18c97c772916b50f62912ffdbc1a20143e3999019`
2. `4a44cd8886990489b13ccd9de6756f3eb04c563f39b1a68b9ad613b57c889b3c`
3. `8b1856d363d08568c1f8824d0dc0d0ebc117365e03f37b55d74efee099aefec4`

Criteria and the normalized final gameplay summary are identical; the latter has digest
`f0414f9a14b076d1e4c6d098ffd47bdfc6e6e75a24b9de1ecad15420e855c01b`.
Two final-tree runs also match exactly. The frozen run's later presentation/transaction
ledger differs because concurrent feature-019 work settled after the baseline freeze;
that distinction and both raw ledgers are retained in `deterministic-comparison.json`.

The final reference save is `user://feature020-after-town.tres`. The integration test
also writes a legacy-format Town Hall record containing its stable building ID and proves
that all four underlay cells are reconstructed solely from current catalogue data.

## Visual and model verification

The authoritative audit uses the normal renderer and includes every live catalogue entry
at 0°, 90°, 180°, and 270°. Each of the 16 repaired assets has before/after evidence at
1280×720 and 1920×1080 using the production camera's exact close and wide size limits,
15.0 and 80.0. Because the model and authored-transform hashes are unchanged, the added
high-resolution before sets reproducibly suppress only the new derived underlay and
reconstruct the frozen presentation without changing source data. Dedicated Town Hall
captures cover preview and cache-bypassed cold-loaded stages at both resolutions, both
zooms, and 0°/90°.

Visual review found no exposed checker/void, footprint overflow, grass over hard surfaces,
visible z-fighting, floating seam, or rotation discontinuity. All 31 imported GLBs retain
stable paths and hashes, finite non-empty first meshes, materials, and resolved texture
bindings. No runtime GLB or upstream model artifact changed.

## Conditional model-pipeline phases

The audit contains no uniformly undersized asset, so transform task T013 is not
applicable. It contains no remaining mesh defect, so Blender/package tasks T020-T022 are
also not applicable and the wiring/packaging tools were intentionally not run. The open
Blender 5.2.1 LTS MCP bridge was nevertheless checked successfully at
`127.0.0.1:9876`. Codex had no registered Blender MCP server, so the check used the
add-on's raw TCP bridge and a read-only `execute_code` request; it reported the open
`Scene`, two objects, OBJECT mode, and an unsaved scene. No mutation command was issued.

## Performance result

The frozen-before comparison exceeded 5% and was investigated rather than silently
accepted. The frozen frame samples changed cadence mid-run and the shared dirty tree's
feature-019 implementation changed afterward. A paired current-tree A/B run isolates
feature 020 by forcing only the in-memory catalogue policy to legacy `replace` for the
control. Underlays change map-load time by -1.830%, placement time by -1.988%, and steady
frame time by -0.006%. Draw calls, visible objects, and primitives change by +2.907%,
+2.247%, and +0.004% respectively. All remain inside the 5% gate; raw measurements and
the complete investigation are in `performance-comparison.md` and its JSON companion.

## Diff boundary

The final audit verifier mechanically confirms exact coverage, unique explicit review at
all 124 asset/rotation combinations, decision-to-authored-treatment parity, and equality
of every frozen catalogue field except the approved `ground_treatment` addition. Stable
IDs, model paths, footprints, transforms, categories, pools, costs, community roles,
palette exclusions, tags, profiles, UI metadata, and source/runtime hashes are preserved.
Feature-019's `palette_excluded`, player-pool resolution, and current Pub and Postwar
Terrace thresholds remain present. The generated data manifest contains the same 16
ground-treatment projections alongside those concurrent feature-019 projections.
`.specify/feature.json` was already dirty and also received concurrent work; feature 020
neither edited nor restored it. No branch switch, index/staging, commit, or remote
operation was performed.
