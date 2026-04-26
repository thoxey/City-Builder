extends StructureMetadata
class_name AttractivenessProfile

## Per-building attractiveness profile. See spec_attractiveness.md.
##
## Each tile holds a SINGLE attractiveness score. The four directional fields
## here are interpreted as "what this building contributes when its neighbour
## is of category X" — the receiver's category picks the field.
##
## A building's `base` is added only to its own tile (own-tile self-contribution).
## The four directional fields radiate outward to neighbours within `radius`
## (Moore neighbourhood, Chebyshev distance), with linear inverse Euclidean
## falloff.
##
## Buildings without an AttractivenessProfile contribute nothing and have
## radius 0 (no spread). Backward-compatible — every JSON that omits this
## profile keeps default behaviour.

## Self-contribution. Added to the OWN tile's score; does not radiate.
@export var base: int = 0

## Contribution to a residential neighbour (per-tile, before distance falloff).
@export var residential: int = 0
## Contribution to a commercial neighbour.
@export var commercial: int = 0
## Contribution to an industrial neighbour.
@export var industrial: int = 0
## Contribution to a nature neighbour.
@export var nature: int = 0

## Moore radius (Chebyshev distance) over which the four fields radiate.
## Default 1 = the 8 surrounding tiles. Landmarks may set higher (e.g. 3).
@export var radius: int = 1

## Returns the raw (pre-falloff) contribution this building emits when its
## neighbour has the given receiver category. Empty / unknown category → 0.
func contribution_for(receiver_category: String) -> int:
	match receiver_category:
		"residential": return residential
		"commercial":  return commercial
		"industrial":  return industrial
		"nature":      return nature
		_:             return 0
