extends GutTest

const CarManagerPlugin := preload("res://plugins/traffic/car_manager_plugin.gd")

class RoadDouble extends PluginBase:
	func get_lane_position(tile: Vector3i, _direction: Vector2i) -> Vector3: return Vector3(tile.x,0,tile.z)

func _manager(capacity := 1) -> Node:
	var manager := CarManagerPlugin.new()
	manager._road_network = RoadDouble.new()
	var pool := CarManagerPlugin.TypePool.new()
	for i in capacity: pool.free_indices.append(i)
	manager._pools = {CarSlot.CarType.CIVILIAN:pool}
	return manager

func test_resolved_request_copies_path_and_preserves_identity() -> void:
	var manager := _manager()
	var path: Array[Vector3i] = [Vector3i.ZERO,Vector3i(1,0,0),Vector3i(2,0,0)]
	var jid: int = manager.request_resolved_journey(42,path.front(),path.back(),path,9,"plan-42")
	assert_gte(jid, 0)
	path.clear()
	var row: Dictionary = manager.get_civilian_snapshot()["pending_departures"][0]
	assert_eq(row["resident_id"], 42)
	assert_eq(row["road_path"].size(), 3)
	assert_eq(row["plan_key"], "plan-42")
	manager._road_network.free(); manager.free()

func test_pool_full_keeps_valid_request_pending_without_fallback() -> void:
	var manager := _manager(0)
	var path: Array[Vector3i] = [Vector3i.ZERO,Vector3i(1,0,0)]
	assert_gte(manager.request_resolved_journey(1,path.front(),path.back(),path,2,"p"), 0)
	manager._process(0.0)
	assert_eq(manager.get_civilian_snapshot()["active_car_count"], 0)
	assert_eq(manager.get_civilian_snapshot()["pending_departure_count"], 1)
	assert_eq(manager.get_civilian_snapshot()["pending_departures"][0]["waiting_reason"], "car_pool_capacity")
	manager._road_network.free(); manager.free()

func test_malformed_resolved_requests_are_rejected_without_pending_state() -> void:
	var manager := _manager()
	var path: Array[Vector3i] = [Vector3i.ZERO, Vector3i(1,0,0)]
	assert_eq(manager.request_resolved_journey(1, path.front(), path.back(), path,
		-1, "negative-revision"), -1)
	assert_eq(manager.request_resolved_journey(-1, path.front(), path.back(), path,
		1, "negative-resident"), -1)
	assert_eq(manager.request_resolved_journey(1, path.front(), path.back(), path,
		1, ""), -1)
	var discontinuous: Array[Vector3i] = [Vector3i.ZERO, Vector3i(2,0,0)]
	assert_eq(manager.request_resolved_journey(1, discontinuous.front(),
		discontinuous.back(), discontinuous, 1, "discontinuous"), -1)
	assert_eq(manager._pending.size(), 0)
	manager._road_network.free(); manager.free()
