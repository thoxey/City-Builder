extends Node3D
class_name PersonProxy

## Handles walking movement, facing, and procedural bob animation.
## PeoplePlugin owns state logic; this class only handles the physical body.

const WALK_SPEED := 1.5   # tiles/sec
const ROT_SPEED  := 12.0
const BOB_FREQ   := 9.0   # cycles per second while walking
const BOB_HEIGHT := 0.035

var current_tile: Vector3i

var _waypoints: Array[Vector3] = []
var _waypoint_tiles: Array[Vector3i] = []
var _bob_time: float = 0.0
var _model: Node3D = null  # assigned by PeoplePlugin after creation

func place_at(tile: Vector3i, world_pos: Vector3) -> void:
	current_tile = tile
	position = world_pos
	_waypoints.clear()
	_waypoint_tiles.clear()

func walk_to(tiles: Array[Vector3i], positions: Array[Vector3]) -> void:
	_waypoint_tiles.assign(tiles)
	_waypoints.assign(positions)

func is_walking() -> bool:
	return not _waypoints.is_empty()

func set_model_visible(v: bool) -> void:
	if _model:
		_model.visible = v

func _process(delta: float) -> void:
	if not _waypoints.is_empty():
		var target := _waypoints[0]
		var step := WALK_SPEED * delta
		var dist := position.distance_to(target)

		# Rotate to face travel direction
		var d := target - position
		d.y = 0.0
		if d.length_squared() > 0.001:
			var tb := Basis.looking_at(d.normalized())
			basis = basis.slerp(tb, delta * ROT_SPEED)

		if step >= dist:
			position = target
			current_tile = _waypoint_tiles[0]
			_waypoints.pop_front()
			_waypoint_tiles.pop_front()
		else:
			position += position.direction_to(target) * step

		# Procedural walking bob
		_bob_time += delta * BOB_FREQ * TAU
		if _model:
			_model.position.y = sin(_bob_time) * BOB_HEIGHT
	else:
		_bob_time = 0.0
		if _model:
			_model.position.y = lerpf(_model.position.y, 0.0, delta * 10.0)
