class_name CarManagerTestFixtures
extends RefCounted

class RoadDouble:
	extends RefCounted
	var revision := 1
	func get_revision() -> int: return revision
	func get_lane_position(tile: Vector3i, _direction: Vector2i) -> Vector3:
		return Vector3(tile.x, 0.0, tile.z)

class PoolDouble:
	extends RefCounted
	var capacity := 2
	var active := 0
	func allocate() -> bool:
		if active >= capacity: return false
		active += 1
		return true
	func release() -> void: active = maxi(0, active - 1)

static func resolved_journey(resident_id := 42, revision := 3,
		path: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]) -> Dictionary:
	return {
		"resident_id": resident_id,
		"origin_stop": path.front(),
		"destination_stop": path.back(),
		"road_path": path.duplicate(),
		"road_revision": revision,
		"plan_key": "%d:%d:%s" % [resident_id, revision, str(path)],
	}
