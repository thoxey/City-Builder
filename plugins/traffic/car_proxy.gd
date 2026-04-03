extends Node3D
class_name CarProxy

const SPEED := 3.0

var current_tile: Vector3i
var travel_dir: Vector2i = Vector2i.ZERO  # last direction moved, in XZ tile space

var _from: Vector3
var _to: Vector3
var _t: float = 1.0

func place_at(tile: Vector3i, world_pos: Vector3) -> void:
	current_tile = tile
	travel_dir = Vector2i.ZERO
	_from = world_pos
	_to = world_pos
	_t = 1.0
	position = world_pos

func travel_to(tile: Vector3i, world_pos: Vector3) -> void:
	travel_dir = Vector2i(tile.x - current_tile.x, tile.z - current_tile.z)
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
