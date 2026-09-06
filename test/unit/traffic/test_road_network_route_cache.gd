extends GutTest

const RoadNetworkPlugin := preload("res://plugins/traffic/road_network_plugin.gd")

var _network: Node

func before_each() -> void:
	_network = RoadNetworkPlugin.new()
	add_child(_network)
	_network._graph = {
		Vector3i(0, 0, 0): [Vector3i(1, 0, 0)],
		Vector3i(1, 0, 0): [Vector3i(0, 0, 0), Vector3i(2, 0, 0)],
		Vector3i(2, 0, 0): [Vector3i(1, 0, 0)],
	}
	_network._build_components()
	_network._access_by_building = {
		1: {"internal_id":1,"road_accessible":true,"stops":[{"x":0,"z":0}],"component_ids":["0,0"],"reasons":[],"primary_reason":""},
		2: {"internal_id":2,"road_accessible":true,"stops":[{"x":2,"z":0}],"component_ids":["0,0"],"reasons":[],"primary_reason":""},
	}

func after_each() -> void:
	_network.queue_free()

func test_repeated_route_uses_cache_and_returns_detached_results() -> void:
	var first: Dictionary = _network.get_route_between_buildings(1, 2)
	first["path"].clear()
	first["shared_component_ids"].clear()
	var second: Dictionary = _network.get_route_between_buildings(1, 2)
	var stats: Dictionary = _network.get_route_cache_stats()
	assert_eq(stats["misses"], 1)
	assert_eq(stats["hits"], 1)
	assert_eq(stats["entries"], 1)
	assert_eq(second["distance"], 2)
	assert_eq(second["path"].size(), 3)
	assert_eq(second["shared_component_ids"], ["0,0"])

func test_cache_clear_forces_new_resolution() -> void:
	_network.get_route_between_buildings(1, 2)
	_network._clear_query_caches()
	var cleared: Dictionary = _network.get_route_cache_stats()
	assert_eq(cleared, {"hits":0,"misses":0,"entries":0,"anchor_entries":0})
	_network.get_route_between_buildings(1, 2)
	assert_eq(_network.get_route_cache_stats()["misses"], 1)

func test_anchor_lookup_uses_rebuilt_stable_index() -> void:
	_network._internal_id_by_anchor = {Vector2i(4, 7): 12}
	assert_eq(_network.get_internal_id_for_anchor(Vector2i(4, 7)), 12)
	assert_eq(_network.get_internal_id_for_anchor(Vector2i(7, 4)), -1)

func test_lightweight_summary_reuses_route_without_exposing_path() -> void:
	var summary: Dictionary = _network.get_route_summary_between_buildings(1, 2)
	assert_true(summary["reachable"])
	assert_eq(summary["distance"], 2)
	assert_does_not_have(summary, "path")
	var again: Dictionary = _network.get_route_summary_between_buildings(1, 2)
	again["shared_component_ids"].clear()
	assert_eq(_network.get_route_summary_between_buildings(1, 2)["shared_component_ids"], ["0,0"])
	assert_eq(_network.get_route_cache_stats()["entries"], 1)
