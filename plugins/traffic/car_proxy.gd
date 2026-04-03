extends Node3D
class_name CarProxy

const ROTATION_SPEED := 30.0
const TILT_ANGLE     := 22.0
const TILT_SPEED     := 80.0
const TILT_RESET_DIST := 0.4  # world units before tilt resets after a turn

var current_tile: Vector3i
var travel_dir: Vector2i = Vector2i.ZERO
var speed: float = 3.0

var _waypoints: Array[Vector3] = []
var _waypoint_tiles: Array[Vector3i] = []
var _prev_dir: Vector2i = Vector2i.ZERO
var _target_basis: Basis = Basis.IDENTITY
var _tilt: float = 0.0
var _target_tilt: float = 0.0
var _dist_since_turn: float = 0.0

func place_at(tile: Vector3i, world_pos: Vector3) -> void:
	current_tile = tile
	travel_dir = Vector2i.ZERO
	_prev_dir = Vector2i.ZERO
	_waypoints.clear()
	_waypoint_tiles.clear()
	position = world_pos

func set_path(tiles: Array[Vector3i], positions: Array[Vector3]) -> void:
	_waypoint_tiles.assign(tiles)
	_waypoints.assign(positions)
	if not _waypoints.is_empty():
		_update_dir(position, _waypoints[0])

func is_path_empty() -> bool:
	return _waypoints.is_empty()

func _process(delta: float) -> void:
	if not _waypoints.is_empty():
		var target := _waypoints[0]
		var dist_to := position.distance_to(target)
		var step := speed * delta

		if step >= dist_to:
			position = target
			current_tile = _waypoint_tiles[0]
			_waypoints.pop_front()
			_waypoint_tiles.pop_front()
			if not _waypoints.is_empty():
				_update_dir(position, _waypoints[0])
		else:
			position += position.direction_to(target) * step
			_dist_since_turn += step
			if _dist_since_turn >= TILT_RESET_DIST:
				_target_tilt = 0.0

	# Smooth tilt and rotation
	_tilt = lerpf(_tilt, _target_tilt, delta * TILT_SPEED)
	var tilt_basis := _target_basis.rotated(_target_basis.z, deg_to_rad(_tilt))
	basis = basis.slerp(tilt_basis, delta * ROTATION_SPEED)

func _update_dir(from_pos: Vector3, to_pos: Vector3) -> void:
	_prev_dir = travel_dir
	var d := to_pos - from_pos
	travel_dir = Vector2i(roundi(sign(d.x)), roundi(sign(d.z)))

	if travel_dir != Vector2i.ZERO:
		_target_basis = Basis.looking_at(Vector3(travel_dir.x, 0.0, travel_dir.y))

	if _prev_dir != Vector2i.ZERO and travel_dir != _prev_dir:
		var cross := _prev_dir.x * travel_dir.y - _prev_dir.y * travel_dir.x
		_target_tilt = -TILT_ANGLE * sign(cross)
		_dist_since_turn = 0.0
