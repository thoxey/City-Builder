extends GutTest

const BuilderCls := preload("res://scripts/builder.gd")
const SAVE_PATH := "user://tests/ground_treatment_legacy.res"
const NORMAL_GRASS_ITEM_ID := 0

var builder: Node
var catalog: StubCatalog
var _saved_map: DataMap
var _saved_structures: Array[Structure]
var _saved_gridmap: GridMap
var _saved_cells: Dictionary
var _saved_registry: Dictionary
var _saved_next_id: int
var _saved_state_version: int


func before_each() -> void:
	_saved_map = GameState.map
	_saved_structures = GameState.structures
	_saved_gridmap = GameState.gridmap
	_saved_cells = GameState.cell_to_building.duplicate(true)
	_saved_registry = GameState.building_registry.duplicate(true)
	_saved_next_id = GameState._next_building_id
	_saved_state_version = GameState._state_version

	GameState.map = DataMap.new()
	GameState.cell_to_building = {}
	GameState.building_registry = {}
	GameState._next_building_id = 0
	GameState.reset_state_version()

	catalog = StubCatalog.new()
	catalog.add_structure("replace_default", _structure([Vector2i.ZERO]))
	catalog.add_structure("underlay_single", _structure([Vector2i.ZERO]), "grass_underlay")
	catalog.add_structure("underlay_multi", _structure([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
	]), "grass_underlay")
	for hard_surface_id in ["road", "pavement", "water_cutout", "hardstanding"]:
		catalog.add_structure(hard_surface_id, _structure([Vector2i.ZERO]), "replace")

	builder = BuilderCls.new()
	builder.map = GameState.map
	builder.structures = catalog.items
	builder._catalog = catalog
	builder.gridmap = GridMap.new()
	builder.ground_gridmap = GridMap.new()
	builder.add_child(builder.gridmap)
	builder.add_child(builder.ground_gridmap)
	GameState.gridmap = builder.gridmap
	GameState.structures = catalog.items


func after_each() -> void:
	builder.free()
	catalog.free()
	GameState.map = _saved_map
	GameState.structures = _saved_structures
	GameState.gridmap = _saved_gridmap
	GameState.cell_to_building = _saved_cells
	GameState.building_registry = _saved_registry
	GameState._next_building_id = _saved_next_id
	GameState._state_version = _saved_state_version
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_commit_resolves_replace_and_grass_underlay_from_catalogue() -> void:
	var replace_cell := Vector2i(0, 0)
	var underlay_cell := Vector2i(2, 0)
	_seed_normal_grass([replace_cell, underlay_cell])

	assert_eq(builder.try_place_building("replace_default", replace_cell).status,
		PlaytestActionResult.STATUS_APPLIED)
	assert_eq(builder.try_place_building("underlay_single", underlay_cell).status,
		PlaytestActionResult.STATUS_APPLIED)

	_assert_empty_ground([replace_cell], "default replace treatment clears normal grass")
	_assert_underlay_ground([underlay_cell], "authored underlay survives commit")
	assert_eq(GameState.building_registry.size(), 2,
		"ground presentation does not change logical placement")


func test_rotated_multicell_commit_applies_underlay_to_every_cell() -> void:
	var anchor := Vector2i(4, 4)
	var expected: Array[Vector2i] = [
		Vector2i(4, 4), Vector2i(4, 3), Vector2i(5, 4), Vector2i(5, 3),
	]
	_seed_normal_grass(expected)

	var outcome: Dictionary = builder.try_place_building("underlay_multi", anchor, 1)
	assert_eq(outcome.status, PlaytestActionResult.STATUS_APPLIED)
	assert_eq(outcome.details.footprint, expected,
		"rotation uses the canonical occupied footprint cells")
	_assert_underlay_ground(expected, "all rotated 2x2 cells receive one underlay item")
	for cell in expected:
		assert_true(GameState.cell_to_building.has(cell),
			"underlay does not alter rotated logical occupancy at %s" % cell)


func test_replacement_resolves_directly_from_the_final_occupant() -> void:
	var anchor := Vector2i(7, 5)
	var original_cells: Array[Vector2i] = [
		Vector2i(7, 5), Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 4),
	]
	var replacement_cell := Vector2i(8, 4)
	_seed_normal_grass(original_cells)
	assert_eq(builder.try_place_building("underlay_multi", anchor, 1).status,
		PlaytestActionResult.STATUS_APPLIED)
	_assert_underlay_ground(original_cells, "initial occupant uses underlay")

	assert_eq(builder.try_place_building("replace_default", replacement_cell, 0, true).status,
		PlaytestActionResult.STATUS_APPLIED)
	_assert_empty_ground([replacement_cell], "replace occupant clears its cell")
	_assert_normal_grass([
		Vector2i(7, 5), Vector2i(7, 4), Vector2i(8, 5),
	], "cells no longer occupied after replacement return to normal grass")

	assert_eq(builder.try_place_building("underlay_single", replacement_cell, 0, true).status,
		PlaytestActionResult.STATUS_APPLIED)
	_assert_underlay_ground([replacement_cell],
		"replacing a replace occupant with underlay does not retain stale empty ground")
	assert_eq(GameState.building_registry.size(), 1)


