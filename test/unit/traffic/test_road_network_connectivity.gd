extends GutTest

const RoadNetworkPlugin := preload("res://plugins/traffic/road_network_plugin.gd")

var _network: Node

func before_each() -> void:
	_network = RoadNetworkPlugin.new()
	add_child(_network)

func after_each() -> void:
	_network.queue_free()

func test_components_receive_stable_minimum_cell_ids() -> void:
	_network._graph = {
		Vector3i(4, 0, 0): [Vector3i(3, 0, 0)],
		Vector3i(3, 0, 0): [Vector3i(4, 0, 0)],
		Vector3i(-2, 0, 5): [],
	}
	_network._build_components()
	assert_eq(_network._component_by_cell[Vector3i(4, 0, 0)], "3,0")
	assert_eq(_network._component_by_cell[Vector3i(-2, 0, 5)], "-2,5")

func test_shortest_route_is_stable_and_reports_distance() -> void:
	_network._graph = {
		Vector3i(0, 0, 0): [Vector3i(1, 0, 0)],
		Vector3i(1, 0, 0): [Vector3i(0, 0, 0), Vector3i(2, 0, 0)],
		Vector3i(2, 0, 0): [Vector3i(1, 0, 0)],
	}
	_network._build_components()
	_network._access_by_building = {
		1: {"internal_id": 1, "road_accessible": true, "stops": [{"x": 0, "z": 0}], "component_ids": ["0,0"], "reasons": [], "primary_reason": ""},
		2: {"internal_id": 2, "road_accessible": true, "stops": [{"x": 2, "z": 0}], "component_ids": ["0,0"], "reasons": [], "primary_reason": ""},
	}
	var route: Dictionary = _network.get_route_between_buildings(1, 2)
	assert_true(route["reachable"])
	assert_eq(route["distance"], 2)
	assert_eq(route["path"], [{"x": 0, "z": 0}, {"x": 1, "z": 0}, {"x": 2, "z": 0}])

func test_route_distinguishes_missing_access_from_isolated_component() -> void:
	_network._access_by_building = {
		1: {"internal_id": 1, "road_accessible": false, "stops": [], "component_ids": [], "reasons": ["no_road_access"], "primary_reason": "no_road_access"},
		2: {"internal_id": 2, "road_accessible": true, "stops": [{"x": 5, "z": 0}], "component_ids": ["5,0"], "reasons": [], "primary_reason": ""},
	}
	assert_eq(_network.get_route_between_buildings(1, 2)["reason"], "no_road_access")
	_network._access_by_building[1] = {"internal_id": 1, "road_accessible": true, "stops": [{"x": 0, "z": 0}], "component_ids": ["0,0"], "reasons": [], "primary_reason": ""}
	_network._clear_query_caches()
	assert_eq(_network.get_route_between_buildings(1, 2)["reason"], "isolated_road_component")

func test_snapshot_is_detached_from_internal_state() -> void:
	_network._graph = {Vector3i.ZERO: []}
	_network._build_components()
	_network._revision = 7
	var snapshot: Dictionary = _network.get_connectivity_snapshot()
	snapshot["components"].clear()
	assert_eq(_network.get_connectivity_snapshot()["revision"], 7)
	assert_eq(_network.get_connectivity_snapshot()["components"].size(), 1)
