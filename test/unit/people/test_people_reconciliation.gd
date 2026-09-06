extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

class RouteDouble extends PluginBase:
	var revision := 2
	var results: Dictionary = {}
	func get_revision() -> int: return revision
	func resolve_civilian_route(origin: Vector2i, destination: Vector2i) -> Dictionary:
		return results.get([origin, destination], {"ok":false,"road_revision":revision,"blocked_reason":"disconnected"}).duplicate(true)

class CarDouble extends PluginBase:
	var cancelled: Array[int] = []
	func cancel_journey(jid: int) -> void: cancelled.append(jid)

func _person(id: int, path: Array[Vector3i]) -> PersonSlot:
	var person := PersonSlot.new()
	person.resident_id = id; person.home_anchor = Vector2i(path.front().x, path.front().z)
	person.current_place = person.home_anchor; person.destination_anchor = Vector2i(path.back().x, path.back().z)
	person.position = Vector3(id, 0, id); person.plan_key = "plan-%d" % id; person.journey_id = id + 10
	person.journey_revision = 1; person.state = PersonSlot.VisualState.IN_CAR
	person.journey_plan = {"road_path_vectors":path.duplicate(),"road_revision":1,"origin_stop":path.front(),"destination_stop":path.back()}
	return person

func test_unrelated_placement_preserves_positions_plan_keys_and_car_ids() -> void:
	var plugin := PeoplePlugin.new(); plugin._road_network = RouteDouble.new(); plugin._car_manager = CarDouble.new()
	var person := _person(1, [Vector3i.ZERO, Vector3i(1,0,0)])
	plugin._people = [person]; plugin._resident_index = {1:person}; plugin._journey_by_person = {person:11}; plugin._person_by_journey = {11:person}
	plugin._on_structure_placed(Vector3i(20,0,20), 0, 0)
	assert_eq(person.position, Vector3(1,0,1)); assert_eq(person.plan_key, "plan-1"); assert_eq(person.journey_id, 11)
	plugin._road_network.free(); plugin._car_manager.free(); plugin.free()

func test_dependent_road_removal_invalidates_only_affected_plan() -> void:
	var plugin := PeoplePlugin.new(); plugin._road_network = RouteDouble.new(); plugin._car_manager = CarDouble.new()
	var affected := _person(1, [Vector3i.ZERO, Vector3i(1,0,0)]); var safe := _person(2, [Vector3i(5,0,0), Vector3i(6,0,0)])
	plugin._people = [affected,safe]; plugin._resident_index = {1:affected,2:safe}
	plugin._journey_by_person = {affected:11,safe:12}; plugin._person_by_journey = {11:affected,12:safe}
	plugin._on_structure_demolished(Vector3i(1,0,0))
	assert_eq(affected.state, PersonSlot.VisualState.BLOCKED); assert_eq(safe.plan_key, "plan-2"); assert_eq(safe.journey_id, 12)
	plugin._road_network.free(); plugin._car_manager.free(); plugin.free()

func test_stale_revision_with_same_canonical_path_preserves_plan_key() -> void:
	var plugin := PeoplePlugin.new(); var roads := RouteDouble.new(); plugin._road_network = roads; plugin._car_manager = CarDouble.new()
	var path: Array[Vector3i] = [Vector3i.ZERO, Vector3i(1,0,0)]; var person := _person(1, path)
	roads.results[[Vector2i.ZERO,Vector2i(1,0)]] = {"ok":true,"origin_stop":path.front(),"destination_stop":path.back(),"road_path":path,"route_distance":1,"road_revision":2,"blocked_reason":""}
	plugin._people = [person]; plugin._revalidate_stale_plans()
	assert_eq(person.journey_revision, 2); assert_eq(person.plan_key, "plan-1"); assert_eq(person.journey_id, 11)
	plugin._road_network.free(); plugin._car_manager.free(); plugin.free()
