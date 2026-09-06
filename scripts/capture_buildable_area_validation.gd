extends SceneTree

const OUTPUT := "res://specs/013-buildable-community-pass/validation/screenshots"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const NORMAL_ZOOM := 60.0

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = VIEWPORT_SIZE
	change_scene_to_file("res://scenes/main.tscn")
	# GroundMap fills incrementally; wait beyond its final yielded row.
	await _frames(48)
	var manager := root.get_node("PluginManager")
	var buildable = manager.get_plugin("BuildableArea")
	var palette = manager.get_plugin("Palette")
	var player_ui = manager.get_plugin("PlayerUI")
	var dashboard = manager.get_plugin("Dashboard")
	var builder = current_scene.get_node("Builder")
	var view = current_scene.get_node("View")
	if buildable == null or palette == null or player_ui == null or builder == null or view == null:
		push_error("buildable_capture_setup_failed")
		quit(1)
		return

	view.camera_position = Vector3.ZERO
	view.zoom = NORMAL_ZOOM
	if dashboard and dashboard.has_method("set_collapsed"):
		dashboard.set_collapsed(true)
	_suppress_guidance(dashboard)
	builder.cancel_placement()
	await _frames(8)
	var hall: Dictionary = builder.try_place_building("building_town_hall", Vector2i(-1, -1))
	var road: Dictionary = builder.try_place_building("road", Vector2i(1, 0))
	var home: Dictionary = builder.try_place_building("building_small_a", Vector2i(1, 1))
	var nature: Dictionary = builder.try_place_building("building_nature_patch", Vector2i(2, 0))
	for result in [hall, road, home, nature]:
		if String(result.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			push_error("buildable_capture_placement_failed:%s" % result)
			quit(1)
			return
	await _frames(8)
	_suppress_guidance(dashboard)
	var normal: Dictionary = buildable.get_presentation_snapshot()
	await _shot("boundary-normal")

	player_ui._request_entry("building_nature_patch")
	if not builder.is_placement_active():
		push_error("buildable_capture_preview_failed")
		quit(1)
		return
	Input.warp_mouse(root.size * 0.5)
	await _frames(8)
	_suppress_guidance(dashboard)
	var emphasized: Dictionary = buildable.get_presentation_snapshot()
	await _shot("boundary-placement")

	var manifest := {
		"schema_version": 1,
		"renderer": RenderingServer.get_current_rendering_method(),
		"viewport": {"width": VIEWPORT_SIZE.x, "height": VIEWPORT_SIZE.y},
		"camera": {"position": {"x": 0, "y": 0, "z": 0}, "zoom": NORMAL_ZOOM},
		"normal": normal,
		"placement": emphasized,
		"files": ["boundary-normal.png", "boundary-placement.png"],
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT + "/manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "  ", true) + "\n")
		file.close()
	print("BUILDABLE_CAPTURE success=true renderer=%s clear=%d veiled=%d" % [manifest["renderer"], int(normal["buildable_clear_cell_count"]), int(normal["non_buildable_cell_count"])])
	quit()

func _shot(name: String) -> void:
	await _frames(3)
	var texture := root.get_texture()
	if texture == null:
		push_error("capture_texture_missing:%s" % name)
		return
	var image := texture.get_image()
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT, name]))
	if error != OK or image.get_size() != VIEWPORT_SIZE:
		push_error("capture_failed:%s:%s:%s" % [name, error, image.get_size()])

func _frames(count: int) -> void:
	for _frame in count:
		await process_frame

func _suppress_guidance(dashboard: Node) -> void:
	if dashboard == null or not dashboard.get("_guidance_view"):
		return
	var guidance: Control = dashboard.get("_guidance_view")
	guidance.set_suppressed(true)
	guidance.hide()
