extends GutTest

const Fixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")

func test_valid_resolved_journey_waits_indefinitely_without_reroute_or_completion() -> void:
	var manager := Fixtures.manager()
	var path: Array[Vector3i] = [Vector3i.ZERO, Vector3i(1,0,0), Vector3i(2,0,0)]
	var journey_id := Fixtures.request(manager, 1, path)
	manager._reserved[Vector3i(1,0,0)] = {
		90:{"dir":Vector2i.RIGHT,"slot":0,"phase":"current","claim_order":0},
		91:{"dir":Vector2i.RIGHT,"slot":1,"phase":"current","claim_order":1},
	}
	manager._process(0.0)
	for _step in 600:
		manager._process(1.0 / 30.0)
	var snapshot: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(snapshot["active_car_count"], 1)
	assert_eq(snapshot["pending_departure_count"], 0)
	assert_eq(snapshot["active_journeys"][0]["journey_id"], journey_id)
	assert_eq(snapshot["active_journeys"][0]["road_path"], path.map(func(cell): return {"x":cell.x,"y":cell.y,"z":cell.z}))
	assert_true(snapshot["active_journeys"][0]["waiting"])
	assert_eq(manager._road_network.legacy_route_queries, 0)
	Fixtures.free_manager(manager)

func test_dependent_invalidation_cancels_pending_and_active_only() -> void:
	var manager := Fixtures.manager()
	var affected_path: Array[Vector3i] = [Vector3i.ZERO, Vector3i(1,0,0), Vector3i(2,0,0)]
	var safe_path: Array[Vector3i] = [Vector3i(10,0,0), Vector3i(11,0,0), Vector3i(12,0,0)]
	var active_affected := Fixtures.request(manager, 1, affected_path)
	var active_safe := Fixtures.request(manager, 2, safe_path)
	manager._process(0.0)
	var pending_affected := Fixtures.request(manager, 3, affected_path)
	manager._on_structure_demolished(Vector3i(1,0,0))
	assert_false(manager._active.has(active_affected))
	assert_true(manager._active.has(active_safe))
	assert_false(manager._pending.has(pending_affected))
	Fixtures.free_manager(manager)
