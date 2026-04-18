extends Resource
class_name DataStructure

@export var position: Vector2i
@export var orientation: int

## Authoritative identifier for the placed building. Looked up against the
## BuildingCatalog at load to resolve the current MeshLibrary item index.
@export var building_id: String = ""

## All grid cells occupied by this building (anchor + satellite cells).
## Recomputed from the structure's footprint if left empty.
@export var footprint_cells: Array[Vector2i] = []
