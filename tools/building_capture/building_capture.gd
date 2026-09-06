extends Node3D

## Deterministic catalogue capture rig. Run this scene directly; it writes
## front and isometric PNGs plus manifest.json, then exits.

const DATA_ROOT := "res://data/buildings"
const OUTPUT_ROOT := "res://artifacts/building_screenshots"
const CAPTURE_SIZE := Vector2i(1024, 1024)
const FRONT_DIRECTION := Vector3(0.0, 0.0, 1.0)
const ISOMETRIC_DIRECTION := Vector3(1.0, 0.8, 1.0)
const FRAME_PADDING := 1.18

@onready var subject: Node3D = $Subject
@onready var camera: Camera3D = $Camera3D
@onready var ground: MeshInstance3D = $Ground


func _ready() -> void:
	get_window().size = CAPTURE_SIZE
	get_viewport().transparent_bg = false
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_ROOT)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	if mkdir_error != OK:
		push_error("[BuildingCapture] Could not create output directory: %s" % error_string(mkdir_error))
		get_tree().quit(1)
		return

	var definitions: Array[Dictionary] = []
	_collect_definitions(DATA_ROOT, definitions)
	definitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("building_id", "")) < String(b.get("building_id", ""))
	)

	var manifest_entries: Array[Dictionary] = []
	var failures: Array[String] = []
	for definition in definitions:
		var result := await _capture_definition(definition)
		if result.is_empty():
			failures.append(String(definition.get("building_id", "unknown")))
		else:
			manifest_entries.append(result)

	var manifest := {
		"capture_size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"count": manifest_entries.size(),
		"failed": failures,
		"views": ["front", "isometric"],
		"buildings": manifest_entries,
	}
	var manifest_path := OUTPUT_ROOT.path_join("manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file:
		manifest_file.store_string(JSON.stringify(manifest, "\t") + "\n")
		manifest_file.close()
	else:
		push_error("[BuildingCapture] Could not write %s" % manifest_path)
		failures.append("manifest")

	print("[BuildingCapture] COMPLETE count=%d failed=%d output=%s" % [
		manifest_entries.size(), failures.size(), output_absolute
	])
	get_tree().quit(0 if failures.is_empty() else 1)


func _collect_definitions(root_path: String, output: Array[Dictionary]) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		push_error("[BuildingCapture] Could not open %s" % root_path)
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		var entry_path := root_path.path_join(entry_name)
		if directory.current_is_dir():
			if not entry_name.begins_with("_"):
				_collect_definitions(entry_path, output)
		elif entry_name.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(entry_path))
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("building_id"):
				var definition: Dictionary = parsed
				definition["_definition_path"] = entry_path
				output.append(definition)
			else:
				push_warning("[BuildingCapture] Skipping invalid definition: %s" % entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _capture_definition(definition: Dictionary) -> Dictionary:
	_clear_subject()
	var building_id := String(definition.get("building_id", "")).validate_filename()
	var model_path := String(definition.get("model_path", ""))
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_error("[BuildingCapture] Missing model for %s: %s" % [building_id, model_path])
		return {}

	var model := packed.instantiate() as Node3D
	if model == null:
		push_error("[BuildingCapture] Model root is not Node3D for %s" % building_id)
		return {}
	subject.add_child(model)
	model.scale = Vector3.ONE * float(definition.get("model_scale", 1.0))
	model.rotation_degrees.y = float(definition.get("model_rotation_y", 0.0))
	model.position = _array_to_vector3(definition.get("model_offset", [0, 0, 0]))

	await get_tree().process_frame
	var points := _mesh_bounds_points(model)
	if points.is_empty():
		push_error("[BuildingCapture] No mesh bounds for %s" % building_id)
		return {}

	var bounds := _bounds_from_points(points)
	var center := bounds.get_center()
	model.position += Vector3(-center.x, -bounds.position.y, -center.z)
	await get_tree().process_frame
	points = _mesh_bounds_points(model)
	ground.visible = true

	var front_path := OUTPUT_ROOT.path_join("%s_front.png" % building_id)
	var iso_path := OUTPUT_ROOT.path_join("%s_isometric.png" % building_id)
	var front_ok := await _capture_view(points, FRONT_DIRECTION, front_path)
	var iso_ok := await _capture_view(points, ISOMETRIC_DIRECTION, iso_path)
	if not front_ok or not iso_ok:
		return {}

	print("[BuildingCapture] captured %s" % building_id)
	return {
		"building_id": building_id,
		"display_name": String(definition.get("display_name", building_id)),
		"category": String(definition.get("category", "")),
		"definition_path": String(definition.get("_definition_path", "")),
		"model_path": model_path,
		"front": front_path,
		"isometric": iso_path,
	}


func _capture_view(points: Array[Vector3], direction: Vector3, output_path: String) -> bool:
	var bounds := _bounds_from_points(points)
	var target := bounds.get_center()
	var radius := maxf(bounds.size.length(), 1.0)
	camera.global_position = target + direction.normalized() * radius * 3.0
	camera.look_at(target, Vector3.UP)
	camera.size = _orthographic_size_for_points(points) * FRAME_PADDING
	camera.near = 0.01
	camera.far = radius * 10.0 + 10.0

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("[BuildingCapture] Empty viewport image for %s" % output_path)
		return false
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("[BuildingCapture] Could not save %s: %s" % [output_path, error_string(save_error)])
		return false
	return true


func _orthographic_size_for_points(points: Array[Vector3]) -> float:
	var inverse_camera := camera.global_transform.affine_inverse()
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for point in points:
		var camera_point := inverse_camera * point
		min_x = minf(min_x, camera_point.x)
		max_x = maxf(max_x, camera_point.x)
		min_y = minf(min_y, camera_point.y)
		max_y = maxf(max_y, camera_point.y)
	var aspect := float(CAPTURE_SIZE.x) / float(CAPTURE_SIZE.y)
	return maxf(maxf(max_y - min_y, (max_x - min_x) / aspect), 0.25)


func _mesh_bounds_points(root: Node) -> Array[Vector3]:
	var points: Array[Vector3] = []
	_append_mesh_bounds(root, points)
	return points


func _append_mesh_bounds(node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			var box := mesh_instance.mesh.get_aabb()
			for x in [box.position.x, box.end.x]:
				for y in [box.position.y, box.end.y]:
					for z in [box.position.z, box.end.z]:
						points.append(mesh_instance.global_transform * Vector3(x, y, z))
	for child in node.get_children():
		_append_mesh_bounds(child, points)


func _bounds_from_points(points: Array[Vector3]) -> AABB:
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func _array_to_vector3(value: Variant) -> Vector3:
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _clear_subject() -> void:
	for child in subject.get_children():
		subject.remove_child(child)
		child.queue_free()
