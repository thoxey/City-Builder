extends SceneTree

## Feature-020 reference-town benchmark. The same script is run before and after
## the repair so the comparison includes map load, a normal placement command,
## rendered frame time, draw calls, and visible render objects.

const DEFAULT_OUTPUT := "res://specs/020-building-ground-contact/validation/performance-before.json"
const DEFAULT_REFERENCE_SAVE := "user://feature020-baseline-town.tres"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const LOAD_RUNS := 7
const PLACEMENT_RUNS := 7
const WARMUP_FRAMES := 90
const MEASURED_FRAMES := 180

var _output_path := DEFAULT_OUTPUT
var _reference_save := DEFAULT_REFERENCE_SAVE
var _phase := "before"
var _force_replace_control := false
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_read_environment()
	if DisplayServer.get_name() == "headless":
		_write({"schema_version": 1, "phase": _phase, "success": false,
			"failures": ["normal_renderer_required"]})
		quit(2)
		return
	root.size = VIEWPORT_SIZE
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(48)
	var builder = current_scene.get_node_or_null("Builder")
	var manager = root.get_node_or_null("PluginManager")
	if builder == null or manager == null:
		_write({"schema_version": 1, "phase": _phase, "success": false,
			"failures": ["reference_scene_setup_failed"]})
		quit(2)
		return
	_apply_control_override(manager)

	var load_samples: Array[int] = []
	var post_load_frame_samples: Array[int] = []
	for _run_index in LOAD_RUNS:
		var started := Time.get_ticks_usec()
		var outcome: Dictionary = builder.load_map_from_path(_reference_save)
		load_samples.append(Time.get_ticks_usec() - started)
		if String(outcome.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_failures.append("reference_load_failed:%s" % outcome)
			break
		started = Time.get_ticks_usec()
		await process_frame
		post_load_frame_samples.append(Time.get_ticks_usec() - started)
	if not _failures.is_empty():
		_finish({}, {}, {}, {})
		return

	var ground_state_before := _ground_state(builder)
	var placement_samples: Array[int] = []
	var placement_cell := Vector2i.ZERO
	var placement_building_id := "building_nature_patch"
	for _run_index in PLACEMENT_RUNS:
		var loaded: Dictionary = builder.load_map_from_path(_reference_save)
		if String(loaded.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_failures.append("placement_reload_failed")
			break
		var candidate := _find_valid_cell(builder, placement_building_id)
		if candidate.x < -90000:
			placement_building_id = "pavement"
			candidate = _find_valid_cell(builder, placement_building_id)
		if candidate.x < -90000:
			_failures.append("no_reference_placement_cell")
			break
		placement_cell = candidate
		var started := Time.get_ticks_usec()
		var outcome: Dictionary = builder.try_place_building(placement_building_id, candidate)
		placement_samples.append(Time.get_ticks_usec() - started)
		if String(outcome.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_failures.append("reference_placement_failed:%s" % outcome)
			break
		await process_frame

	var final_load: Dictionary = builder.load_map_from_path(_reference_save)
	if String(final_load.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
		_failures.append("final_reference_load_failed")
	for _frame in WARMUP_FRAMES:
		await process_frame
	var frame_samples: Array[int] = []
	var draw_call_samples: Array[int] = []
	var object_samples: Array[int] = []
	var primitive_samples: Array[int] = []
	for _frame in MEASURED_FRAMES:
		var started := Time.get_ticks_usec()
		await process_frame
		frame_samples.append(Time.get_ticks_usec() - started)
		draw_call_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		object_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		primitive_samples.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var ground_state_after := _ground_state(builder)
	_finish(
		_sample_record(load_samples),
		_sample_record(placement_samples),
		_sample_record(frame_samples),
		{
			"draw_calls": _sample_record(draw_call_samples),
			"visible_objects": _sample_record(object_samples),
			"primitives": _sample_record(primitive_samples),
			"post_load_frame": _sample_record(post_load_frame_samples),
			"ground_state_before_frames": ground_state_before,
			"ground_state_after_frames": ground_state_after,
			"placement_building_id": placement_building_id,
			"placement_cell": [placement_cell.x, placement_cell.y],
		})

func _finish(load_record: Dictionary, placement_record: Dictionary,
		frame_record: Dictionary, rendering: Dictionary) -> void:
	var report := {
		"schema_version": 1,
		"feature": "020-building-ground-contact",
		"phase": _phase,
		"success": _failures.is_empty(),
		"failures": _failures,
		"reference_save": _reference_save,
		"load": load_record,
		"placement": placement_record,
		"steady_frame": frame_record,
		"rendering": rendering,
		"environment": {
			"engine_version": Engine.get_version_info().get("string", ""),
			"platform": OS.get_name(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"display_server": DisplayServer.get_name(),
			"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
			"build_mode": "debug" if OS.is_debug_build() else "release",
		},
		"sample_policy": {
			"load_runs": LOAD_RUNS,
			"placement_runs": PLACEMENT_RUNS,
			"warmup_frames": WARMUP_FRAMES,
			"measured_frames": MEASURED_FRAMES,
			"median": "nearest-rank ceil(0.5*n), one-based",
		},
		"investigation": {
			"force_replace_control": _force_replace_control,
			"purpose": "paired current-tree control; in-memory catalogue projection only",
		},
	}
	_write(report)
	print("GROUND_CONTACT_PERFORMANCE success=%s phase=%s load_median_us=%d placement_median_us=%d frame_median_us=%d draw_calls=%d visible=%d" % [
		_failures.is_empty(), _phase,
		int(load_record.get("median", 0)), int(placement_record.get("median", 0)),
		int(frame_record.get("median", 0)), int(rendering.get("draw_calls", {}).get("median", 0)),
		int(rendering.get("visible_objects", {}).get("median", 0))])
	quit(0 if _failures.is_empty() else 1)

func _find_valid_cell(builder: Node, building_id: String) -> Vector2i:
	for z in range(-8, 8):
		for x in range(-8, 8):
			var cell := Vector2i(x, z)
			var evaluation: Dictionary = builder.evaluate_placement(building_id, cell)
			if bool(evaluation.get("ok", false)):
				return cell
	return Vector2i(-99999, -99999)

func _ground_state(builder: Node) -> Dictionary:
	var game_state = root.get_node("GameState")
	var counts := {"normal_grass": 0, "grass_underlay": 0, "empty": 0, "other": 0}
	var occupied_rows: Array = []
	for cell_any in game_state.cell_to_building:
		var cell: Vector2i = cell_any
		var item: int = builder.ground_gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y))
		match item:
			0: counts["normal_grass"] += 1
			1: counts["grass_underlay"] += 1
			-1: counts["empty"] += 1
			_: counts["other"] += 1
		occupied_rows.append({"cell": [cell.x, cell.y], "item": item})
	occupied_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["cell"][1] != b["cell"][1]:
			return a["cell"][1] < b["cell"][1]
		return a["cell"][0] < b["cell"][0])
	return {
		"occupied_cell_count": occupied_rows.size(),
		"counts": counts,
		"occupied_cells_sha256": (JSON.stringify(occupied_rows)).sha256_text(),
		"building_count": game_state.building_registry.size(),
	}

static func _sample_record(values: Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	return {
		"samples": values,
		"sample_count": values.size(),
		"median": _nearest_rank(ordered, 0.5),
		"p95": _nearest_rank(ordered, 0.95),
		"min": int(ordered[0]) if not ordered.is_empty() else 0,
		"max": int(ordered[-1]) if not ordered.is_empty() else 0,
	}

static func _nearest_rank(ordered: Array, percentile: float) -> int:
	if ordered.is_empty():
		return 0
	var rank := clampi(int(ceil(percentile * ordered.size())), 1, ordered.size())
	return int(ordered[rank - 1])

func _read_environment() -> void:
	var output := OS.get_environment("CITY_BUILDER_GROUND_CONTACT_PERF_OUTPUT").strip_edges()
	if not output.is_empty():
		_output_path = output
	var save_path := OS.get_environment("CITY_BUILDER_GROUND_CONTACT_REFERENCE_SAVE").strip_edges()
	if not save_path.is_empty():
		_reference_save = save_path
	var phase := OS.get_environment("CITY_BUILDER_GROUND_CONTACT_PHASE").strip_edges()
	if not phase.is_empty():
		_phase = phase
	_force_replace_control = OS.get_environment(
		"CITY_BUILDER_GROUND_CONTACT_FORCE_REPLACE").strip_edges().to_lower() in ["1", "true", "yes"]

func _apply_control_override(manager: Node) -> void:
	if not _force_replace_control:
		return
	var catalog = manager.get_plugin("BuildingCatalog")
	if catalog == null:
		_failures.append("control_catalog_missing")
		return
	for summary_any in catalog.get_summary():
		var summary: Dictionary = summary_any
		summary["ground_treatment"] = "replace"

func _write(payload: Dictionary) -> void:
	var file := FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("ground_contact_performance_write_failed:%s" % _output_path)
		return
	file.store_string(JSON.stringify(payload, "  ", true) + "\n")
	file.close()

func _frames(count: int) -> void:
	for _frame in count:
		await process_frame
