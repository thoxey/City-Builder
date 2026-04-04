extends Resource
class_name DataStructure

@export var position: Vector2i
@export var orientation: int
@export var structure: int
## All grid cells occupied by this building (anchor + satellite cells).
## Empty on legacy saves — builder.gd migrates from the structure's footprint definition.
@export var footprint_cells: Array[Vector2i] = []
