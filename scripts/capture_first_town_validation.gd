extends SceneTree

const ROOT := "res://test/scenarios/first_town/"
const OUTPUT := "res://specs/006-connected-first-town-loop/validation/screenshots"
const CAMERA_POSITION := Vector3(2.0, 0.0, 1.0)
const CAMERA_ZOOM := 42.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(12)
	var manager = root.get_node("PluginManager")
	var playtest = manager.get_plugin("Playtest")
	var community = manager.get_plugin("Community")
	var dashboard = manager.get_plugin("Dashboard")
	if playtest == null or community == null or dashboard == null:
		push_error("first_town_capture_setup_failed")
		quit(1)
		return
	community._balance["candidate_batch_size"] = 0
	for scenario_name in ["compact", "spread"]:
		var scenario := _json(ROOT + scenario_name + ".json")
		if not await _apply(playtest, community, scenario):
			quit(1)
			return
		_freeze_camera()
		dashboard.set_collapsed(true)
		await _shot("matched-%s" % scenario_name)
	# Use the compact town for the visible operation/exposure inspection surface.
	var compact := _json(ROOT + "compact.json")
	if not await _apply(playtest, community, compact):
		quit(1)
		return
	_freeze_camera()
	dashboard.set_collapsed(false)
	dashboard.select_top_tab("community")
	root.get_node("GameEvents").community_place_selected.emit(Vector2i(2, 0))
	await _frames(12)
	await _shot("operation-inspection")
	dashboard.set_collapsed(true)
	var player_ui = manager.get_plugin("PlayerUI")
	var pond_index := int(manager.get_plugin("BuildingCatalog").get_item_index("building_duck_pond"))
	player_ui._dock.show_placement("building_duck_pond", "", 0, community.get_placement_preview(pond_index, Vector2i(0, 0)))
	await _frames(8)
	await _shot("placement-coverage-preview")
	for scenario_name in ["midgame_green_corridors", "midgame_garden_blocks"]:
		var scenario := _json(ROOT + scenario_name + ".json")
		if not await _apply(playtest, community, scenario):
			push_error("midgame_capture_failed:%s" % scenario_name)
			quit(1)
			return
		var view = current_scene.get_node_or_null("View")
		if view:
			view.camera_position = Vector3(-0.5, 0.0, 0.0)
			view.zoom = 36.0
		dashboard.set_collapsed(true)
		player_ui._dock.show_idle()
		await _shot(scenario_name.replace("_", "-"))
	var manifest := {
		"schema_version": 1,
		"renderer": RenderingServer.get_current_rendering_method(),
		"viewport": {"width": 1280, "height": 720},
		"frozen_camera": {"position": {"x": CAMERA_POSITION.x, "y": CAMERA_POSITION.y, "z": CAMERA_POSITION.z}, "zoom": CAMERA_ZOOM},
		"midgame_frozen_camera": {"position": {"x": -0.5, "y": 0.0, "z": 0.0}, "zoom": 36.0},
		"files": ["matched-compact.png", "matched-spread.png", "operation-inspection.png", "placement-coverage-preview.png", "midgame-green-corridors.png", "midgame-garden-blocks.png"],
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT + "/manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "  ", true) + "\n")
		file.close()
	print("FIRST_TOWN_CAPTURE success=true renderer=%s files=6" % manifest["renderer"])
	quit()

func _apply(playtest, community, scenario: Dictionary) -> bool:
	var started: Dictionary = playtest.start_session({"scenario_id": scenario.get("scenario_id", ""), "seed": scenario.get("seed", 1)})
	if started.has("error"): return false
	var index := 0
	for item in scenario.get("layout", []):
		index += 1
		var outcome: Dictionary = playtest.handle_command("place", {"request_id": "capture-place-%d" % index, "building_id": item.get("building_id", ""), "anchor": item.get("anchor", {})})
		if String(outcome.get("status", "")) != PlaytestActionResult.STATUS_APPLIED: return false
	community.apply_scenario_fixture(scenario.get("fixture", {}), int(scenario.get("seed", 1)))
	var advanced: Dictionary = playtest.handle_command("advance", {"request_id": "capture-advance", "hours": int(scenario.get("capture_hours", 2))})
	await _frames(12)
	return String(advanced.get("status", "")) == PlaytestActionResult.STATUS_APPLIED

func _freeze_camera() -> void:
	var view = current_scene.get_node_or_null("View")
	if view:
		view.camera_position = CAMERA_POSITION
		view.zoom = CAMERA_ZOOM

func _shot(name: String) -> void:
	await _frames(8)
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280, 720):
		push_error("capture_size_failed:%s:%s" % [name, image.get_size()])
		return
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT, name]))
	if error != OK: push_error("capture_write_failed:%s:%s" % [name, error])

func _frames(count: int) -> void:
	for _frame in count: await process_frame

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
