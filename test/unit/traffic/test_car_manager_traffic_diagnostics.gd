extends GutTest

const Fixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")

func _path() -> Array[Vector3i]:
	return [Vector3i.ZERO, Vector3i(1,0,0), Vector3i(2,0,0)]

func test_clean_projection_is_stable_complete_and_detached() -> void:
	var manager := Fixtures.manager()
	Fixtures.request(manager, 1, _path())
	manager._process(0.0)
	var first: Dictionary = manager.get_traffic_flow_snapshot()
	var second: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(JSON.stringify(first), JSON.stringify(second))
	assert_eq(first["schema_version"], 1)
	assert_true(first["violations"].is_empty())
	first["active_journeys"][0]["road_path"].clear()
	first["tile_occupancy"].clear()
	var detached: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(detached["active_journeys"][0]["road_path"].size(), 3)
	assert_gt(detached["tile_occupancy"].size(), 0)
	Fixtures.free_manager(manager)

func test_all_required_vehicle_fault_codes_are_detected_in_stable_order() -> void:
	var manager := Fixtures.manager()
	for resident_id in range(1, 5):
		Fixtures.request(manager, resident_id, _path())
	manager._process(0.0)
	manager._pending_order.reverse()
	var first: CarSlot = manager._active[0]
	var second: CarSlot = manager._active[1]
	first.position = Vector3(99, 0, 99)
	second.position = first.position
	first.admitted = false
	first.route = [Vector3i.ZERO, Vector3i(0,0,1)]
	manager._reserved[first.current_tile].erase(first.journey_id)
	first.next_tile = Vector3i(8,0,8)
	manager._reserved[Vector3i(7,0,7)] = {
		90:{"dir":Vector2i.RIGHT,"slot":0,"phase":"current","claim_order":90},
		91:{"dir":Vector2i.RIGHT,"slot":1,"phase":"current","claim_order":91},
		92:{"dir":Vector2i.RIGHT,"slot":2,"phase":"current","claim_order":92},
	}
	var codes: Array = manager.get_traffic_flow_snapshot()["violations"].map(
		func(row): return row["code"])
	var required := ["canonical_route_changed_by_congestion", "car_transform_off_road",
		"duplicate_car_position", "invalid_next_tile_claim", "missing_current_tile_claim",
		"pending_order_violation", "road_tile_over_capacity", "spawned_without_admission"]
	for code in required:
		assert_has(codes, code)
	var sorted_codes := codes.duplicate()
	sorted_codes.sort()
	assert_eq(codes, sorted_codes)
	Fixtures.free_manager(manager)

func test_pending_and_occupancy_rows_follow_contract_order() -> void:
	var manager := Fixtures.manager()
	for resident_id in range(1, 5):
		Fixtures.request(manager, resident_id, _path())
	manager._process(0.0)
	var snapshot: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(snapshot["pending_departures"].map(func(row): return row["resident_id"]), [3,4])
	for occupancy: Dictionary in snapshot["tile_occupancy"]:
		var slots: Array = occupancy["claims"].map(func(claim): return claim["slot"])
		var sorted_slots := slots.duplicate(); sorted_slots.sort()
		assert_eq(slots, sorted_slots)
	Fixtures.free_manager(manager)
