extends SceneTree

const SCENARIO_ID := "civilian_simulation/connected_day"
const SCENARIO_PATH := "res://test/scenarios/civilian_simulation/connected_day.json"
const EVIDENCE_PATH := "res://specs/008-civilian-simulation-coherence/validation/last-run.json"
const REPEAT_COUNT := 10
const FIXED_DELTA := 1.0 / 30.0
const STEPS_PER_HOUR := 240
const FAULT_CODES := ["duplicate_resident_binding","intent_destination_mismatch","unreachable_journey_started",
	"invalid_waypoint_cell","stale_route_revision","missing_car_binding","unexpected_proxy_reset","unexpected_car_cancellation"]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12: await process_frame
	var manager := root.get_node("PluginManager")
	var playtest = manager.get_plugin("Playtest"); var community = manager.get_plugin("Community")
	var roads = manager.get_plugin("RoadNetwork"); var people = manager.get_plugin("People"); var cars = manager.get_plugin("CarManager")
	var scenario := _json(SCENARIO_PATH)
	if playtest == null or community == null or roads == null or people == null or cars == null or scenario.is_empty():
		_failures.append("scenario_setup_failed"); _finish([],{}) ; return
	community._balance["candidate_batch_size"] = 0
	var traces: Array = []
	var hashes: Array[String] = []
	for repeat_index in REPEAT_COUNT:
		# Each replay models a fresh process. Revisions are diagnostic epochs, so the
		# runner resets their counters before invoking the public scenario surface.
		community._assignment_revision = 0; roads._revision = 0
		var trace := _run_day(playtest, people, cars, scenario, repeat_index)
		traces.append(trace); hashes.append(JSON.stringify(trace).sha256_text())
	var deterministic := hashes.all(func(value): return value == hashes[0])
	if not deterministic: _failures.append("ten_run_trace_mismatch")
	var fault_results := {}
	if not people._people.is_empty():
		var person: PersonSlot = people._people[0]
		for code in FAULT_CODES:
			person.diagnostic_faults = [code]
			var projected: Array = playtest.get_snapshot(false).get("civilian_simulation", {}).get("violations", [])
			var detected := projected.any(func(row): return String(row.get("code", "")) == code)
			fault_results[code] = detected
			if not detected: _failures.append("fault_not_detected:%s" % code)
		person.diagnostic_faults.clear()
	_finish(hashes,{"deterministic":deterministic,"canonical_trace":traces[0] if not traces.is_empty() else [],"fault_detection":fault_results})

func _run_day(playtest, people, cars, scenario: Dictionary, repeat_index: int) -> Array:
	var started: Dictionary = playtest.handle_command("start", {"scenario_id":SCENARIO_ID,"seed":int(scenario.get("seed",8008))})
	if started.has("error"):
		_failures.append("start_failed:%d" % repeat_index); return []
	var item_index := 0
	for item: Dictionary in scenario.get("civilian_layout", {}).get("placements", []):
		item_index += 1
		var result: Dictionary = playtest.handle_command("place", {"request_id":"r%d-place-%d" % [repeat_index,item_index],
			"building_id":item.get("building_id", ""),"anchor":{"x":item.get("x",0),"z":item.get("z",0)}})
		if String(result.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_failures.append("placement_failed:%d:%d:%s" % [repeat_index,item_index,result.get("reason","")]); return []
	var trace: Array = [_capture(playtest, "start")]
	for hour_index in 24:
		var advanced: Dictionary = playtest.handle_command("advance", {"request_id":"r%d-hour-%d" % [repeat_index,hour_index],"hours":1})
		if String(advanced.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_failures.append("advance_failed:%d:%d" % [repeat_index,hour_index]); return trace
		for _step in STEPS_PER_HOUR:
			cars._process(FIXED_DELTA); people._process(FIXED_DELTA)
		trace.append(_capture(playtest, "hour_%02d" % (hour_index + 1)))
	return trace

func _capture(playtest, checkpoint: String) -> Dictionary:
	var snapshot: Dictionary = playtest.get_snapshot(false)
	var civilian: Dictionary = _normalize(snapshot.get("civilian_simulation", {}))
	var violations: Array = civilian.get("violations", [])
	if not violations.is_empty(): _failures.append("clean_trace_violation:%s:%s" % [checkpoint,violations])
	return {"checkpoint":checkpoint,"absolute_hour":snapshot.get("simulation",{}).get("absolute_hour",0),"civilian_simulation":civilian}

func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}; var keys: Array = value.keys(); keys.sort()
		for key in keys:
			if String(key) in ["display_position","wall_clock_ms","frame_time_ms"]: continue
			result[key] = _normalize(value[key])
		return result
	if value is Array: return value.map(func(entry): return _normalize(entry))
	if value is float: return snappedf(value,0.0001)
	return value

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _finish(hashes: Array, details: Dictionary) -> void:
	var evidence := {"schema_version":1,"scenario_id":SCENARIO_ID,"seed":8008,"repeat_count":REPEAT_COUNT,
		"success":_failures.is_empty(),"failures":_failures,"trace_hashes":hashes}
	evidence.merge(details,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_PATH.get_base_dir()))
	var file := FileAccess.open(EVIDENCE_PATH,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(evidence,"  ",true) + "\n"); file.close()
	print("CIVILIAN_SCENARIO success=%s repeats=%d failures=%d" % [_failures.is_empty(),hashes.size(),_failures.size()])
	for failure in _failures: push_error(failure)
	quit(0 if _failures.is_empty() else 1)
