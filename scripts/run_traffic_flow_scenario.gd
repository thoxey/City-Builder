extends SceneTree

const SCENARIO_PATH := "res://test/scenarios/traffic_flow/coherence.json"
const AUTHORITY_SCENARIO_PATH := "res://test/scenarios/civilian_simulation/connected_day.json"
const AUTHORITY_SCENARIO_ID := "civilian_simulation/connected_day"
const EVIDENCE_PATH := "res://specs/010-traffic-flow-coherence/validation/last-run.json"
const REQUIRED_FAULTS := ["road_tile_over_capacity", "duplicate_car_position",
	"car_transform_off_road", "spawned_without_admission", "pending_order_violation",
	"missing_current_tile_claim", "invalid_next_tile_claim",
	"canonical_route_changed_by_congestion", "persistent_pedestrian_overlap"]

var _failures: Array[String] = []
var _cars: Node
var _people: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenario := _json(SCENARIO_PATH)
	if scenario.is_empty():
		_finish({}, [], {})
		return
	var authority := await _run_authority_smoke()
	var fixtures: Variant = load("res://test/unit/traffic/car_manager_test_fixtures.gd")
	_cars = fixtures.manager(8)
	var replay_count := int(scenario.get("replay_count", 10))
	var traces: Array = []
	var hashes: Array[String] = []
	for repeat_index in replay_count:
		var trace := _run_traffic_replay(scenario, repeat_index)
		traces.append(trace)
		hashes.append(JSON.stringify(trace).sha256_text())
	var deterministic := not hashes.is_empty() \
		and hashes.all(func(value): return value == hashes[0])
	if not deterministic:
		_failures.append("ten_run_trace_mismatch")
	var faults := _run_fault_injection(scenario)
	for code in REQUIRED_FAULTS:
		if not bool(faults.get(code, false)):
			_failures.append("fault_not_detected:%s" % code)
	fixtures.free_manager(_cars)
	_cars = null
	_finish(authority, hashes, {
		"deterministic":deterministic,
		"canonical_trace":traces[0] if not traces.is_empty() else [],
		"fault_detection":faults,
	})

