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
