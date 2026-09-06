extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")
const CarManagerPlugin := preload("res://plugins/traffic/car_manager_plugin.gd")
const CarFixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")
const SAMPLE_COUNT := 300

func test_512_proxy_update_stays_within_frame_budget_without_diagnostics() -> void:
	var people := PeoplePlugin.new(); var cars := CarManagerPlugin.new()
	for id in 512:
		var person := PersonSlot.new(); person.resident_id = id + 1; person.home_anchor = Vector2i(id,0)
		person.current_place = person.home_anchor; person.destination_anchor = person.home_anchor
		people._people.append(person); people._resident_index[id + 1] = person
	var total_usec := 0; var maximum_usec := 0
	for _sample in SAMPLE_COUNT:
		var started := Time.get_ticks_usec(); cars._process(1.0 / 60.0); people._process(1.0 / 60.0)
		var elapsed := Time.get_ticks_usec() - started; total_usec += elapsed; maximum_usec = maxi(maximum_usec,elapsed)
	var snapshot_started := Time.get_ticks_usec(); var snapshot := people.get_civilian_snapshot(); var snapshot_usec := Time.get_ticks_usec() - snapshot_started
	var average_ms := float(total_usec) / float(SAMPLE_COUNT) / 1000.0
	gut.p("CIVILIAN_PERF proxies=512 samples=%d average_ms=%.4f max_ms=%.4f snapshot_ms=%.4f" % [SAMPLE_COUNT,average_ms,float(maximum_usec)/1000.0,float(snapshot_usec)/1000.0])
	assert_eq(snapshot["visible_count"],512); assert_lt(average_ms,16.7)
	people.free(); cars.free()

func test_512_mixed_traffic_update_stays_within_frame_budget_and_profiles_diagnostics_separately() -> void:
	var people := PeoplePlugin.new()
	var cars := CarFixtures.manager(256)
	people._car_manager = cars
	var paths: Array[Array] = []
	for origin_index in 128:
		var origin := Vector3i(origin_index * 4, 0, 0)
		var path: Array[Vector3i] = [origin, origin + Vector3i.RIGHT,
			origin + Vector3i.RIGHT * 2]
		paths.append(path)
		cars._reserved[path[1]] = {
			10_000 + origin_index * 2:{"dir":Vector2i.RIGHT,"slot":0,
				"phase":"current","claim_order":origin_index * 2},
			10_001 + origin_index * 2:{"dir":Vector2i.RIGHT,"slot":1,
				"phase":"current","claim_order":origin_index * 2 + 1},
		}
	for index in 512:
		var person := PersonSlot.new()
		person.resident_id = index + 1
		person.home_anchor = Vector2i(index, 0)
		person.current_place = person.home_anchor
		person.destination_anchor = person.home_anchor
		person.visible = true
		if index < 384:
			var path: Array[Vector3i] = paths[index % paths.size()]
			person.state = PersonSlot.VisualState.WAITING_FOR_CAR
			person.current_tile = path.front()
			person.position = Vector3(path.front())
			person.display_position = person.position
			person.journey_plan = {"road_path_vectors":path.duplicate(),
				"route_distance":path.size() - 1}
			person.journey_id = CarFixtures.request(cars, person.resident_id, path)
		else:
			var lane := index - 384
			person.state = PersonSlot.VisualState.WALKING_ROUTE
			person.current_tile = Vector3i(0, 0, 20 + lane % 32)
			person.position = Vector3(0.1 + float(lane / 32) * 0.03, 0.1,
				person.current_tile.z)
			person.display_position = person.position
			person._waypoint_tiles = [person.current_tile + Vector3i(1000, 0, 0)]
			person._waypoints = [Vector3(1000.0, 0.1, person.current_tile.z)]
			person.journey_plan = {"road_path_vectors":person._waypoint_tiles.duplicate(),
				"route_distance":1000}
		people._people.append(person)
		people._resident_index[person.resident_id] = person
	cars._process(0.0)
	assert_eq(cars._active.size(), 256)
	assert_eq(cars._pending.size(), 128)

	var total_usec := 0
	var maximum_usec := 0
	for _sample in SAMPLE_COUNT:
		var started := Time.get_ticks_usec()
		cars._process(1.0 / 60.0)
		people._process(1.0 / 60.0)
		var elapsed := Time.get_ticks_usec() - started
		total_usec += elapsed
		maximum_usec = maxi(maximum_usec, elapsed)
	var diagnostic_started := Time.get_ticks_usec()
	var car_snapshot: Dictionary = cars.get_traffic_flow_snapshot(
		people.get_pedestrian_spacing_snapshot())
	var car_diagnostic_usec := Time.get_ticks_usec() - diagnostic_started
	diagnostic_started = Time.get_ticks_usec()
	var people_snapshot: Dictionary = people.get_civilian_snapshot()
	var people_diagnostic_usec := Time.get_ticks_usec() - diagnostic_started
	var average_ms := float(total_usec) / float(SAMPLE_COUNT) / 1000.0
	gut.p("TRAFFIC_FLOW_PERF civilians=512 cars=%d pending=%d walkers=128 samples=%d average_ms=%.4f max_ms=%.4f car_diagnostics_ms=%.4f people_diagnostics_ms=%.4f" % [
		cars._active.size(), cars._pending.size(), SAMPLE_COUNT, average_ms,
		float(maximum_usec) / 1000.0, float(car_diagnostic_usec) / 1000.0,
		float(people_diagnostic_usec) / 1000.0])
	assert_eq(people_snapshot["visible_count"], 512)
	assert_eq(car_snapshot["active_car_count"], 256)
	assert_eq(car_snapshot["pending_departure_count"], 128)
	assert_eq(car_snapshot["waiting_car_count"], 256)
	assert_lt(average_ms, 16.7)
	CarFixtures.free_manager(cars)
	people.free()
