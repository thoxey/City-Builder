extends SceneTree

const SCENARIO_PATH := "res://test/scenarios/first_patron_reachable.json"
const OUTPUT := "res://specs/005-reachable-first-patron/validation/screenshots"

var _captured := {}

func _initialize() -> void:
	call_deferred("_capture_route")

func _capture_route() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(12)
	var scenario := _read_json(SCENARIO_PATH)
	var playtest = root.get_node("PluginManager").get_plugin("Playtest")
	if scenario.is_empty() or playtest == null:
		push_error("capture_failed: scenario_or_playtest_unavailable")
		quit(1)
		return
	var started: Dictionary = playtest.start_session({
		"scenario_id": scenario.get("scenario_id", "first_patron_reachable"),
		"seed": scenario.get("seed", 5005),
	})
	if started.has("error"):
		push_error("capture_failed: session_start_failed")
		quit(1)
		return
	var plugin_manager := root.get_node("PluginManager")
	var dashboard = plugin_manager.get_plugin("Dashboard")
	if dashboard:
		dashboard.set_collapsed(false)
		dashboard.select_top_tab("patrons")
	var nameplates = plugin_manager.get_plugin("Nameplate")
	if nameplates:
		nameplates._set_visible(false)
	for raw_action in scenario.get("actions", []):
		var action: Dictionary = raw_action
		var params: Dictionary = action.get("params", {})
		var outcome: Dictionary = playtest.handle_command(String(action.get("kind", "")), params)
		if String(outcome.get("status", "error")) != String(action.get("expected_status", PlaytestActionResult.STATUS_APPLIED)):
			push_error("capture_failed: unexpected action outcome for %s" % params.get("request_id", ""))
			quit(1)
			return
		await _capture_new_milestones(playtest)
	var expected := ["first-arrival", "request-revealed", "patron-ready", "landmark-complete", "land-expanded"]
	for capture_name in expected:
		if not _captured.has(capture_name):
			push_error("capture_failed: missing %s" % capture_name)
			quit(1)
			return
	print("FIRST_PATRON_CAPTURE success=true files=%d size=1280x720" % _captured.size())
	quit()

func _capture_new_milestones(playtest: Node) -> void:
	var milestone_ids := {}
	for milestone in playtest.get_progression_milestones():
		milestone_ids[String(milestone.get("milestone_id", ""))] = true
	if milestone_ids.has("character.aristocrat_residential.arrived") and not _captured.has("first-arrival"):
		await _shot("first-arrival")
	if milestone_ids.has("character.aristocrat_residential.want_revealed") and not _captured.has("request-revealed"):
		await _shot("request-revealed")
	if milestone_ids.has("patron.aristocrat.landmark_available") and not _captured.has("patron-ready"):
		await _shot("patron-ready")
	if milestone_ids.has("patron.aristocrat.completed") and not _captured.has("landmark-complete"):
		await _shot("landmark-complete")
	if milestone_ids.has("patron.aristocrat.land_donated") and not _captured.has("land-expanded"):
		var view = current_scene.get_node_or_null("View")
		if view:
			view.camera_position = Vector3(7, 0, 0)
			view.zoom = 45.0
		await _frames(12)
		await _shot("land-expanded")

func _shot(name: String) -> void:
	await _frames(4)
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280, 720):
		push_error("capture_failed: %s size=%s" % [name, image.get_size()])
		return
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT, name]))
	if error != OK:
		push_error("capture_failed: %s error=%s" % [name, error])
		return
	_captured[name] = true

func _frames(count: int) -> void:
	for _frame in count:
		await process_frame

func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
