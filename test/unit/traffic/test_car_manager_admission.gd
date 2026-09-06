extends GutTest

const Fixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")

func _path(origin_x := 0, direction := 1) -> Array[Vector3i]:
	return [Vector3i(origin_x, 0, 0), Vector3i(origin_x + direction, 0, 0),
		Vector3i(origin_x + direction * 2, 0, 0)]

func test_every_valid_request_is_pending_until_deterministic_step() -> void:
	var manager := Fixtures.manager(8)
	var ids: Array[int] = []
	for resident_id in range(1, 5):
		ids.append(Fixtures.request(manager, resident_id, _path()))
	assert_true(ids.all(func(journey_id): return journey_id >= 0))
	var before: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(before["active_car_count"], 0)
	assert_eq(before["pending_departure_count"], 4)
	manager._process(0.0)
	var after: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(after["active_car_count"], 2)
	assert_eq(after["pending_departure_count"], 2)
	assert_eq(after["pending_departures"].map(func(row): return row["resident_id"]), [3, 4])
	Fixtures.free_manager(manager)

func test_release_admits_exactly_one_next_fifo_request() -> void:
	var manager := Fixtures.manager(8)
	for resident_id in range(1, 5):
		Fixtures.request(manager, resident_id, _path())
	manager._process(0.0)
	manager.cancel_journey(0)
	manager._process(0.0)
	var snapshot: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(snapshot["active_journeys"].map(func(row): return row["journey_id"]), [1, 2])
	assert_eq(snapshot["pending_departures"].map(func(row): return row["journey_id"]), [3])
	Fixtures.free_manager(manager)

func test_origin_claim_uses_first_canonical_direction() -> void:
	var manager := Fixtures.manager()
	var journey_id := Fixtures.request(manager, 7, _path(4, -1))
	manager._process(0.0)
	var row: Dictionary = manager.get_traffic_flow_snapshot()["active_journeys"][0]
	assert_eq(row["journey_id"], journey_id)
	assert_eq(row["travel_direction"], {"x": -1, "z": 0})
	assert_ne(row["display_position"], {"x": 4.0, "y": 0.0, "z": 0.0})
	Fixtures.free_manager(manager)

func test_pending_reason_distinguishes_origin_and_pool_capacity() -> void:
	var origin_limited := Fixtures.manager(8)
	for resident_id in range(1, 4):
		Fixtures.request(origin_limited, resident_id, _path())
	origin_limited._process(0.0)
	assert_eq(origin_limited.get_traffic_flow_snapshot()["pending_departures"][0]["waiting_reason"],
		"origin_capacity")
	Fixtures.free_manager(origin_limited)

	var pool_limited := Fixtures.manager(1)
	Fixtures.request(pool_limited, 1, _path(0))
	Fixtures.request(pool_limited, 2, _path(10))
	pool_limited._process(0.0)
	assert_eq(pool_limited.get_traffic_flow_snapshot()["pending_departures"][0]["waiting_reason"],
		"car_pool_capacity")
	Fixtures.free_manager(pool_limited)

func test_cancelling_pending_request_never_spawns_or_completes_it() -> void:
	var manager := Fixtures.manager()
	var journey_id := Fixtures.request(manager, 3, _path())
	manager.cancel_journey(journey_id)
	manager._process(0.0)
	var snapshot: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(snapshot["pending_departure_count"], 0)
	assert_eq(snapshot["active_car_count"], 0)
	Fixtures.free_manager(manager)
