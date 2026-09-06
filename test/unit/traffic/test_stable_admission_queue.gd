extends GutTest

const Fixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")

func _path(origin_x: int) -> Array[Vector3i]:
	return [Vector3i(origin_x, 0, 0), Vector3i(origin_x + 1, 0, 0), Vector3i(origin_x + 2, 0, 0)]

func test_each_origin_is_fifo_and_origins_receive_round_robin_opportunities() -> void:
	var manager := Fixtures.manager(3)
	var a0 := Fixtures.request(manager, 10, _path(0))
	var a1 := Fixtures.request(manager, 11, _path(0))
	var a2 := Fixtures.request(manager, 12, _path(0))
	var b0 := Fixtures.request(manager, 20, _path(10))
	manager._process(0.0)
	var active: Array = manager.get_traffic_flow_snapshot()["active_journeys"]
	assert_true(active.any(func(row): return row["journey_id"] == a0))
	assert_true(active.any(func(row): return row["journey_id"] == a1))
	assert_true(active.any(func(row): return row["journey_id"] == b0), "a busy origin must not starve a later origin")
	assert_false(active.any(func(row): return row["journey_id"] == a2))
	Fixtures.free_manager(manager)

func test_cancellation_removes_queue_entry_and_topology_reset_clears_cursor_state() -> void:
	var manager := Fixtures.manager(2)
	var first := Fixtures.request(manager, 1, _path(0))
	var second := Fixtures.request(manager, 2, _path(0))
	manager.cancel_journey(first)
	manager._process(0.0)
	assert_eq(manager.get_traffic_flow_snapshot()["active_journeys"][0]["journey_id"], second)
	manager._on_map_loaded(null)
	assert_eq(manager._pending_by_origin.size(), 0)
	assert_eq(manager._origin_order.size(), 0)
	assert_eq(manager._origin_cursor, 0)
	Fixtures.free_manager(manager)
