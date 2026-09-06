extends SceneTree

const REPORT_PATH := "res://specs/015-transactional-performance/validation/benchmark-rendered.json"
const RUN_COUNT := 3
const WARMUP_FRAMES := 120
const MEASURED_FRAMES := 180
const FRAME_MEDIAN_USEC := 16_700
const FRAME_P95_USEC := 25_000
const FRAME_MAX_USEC := 50_000

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_write({"schema_version":2, "all_passed":false, "failures":["rendered_display_required"]})
		quit(2); return
	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var save_path := "/tmp/city-builder-transactional-reference-town.tres"
	var source_evidence := "/tmp/city-builder-rendered-source.json"
	var child_output: Array = []
	var child_exit := OS.execute("/usr/bin/env", [
		"CITY_BUILDER_REBALANCE_SAVE_PATH=%s" % save_path,
		"CITY_BUILDER_REBALANCE_EVIDENCE_PATH=%s" % source_evidence,
		executable, "--headless", "--path", project_path, "--log-file", "/tmp/city-builder-rendered-source.log",
		"-s", "res://scripts/run_town_rebalance.gd"], child_output, true, false)
	if child_exit != 0:
		_write({"schema_version":2, "all_passed":false, "failures":["reference_town_generation_failed"], "child_exit":child_exit})
		quit(2); return
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12: await process_frame
	var manager = root.get_node("PluginManager")
	var game_state = root.get_node("GameState")
	var builder = current_scene.get_node("Builder")
	var loaded: Dictionary = builder.load_map_from_path(save_path)
	if String(loaded.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
		_write({"schema_version":2, "all_passed":false, "failures":["reference_town_load_failed"], "load_result":loaded})
		quit(2); return
	for _frame in WARMUP_FRAMES: await process_frame
	var monitor = manager.get_plugin("PerformanceMonitor")
	var transaction = manager.get_plugin("SimulationTransaction")
	var people = manager.get_plugin("People")
	var traffic = manager.get_plugin("CarManager")
	var scheduler = manager.get_plugin("PresentationScheduler")
	var community = manager.get_plugin("Community")
	var source := _read_json(source_evidence)
	var runs: Array = []
	var failures: Array[String] = []
	for run_index in RUN_COUNT:
		monitor.clear()
		var frames: Array = []
		var unattributed: Array = []
		for frame_index in MEASURED_FRAMES:
			var before_count: int = monitor.get_samples().size()
			var started := Time.get_ticks_usec()
			await process_frame
			var elapsed := Time.get_ticks_usec() - started
			var samples: Array = monitor.get_samples()
			var attributed := 0
			for index in range(before_count, samples.size()):
				var sample = samples[index]
				if sample.boundary in [&"people.process", &"traffic.process", &"presentation.flush", &"projection.operational", &"projection.diagnostic"]:
					attributed += int(sample.elapsed_usec)
			attributed = mini(attributed, elapsed)
			frames.append(elapsed)
			unattributed.append(elapsed - attributed)
			monitor.record(&"frame.total", elapsed, {"run":run_index + 1}, -1, frame_index)
			monitor.record(&"engine_unattributed", elapsed - attributed, {"run":run_index + 1}, -1, frame_index)
		var workload := {"buildings":game_state.building_registry.size(), "residents":community.get_population() if community else 0,
			"vehicles":traffic._active.size() if traffic else 0, "ui_presenters":scheduler._presenters.size() if scheduler else 0,
			"people_instances":people._people.size() if people else 0}
		var record := build_profile_record(frames, unattributed, workload,
			{"run":run_index + 1, "warmup_frames":WARMUP_FRAMES, "measured_frames":MEASURED_FRAMES,
			"state_hash":source.get("final_summary", {}).get("state_hash", ""),
			"ledger_hash":source.get("transaction", {}).get("ledger_hash", transaction.ledger_hash() if transaction else "")})
		runs.append(record)
		for failure in record.failures: failures.append("run_%d:%s" % [run_index + 1, failure])
	var report := {"schema_version":2, "workload_id":"transactional_reference_town_135x240", "run_count":RUN_COUNT,
		"all_passed":failures.is_empty(), "failures":failures, "runs":runs,
		"environment":{"engine_version":Engine.get_version_info().string, "build_mode":"debug" if OS.is_debug_build() else "release",
			"platform":OS.get_name(), "renderer":RenderingServer.get_current_rendering_method(), "display_server":DisplayServer.get_name()},
		"percentile_rule":"nearest-rank ceil(p*n), one-based", "exclusions":{"load":true, "warmup_frames":WARMUP_FRAMES, "diagnostic_capture":true},
		"reproduce_command":"Godot --path %s -s res://scripts/run_rendered_performance_profile.gd" % project_path}
	_write(report)
	print("RENDERED_PERFORMANCE success=%s runs=%d failures=%s" % [failures.is_empty(), runs.size(), failures])
	quit(0 if failures.is_empty() else 1)

static func build_profile_record(frame_values: Array, unattributed_values: Array,
		workload: Dictionary, metadata: Dictionary) -> Dictionary:
	var ordered := frame_values.duplicate(); ordered.sort()
	var unattr_total := 0
	for value in unattributed_values: unattr_total += int(value)
	var total := 0
	for value in frame_values: total += int(value)
	var median := _nearest_rank(ordered, 0.5)
	var p95 := _nearest_rank(ordered, 0.95)
	var maximum := int(ordered[-1]) if not ordered.is_empty() else 0
	var failures: Array[String] = []
	if median > FRAME_MEDIAN_USEC: failures.append("frame.total:median")
	if p95 > FRAME_P95_USEC: failures.append("frame.total:p95")
	if maximum > FRAME_MAX_USEC: failures.append("frame.total:max")
	var result := {"workload":workload.duplicate(true), "warmup_frames":metadata.get("warmup_frames", 0),
		"measured_frames":metadata.get("measured_frames", frame_values.size()), "run":metadata.get("run", 0),
		"state_hash":metadata.get("state_hash", ""), "ledger_hash":metadata.get("ledger_hash", ""), "failures":failures,
		"passed":failures.is_empty(), "frame_total":{"sample_count":frame_values.size(), "median_usec":median,
			"p95_usec":p95, "max_usec":maximum, "median_fps":1_000_000.0 / float(median) if median > 0 else 0.0},
		"engine_unattributed":{"median_usec":_nearest_rank(unattributed_values, 0.5), "p95_usec":_nearest_rank(unattributed_values, 0.95)},
		"frame_accounting":{"coverage_ratio":1.0 if total > 0 else 0.0, "unattributed_ratio":float(unattr_total) / float(total) if total > 0 else 0.0}}
	return result

static func _nearest_rank(values: Array, percentile: float) -> int:
	if values.is_empty(): return 0
	var ordered := values.duplicate(); ordered.sort()
	var rank := clampi(int(ceil(percentile * ordered.size())), 1, ordered.size())
	return int(ordered[rank - 1])

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _write(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "  ", true) + "\n")
