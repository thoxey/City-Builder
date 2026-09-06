extends GutTest

const Fixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")
const FlowFixtures := preload("res://test/integration/traffic_flow/traffic_flow_fixtures.gd")

func test_four_same_origin_departures_admit_two_then_one_fifo() -> void:
	var manager := Fixtures.manager()
	var path := FlowFixtures.straight_path(5)
	for resident_id in range(1, 5):
		Fixtures.request(manager, resident_id, path)
	FlowFixtures.step_cars(manager)
	var first: Dictionary = FlowFixtures.snapshot(manager)
	assert_eq([first["active_car_count"], first["pending_departure_count"]], [2, 2])
	manager.cancel_journey(0)
	FlowFixtures.step_cars(manager)
	var second: Dictionary = FlowFixtures.snapshot(manager)
	assert_eq(second["active_journeys"].map(func(row): return row["journey_id"]), [1, 2])
	assert_eq(second["pending_departures"].map(func(row): return row["journey_id"]), [3])
	Fixtures.free_manager(manager)

func test_downstream_capacity_backs_up_without_route_changes() -> void:
	var manager := Fixtures.manager()
	manager._reserved[Vector3i(1,0,0)] = {
		90:{"dir":Vector2i.RIGHT,"slot":0,"phase":"current","claim_order":0},
		91:{"dir":Vector2i.RIGHT,"slot":1,"phase":"current","claim_order":1},
	}
	var path := FlowFixtures.straight_path(4)
	Fixtures.request(manager, 1, path)
	Fixtures.request(manager, 2, path)
	FlowFixtures.step_cars(manager, 300)
	var snapshot: Dictionary = FlowFixtures.snapshot(manager)
	assert_eq(snapshot["waiting_car_count"], 2)
	assert_eq(snapshot["active_journeys"].map(func(row): return row["road_path"]),
		[path.map(func(cell): return {"x":cell.x,"y":cell.y,"z":cell.z}),
		 path.map(func(cell): return {"x":cell.x,"y":cell.y,"z":cell.z})])
	assert_true(snapshot["violations"].is_empty())
	Fixtures.free_manager(manager)