func test_demolition_from_rotated_satellite_restores_normal_grass() -> void:
	var anchor := Vector2i(3, 9)
	var expected: Array[Vector2i] = [
		Vector2i(3, 9), Vector2i(3, 10), Vector2i(2, 9), Vector2i(2, 10),
	]
	_seed_normal_grass(expected)
	assert_eq(builder.try_place_building("underlay_multi", anchor, 3).status,
		PlaytestActionResult.STATUS_APPLIED)
	_assert_underlay_ground(expected, "rotated footprint starts with underlay")

	assert_eq(builder.try_demolish_cell(Vector2i(2, 10)).status,
		PlaytestActionResult.STATUS_APPLIED)
	_assert_normal_grass(expected, "demolishing through a satellite restores the full footprint")
	assert_true(GameState.cell_to_building.is_empty())
	assert_true(GameState.building_registry.is_empty())


func test_demolition_of_replace_occupant_restores_normal_grass() -> void:
	var cell := Vector2i(12, 11)
	_seed_normal_grass([cell])
	assert_eq(builder.try_place_building("replace_default", cell).status,
		PlaytestActionResult.STATUS_APPLIED)
	_assert_empty_ground([cell], "replace occupant clears normal grass before demolition")

	assert_eq(builder.try_demolish_cell(cell).status,
		PlaytestActionResult.STATUS_APPLIED)
	_assert_normal_grass([cell], "demolishing a replace occupant restores normal grass")
	assert_true(GameState.cell_to_building.is_empty())
	assert_true(GameState.building_registry.is_empty())


func test_public_load_of_legacy_save_derives_treatment_from_current_catalogue() -> void:
	var legacy_map := DataMap.new()
	var underlay_record := DataStructure.new()
	underlay_record.building_id = "underlay_multi"
	underlay_record.position = Vector2i(10, 8)
	underlay_record.orientation = 16
	# Deliberately leave footprint_cells empty, matching an older save which only
	# carries stable identity, anchor, and orientation.
	legacy_map.structures.append(underlay_record)
	var replace_record := DataStructure.new()
	replace_record.building_id = "replace_default"
	replace_record.position = Vector2i(14, 8)
	legacy_map.structures.append(replace_record)

	var underlay_cells: Array[Vector2i] = [
		Vector2i(10, 8), Vector2i(10, 7), Vector2i(11, 8), Vector2i(11, 7),
	]
	var seeded_cells := underlay_cells.duplicate()
	seeded_cells.append(replace_record.position)
	_seed_normal_grass(seeded_cells)
	var directory := ProjectSettings.globalize_path(SAVE_PATH.get_base_dir())
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	assert_eq(ResourceSaver.save(legacy_map, SAVE_PATH), OK)

	var outcome: Dictionary = builder.load_map_from_path(SAVE_PATH)
	assert_eq(outcome.status, PlaytestActionResult.STATUS_APPLIED)
	_assert_underlay_ground(underlay_cells,
		"load derives underlay from the current catalogue, not save-only presentation state")
	_assert_empty_ground([replace_record.position], "legacy replace entry remains empty underneath")
	assert_eq(GameState.building_registry.size(), 2)
	assert_true(underlay_record.footprint_cells.is_empty(),
		"legacy save data is not migrated with derived footprint or treatment state")


func test_fresh_map_clear_restores_both_treatments_to_normal_grass() -> void:
	var replace_cell := Vector2i(-2, 1)
	var underlay_cell := Vector2i(-4, 1)
	_seed_normal_grass([replace_cell, underlay_cell])
	assert_eq(builder.try_place_building("replace_default", replace_cell).status,
		PlaytestActionResult.STATUS_APPLIED)
	assert_eq(builder.try_place_building("underlay_single", underlay_cell).status,
		PlaytestActionResult.STATUS_APPLIED)

	assert_eq(builder.reset_to_fresh_map().status, PlaytestActionResult.STATUS_APPLIED)
	_assert_normal_grass([replace_cell, underlay_cell],
		"clear restores normal grass independent of the old occupant treatment")
	assert_true(GameState.cell_to_building.is_empty())
	assert_true(GameState.building_registry.is_empty())


func test_map_reset_reconciliation_is_idempotent() -> void:
	var loaded := DataMap.new()
	var underlay_record := DataStructure.new()
	underlay_record.building_id = "underlay_single"
	underlay_record.position = Vector2i(-8, -3)
	loaded.structures.append(underlay_record)
	var replace_record := DataStructure.new()
	replace_record.building_id = "replace_default"
	replace_record.position = Vector2i(-6, -3)
	loaded.structures.append(replace_record)
	_seed_normal_grass([underlay_record.position, replace_record.position])

	builder._apply_map(loaded)
	var first_underlay_item := _ground_item(underlay_record.position)
	builder._apply_map(loaded)

	_assert_underlay_ground([underlay_record.position],
		"resetting the same map keeps the resolved underlay stable")
	assert_eq(_ground_item(underlay_record.position), first_underlay_item)
	_assert_empty_ground([replace_record.position],
		"resetting the same map keeps replace ground empty")
	assert_eq(GameState.building_registry.size(), 2,
		"idempotent presentation reconciliation does not duplicate logical buildings")


