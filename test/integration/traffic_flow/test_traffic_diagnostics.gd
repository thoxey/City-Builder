extends GutTest

const Fixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")

func test_clean_congested_projection_has_no_faults_and_is_repeatable() -> void:
	var manager := Fixtures.manager()
	var path: Array[Vector3i] = [Vector3i.ZERO,Vector3i(1,0,0),Vector3i(2,0,0)]
	for resident_id in range(1,5): Fixtures.request(manager,resident_id,path)
	manager._process(0.0)
	var first: Dictionary = manager.get_traffic_flow_snapshot()
	var second: Dictionary = manager.get_traffic_flow_snapshot()
	assert_true(first["violations"].is_empty())
	assert_eq(JSON.stringify(first),JSON.stringify(second))
	assert_eq([first["active_car_count"],first["pending_departure_count"]],[2,2])
	Fixtures.free_manager(manager)

func test_fault_injection_does_not_change_unrelated_pending_identity() -> void:
	var manager := Fixtures.manager()
	var path: Array[Vector3i] = [Vector3i.ZERO,Vector3i(1,0,0),Vector3i(2,0,0)]
	for resident_id in range(1,5): Fixtures.request(manager,resident_id,path)
	manager._process(0.0)
	var pending_before: Array = manager.get_traffic_flow_snapshot()["pending_departures"].map(
		func(row): return row["journey_id"])
	manager._active[0].position = Vector3(50,0,50)
	var snapshot: Dictionary = manager.get_traffic_flow_snapshot()
	assert_has(snapshot["violations"].map(func(row): return row["code"]),"car_transform_off_road")
	assert_eq(snapshot["pending_departures"].map(func(row): return row["journey_id"]),pending_before)
	Fixtures.free_manager(manager)
