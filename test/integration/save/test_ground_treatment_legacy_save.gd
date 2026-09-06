extends GutTest

const BuilderCls := preload("res://scripts/builder.gd")
const BuildingCatalogPlugin := preload("res://plugins/building_catalog/building_catalog_plugin.gd")
const SAVE_PATH := "user://tests/ground_treatment_legacy_catalogue.tres"
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


func test_legacy_save_persists_stable_id_but_derives_town_hall_underlay_on_load() -> void:
	var legacy_map := DataMap.new()
	var legacy_record := DataStructure.new()
	legacy_record.building_id = "building_town_hall"
	legacy_record.position = Vector2i(-12, 6)
	legacy_record.orientation = 16
	legacy_map.structures.append(legacy_record)
	var rotated_cells: Array[Vector2i] = [
		Vector2i(-12, 6), Vector2i(-12, 5), Vector2i(-11, 6), Vector2i(-11, 5),
	]
	for cell in rotated_cells:
		_builder.ground_gridmap.set_cell_item(
			Vector3i(cell.x, 0, cell.y), NORMAL_GRASS_ITEM_ID, 0)

	var save_directory := ProjectSettings.globalize_path(SAVE_PATH.get_base_dir())
	assert_eq(DirAccess.make_dir_recursive_absolute(save_directory), OK)
	assert_eq(ResourceSaver.save(legacy_map, SAVE_PATH), OK)
	var persisted_text := FileAccess.get_file_as_string(SAVE_PATH)
	assert_true(persisted_text.contains("building_town_hall"),
		"legacy save keeps the stable catalogue identity")
	assert_false(persisted_text.contains("ground_treatment"),
		"derived visual treatment never enters save data")
	assert_false(_property_names(legacy_record).has("ground_treatment"),
		"DataStructure schema remains treatment-free")

	var loaded: Dictionary = _builder.load_map_from_path(SAVE_PATH)
	assert_eq(loaded.status, PlaytestActionResult.STATUS_APPLIED)
	assert_eq(GameState.map.structures[0].building_id, "building_town_hall")
	assert_true(GameState.map.structures[0].footprint_cells.is_empty(),
		"legacy record remains valid without a footprint or treatment migration")
	for cell in rotated_cells:
		var ground_item: int = _builder.ground_gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y))
		assert_ne(ground_item, GridMap.INVALID_CELL_ITEM,
			"loaded Town Hall footprint is intentionally covered at %s" % cell)
		assert_ne(ground_item, NORMAL_GRASS_ITEM_ID,
			"loaded treatment is re-derived as the depth-biased underlay at %s" % cell)


func _property_names(resource: Resource) -> Array[String]:
	var names: Array[String] = []
	for property in resource.get_property_list():
		names.append(String(property.get("name", "")))
	return names
