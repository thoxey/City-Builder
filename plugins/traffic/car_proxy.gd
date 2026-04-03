extends Node3D
class_name CarProxy

## A simple sphere that travels between road tile centres.
## Call travel_to() with a new world position; is_arrived() returns true when it gets there.

const SPEED := 3.0  # units per second

var current_tile: Vector3i
var _from: Vector3
var _to: Vector3
var _t: float = 1.0

func place_at(tile: Vector3i, world_pos: Vector3) -> void:
	current_tile = tile
	_from = world_pos
	_to = world_pos
	_t = 1.0
	position = world_pos

func travel_to(tile: Vector3i, world_pos: Vector3) -> void:
	current_tile = tile
	_from = position
	_to = world_pos
	_t = 0.0

func is_arrived() -> bool:
	return _t >= 1.0

func _process(delta: float) -> void:
	if _t >= 1.0:
		return
	_t = minf(_t + delta * SPEED, 1.0)
	position = _from.lerp(_to, _t)
