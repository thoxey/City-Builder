extends GutTest

const RoadNetworkPlugin := preload("res://plugins/traffic/road_network_plugin.gd")

var _saved_registry: Dictionary

func before_each() -> void:
	_saved_registry = GameState.building_registry
	GameState.building_registry = {
		10:{"anchor":Vector2i(0, 1)}, 20:{"anchor":Vector2i(4, 1)}
	}

func after_each() -> void:
	GameState.building_registry = _saved_registry

func _network() -> Node:
	var network := RoadNetworkPlugin.new()
	network._revision = 7
	network._graph = {
		Vector3i(0,0,0):[Vector3i(1,0,0)],
		Vector3i(1,0,0):[Vector3i(0,0,0),Vector3i(2,0,0)],
		Vector3i(2,0,0):[Vector3i(1,0,0),Vector3i(3,0,0)],
		Vector3i(3,0,0):[Vector3i(2,0,0)],
	}
	network._build_components()
	network._access_by_building = {
		10:{"internal_id":10,"road_accessible":true,"stops":[{"x":0,"z":0}],"component_ids":["0,0"],"reasons":[],"primary_reason":""},
		20:{"internal_id":20,"road_accessible":true,"stops":[{"x":3,"z":0}],"component_ids":["0,0"],"reasons":[],"primary_reason":""},
	}
	return network

func test_projection_contains_resolved_stops_distance_revision_and_detached_path() -> void:
	var network := _network()
	var route: Dictionary = network.resolve_civilian_route(Vector2i(0,1), Vector2i(4,1))
	assert_true(route["ok"])
	assert_eq(route["origin_stop"], {"x":0,"y":0,"z":0})
	assert_eq(route["destination_stop"], {"x":3,"y":0,"z":0})
	assert_eq(route["route_distance"], 3)
	assert_eq(route["road_revision"], 7)
	route["road_path"].clear()
	assert_eq(network.resolve_civilian_route(Vector2i(0,1), Vector2i(4,1))["road_path"].size(), 4)
	network.free()

func test_equal_cost_resolution_is_stable_across_repeats() -> void:
	var network := _network()
	var expected: Dictionary = network.resolve_civilian_route(Vector2i(0,1), Vector2i(4,1))
	for _index in 10:
		assert_eq(network.resolve_civilian_route(Vector2i(0,1), Vector2i(4,1)), expected)
	network.free()
