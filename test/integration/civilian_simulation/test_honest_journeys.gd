extends GutTest

const PeoplePolicyTest := preload("res://test/unit/people/test_people_journey_policy.gd")
const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

func test_matched_connected_and_disconnected_routes_are_honest() -> void:
	var fixtures := PeoplePolicyTest.new()
	var connected := PeoplePlugin.new(); var connected_roads := PeoplePolicyTest.RouteDouble.new()
	connected._road_network = connected_roads; connected._walk_route_threshold = 6
	connected_roads.result = fixtures._route(4, true)
	var walker := fixtures._person(); walker.destination_anchor = Vector2i(4, 0); connected._plan_journey(walker)
	assert_eq(walker.state, PersonSlot.VisualState.WALKING_ROUTE)
	assert_eq(walker._waypoint_tiles.size(), 5)
	var disconnected := PeoplePlugin.new(); var disconnected_roads := PeoplePolicyTest.RouteDouble.new()
	disconnected._road_network = disconnected_roads
	disconnected_roads.result = fixtures._route(4, false)
	var blocked := fixtures._person(); blocked.destination_anchor = Vector2i(4, 0); disconnected._plan_journey(blocked)
	assert_eq(blocked.state, PersonSlot.VisualState.BLOCKED)
	assert_true(blocked._waypoints.is_empty())
	connected_roads.free(); disconnected_roads.free(); connected.free(); disconnected.free(); fixtures.free()
