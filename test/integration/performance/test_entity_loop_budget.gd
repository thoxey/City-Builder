extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")
const CarFixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")

func test_512_people_and_256_vehicle_slots_stay_below_eight_millisecond_p95() -> void:
	var people := PeoplePlugin.new()
	var cars = CarFixtures.manager(256)
	for resident_id in 512:
		var person := PersonSlot.new()
		person.resident_id = resident_id + 1
		person.home_anchor = Vector2i(resident_id, 0)
		person.current_place = person.home_anchor
		person.destination_anchor = person.home_anchor
		people._people.append(person)
		people._resident_index[person.resident_id] = person
	for vehicle_id in 256:
		var origin := Vector3i(vehicle_id * 3, 0, 0)
		CarFixtures.request(cars, vehicle_id + 1, [origin, origin + Vector3i.RIGHT, origin + Vector3i.RIGHT * 2])
	cars._process(0.0)
	var samples: Array[int] = []
	for _sample in 180:
		var started := Time.get_ticks_usec()
		cars._process(1.0 / 60.0)
		people._process(1.0 / 60.0)
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	var p95: int = samples[ceili(samples.size() * 0.95) - 1]
	assert_lt(p95, 8_000, "combined entity loop p95 was %.3f ms" % (float(p95) / 1000.0))
	CarFixtures.free_manager(cars)
	people.free()
