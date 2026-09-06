extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

class RouteDouble extends PluginBase:
	var result: Dictionary
	func resolve_civilian_route(_origin: Vector2i, _destination: Vector2i) -> Dictionary: return result.duplicate(true)
	func get_revision() -> int: return int(result.get("road_revision", 0))

class CarDouble extends PluginBase:
	var accept := true
	var request: Dictionary = {}
	func request_resolved_journey(resident_id: int, origin: Vector3i, destination: Vector3i,
			path: Array[Vector3i], revision: int, key: String, _type := 0) -> int:
		request = {"resident_id":resident_id,"origin":origin,"destination":destination,"path":path.duplicate(),"revision":revision,"key":key}
		return 12 if accept else -1
	func cancel_journey(_id: int) -> void: pass

func _person() -> PersonSlot:
	var person := PersonSlot.new()
	person.resident_id = 5; person.resident_seed = 55
	person.home_anchor = Vector2i.ZERO; person.current_place = Vector2i.ZERO
	person.destination_anchor = Vector2i(3,0); person.purpose = "work"
	return person

func _route(distance: int, ok := true) -> Dictionary:
	return {"ok":ok,"origin_stop":{"x":0,"y":0,"z":0},"destination_stop":{"x":distance,"y":0,"z":0},
		"road_path":range(distance + 1).map(func(x): return {"x":x,"y":0,"z":0}),
		"route_distance":distance,"road_revision":4,"blocked_reason":"" if ok else "disconnected"}

func test_route_distance_at_threshold_walks_only_canonical_waypoints() -> void:
	var plugin := PeoplePlugin.new(); var roads := RouteDouble.new(); var cars := CarDouble.new()
	plugin._road_network = roads; plugin._car_manager = cars; plugin._walk_route_threshold = 3
	roads.result = _route(3)
	var person := _person(); plugin._plan_journey(person)
	assert_eq(person.mode, "walk")
	assert_eq(person._waypoint_tiles, [Vector3i.ZERO,Vector3i(1,0,0),Vector3i(2,0,0),Vector3i(3,0,0)])
	roads.free(); cars.free(); plugin.free()

func test_threshold_plus_one_uses_resolved_car_request() -> void:
	var plugin := PeoplePlugin.new(); var roads := RouteDouble.new(); var cars := CarDouble.new()
	plugin._road_network = roads; plugin._car_manager = cars; plugin._walk_route_threshold = 3
	roads.result = _route(4)
	var person := _person(); plugin._plan_journey(person); plugin._begin_car_journey(person)
	assert_eq(person.mode, "car")
	assert_eq(cars.request["resident_id"], 5)
	assert_eq(cars.request["revision"], 4)
	roads.free(); cars.free(); plugin.free()

func test_disconnected_route_blocks_without_direct_waypoint() -> void:
	var plugin := PeoplePlugin.new(); var roads := RouteDouble.new()
	plugin._road_network = roads; roads.result = _route(3, false)
	var person := _person(); plugin._plan_journey(person)
	assert_eq(person.state, PersonSlot.VisualState.BLOCKED)
	assert_eq(person.blocked_reason, "disconnected")
	assert_true(person._waypoints.is_empty())
	roads.free(); plugin.free()
