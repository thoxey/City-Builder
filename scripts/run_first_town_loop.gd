extends SceneTree

const SCENARIO_ID := "first_town_connected"
const EVIDENCE_PATH := "res://specs/006-connected-first-town-loop/validation/last-run.json"

var _failures: Array[String] = []
var _observations: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12:
		await process_frame
	var playtest = root.get_node("PluginManager").get_plugin("Playtest")
	if playtest == null:
		_finish("playtest_unavailable")
		return
	var started: Dictionary = playtest.start_session({"scenario_id": SCENARIO_ID, "seed": 6006})
	if started.has("error"):
		_finish("session_start_failed")
		return
	_assert(not bool(started["snapshot"].get("tier_two_available", true)), "Tier 2 choices must not be available at a fresh-town demand of 25")

	_apply(playtest, "place", {"request_id": "place-home", "building_id": "building_small_a", "anchor": {"x": -1, "z": 0}})
	_apply(playtest, "place", {"request_id": "place-workplace", "building_id": "building_garage", "anchor": {"x": 2, "z": 0}})
	_apply(playtest, "advance", {"request_id": "advance-roadless", "hours": 2})
	var roadless: Dictionary = playtest.get_snapshot()
	_observations["roadless"] = _evidence_slice(roadless)
	_assert(_fulfilled(roadless) == 0, "Roadless workplace must have no fulfilled workers")
	_assert(int(roadless["economy"]["industrial_output"]) == 0, "Roadless workplace must produce no output")
	_assert(int(roadless["economy"]["last_hourly_income"]) == 0, "Roadless workplace must produce no income")
	_assert(_primary_reason(roadless) == "no_road_access", "Roadless workplace must report no_road_access")

	_apply(playtest, "place", {"request_id": "place-road-a", "building_id": "road", "anchor": {"x": 0, "z": 0}})
	_apply(playtest, "place", {"request_id": "place-road-b", "building_id": "road", "anchor": {"x": 1, "z": 0}})
	_apply(playtest, "advance", {"request_id": "advance-connected", "hours": 1})
	var connected: Dictionary = playtest.get_snapshot()
	_observations["connected"] = _evidence_slice(connected)
	_assert(_fulfilled(connected) == 1, "Connected workplace must receive the resident")
	_assert(int(connected["economy"]["industrial_output"]) == 1, "Connected workplace must produce output immediately at the boundary")
	_assert(int(connected["economy"]["last_hourly_income"]) > 0, "Connected workplace must produce income immediately at the boundary")
	_assert(_primary_reason(connected).is_empty(), "Connected workplace must have no failure reason")

	_apply(playtest, "demolish", {"request_id": "remove-road-a", "cell": {"x": 0, "z": 0}})
	_apply(playtest, "advance", {"request_id": "advance-disconnected", "hours": 1})
	var disconnected: Dictionary = playtest.get_snapshot()
	_observations["disconnected"] = _evidence_slice(disconnected)
	_assert(_fulfilled(disconnected) == 0, "Disconnected workplace must clear fulfilled workers by the next boundary")
	_assert(int(disconnected["economy"]["industrial_output"]) == 0, "Disconnected workplace must clear output by the next boundary")
	_assert(int(disconnected["economy"]["last_hourly_income"]) == 0, "Disconnected workplace must clear income by the next boundary")
	_assert(_primary_reason(disconnected) in ["no_road_access", "isolated_road_component"], "Disconnected workplace must report a connectivity reason")
	_finish("")

func _apply(playtest, operation: String, params: Dictionary) -> void:
	var outcome: Dictionary = playtest.handle_command(operation, params)
	_assert(String(outcome.get("status", "error")) == PlaytestActionResult.STATUS_APPLIED,
		"%s failed: %s" % [params.get("request_id", operation), outcome])

func _fulfilled(snapshot: Dictionary) -> int:
	for record in snapshot.get("operation", []):
		if String(record.get("building_id", "")) == "building_garage":
			return int(record.get("fulfilled", 0))
	return -1

func _primary_reason(snapshot: Dictionary) -> String:
	for record in snapshot.get("operation", []):
		if String(record.get("building_id", "")) == "building_garage":
			return String(record.get("primary_reason", ""))
	return "missing_operation_record"

func _evidence_slice(snapshot: Dictionary) -> Dictionary:
	return {
		"absolute_hour": snapshot.get("simulation", {}).get("absolute_hour", 0),
		"economy": snapshot.get("economy", {}).duplicate(true),
		"community": {
			"population": snapshot.get("community", {}).get("population", 0),
			"assignments": snapshot.get("community", {}).get("assignments", []).duplicate(true),
		},
		"connectivity": snapshot.get("connectivity", {}).duplicate(true),
		"operation": snapshot.get("operation", []).duplicate(true),
		"state_hash": snapshot.get("state_hash", ""),
	}

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish(setup_failure: String) -> void:
	if not setup_failure.is_empty():
		_failures.append(setup_failure)
	var evidence := {
		"schema_version": 1,
		"scenario_id": SCENARIO_ID,
		"seed": 6006,
		"success": _failures.is_empty(),
		"failures": _failures,
		"observations": _observations,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_PATH.get_base_dir()))
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(evidence, "  ", true) + "\n")
		file.close()
	print("FIRST_TOWN_LOOP success=%s failures=%d" % [_failures.is_empty(), _failures.size()])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
