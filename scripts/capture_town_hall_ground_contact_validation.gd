extends SceneTree

## Runtime Town Hall checkpoint for feature 020. Unlike the isolated catalogue
## sheets, this loads the real Main scene and Builder MeshLibraries, then records
## preview/commit/save-load evidence beside replace-ground neighbours.

const OUTPUT_ROOT := "res://specs/020-building-ground-contact/validation/town-hall-context"
const REPORT_PATH := "res://specs/020-building-ground-contact/validation/town-hall-checkpoint.json"
const SAVE_PATH := "user://feature020-town-hall-checkpoint.tres"
const TOWN_HALL_ID := "building_town_hall"
const NORMAL_GRASS_ITEM := 0
const UNDERLAY_ITEM := 1
const ORIENTATIONS := [0, 16]
const ROTATION_STEPS := [0, 1]
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const ZOOMS := {"close": 15.0, "town-context": 80.0}

var _builder: Node
var _catalogue
var _view: Node3D
var _camera: Camera3D
var _failures: Array[String] = []
var _captures: Array = []
var _ground_snapshots: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("normal_renderer_required")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	root.size = VIEWPORTS[0]
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(48)
	_builder = current_scene.get_node_or_null("Builder")
	_view = current_scene.get_node_or_null("View")
	_camera = current_scene.get_node_or_null("View/Camera")
	var manager := root.get_node_or_null("PluginManager")
	_catalogue = manager.get_plugin("BuildingCatalog") if manager else null
	if _builder == null or _view == null or _camera == null or _catalogue == null:
		_failures.append("runtime_scene_setup_failed")
		_finish()
		return
	_hide_canvas_layers(root)
	_view.process_mode = Node.PROCESS_MODE_DISABLED
	_builder.process_mode = Node.PROCESS_MODE_DISABLED
	_validate_mesh_library()

	for rotation_index in ROTATION_STEPS.size():
		var steps: int = ROTATION_STEPS[rotation_index]
		var orientation: int = ORIENTATIONS[rotation_index]
		var scenario := _build_town_context(steps, orientation)
		var map: DataMap = scenario["map"]
		var town_cells: Array[Vector2i] = scenario["town_cells"]
		var replace_cells: Array[Vector2i] = scenario["replace_cells"]
		var centre: Vector3 = scenario["centre"]

		# A placement preview sits above ordinary grass. Its exposed footprint is
		# therefore visually equivalent to the eventual grass underlay.
		_builder.reset_to_fresh_map()
		_builder._preview_idx = _catalogue.get_item_index(TOWN_HALL_ID)
		_builder._rotation_steps = steps
		_builder._placement_active = true
		_builder._input_mode = "placement"
		_builder.selector.rotation_degrees.y = steps * 90.0
		_builder.selector.position = Vector3(0.0, 0.0, 0.0)
		_builder.selector.visible = true
		_builder.update_structure()
		await _frames(4)
		await _capture_views("preview", steps * 90, centre)
		_builder.cancel_placement()

		# Commit/rebuild the authored town, save it through the public schema, clear,
		# and cold-load it through Builder's public lifecycle.
		_builder._apply_map(map)
		await _frames(4)
		_validate_ground("commit", steps * 90, town_cells, replace_cells)
		var save_result: Dictionary = _builder.save_map_to_path(SAVE_PATH)
		if String(save_result.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_failures.append("save_failed:%s:%s" % [steps * 90, save_result])
		_builder.reset_to_fresh_map()
		var load_result: Dictionary = _builder.load_map_from_path(SAVE_PATH)
		if String(load_result.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_failures.append("load_failed:%s:%s" % [steps * 90, load_result])
		await _frames(8)
		_validate_ground("load", steps * 90, town_cells, replace_cells)
		await _capture_views("loaded", steps * 90, centre)

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_finish()


func _build_town_context(steps: int, orientation: int) -> Dictionary:
	var map := DataMap.new()
	var town_index: int = _catalogue.get_item_index(TOWN_HALL_ID)
	var town_cells: Array[Vector2i] = _builder._get_footprint_cells(Vector2i.ZERO, town_index, steps)
	_add_record(map, TOWN_HALL_ID, Vector2i.ZERO, orientation)
	var min_x: int = int(town_cells.map(func(cell: Vector2i): return cell.x).min())
	var max_x: int = int(town_cells.map(func(cell: Vector2i): return cell.x).max())
	var min_z: int = int(town_cells.map(func(cell: Vector2i): return cell.y).min())
	var max_z: int = int(town_cells.map(func(cell: Vector2i): return cell.y).max())
	var replace_cells: Array[Vector2i] = []
	for x in range(min_x - 1, max_x + 2):
		for z in [min_z - 1, max_z + 1]:
			var cell := Vector2i(x, z)
			_add_record(map, "road_straight", cell, 0)
			replace_cells.append(cell)
	for z in range(min_z, max_z + 1):
		for x in [min_x - 1, max_x + 1]:
			var cell := Vector2i(x, z)
			_add_record(map, "pavement", cell, 0)
			replace_cells.append(cell)
	_add_record(map, "building_members_club", Vector2i(min_x - 2, min_z), 0)
	replace_cells.append(Vector2i(min_x - 2, min_z))
	_add_record(map, "building_duck_pond", Vector2i(max_x + 2, max_z), 0)
	replace_cells.append(Vector2i(max_x + 2, max_z))
	var centre := Vector3.ZERO
	for cell in town_cells:
		centre += Vector3(cell.x, 0.0, cell.y)
	centre /= float(town_cells.size())
	return {"map": map, "town_cells": town_cells, "replace_cells": replace_cells,
		"centre": centre}


func _add_record(map: DataMap, building_id: String, position: Vector2i, orientation: int) -> void:
	var record := DataStructure.new()
	record.building_id = building_id
	record.position = position
	record.orientation = orientation
	map.structures.append(record)


func _capture_views(stage: String, degrees: int, centre: Vector3) -> void:
	_view.position = centre
	_view.camera_position = centre
	for viewport_size in VIEWPORTS:
		root.size = viewport_size
		for zoom_name in ZOOMS:
			var zoom: float = ZOOMS[zoom_name]
			_view.zoom = zoom
			_camera.position = Vector3(0.0, 0.0, zoom)
			await _frames(5)
			var directory := "%s/%dx%d" % [OUTPUT_ROOT, viewport_size.x, viewport_size.y]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
			var path := "%s/town-hall-%s-%03d-%s.png" % [directory, stage, degrees, zoom_name]
			var image := root.get_texture().get_image()
			var error := image.save_png(ProjectSettings.globalize_path(path))
			if error != OK:
				_failures.append("capture_failed:%s:%s" % [path, error])
			else:
				_captures.append({"stage": stage, "degrees": degrees, "zoom": zoom_name,
					"viewport": [viewport_size.x, viewport_size.y], "path": path})


func _validate_mesh_library() -> void:
	var library: MeshLibrary = _builder.ground_gridmap.mesh_library
	if library == null:
		_failures.append("ground_mesh_library_missing")
		return
	var item_ids := library.get_item_list()
	if NORMAL_GRASS_ITEM not in item_ids or UNDERLAY_ITEM not in item_ids:
		_failures.append("ground_mesh_library_items_missing")
		return
	var normal_mesh := library.get_item_mesh(NORMAL_GRASS_ITEM)
	var underlay_mesh := library.get_item_mesh(UNDERLAY_ITEM)
	if normal_mesh == null or underlay_mesh == null or normal_mesh != underlay_mesh:
		_failures.append("underlay_does_not_reuse_grass_mesh")
	var normal_y := library.get_item_mesh_transform(NORMAL_GRASS_ITEM).origin.y
	var underlay_y := library.get_item_mesh_transform(UNDERLAY_ITEM).origin.y
	if not is_equal_approx(underlay_y - normal_y, -0.003):
		_failures.append("underlay_bias_mismatch:%0.9f" % (underlay_y - normal_y))


func _validate_ground(stage: String, degrees: int, town_cells: Array[Vector2i],
		replace_cells: Array[Vector2i]) -> void:
	var snapshot := {"stage": stage, "degrees": degrees, "town_hall": [], "replace": []}
	for cell in town_cells:
		var item: int = _builder.ground_gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y))
		snapshot["town_hall"].append({"cell": [cell.x, cell.y], "item": item})
		if item != UNDERLAY_ITEM:
			_failures.append("town_hall_ground:%s:%s:%s" % [stage, degrees, cell])
	for cell in replace_cells:
		var item: int = _builder.ground_gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y))
		snapshot["replace"].append({"cell": [cell.x, cell.y], "item": item})
		if item != GridMap.INVALID_CELL_ITEM:
			_failures.append("replace_ground_bleed:%s:%s:%s" % [stage, degrees, cell])
	_ground_snapshots.append(snapshot)


