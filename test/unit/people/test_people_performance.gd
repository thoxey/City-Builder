extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")
const CarManagerPlugin := preload("res://plugins/traffic/car_manager_plugin.gd")
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
