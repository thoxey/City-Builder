extends GutTest

const BuilderCls := preload("res://scripts/builder.gd")
const BuildingCatalogPlugin := preload("res://plugins/building_catalog/building_catalog_plugin.gd")
const SAVE_PATH := "user://tests/town_hall_ground_lifecycle.res"
const NORMAL_GRASS_ITEM_ID := 0

var _builder: Node
var _catalog: BuildingCatalogPlugin
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

	_catalog = BuildingCatalogPlugin.new()
	_catalog.ensure_loaded()
	_builder = BuilderCls.new()
	_builder.map = GameState.map
	_builder.structures = _catalog.get_all()
	_builder._catalog = _catalog
	_builder.gridmap = GridMap.new()
	_builder.ground_gridmap = GridMap.new()
	_builder.add_child(_builder.gridmap)
	_builder.add_child(_builder.ground_gridmap)
	GameState.gridmap = _builder.gridmap
	GameState.structures = _builder.structures


func after_each() -> void:
	_builder.free()
	_catalog.free()
	GameState.map = _saved_map
	GameState.structures = _saved_structures
	GameState.gridmap = _saved_gridmap
	GameState.cell_to_building = _saved_cells
	GameState.building_registry = _saved_registry
	GameState._next_building_id = _saved_next_id
	GameState._state_version = _saved_state_version
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_real_town_hall_ground_survives_its_full_builder_lifecycle() -> void:
	var summary: Dictionary = _catalog.get_summary_by_id("building_town_hall")
	assert_eq(summary.get("ground_treatment"), "grass_underlay")
	var anchor := Vector2i(20, 20)
	var rotated_cells: Array[Vector2i] = [
		Vector2i(20, 20), Vector2i(20, 19), Vector2i(21, 20), Vector2i(21, 19),
	]
	_seed_normal_grass(rotated_cells)

	var committed: Dictionary = _builder.try_place_building("building_town_hall", anchor, 1)
	assert_eq(committed.status, PlaytestActionResult.STATUS_APPLIED)
	assert_eq(committed.details.footprint, rotated_cells,
		"real 2x2 Town Hall footprint rotates around its canonical anchor")
	_assert_underlay(rotated_cells, "commit")
	var saved_map: DataMap = _builder.serialize_map_state()
	assert_eq(saved_map.structures.size(), 1)
	assert_eq(saved_map.structures[0].building_id, "building_town_hall")
	assert_eq(saved_map.structures[0].orientation, 16)
	var save_directory := ProjectSettings.globalize_path(SAVE_PATH.get_base_dir())
	assert_eq(DirAccess.make_dir_recursive_absolute(save_directory), OK)
	assert_eq(ResourceSaver.save(saved_map, SAVE_PATH), OK)

	# Removing an ordinary replace-mode neighbour must reconcile only that
	# neighbour's cell; the protected Town Hall underlay remains untouched.
	var neighbour_cell := Vector2i(22, 20)
	var neighbour_summary: Dictionary = _catalog.get_summary_by_id("building_nature_patch")
	assert_eq(neighbour_summary.get("ground_treatment"), "replace")
	_seed_normal_grass([neighbour_cell])
	var neighbour_placement: Dictionary = _builder.try_place_building(
		"building_nature_patch", neighbour_cell)
	assert_eq(neighbour_placement.status, PlaytestActionResult.STATUS_APPLIED)
	assert_eq(_builder.ground_gridmap.get_cell_item(
		Vector3i(neighbour_cell.x, 0, neighbour_cell.y)), GridMap.INVALID_CELL_ITEM,
		"replace-mode neighbour clears its own ground cell")
	_assert_underlay(rotated_cells, "neighbour placement")

	var neighbour_demolition: Dictionary = _builder.try_demolish_cell(neighbour_cell)
	assert_eq(neighbour_demolition.status, PlaytestActionResult.STATUS_APPLIED)
	_assert_normal_grass([neighbour_cell], "neighbour demolition")
	_assert_underlay(rotated_cells, "neighbour demolition")
	assert_eq(GameState.building_registry.size(), 1,
		"demolishing the neighbour leaves only the Town Hall")

	var replacement: Dictionary = _builder.try_place_building(
		"building_postwar_terrace", rotated_cells[3], 0, true)
	assert_eq(replacement.status, PlaytestActionResult.STATUS_REJECTED)
	assert_eq(replacement.reason, PlaytestActionResult.DEMOLITION_NOT_ALLOWED,
		"replacement cannot bypass Town Hall protection")
	_assert_underlay(rotated_cells, "rejected replacement")

	var demolition: Dictionary = _builder.try_demolish_cell(rotated_cells[2])
	assert_eq(demolition.status, PlaytestActionResult.STATUS_REJECTED)
	assert_eq(demolition.reason, PlaytestActionResult.DEMOLITION_NOT_ALLOWED,
		"satellite-cell demolition preserves the Town Hall")
	_assert_underlay(rotated_cells, "rejected demolition")

	assert_eq(_builder.reset_to_fresh_map().status, PlaytestActionResult.STATUS_APPLIED)
	_assert_normal_grass(rotated_cells, "clear")
	assert_true(GameState.cell_to_building.is_empty())

	var loaded: Dictionary = _builder.load_map_from_path(SAVE_PATH)
	assert_eq(loaded.status, PlaytestActionResult.STATUS_APPLIED)
	_assert_underlay(rotated_cells, "cold load")
	assert_eq(GameState.building_registry.size(), 1)
	assert_eq(GameState.building_registry[0].orientation, 16)

	assert_eq(_builder.reset_to_fresh_map().status, PlaytestActionResult.STATUS_APPLIED)
	_assert_normal_grass(rotated_cells, "post-load clear")


func _seed_normal_grass(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_builder.ground_gridmap.set_cell_item(
			Vector3i(cell.x, 0, cell.y), NORMAL_GRASS_ITEM_ID, 0)


func _assert_underlay(cells: Array[Vector2i], lifecycle_stage: String) -> void:
	var item_id := -999
	for cell in cells:
		var current: int = _builder.ground_gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y))
		assert_ne(current, GridMap.INVALID_CELL_ITEM,
			"Town Hall %s is non-empty at %s" % [lifecycle_stage, cell])
		assert_ne(current, NORMAL_GRASS_ITEM_ID,
			"Town Hall %s uses the depth-biased underlay at %s" % [lifecycle_stage, cell])
		if item_id == -999:
			item_id = current
		else:
			assert_eq(current, item_id,
				"Town Hall %s uses one underlay item across all four cells" % lifecycle_stage)


func _assert_normal_grass(cells: Array[Vector2i], lifecycle_stage: String) -> void:
	for cell in cells:
		assert_eq(_builder.ground_gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y)),
			NORMAL_GRASS_ITEM_ID,
			"Town Hall %s restores normal grass at %s" % [lifecycle_stage, cell])
