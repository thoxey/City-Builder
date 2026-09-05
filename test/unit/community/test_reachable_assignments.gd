extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")
const CatalogPlugin := preload("res://plugins/building_catalog/building_catalog_plugin.gd")

class FakeResidential extends PluginBase:
	var slots: Array = []
	func get_housing_slots() -> Array: return slots.duplicate(true)

class FakeClock extends PluginBase:
	var hour := 10
	func current_hour() -> int: return hour
	func get_absolute_hour() -> int: return hour

class FakeRoadNetwork extends PluginBase:
	var revision := 1
	var reachable_pairs := {}
	func get_revision() -> int: return revision
	func get_route_between_buildings(origin_id: int, destination_id: int) -> Dictionary:
		var key := "%d>%d" % [origin_id, destination_id]
		if not reachable_pairs.has(key):
			return {"reachable": false, "distance": -1, "reason": "isolated_road_component"}
		return {"reachable": true, "distance": int(reachable_pairs[key]), "reason": ""}

var _saved_map: DataMap
var _saved_structures: Array[Structure]
var _saved_registry: Dictionary
var _catalog: PluginBase
var _residential: FakeResidential
var _clock: FakeClock
var _roads: FakeRoadNetwork
var _plugin: Node

func before_each() -> void:
	_saved_map = GameState.map
	_saved_structures = GameState.structures
	_saved_registry = GameState.building_registry
	GameState.map = DataMap.new()
	GameState.map.community_schema_version = 1
	_catalog = CatalogPlugin.new()
	_catalog.ensure_loaded()
	GameState.structures = _catalog.get_all()
	GameState.building_registry = {}
	_residential = FakeResidential.new()
	_clock = FakeClock.new()
	_roads = FakeRoadNetwork.new()
	_plugin = CommunityPlugin.new()
	_plugin._catalog = _catalog
	_plugin._residential = _residential
	_plugin._clock = _clock
	_plugin._road_network = _roads
	_plugin._load_authored_data()

func after_each() -> void:
	_plugin.free()
	_clock.free()
	_residential.free()
	_roads.free()
	_catalog.free()
	GameState.map = _saved_map
	GameState.structures = _saved_structures
	GameState.building_registry = _saved_registry

func _place(internal_id: int, building_id: String, anchor: Vector2i) -> void:
	GameState.building_registry[internal_id] = {
		"anchor": anchor,
		"structure": _catalog.get_item_index(building_id),
		"orientation": 0,
		"cells": [anchor],
	}

func _resident(id: int, home: Vector2i) -> CommunityResident:
	var resident := CommunityResident.new()
	resident.resident_id = id
	resident.home_anchor = home
	return resident

func test_disconnected_residents_do_not_fill_workplace() -> void:
	_place(1, "building_small_a", Vector2i.ZERO)
	_place(2, "building_garage", Vector2i(3, 0))
	_plugin._residents = {1: _resident(1, Vector2i.ZERO)}
	_plugin._assign_residents(_plugin._source_records(10), 10, true)
	assert_eq(_plugin.get_fulfilled_workplace(Vector2i(3, 0), 10), 0)
	assert_null(_plugin._residents[1].work_assignment)

func test_reachable_residents_fill_work_before_activity() -> void:
	_place(1, "building_small_a", Vector2i.ZERO)
	_place(2, "building_garage", Vector2i(3, 0))
	_place(3, "building_duck_pond", Vector2i(1, 0))
	_plugin._residents = {1: _resident(1, Vector2i.ZERO), 2: _resident(2, Vector2i.ZERO)}
	_roads.reachable_pairs = {"1>2": 4, "1>3": 2}
	var sources: Array = _plugin._source_records(10)
	_plugin._assign_residents(sources, 10, true)
	assert_eq(_plugin.get_fulfilled_workplace(Vector2i(3, 0), 10), 2)
	assert_eq(_plugin.get_fulfilled_activity(Vector2i(1, 0), 10), 0)
	assert_eq(_plugin.get_assignment_records().map(func(row): return row["purpose"]), ["work", "work"])

func test_connectivity_revision_recomputes_and_clears_stale_assignment() -> void:
	_place(1, "building_small_a", Vector2i.ZERO)
	_place(2, "building_garage", Vector2i(3, 0))
	_plugin._residents = {1: _resident(1, Vector2i.ZERO)}
	_roads.reachable_pairs = {"1>2": 3}
	assert_eq(_plugin.get_fulfilled_workplace(Vector2i(3, 0), 10), 1)
	_roads.reachable_pairs.clear()
	_roads.revision += 1
	assert_eq(_plugin.get_fulfilled_workplace(Vector2i(3, 0), 10), 0)
	assert_null(_plugin._residents[1].work_assignment)

func test_nature_projection_distinguishes_occupied_and_candidate_home_service() -> void:
	_place(1, "building_small_a", Vector2i.ZERO)
	_place(2, "building_nature_patch", Vector2i(1, 0))
	_residential.slots = [{"anchor": Vector2i.ZERO, "slot": 0}, {"anchor": Vector2i.ZERO, "slot": 1}]
	_plugin._residents = {1: _resident(1, Vector2i.ZERO)}
	_plugin._on_hour(10)
	var rows: Array = _plugin.get_spatial_snapshot()["resident_serving_nature"]
	assert_eq(rows.size(), 1)
	assert_true(rows[0]["resident_serving"])
	assert_eq(rows[0]["occupied_resident_ids"], [1])
	assert_eq(rows[0]["candidate_home_anchors"], [{"x": 0, "z": 0}])
