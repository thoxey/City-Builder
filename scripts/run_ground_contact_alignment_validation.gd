extends SceneTree

## Compares the actual first rendered preview mesh against the live StructureMap
## item before and after a real ResourceSaver -> clear -> cold Builder load for
## every repaired asset and all four rotations.

const OUTPUT := "res://specs/020-building-ground-contact/validation/alignment-after.json"
const DECISIONS := "res://specs/020-building-ground-contact/validation/audit-decisions.json"
const SAVE_PATH := "user://feature020/alignment-roundtrip.tres"
const ROTATIONS := [0, 1, 2, 3]
const TOLERANCE := 0.0001
const EXPECTED_UNDERLAY_ITEM := 1

var _failures: Array[String] = []
var _rows: Array = []
var _game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(48)
	var builder = current_scene.get_node_or_null("Builder")
	var manager := root.get_node_or_null("PluginManager")
	_game_state = root.get_node_or_null("GameState")
	var catalogue = manager.get_plugin("BuildingCatalog") if manager else null
	if builder == null or catalogue == null or _game_state == null or builder.gridmap.mesh_library == null:
		_failures.append("runtime_scene_setup_failed")
		_finish()
		return
	builder.process_mode = Node.PROCESS_MODE_DISABLED
	builder.selector.visible = true
	var decisions: Dictionary = _read_json(DECISIONS).get("rows", {})
	for building_id_any in decisions:
		var building_id := String(building_id_any)
		if String(decisions[building_id].get("status", "")) == "pass":
			continue
		var index: int = catalogue.get_item_index(building_id)
		if index < 0:
			_failures.append("catalogue_id_missing:%s" % building_id)
			continue
		var summary: Dictionary = catalogue.get_summary_by_id(building_id)
		if String(summary.get("ground_treatment", "replace")) != "grass_underlay":
			_failures.append("unexpected_treatment:%s" % building_id)
			continue
		for steps_any in ROTATIONS:
			var steps: int = int(steps_any)
			var degrees := steps * 90
			var orientation: int = builder._steps_to_orientation(steps)
			var anchor := Vector2i.ZERO
			var expected_cells: Array[Vector2i] = builder._get_footprint_cells(anchor, index, steps)

			builder._preview_idx = index
			builder._rotation_steps = steps
			builder.selector.position = Vector3.ZERO
			builder.selector.rotation = Vector3(0.0, deg_to_rad(degrees), 0.0)
			builder.update_structure()
			await process_frame
			var preview_mesh := _first_mesh_instance(builder.selector_container)
			if preview_mesh == null or preview_mesh.mesh == null:
				_failures.append("preview_mesh_missing:%s:%s" % [building_id, degrees])
				continue
			var preview_transform: Transform3D = \
				builder.global_transform.affine_inverse() * preview_mesh.global_transform
			var preview_bounds := _transformed_bounds(preview_mesh.mesh.get_aabb(), preview_transform)

			var staged_map := DataMap.new()
			var staged_structure := DataStructure.new()
			staged_structure.building_id = building_id
			staged_structure.position = anchor
			staged_structure.orientation = orientation
			# Leave footprint_cells empty so both apply and cold load derive the
			# canonical rotated footprint from the unchanged catalogue definition.
			staged_map.structures.append(staged_structure)
			var apply_result: Dictionary = builder.reset_to_fresh_map(staged_map)
			await process_frame
			var committed := _placed_mesh_state(builder, anchor)
			var commit_bounds: AABB = committed.get("bounds", AABB())
			var commit_cells_ok := _registry_matches(index, orientation, expected_cells)
			var commit_ground_ok := _ground_matches(builder, expected_cells, EXPECTED_UNDERLAY_ITEM)

			var save_result: Dictionary = builder.save_map_to_path(SAVE_PATH)
			var clear_result: Dictionary = builder.reset_to_fresh_map()
			await process_frame
			var clear_ok: bool = \
				builder.gridmap.get_cell_item(Vector3i(anchor.x, 0, anchor.y)) == GridMap.INVALID_CELL_ITEM \
				and _ground_matches(builder, expected_cells, 0)
			var load_result: Dictionary = builder.load_map_from_path(SAVE_PATH)
			await process_frame
			var loaded := _placed_mesh_state(builder, anchor)
			var post_load_bounds: AABB = loaded.get("bounds", AABB())
			var loaded_cells_ok := _registry_matches(index, orientation, expected_cells)
			var loaded_ground_ok := _ground_matches(builder, expected_cells, EXPECTED_UNDERLAY_ITEM)

			var preview_commit_min_delta: Vector3 = preview_bounds.position - commit_bounds.position
			var preview_commit_max_delta: Vector3 = preview_bounds.end - commit_bounds.end
			var commit_load_min_delta: Vector3 = commit_bounds.position - post_load_bounds.position
			var commit_load_max_delta: Vector3 = commit_bounds.end - post_load_bounds.end
			var transforms_aligned := _within(preview_commit_min_delta) \
				and _within(preview_commit_max_delta) \
				and _within(commit_load_min_delta) \
				and _within(commit_load_max_delta)
			var lifecycle_ok: bool = \
				apply_result.get("status") == PlaytestActionResult.STATUS_APPLIED \
				and committed.get("item", GridMap.INVALID_CELL_ITEM) == index \
				and committed.get("orientation", -1) == orientation \
				and commit_cells_ok and commit_ground_ok \
				and save_result.get("status") == PlaytestActionResult.STATUS_APPLIED \
				and clear_result.get("status") == PlaytestActionResult.STATUS_APPLIED \
				and clear_ok \
				and load_result.get("status") == PlaytestActionResult.STATUS_APPLIED \
				and loaded.get("item", GridMap.INVALID_CELL_ITEM) == index \
				and loaded.get("orientation", -1) == orientation \
				and loaded_cells_ok and loaded_ground_ok
			var aligned: bool = transforms_aligned and lifecycle_ok
			if not transforms_aligned:
				_failures.append("preview_commit_load_drift:%s:%s:preview_min=%s:preview_max=%s:load_min=%s:load_max=%s" % [
					building_id, degrees, preview_commit_min_delta, preview_commit_max_delta,
					commit_load_min_delta, commit_load_max_delta])
			if not lifecycle_ok:
				_failures.append("roundtrip_state_mismatch:%s:%s" % [building_id, degrees])
			_rows.append({
				"building_id": building_id,
				"degrees": degrees,
				"expected_orientation": orientation,
				"expected_cells": _cell_records(expected_cells),
				"preview_bounds": _aabb_record(preview_bounds),
				"commit_bounds": _aabb_record(commit_bounds),
				"post_load_bounds": _aabb_record(post_load_bounds),
				"preview_commit_min_delta": _vec3(preview_commit_min_delta),
				"preview_commit_max_delta": _vec3(preview_commit_max_delta),
				"commit_load_min_delta": _vec3(commit_load_min_delta),
				"commit_load_max_delta": _vec3(commit_load_max_delta),
				"commit_item": committed.get("item", GridMap.INVALID_CELL_ITEM),
				"commit_orientation": committed.get("orientation", -1),
				"post_load_item": loaded.get("item", GridMap.INVALID_CELL_ITEM),
				"post_load_orientation": loaded.get("orientation", -1),
				"commit_cells_ok": commit_cells_ok,
				"commit_ground_ok": commit_ground_ok,
				"clear_ok": clear_ok,
				"post_load_cells_ok": loaded_cells_ok,
				"post_load_ground_ok": loaded_ground_ok,
				"save_status": save_result.get("status", ""),
				"load_status": load_result.get("status", ""),
				"aligned": aligned,
			})
	_finish()


