class_name CarManagerTestFixtures
extends RefCounted

class RoadDouble:
	extends PluginBase
	var revision := 1
	var legacy_route_queries := 0
	func get_revision() -> int: return revision
	func get_lane_position(tile: Vector3i, direction: Vector2i) -> Vector3:
		var base := Vector3(tile.x, 0.0, tile.z)
		if direction == Vector2i.ZERO:
			return base
		return base + Vector3(direction.y, 0.0, -direction.x).normalized() * 0.2
	func get_stops_for_building(tile: Vector3i) -> Array[Vector3i]:
		legacy_route_queries += 1
		return [tile]
	func get_road_graph() -> Dictionary: return {}
	func get_edge_cost(_from: Vector3i, _to: Vector3i) -> float: return 1.0

class PoolDouble:
	extends RefCounted
	var capacity := 2
	var active := 0
	func allocate() -> bool:
		if active >= capacity: return false
		active += 1
		return true
	func release() -> void: active = maxi(0, active - 1)

static func manager(pool_capacity := 8) -> Node:
	var instance := preload("res://plugins/traffic/car_manager_plugin.gd").new()
	instance._road_network = RoadDouble.new()
	var pool := preload("res://plugins/traffic/car_manager_plugin.gd").TypePool.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = pool_capacity
	pool.mminstance = MultiMeshInstance3D.new()
	pool.mminstance.multimesh = multimesh
	for index in pool_capacity:
		pool.free_indices.append(index)
	instance._pools = {CarSlot.CarType.CIVILIAN: pool}
	return instance

static func free_manager(manager_instance: Node) -> void:
	var road: Variant = manager_instance._road_network
	var pool: Variant = manager_instance._pools.get(CarSlot.CarType.CIVILIAN)
	manager_instance._cancel_all()
	if pool and pool.mminstance:
		pool.mminstance.free()
	if road:
		road.free()
	manager_instance.free()

static func request(manager_instance: Node, resident_id: int,
		path: Array[Vector3i], plan_key := "") -> int:
	return manager_instance.request_resolved_journey(
		resident_id, path.front(), path.back(), path, 1,
		plan_key if not plan_key.is_empty() else "plan-%d" % resident_id)

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
