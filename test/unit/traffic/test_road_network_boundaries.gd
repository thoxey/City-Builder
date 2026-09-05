extends GutTest

const RoadNetworkPlugin := preload("res://plugins/traffic/road_network_plugin.gd")

var _saved_structures: Array[Structure]
var _saved_registry: Dictionary
var _network: Node

func before_each() -> void:
	_saved_structures = GameState.structures
	_saved_registry = GameState.building_registry
	GameState.structures = [Structure.new()]
	GameState.building_registry = {}
	_network = RoadNetworkPlugin.new()

func after_each() -> void:
	_network.free()
	GameState.structures = _saved_structures
	GameState.building_registry = _saved_registry

func test_access_projection_checks_every_footprint_edge() -> void:
	GameState.building_registry = {
		9: {
			"anchor": Vector2i(0, 0),
			"structure": 0,
			"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		},
	}
	_network._graph = {Vector3i(3, 0, 0): []}
	_network._build_components()
	_network._build_access_projection()
	var access: Dictionary = _network.get_access_for_building(9)
	assert_true(access["road_accessible"])
	assert_eq(access["stops"], [{"x": 3, "z": 0}])
	assert_eq(access["component_ids"], ["3,0"])
	assert_eq(access["footprint_cells"].size(), 3)

func test_shortest_path_uses_stable_cell_order_when_routes_tie() -> void:
	_network._graph = {
		Vector3i(0, 0, 0): [Vector3i(0, 0, 1), Vector3i(1, 0, 0)],
		Vector3i(0, 0, 1): [Vector3i(0, 0, 0), Vector3i(1, 0, 1)],
		Vector3i(1, 0, 0): [Vector3i(0, 0, 0), Vector3i(1, 0, 1)],
		Vector3i(1, 0, 1): [Vector3i(0, 0, 1), Vector3i(1, 0, 0)],
	}
	var starts: Array[Vector3i] = [Vector3i.ZERO]
	var path: Array[Vector3i] = _network._shortest_path(starts, {Vector3i(1, 0, 1): true})
	assert_eq(path, [Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)])