func _placed_mesh_state(builder: Node, anchor: Vector2i) -> Dictionary:
	var cell := Vector3i(anchor.x, 0, anchor.y)
	var item: int = builder.gridmap.get_cell_item(cell)
	var orientation: int = builder.gridmap.get_cell_item_orientation(cell)
	if item == GridMap.INVALID_CELL_ITEM or item < 0:
		return {"item": item, "orientation": orientation}
	var mesh: Mesh = builder.gridmap.mesh_library.get_item_mesh(item)
	if mesh == null:
		return {"item": item, "orientation": orientation}
	var cell_transform := Transform3D(
		builder.gridmap.get_cell_item_basis(cell), builder.gridmap.map_to_local(cell))
	var gridmap_to_builder: Transform3D = \
		builder.global_transform.affine_inverse() * builder.gridmap.global_transform
	var transform: Transform3D = gridmap_to_builder * cell_transform \
		* builder.gridmap.mesh_library.get_item_mesh_transform(item)
	return {
		"item": item,
		"orientation": orientation,
		"bounds": _transformed_bounds(mesh.get_aabb(), transform),
	}


func _registry_matches(index: int, orientation: int, expected_cells: Array[Vector2i]) -> bool:
	if _game_state.building_registry.size() != 1 or not _game_state.building_registry.has(0):
		return false
	var entry: Dictionary = _game_state.building_registry[0]
	return int(entry.get("structure", -1)) == index \
		and int(entry.get("orientation", -1)) == orientation \
		and _same_cells(entry.get("cells", []), expected_cells)


func _same_cells(actual: Array, expected: Array[Vector2i]) -> bool:
	if actual.size() != expected.size():
		return false
	for cell in expected:
		if cell not in actual:
			return false
	return true


func _ground_matches(builder: Node, cells: Array[Vector2i], expected_item: int) -> bool:
	for cell in cells:
		if builder.ground_gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y)) != expected_item:
			return false
	return true


func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh_instance(child)
		if found:
			return found
	return null


func _transformed_bounds(bounds: AABB, transform: Transform3D) -> AABB:
	var first := true
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				var point := transform * Vector3(x, y, z)
				if first:
					minimum = point
					maximum = point
					first = false
				else:
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func _within(value: Vector3) -> bool:
	return absf(value.x) <= TOLERANCE and absf(value.y) <= TOLERANCE \
		and absf(value.z) <= TOLERANCE


func _aabb_record(bounds: AABB) -> Dictionary:
	return {"min": _vec3(bounds.position), "max": _vec3(bounds.end), "extent": _vec3(bounds.size)}


func _vec3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _cell_records(cells: Array[Vector2i]) -> Array:
	var records: Array = []
	for cell in cells:
		records.append([cell.x, cell.y])
	return records


func _read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _finish() -> void:
	var report := {
		"schema_version": 2,
		"feature": "020-building-ground-contact",
		"success": _failures.is_empty(),
		"tolerance": TOLERANCE,
		"save_path": SAVE_PATH,
		"comparison": "first rendered preview mesh vs live committed GridMap mesh vs ResourceSaver/clear/cache-bypassed Builder cold-load GridMap mesh",
		"row_count": _rows.size(),
		"rows": _rows,
		"failures": _failures,
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ", true) + "\n")
		file.close()
	print("GROUND_CONTACT_ALIGNMENT success=%s rows=%d failures=%d" % [
		report["success"], _rows.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _frames(count: int) -> void:
	for _frame in count:
		await process_frame
