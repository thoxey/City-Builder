extends Resource
class_name Structure

@export_subgroup("Model")
@export var model: PackedScene

@export_subgroup("Gameplay")
@export var price: int
@export var metadata: Array[StructureMetadata] = []

@export_subgroup("Transform")
@export var model_scale: float = 1.0
@export var model_offset: Vector3 = Vector3.ZERO

## Returns the first metadata entry of the given type, or null if none exists.
## Usage: var road := structure.find_metadata(RoadMetadata) as RoadMetadata
func find_metadata(type: Variant) -> StructureMetadata:
	for m in metadata:
		if is_instance_of(m, type):
			return m
	return null