func _run_authority_smoke() -> Dictionary:
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12:
		await process_frame
	var manager := root.get_node_or_null("PluginManager")
	var playtest: Variant = manager.get_plugin("Playtest") if manager else null
	_cars = manager.get_plugin("CarManager") if manager else null
	_people = manager.get_plugin("People") if manager else null
	var scenario := _json(AUTHORITY_SCENARIO_PATH)
	if playtest == null or _cars == null or _people == null or scenario.is_empty():
		_failures.append("authority_smoke_setup_failed")
		return {}
	var started: Dictionary = playtest.handle_command("start", {
		"scenario_id":AUTHORITY_SCENARIO_ID, "seed":int(scenario.get("seed", 8008))})
	if started.has("error"):
		_failures.append("authority_smoke_start_failed")
		return {}
	var index := 0
	for item: Dictionary in scenario.get("civilian_layout", {}).get("placements", []):
		index += 1
		var result: Dictionary = playtest.handle_command("place", {
			"request_id":"traffic-authority-place-%d" % index,
			"building_id":String(item.get("building_id", "")),
			"anchor":{"x":int(item.get("x", 0)), "z":int(item.get("z", 0))},
			"snapshot_mode":"none",
		})
		if String(result.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_failures.append("authority_smoke_placement_failed:%d" % index)
			return {}
	var advanced: Dictionary = playtest.handle_command("advance", {
		"request_id":"traffic-authority-advance", "hours":1, "snapshot_mode":"compact"})
	if String(advanced.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
		_failures.append("authority_smoke_advance_failed")
		return {}
	return {
		"scenario_id":AUTHORITY_SCENARIO_ID,
		"public_operations":["start", "place", "advance"],
		"state_hash":String(advanced.get("snapshot", {}).get("state_hash", "")),
		"success":true,
	}

func _run_traffic_replay(scenario: Dictionary, repeat_index: int) -> Array:
	var manager := _cars
	manager._cancel_all()
	var path := _path(scenario.get("road_path", []))
	var delta := float(scenario.get("fixed_delta", 1.0 / 30.0))
	var blocked_steps := int(scenario.get("blocked_steps", 600))
	var blocker_tile: Vector3i = path[1]
	manager._reserved[blocker_tile] = {
		90:{"dir":Vector2i.RIGHT,"slot":0,"phase":"current","claim_order":0},
		91:{"dir":Vector2i.RIGHT,"slot":1,"phase":"current","claim_order":1},
	}
	for resident_id in scenario.get("resident_ids", []):
		var journey_id: int = manager.request_resolved_journey(int(resident_id), path.front(), path.back(),
			path, 1, "plan-%d" % int(resident_id))
		if journey_id < 0:
			_failures.append("replay_request_rejected:%d:%d:pools=%s:path=%s" % [
				repeat_index, int(resident_id), str(manager._pools.keys()), str(path)])
	manager._process(0.0)
	var trace: Array = [_capture(manager, "admitted", repeat_index)]
	for _step in blocked_steps:
		manager._process(delta)
	trace.append(_capture(manager, "gridlock_end", repeat_index))
	manager._release_tile(blocker_tile, 90)
	manager._release_tile(blocker_tile, 91)
	for _step in 15:
		manager._process(delta)
	trace.append(_capture(manager, "queue_release", repeat_index))
	for _step in 180:
		manager._process(delta)
	trace.append(_capture(manager, "completed", repeat_index))
	var saved_people: Array[PersonSlot] = _people._people.duplicate()
	var saved_spacing: Array = _people._pedestrian_spacing.duplicate(true)
	var walkers: Array[PersonSlot] = []
	for resident_id in scenario.get("resident_ids", []):
		walkers.append(_walker(int(resident_id)))
	_people._people = walkers
	_people._apply_pedestrian_spacing()
	var pedestrian_rows: Array = _people.get_pedestrian_spacing_snapshot()
	trace.append({"checkpoint":"pedestrians", "traffic":{
		"pedestrian_spacing":pedestrian_rows,
		"violations":_people._pedestrian_spacing_violations(),
	}})
	if _people._pedestrian_spacing_violations().size() > 0:
		_failures.append("clean_pedestrian_violation:%d" % repeat_index)
	_people._people = saved_people
	_people._pedestrian_spacing = saved_spacing
	manager._cancel_all()
	return _normalize(trace)

func _capture(manager: Node, checkpoint: String, repeat_index: int) -> Dictionary:
	var snapshot: Dictionary = manager.get_traffic_flow_snapshot()
	if not snapshot["violations"].is_empty():
		_failures.append("clean_traffic_violation:%d:%s" % [repeat_index, checkpoint])
	for occupancy: Dictionary in snapshot["tile_occupancy"]:
		if int(occupancy["claim_count"]) > 2:
			_failures.append("capacity_exceeded:%d:%s" % [repeat_index, checkpoint])
	var positions: Array = snapshot["active_journeys"].map(
		func(row): return row["display_position"])
	var unique_positions: Array = positions.duplicate().reduce(
		func(unique, value): return unique if value in unique else unique + [value], [])
	if unique_positions.size() != positions.size():
		_failures.append("duplicate_position:%d:%s" % [repeat_index, checkpoint])
	return {"checkpoint":checkpoint, "traffic":snapshot}

func _run_fault_injection(scenario: Dictionary) -> Dictionary:
	var manager := _cars
	manager._cancel_all()
	var path := _path(scenario.get("road_path", []))
	for resident_id in scenario.get("resident_ids", []):
		var journey_id: int = manager.request_resolved_journey(int(resident_id), path.front(), path.back(),
			path, 1, "plan-%d" % int(resident_id))
		if journey_id < 0:
			_failures.append("fault_request_rejected:%d:pools=%s:path=%s" % [
				int(resident_id), str(manager._pools.keys()), str(path)])
	manager._process(0.0)
	manager._pending_order.reverse()
	if manager._active.size() < 2:
		manager._cancel_all()
		return {}
	var first: CarSlot = manager._active[0]
	var second: CarSlot = manager._active[1]
	first.position = Vector3(99, 0, 99)
	second.position = first.position
	first.admitted = false
	first.route = [Vector3i.ZERO, Vector3i(0,0,1)]
	manager._reserved[first.current_tile].erase(first.journey_id)
	first.next_tile = Vector3i(8,0,8)
	manager._reserved[Vector3i(7,0,7)] = {
		90:{"dir":Vector2i.RIGHT,"slot":0,"phase":"current","claim_order":90},
		91:{"dir":Vector2i.RIGHT,"slot":1,"phase":"current","claim_order":91},
		92:{"dir":Vector2i.RIGHT,"slot":2,"phase":"current","claim_order":92},
	}
	var detected_codes: Array = manager.get_traffic_flow_snapshot()["violations"].map(
		func(row): return row["code"])
	var saved_spacing: Array = _people._pedestrian_spacing.duplicate(true)
	_people._pedestrian_spacing = [
		{"resident_id":1,"display_position":{"x":0.5,"y":0.1,"z":0.38}},
		{"resident_id":2,"display_position":{"x":0.5,"y":0.1,"z":0.38}},
	]
	detected_codes.append_array(_people._pedestrian_spacing_violations().map(
		func(row): return row["code"]))
	var result := {}
	for code in REQUIRED_FAULTS:
		result[code] = code in detected_codes
	_people._pedestrian_spacing = saved_spacing
	manager._cancel_all()
	return result

func _walker(resident_id: int) -> PersonSlot:
	var person := PersonSlot.new()
	person.resident_id = resident_id
	person.current_tile = Vector3i.ZERO
	person.position = Vector3(0.45, 0.1, 0.0)
	person.display_position = person.position
	person.visible = true
	person.state = PersonSlot.VisualState.WALKING_ROUTE
	person._waypoint_tiles = [Vector3i(1,0,0)]
	person._waypoints = [Vector3(1,0.1,0)]
	return person

func _path(records: Array) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for record: Dictionary in records:
		result.append(Vector3i(int(record.get("x", 0)), int(record.get("y", 0)),
			int(record.get("z", 0))))
	return result

func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _normalize(value[key])
		return result
	if value is Array:
		return value.map(func(entry): return _normalize(entry))
	if value is float:
		return snappedf(value, 0.0001)
	return value

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _finish(authority: Dictionary, hashes: Array, details: Dictionary) -> void:
	var evidence := {
		"schema_version":1,
		"scenario_id":"traffic_flow_coherence",
		"seed":1010,
		"repeat_count":hashes.size(),
		"success":_failures.is_empty(),
		"failures":_failures,
		"authority_smoke":authority,
		"trace_hashes":hashes,
	}
	evidence.merge(details, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		EVIDENCE_PATH.get_base_dir()))
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(evidence, "  ", true) + "\n")
		file.close()
	else:
		_failures.append("evidence_write_failed")
	print("TRAFFIC_FLOW_SCENARIO success=%s repeats=%d failures=%d" % [
		_failures.is_empty(), hashes.size(), _failures.size()])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
