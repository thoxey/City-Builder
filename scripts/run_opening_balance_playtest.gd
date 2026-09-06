extends SceneTree

const CONFIG_PATH := "res://test/scenarios/first_town/opening_balance.json"
const REPORT_PATH := "res://specs/014-opening-balance-playtest/validation/baseline-report.json"
const Agent := preload("res://scripts/opening_balance_agent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture: Dictionary = _read_json(CONFIG_PATH)
	if fixture.is_empty():
		push_error("OPENING_BALANCE fixture unavailable")
		quit(1)
		return
	var requested_seed := _arg_value("--single-seed=")
	if requested_seed.is_empty():
		_run_isolated_suite(fixture)
		return
	var capture_path := _arg_value("--capture=")
	if not capture_path.is_empty(): root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12: await process_frame
	var manager = root.get_node_or_null("PluginManager")
	var playtest = manager.get_plugin("Playtest") if manager else null
	if playtest == null:
		push_error("OPENING_BALANCE Playtest unavailable")
		quit(1)
		return
	var config: Dictionary = fixture.get("strategy", {})
	var primary_seed := int(fixture.get("seed", 14014))
	var seeds: Array = [int(requested_seed)] if not requested_seed.is_empty() else fixture.get("seeds", [primary_seed])
	var runs: Array = []
	for seed in seeds:
		var agent: RefCounted = Agent.new()
		var report: Dictionary = agent.run(playtest, int(seed), config, "seed-%d" % int(seed))
		runs.append(report)
		_print_run(report)
	var replay := {"performed":false, "passed":true, "differences":[]}
	if requested_seed.is_empty():
		var replay_agent: RefCounted = Agent.new()
		var duplicate: Dictionary = replay_agent.run(playtest, primary_seed, config, "primary-replay")
		runs.append(duplicate)
		_print_run(duplicate)
		var primary: Dictionary = runs[0]
		replay = _compare(primary, duplicate)
	var failures: Array = []
	for report in runs:
		if not bool(report.get("success", false)):
			failures.append("%s:%s" % [report.get("run_label", "run"), report.get("failures", [])])
	if not bool(replay.get("passed", false)): failures.append("primary_replay_mismatch:%s" % str(replay.get("differences", [])))
	var suite := {"schema_version":1, "scenario_id":fixture.get("scenario_id", ""),
		"config":config, "runs":runs, "replay":replay,
		"aggregate":_aggregate(runs), "all_passed":failures.is_empty(), "failures":failures}
	var output_path := _arg_value("--evidence-path=")
	if output_path.is_empty(): output_path = REPORT_PATH
	if not _safe_output(output_path) or not _write_json(output_path, suite):
		failures.append("report_write_failed")
		suite["all_passed"] = false
	if not capture_path.is_empty():
		_prepare_capture(manager)
		for _frame in 12: await process_frame
		_prepare_capture(manager)
		await process_frame
		if not _capture(capture_path):
			failures.append("capture_failed")
			suite["all_passed"] = false
	print("OPENING_BALANCE_SUITE success=%s runs=%d replay=%s endpoint_hour=%s idle_hours=%s failures=%s" % [
		suite["all_passed"], runs.size(), replay.get("passed", false),
		runs[0].get("summary", {}).get("elapsed_hours", -1),
		runs[0].get("summary", {}).get("idle_hours", -1), failures])
	quit(0 if bool(suite["all_passed"]) else 1)

func _run_isolated_suite(fixture: Dictionary) -> void:
	var primary_seed := int(fixture.get("seed", 14014))
	var jobs: Array = []
	for seed in fixture.get("seeds", [primary_seed]):
		jobs.append({"seed":int(seed), "label":"seed-%d" % int(seed)})
	jobs.append({"seed":primary_seed, "label":"primary-replay"})
	var runs: Array = []
	var failures: Array = []
	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	for job in jobs:
		var safe_label: String = String(job.label).validate_filename()
		var child_report := "res://specs/014-opening-balance-playtest/validation/isolated-%s.json" % safe_label
		var child_output: Array = []
		var exit_code := OS.execute(executable, ["--headless", "--quiet", "--path", project_path,
			"--log-file", "/tmp/city-builder-opening-%s.log" % safe_label,
			"-s", "res://scripts/run_opening_balance_playtest.gd", "--",
			"--single-seed=%d" % int(job.seed), "--evidence-path=%s" % child_report], child_output, true, false)
		var child_suite := _read_json(child_report)
		if exit_code != 0 or child_suite.is_empty() or child_suite.get("runs", []).is_empty():
			failures.append("%s:child_exit_%d" % [job.label, exit_code])
			continue
		var run: Dictionary = child_suite.runs[0]
		run["run_label"] = job.label
		runs.append(run)
		_print_run(run)
	var replay := {"performed":false, "passed":false, "differences":["missing_primary_run"]}
	if runs.size() == jobs.size(): replay = _compare(runs[0], runs[-1])
	for report in runs:
		if not bool(report.get("success", false)): failures.append("%s:%s" % [report.run_label, report.failures])
	if not bool(replay.get("passed", false)): failures.append("primary_replay_mismatch:%s" % str(replay.get("differences", [])))
	var suite := {"schema_version":1, "scenario_id":fixture.get("scenario_id", ""),
		"config":fixture.get("strategy", {}), "runs":runs, "replay":replay,
		"aggregate":_aggregate(runs), "all_passed":failures.is_empty(), "failures":failures}
	if not _write_json(REPORT_PATH, suite):
		failures.append("report_write_failed")
		suite["all_passed"] = false
	print("OPENING_BALANCE_SUITE success=%s runs=%d replay=%s failures=%s" % [suite.all_passed, runs.size(), replay.get("passed", false), failures])
	quit(0 if bool(suite.all_passed) else 1)

func _compare(first: Dictionary, second: Dictionary) -> Dictionary:
	var differences: Array = []
	if first.get("semantic_trace_hash") != second.get("semantic_trace_hash"): differences.append("semantic_trace_hash")
	if first.get("final", {}).get("state", {}).get("state_hash") != second.get("final", {}).get("state", {}).get("state_hash"): differences.append("final_state_hash")
	if _milestone_hours(first) != _milestone_hours(second): differences.append("milestone_hours")
	if _placed_variants(first) != _placed_variants(second): differences.append("placed_variants")
	return {"performed":true, "passed":differences.is_empty(), "differences":differences,
		"primary_trace_hash":first.get("semantic_trace_hash", ""),
		"replay_trace_hash":second.get("semantic_trace_hash", "")}

func _milestone_hours(report: Dictionary) -> Dictionary:
	var result := {}
	for milestone in report.get("milestones", []): result[milestone.get("milestone_id", "")] = milestone.get("absolute_hour", -1)
	return result

func _placed_variants(report: Dictionary) -> Array:
	var result: Array = []
	for record in report.get("decisions", []):
		if record.get("decision") == "place" and record.get("outcome", {}).get("status") == PlaytestActionResult.STATUS_APPLIED:
			result.append(record.get("outcome", {}).get("details", {}).get("building_id", record.get("request", {}).get("building_id", "")))
	return result

func _aggregate(runs: Array) -> Dictionary:
	var constraint_counts := {}
	var longest_idle := {"seed":0, "hours":-1}
	for report in runs:
		var summary: Dictionary = report.get("summary", {})
		if int(summary.get("idle_hours", 0)) > int(longest_idle.hours):
			longest_idle = {"seed":report.get("seed", 0), "hours":summary.get("idle_hours", 0)}
		for reason in summary.get("resource_constraints", {}):
			constraint_counts[reason] = int(constraint_counts.get(reason, 0)) + int(summary.resource_constraints[reason])
	return {"longest_idle_run":longest_idle, "constraint_counts":constraint_counts,
		"introductory_homes_boosts_for_later_comparison":[0, 5, 10, 15, 20, 25]}

func _print_run(report: Dictionary) -> void:
	print("OPENING_BALANCE_RUN label=%s seed=%d success=%s hours=%s idle=%s actions=%s hash=%s failures=%s" % [
		report.get("run_label", ""), report.get("seed", 0), report.get("success", false),
		report.get("summary", {}).get("elapsed_hours", -1), report.get("summary", {}).get("idle_hours", -1),
		report.get("summary", {}).get("action_count", -1), report.get("semantic_trace_hash", ""), report.get("failures", [])])

func _capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless": return false
	var manager = root.get_node_or_null("PluginManager")
	var dashboard = manager.get_plugin("Dashboard") if manager else null
	if dashboard and dashboard.get("_guidance_view"):
		dashboard.get("_guidance_view").set_suppressed(true)
	var texture := root.get_texture()
	if texture == null: return false
	var image := texture.get_image()
	if image == null: return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return image.save_png(ProjectSettings.globalize_path(path)) == OK and image.get_size() == Vector2i(1280, 720)

func _prepare_capture(manager: Object) -> void:
	var dashboard = manager.get_plugin("Dashboard") if manager else null
	if dashboard and dashboard.has_method("set_collapsed"):
		dashboard.set_collapsed(true)
	if dashboard and dashboard.get("_guidance_view"):
		var guidance = dashboard.get("_guidance_view")
		if guidance.has_method("set_suppressed"):
			guidance.set_suppressed(true)
		else:
			guidance.hide()
	var view = current_scene.get_node_or_null("View") if current_scene else null
	if view:
		view.camera_position = Vector3(-0.5, 0.0, -0.5)
		view.zoom = 25.0

func _arg_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

func _safe_output(path: String) -> bool:
	return path.begins_with("res://specs/014-opening-balance-playtest/validation/") and path.ends_with(".json") and not path.contains("..")

func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return parsed if parsed is Dictionary else {}

func _write_json(path: String, value: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "  ", true) + "\n")
	file.close()
	return true
