extends GutTest

const BuilderCls := preload("res://scripts/builder.gd")
const SAVE_PATH := "user://tests/progression_boundary.res"

var _saved_map: DataMap
var _saved_structures: Array[Structure]
var _saved_registry: Dictionary
var _saved_cells: Dictionary
var _saved_next_id: int

func before_each() -> void:
	_saved_map = GameState.map
	_saved_structures = GameState.structures
	_saved_registry = GameState.building_registry.duplicate(true)
	_saved_cells = GameState.cell_to_building.duplicate(true)
	_saved_next_id = GameState._next_building_id
	GameState.building_registry = {}
	GameState.cell_to_building = {}

func after_each() -> void:
	GameState.map = _saved_map
	GameState.structures = _saved_structures
	GameState.building_registry = _saved_registry
	GameState.cell_to_building = _saved_cells
	GameState._next_building_id = _saved_next_id
	var absolute := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(absolute)

func test_builder_cold_round_trip_preserves_every_progression_boundary_field() -> void:
	var map := DataMap.new()
	map.rooted_town_rules = false
	map.character_states = {"aristocrat_residential":2, "aristocrat_commercial":1}
	map.patron_states = {"aristocrat":1}
	map.demand_totals = {"residential":390.0, "industrial":164.5, "commercial":198.0}
	map.pending_dialogue_event_ids = ["aristocrat_commercial_arrival"]
	map.event_counts = {"aristocrat_commercial_arrival":1}
	map.flags = {"met_aristocrat_residential":true}
	map.patron_donations_applied = {"aristocrat":true}
	map.allowed_cells = [Vector2i(-4, -4), Vector2i(8, -8)]
	GameState.map = map
	var builder := BuilderCls.new()
	builder.map = map
	builder.gridmap = GridMap.new()
	builder.ground_gridmap = GridMap.new()
	builder.add_child(builder.gridmap)
	builder.add_child(builder.ground_gridmap)
	var saved: Dictionary = builder.save_map_to_path(SAVE_PATH)
	assert_eq(saved.get("status"), PlaytestActionResult.STATUS_APPLIED)
	map.demand_totals.clear()
	map.pending_dialogue_event_ids.clear()
	map.patron_donations_applied.clear()
	var loaded: Dictionary = builder.load_map_from_path(SAVE_PATH)
	assert_eq(loaded.get("status"), PlaytestActionResult.STATUS_APPLIED)
	assert_eq(GameState.map.demand_totals, {"residential":390.0, "industrial":164.5, "commercial":198.0})
	assert_false(GameState.map.rooted_town_rules)
	assert_eq(GameState.map.pending_dialogue_event_ids, ["aristocrat_commercial_arrival"])
	assert_eq(GameState.map.event_counts.get("aristocrat_commercial_arrival"), 1)
	assert_true(GameState.map.patron_donations_applied.get("aristocrat", false))
	assert_true(Vector2i(8, -8) in GameState.map.allowed_cells)
	builder.free()

func test_cold_round_trip_matrix_preserves_each_progression_boundary() -> void:
	var boundaries := [
		{"name":"before_arrival", "characters":{}, "patron":{}, "pending":[], "counts":{}, "placed":[], "receipt":{}, "land":[Vector2i(-4, -4)]},
		{"name":"after_arrival", "characters":{"aristocrat_residential":1}, "patron":{}, "pending":["aristocrat_residential_arrival"], "counts":{"aristocrat_residential_arrival":1}, "placed":["building_postwar_terrace"], "receipt":{}, "land":[Vector2i(-4, -4)]},
		{"name":"after_reveal", "characters":{"aristocrat_residential":2}, "patron":{}, "pending":[], "counts":{"aristocrat_residential_arrival":1}, "placed":["building_postwar_terrace"], "receipt":{}, "land":[Vector2i(-4, -4)]},
		{"name":"after_satisfaction", "characters":{"aristocrat_residential":3}, "patron":{}, "pending":[], "counts":{"aristocrat_residential_arrival":1}, "placed":["building_postwar_terrace", "building_pirate_radio"], "receipt":{}, "land":[Vector2i(-4, -4)]},
		{"name":"patron_available", "characters":{"aristocrat_residential":3, "aristocrat_industrial":3, "aristocrat_commercial":3}, "patron":{"aristocrat":1}, "pending":[], "counts":{"aristocrat_landmark_ready":1}, "placed":["building_pirate_radio", "building_crazy_golf", "building_members_club"], "receipt":{}, "land":[Vector2i(-4, -4)]},
		{"name":"completed_and_donated", "characters":{"aristocrat_residential":4, "aristocrat_industrial":4, "aristocrat_commercial":4}, "patron":{"aristocrat":2}, "pending":["aristocrat_landmark_completed"], "counts":{"aristocrat_landmark_completed":1}, "placed":["building_pirate_radio", "building_crazy_golf", "building_members_club", "building_theatre"], "receipt":{"aristocrat":true}, "land":[Vector2i(-4, -4), Vector2i(8, -8)]},
	]
	for boundary in boundaries:
		_round_trip_boundary(boundary)