func test_roads_pavement_water_and_hardstanding_never_receive_underlay() -> void:
	var hard_surface_ids := ["road", "pavement", "water_cutout", "hardstanding"]
	for index in hard_surface_ids.size():
		var building_id: String = hard_surface_ids[index]
		var cell := Vector2i(index * 2, 14)
		_seed_normal_grass([cell])
		assert_eq(builder.try_place_building(building_id, cell).status,
			PlaytestActionResult.STATUS_APPLIED, building_id)
		_assert_empty_ground([cell], "%s must keep hard ground free of grass bleed" % building_id)


func test_startup_background_fill_preserves_early_rotated_multicell_commit() -> void:
	# The small extent retains the production coroutine boundary at x=0. Place
	# while it is suspended, before it reaches either occupied x column.
	builder._fill_grass_background(3)
	var anchor := Vector2i(1, 2)
	var expected: Array[Vector2i] = [
		Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 2), Vector2i(2, 1),
	]
	assert_eq(builder.try_place_building("underlay_multi", anchor, 1).status,
		PlaytestActionResult.STATUS_APPLIED)
	await get_tree().process_frame
	_assert_underlay_ground(expected,
		"startup fill must not overwrite an early rotated commit or its satellite cells")


func test_startup_background_fill_preserves_early_rotated_multicell_load() -> void:
	builder._fill_grass_background(3)
	var loaded := DataMap.new()
	var record := DataStructure.new()
	record.building_id = "underlay_multi"
	record.position = Vector2i(1, 2)
	record.orientation = 16
	loaded.structures.append(record)
	var expected: Array[Vector2i] = [
		Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 2), Vector2i(2, 1),
	]
	builder._apply_map(loaded)
	await get_tree().process_frame
	_assert_underlay_ground(expected,
		"startup fill must not overwrite an early cold load or its satellite cells")


func _structure(footprint: Array[Vector2i]) -> Structure:
	var structure := Structure.new()
	structure.footprint = footprint
	return structure


func _seed_normal_grass(cells: Array[Vector2i]) -> void:
	for cell in cells:
		builder.ground_gridmap.set_cell_item(Vector3i(cell.x, 0, cell.y), NORMAL_GRASS_ITEM_ID, 0)


func _ground_item(cell: Vector2i) -> int:
	return builder.ground_gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y))


func _assert_empty_ground(cells: Array[Vector2i], context: String) -> void:
	for cell in cells:
		assert_eq(_ground_item(cell), GridMap.INVALID_CELL_ITEM, "%s at %s" % [context, cell])


func _assert_normal_grass(cells: Array[Vector2i], context: String) -> void:
	for cell in cells:
		assert_eq(_ground_item(cell), NORMAL_GRASS_ITEM_ID, "%s at %s" % [context, cell])


func _assert_underlay_ground(cells: Array[Vector2i], context: String) -> void:
	var shared_item := -999
	for cell in cells:
		var item := _ground_item(cell)
		assert_ne(item, GridMap.INVALID_CELL_ITEM, "%s is non-empty at %s" % [context, cell])
		assert_ne(item, NORMAL_GRASS_ITEM_ID,
			"%s uses the distinct depth-biased item at %s" % [context, cell])
		if shared_item == -999:
			shared_item = item
		else:
			assert_eq(item, shared_item, "%s uses one deterministic item ID" % context)
		assert_eq(builder.ground_gridmap.get_cell_item_orientation(Vector3i(cell.x, 0, cell.y)), 0,
			"%s uses stable orientation at %s" % [context, cell])


class StubCatalog extends PluginBase:
	var items: Array[Structure] = []
	var ids: Array[String] = []
	var summaries: Array[Dictionary] = []

	func get_plugin_name() -> String:
		return "GroundTreatmentStubCatalog"

	func add_structure(id: String, structure: Structure, ground_treatment: String = "") -> void:
		ids.append(id)
		items.append(structure)
		var summary := {"building_id": id, "pool_id": "", "palette_excluded": false}
		if not ground_treatment.is_empty():
			summary["ground_treatment"] = ground_treatment
		summaries.append(summary)

	func get_item_index(id: String) -> int:
		return ids.find(id)

	func get_id_by_index(index: int) -> String:
		return ids[index] if index >= 0 and index < ids.size() else ""

	func get_summary_by_index(index: int) -> Dictionary:
		return summaries[index].duplicate(true) if index >= 0 and index < summaries.size() else {}

	func get_summary_by_id(id: String) -> Dictionary:
		return get_summary_by_index(get_item_index(id))
