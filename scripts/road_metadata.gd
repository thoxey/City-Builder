extends StructureMetadata
class_name RoadMetadata

## Metadata for road tiles. Defines connection topology in default orientation
## (orientation index 0). The traffic plugin rotates these at runtime based on
## the placed tile's orientation from the GridMap.
##
## Connection direction convention (XZ plane):
##   North = Vector2i( 0, -1)
##   South = Vector2i( 0,  1)
##   East  = Vector2i( 1,  0)
##   West  = Vector2i(-1,  0)

enum RoadType { STRAIGHT, CORNER, SPLIT, INTERSECTION }

@export var road_type: RoadType = RoadType.STRAIGHT
## Which sides this tile connects to in its default (unrotated) orientation
@export var connections: Array[Vector2i] = []
@export var speed_limit: int = 30
@export var lanes: int = 1

## Returns the actual world-space connection directions for a tile placed at
## the given GridMap orientation index. Pass GameState.gridmap as gridmap.
func get_world_connections(orientation: int, gridmap: GridMap) -> Array[Vector2i]:
	if orientation == 0:
		return connections
	var basis := gridmap.get_basis_with_orthogonal_index(orientation)
	var result: Array[Vector2i] = []
	for conn in connections:
		var rotated := basis * Vector3(conn.x, 0, conn.y)
		result.append(Vector2i(roundi(rotated.x), roundi(rotated.z)))
	return result