func _round_trip_boundary(boundary: Dictionary) -> void:
	var ids: Array[String] = [
		"building_postwar_terrace", "building_pirate_radio", "building_crazy_golf",
		"building_members_club", "building_theatre",
	]
	var catalog := _StubCatalog.new(ids)
	GameState.structures = []
	for _id in ids:
		GameState.structures.append(Structure.new())
	var map := DataMap.new()
	map.character_states = boundary.characters.duplicate(true)
	map.patron_states = boundary.patron.duplicate(true)
	map.pending_dialogue_event_ids.assign(boundary.pending)
	map.event_counts = boundary.counts.duplicate(true)
	map.patron_donations_applied = boundary.receipt.duplicate(true)
	map.allowed_cells.assign(boundary.land)
	map.demand_totals = {"residential":390.0, "industrial":164.5, "commercial":198.0}
	GameState.map = map
	GameState.building_registry = {}
	GameState.cell_to_building = {}
	var placed: Array = boundary.placed
	for index in placed.size():
		var anchor := Vector2i(index, 0)
		var structure_index := ids.find(String(placed[index]))
		GameState.building_registry[index] = {"anchor":anchor, "structure":structure_index, "orientation":0, "cells":[anchor]}
		GameState.cell_to_building[anchor] = index
	var builder := BuilderCls.new()
	builder.map = map
	builder._catalog = catalog
	builder.gridmap = GridMap.new()
	builder.ground_gridmap = GridMap.new()
	builder.add_child(builder.gridmap)
	builder.add_child(builder.ground_gridmap)
	var path := "user://tests/progression_%s.res" % boundary.name
	assert_eq(builder.save_map_to_path(path).get("status"), PlaytestActionResult.STATUS_APPLIED, boundary.name)
	GameState.map = DataMap.new()
	GameState.building_registry = {}
	GameState.cell_to_building = {}
	assert_eq(builder.load_map_from_path(path).get("status"), PlaytestActionResult.STATUS_APPLIED, boundary.name)
	assert_eq(GameState.map.character_states, boundary.characters, boundary.name)
	assert_eq(GameState.map.patron_states, boundary.patron, boundary.name)
	assert_eq(GameState.map.pending_dialogue_event_ids, boundary.pending, boundary.name)
	assert_eq(GameState.map.event_counts, boundary.counts, boundary.name)
	assert_eq(GameState.map.patron_donations_applied, boundary.receipt, boundary.name)
	assert_eq(GameState.map.allowed_cells, boundary.land, boundary.name)
	var loaded_ids: Array[String] = []
	for structure in GameState.map.structures:
		loaded_ids.append(structure.building_id)
	assert_eq(loaded_ids, boundary.placed, boundary.name)
	builder.free()
	catalog.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

class _StubCatalog extends PluginBase:
	var ids: Array[String]
	func _init(values: Array[String]) -> void: ids = values
	func get_plugin_name() -> String: return "_StubCatalog"
	func get_item_index(id: String) -> int: return ids.find(id)
	func get_id_by_index(index: int) -> String: return ids[index] if index >= 0 and index < ids.size() else ""