func _hide_canvas_layers(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			child.visible = false
		_hide_canvas_layers(child)


func _finish() -> void:
	var library: MeshLibrary = _builder.ground_gridmap.mesh_library if _builder and _builder.ground_gridmap else null
	var report := {
		"schema_version": 1,
		"feature": "020-building-ground-contact",
		"success": _failures.is_empty(),
		"failures": _failures,
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(),
		"engine_version": Engine.get_version_info().get("string", ""),
		"ground_map_node_y": _builder.ground_gridmap.position.y if _builder and _builder.ground_gridmap else null,
		"normal_item_y": library.get_item_mesh_transform(NORMAL_GRASS_ITEM).origin.y if library and NORMAL_GRASS_ITEM in library.get_item_list() else null,
		"underlay_item_y": library.get_item_mesh_transform(UNDERLAY_ITEM).origin.y if library and UNDERLAY_ITEM in library.get_item_list() else null,
		"captures": _captures,
		"ground_snapshots": _ground_snapshots,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ", true) + "\n")
		file.close()
	else:
		push_error("town_hall_checkpoint_report_write_failed")
	print("TOWN_HALL_GROUND_CONTACT success=%s captures=%d snapshots=%d failures=%d" % [
		report["success"], _captures.size(), _ground_snapshots.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _frames(count: int) -> void:
	for _frame in count:
		await process_frame
