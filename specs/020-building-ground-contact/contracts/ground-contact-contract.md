# Contract: Building Ground Contact

## Catalogue contract

Every building summary exposes:

```text
ground_treatment: "replace" | "grass_underlay"
```

Omission means `replace`. Authored values outside the enum are content errors.

## Builder lifecycle contract

Builder resolves the desired GroundMap item from the final occupant of each canonical
footprint cell:

```text
no occupant                  -> normal_grass
occupant.ground_treatment
  == "grass_underlay"        -> grass_underlay
otherwise                    -> empty
```

The same helper is used after commit, load, replacement, demolition, clear, and reset.
It does not mutate occupancy or enter save records. Applying it more than once is
idempotent.

The underlay item reuses the existing grass mesh/material and has one fixed negative
vertical bias selected by visual testing. Preview remains aligned with the eventual
committed result.

## Audit contract

The audit enumerates definitions from BuildingCatalog rather than a hand-maintained list.
Each stable building ID produces one row and four rotation captures with a visible
canonical footprint guide. The audit fails when any live item has no decision or when a
changed item lacks before/after evidence.

Classification order is:

```text
visually passes -> pass
incomplete base + correctly sized architecture -> grass_underlay
whole asset uniformly undersized/misaligned -> transform
neither safe treatment works -> mesh_repair
```

Town Hall cannot finish as `pass` without post-change 2×2 evidence.

## Model pipeline contract

Transform changes are authored in the upstream production result consumed by
`tools/wire_city_builder_models.py`. Mesh repairs are applied upstream of
`tools/package_city_builder_models.py`. The packaged paths under `models/city-builder/`
remain stable derivatives.

Every generated runtime model must provide a non-empty first MeshInstance3D mesh with
finite bounds and retain required materials/textures. Re-running the documented pipeline
must not revert an approved repair.
