extends Resource
class_name Structure

@export_subgroup("Model")
@export var model: PackedScene

@export_subgroup("Gameplay")
@export var metadata: Array[StructureMetadata] = []
## Palette grouping. Structures sharing a pool_id appear as a single cyclable
## palette entry; placement picks one at random from the pool. Empty string =
## standalone entry (or hidden, for auto-tile-only road variants).
@export var pool_id: String = ""

@export_subgroup("Footprint")
## Grid cells this building occupies, as offsets from the anchor (0,0).
## A 2×2 building: [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)].
## Leave as default [Vector2i(0,0)] for a standard 1×1 building.
@export var footprint: Array[Vector2i] = [Vector2i(0, 0)]

@export_subgroup("Transform")
@export var model_scale: float = 1.0
@export var model_offset: Vector3 = Vector3.ZERO
## Rotation applied to the model mesh in degrees around the Y axis.
## Use this to correct the facing direction of an imported model.
@export var model_rotation_y: float = 0.0

## Returns the first metadata entry of the given type, or null if none exists.
## Usage: var road := structure.find_metadata(RoadMetadata) as RoadMetadata
func find_metadata(type: Variant) -> StructureMetadata:
	for m in metadata:
		if is_instance_of(m, type):
			return m
	return null
