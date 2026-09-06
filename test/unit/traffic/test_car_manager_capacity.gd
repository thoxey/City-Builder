extends GutTest

const Fixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")

func _path(cells: Array[Vector3i]) -> Array[Vector3i]:
	return cells

func _row(snapshot: Dictionary, journey_id: int) -> Dictionary:
	for row: Dictionary in snapshot["active_journeys"]:
		if int(row["journey_id"]) == journey_id:
			return row
	return {}

func test_two_total_claims_apply_even_when_directions_oppose() -> void:
	var manager := Fixtures.manager()
	Fixtures.request(manager, 1, _path([Vector3i.ZERO, Vector3i(1,0,0)]))
	Fixtures.request(manager, 2, _path([Vector3i.ZERO, Vector3i(-1,0,0)]))
	Fixtures.request(manager, 3, _path([Vector3i.ZERO, Vector3i(0,0,1)]))
	manager._process(0.0)
	var snapshot: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(snapshot["active_car_count"], 2)
	assert_eq(snapshot["pending_departure_count"], 1)
	var origin_rows: Array = snapshot["tile_occupancy"].filter(
		func(row): return row["tile"] == {"x":0,"y":0,"z":0})
	assert_eq(origin_rows[0]["claim_count"], 2)
	Fixtures.free_manager(manager)

func test_crossing_retains_current_and_next_claim_then_promotes_atomically() -> void:
	var manager := Fixtures.manager()
	var journey_id := Fixtures.request(manager, 1,
		_path([Vector3i.ZERO, Vector3i(1,0,0), Vector3i(2,0,0)]))
	manager._process(0.0)
	var crossing: Dictionary = _row(manager.get_traffic_flow_snapshot(), journey_id)
	assert_eq(crossing["current_tile"], {"x":0,"y":0,"z":0})
	assert_eq(crossing["next_tile"], {"x":1,"y":0,"z":0})
	assert_eq(manager.get_traffic_flow_snapshot()["tile_occupancy"].size(), 2)

	manager._process(1.0)
	var arrived: Dictionary = _row(manager.get_traffic_flow_snapshot(), journey_id)
	assert_eq(arrived["current_tile"], {"x":1,"y":0,"z":0})
	assert_null(arrived["next_tile"])
	var occupancy: Array = manager.get_traffic_flow_snapshot()["tile_occupancy"]
	assert_eq(occupancy.size(), 1)
	assert_eq(occupancy[0]["claims"][0]["phase"], "current")
	Fixtures.free_manager(manager)

func test_large_delta_crosses_at_most_one_capacity_boundary() -> void:
	var manager := Fixtures.manager()
	var journey_id := Fixtures.request(manager, 1,
		_path([Vector3i.ZERO, Vector3i(1,0,0), Vector3i(2,0,0), Vector3i(3,0,0)]))
	manager._process(10.0)
	var row: Dictionary = _row(manager.get_traffic_flow_snapshot(), journey_id)
	assert_eq(row["current_tile"], {"x":1,"y":0,"z":0})
	assert_eq(row["road_path"].size(), 4)
	Fixtures.free_manager(manager)

func test_same_direction_slots_are_distinct_and_bounded_inside_origin_tile() -> void:
	var manager := Fixtures.manager()
	Fixtures.request(manager, 1, _path([Vector3i.ZERO, Vector3i(1,0,0), Vector3i(2,0,0)]))
	Fixtures.request(manager, 2, _path([Vector3i.ZERO, Vector3i(1,0,0), Vector3i(2,0,0)]))
	manager._process(0.0)
	var rows: Array = manager.get_traffic_flow_snapshot()["active_journeys"]
	assert_ne(rows[0]["display_position"], rows[1]["display_position"])
	for row: Dictionary in rows:
		var position: Dictionary = row["display_position"]
		assert_lte(absf(float(position["x"])), 0.5)
		assert_lte(absf(float(position["z"])), 0.5)
	Fixtures.free_manager(manager)

func test_release_promotes_remaining_claim_in_stable_order() -> void:
	var manager := Fixtures.manager()
	var first := Fixtures.request(manager, 1, _path([Vector3i.ZERO, Vector3i(1,0,0)]))
	var second := Fixtures.request(manager, 2, _path([Vector3i.ZERO, Vector3i(1,0,0)]))
	manager._process(0.0)
	manager.cancel_journey(first)
	var row: Dictionary = _row(manager.get_traffic_flow_snapshot(), second)
	assert_eq(row["current_claim_slot"], 0)
	assert_eq(manager._reserved[Vector3i.ZERO][second]["slot"], 0)
	Fixtures.free_manager(manager)

func test_corner_interpolation_remains_within_claimed_tile_union() -> void:
	var manager := Fixtures.manager()
	var journey_id := Fixtures.request(manager, 1,
		_path([Vector3i.ZERO, Vector3i(1,0,0), Vector3i(1,0,1)]))
	manager._process(0.15)
	var row: Dictionary = _row(manager.get_traffic_flow_snapshot(), journey_id)
	var position: Dictionary = row["display_position"]
	var inside_current := absf(float(position["x"])) <= 0.5 and absf(float(position["z"])) <= 0.5
	var inside_next := absf(float(position["x"]) - 1.0) <= 0.5 and absf(float(position["z"])) <= 0.5
	assert_true(inside_current or inside_next)
	Fixtures.free_manager(manager)
