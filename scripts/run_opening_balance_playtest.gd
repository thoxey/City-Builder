extends SceneTree

const CONFIG_PATH := "res://test/scenarios/first_town/opening_balance.json"
const REPORT_PATH := "res://specs/014-opening-balance-playtest/validation/baseline-report.json"
const Agent := preload("res://scripts/opening_balance_agent.gd")

var _feature_handoffs: Array = []

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
	var feature_019: Dictionary = {}
	if _has_arg("--feature-019"):
		feature_019 = await _feature_019_evidence(manager, playtest, int(requested_seed))
		if not bool(feature_019.get("success", false)):
			failures.append("feature_019:%s" % str(feature_019.get("failures", [])))
	var suite := {"schema_version":1, "scenario_id":fixture.get("scenario_id", ""),
		"config":config, "runs":runs, "replay":replay,
		"aggregate":_aggregate(runs), "all_passed":failures.is_empty(), "failures":failures}
	if not feature_019.is_empty(): suite["feature_019"] = feature_019
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

func _feature_019_evidence(manager: Node, playtest: Node, seed: int) -> Dictionary:
	var failures: Array[String] = []
	var builder := current_scene.find_child("Builder", true, false) if current_scene else null
	var tutorial: Variant = manager.get_plugin("OpeningTutorial") if manager else null
	var community: Variant = manager.get_plugin("Community") if manager else null
	var demand: Variant = manager.get_plugin("Demand") if manager else null
	var uniques: Variant = manager.get_plugin("UniqueRegistry") if manager else null
	var dashboard: Variant = manager.get_plugin("Dashboard") if manager else null
	var catalog: Variant = manager.get_plugin("BuildingCatalog") if manager else null
	var game_events := root.get_node_or_null("GameEvents")
	var game_state := root.get_node_or_null("GameState")
	if [builder, tutorial, community, demand, uniques, dashboard, catalog, game_events, game_state].any(func(node): return node == null):
		return {"success":false, "seed":seed, "failures":["real_stack_unavailable"]}

	_feature_handoffs.clear()
	var handoff_callback := Callable(self, "_on_feature_handoff")
	if not game_events.tutorial_opening_completed.is_connected(handoff_callback):
		game_events.tutorial_opening_completed.connect(handoff_callback)
	var started: Dictionary = playtest.start_session({"scenario_id":"first_town/opening_balance", "seed":seed})
	if started.has("error"):
		failures.append("tutorial_session_start_failed")
		return {"success":false, "seed":seed, "failures":failures}
	await _feature_frames(4)

	var request_index := 0
	request_index += 1
	await _feature_place(playtest, "building_town_hall", Vector2i(-1, -1), request_index, failures)
	for x in range(-1, 7):
		request_index += 1
		await _feature_place(playtest, "road", Vector2i(x, 1), request_index, failures)
	request_index += 1
	await _feature_place(playtest, "road", Vector2i(7, 1), request_index, failures)
	var after_nine := {
		"absolute_hour":_feature_hour(playtest),
		"rooted_road_count":int(tutorial.get_evidence_snapshot().get("rooted_road_count", 0)),
		"receipt_present":tutorial.get_state().get("completed_receipts", {}).has("opening.rooted_roads_connected"),
		"projection_beat":str(tutorial.get_projection().get("beat_id", "")),
	}
	if after_nine.rooted_road_count != 9 or after_nine.receipt_present:
		failures.append("nine_road_boundary_failed")
	request_index += 1
	await _feature_place(playtest, "road", Vector2i(7, 2), request_index, failures)
	var road_receipt: Dictionary = tutorial.get_state().get("completed_receipts", {}).get("opening.rooted_roads_connected", {})
	var after_ten := {
		"absolute_hour":_feature_hour(playtest),
		"rooted_road_count":int(tutorial.get_evidence_snapshot().get("rooted_road_count", 0)),
		"receipt_present":not road_receipt.is_empty(),
		"receipt_count":int(road_receipt.get("evidence", {}).get("count", 0)),
		"projection_beat":str(tutorial.get_projection().get("beat_id", "")),
	}
	if after_ten.rooted_road_count != 10 or after_ten.receipt_count != 10 or after_ten.projection_beat != "B03":
		failures.append("ten_road_boundary_failed")

	for placement in [
		["grass_trees", Vector2i(-7, -7)],
		["grass_trees_tall", Vector2i(-6, -7)],
	]:
		request_index += 1
		await _feature_place(playtest, placement[0], placement[1], request_index, failures)
	request_index += 1
	await _feature_place(playtest, "building_small_a", Vector2i(2, 0), request_index, failures)
	var first_home_hour := _feature_hour(playtest)
	var adjacency_direction := str(tutorial.get_projection().get("text", ""))
	if not adjacency_direction.to_lower().contains("another home"):
		failures.append("adjacency_direction_failed")
	request_index += 1
	await _feature_place(playtest, "building_small_a", Vector2i(3, 0), request_index, failures)
	request_index += 1
	await _feature_place(playtest, "grass_trees", Vector2i(2, -1), request_index, failures)
	request_index += 1
	await _feature_place(playtest, "building_garage", Vector2i(6, 0), request_index, failures)
	community.apply_scenario_fixture({"residents":[{
		"resident_id":1, "seed":seed * 100 + 1, "cohort_id":"general",
		"home_anchor":{"x":2, "z":0},
	}]}, seed)
	var advance: Dictionary = playtest.handle_command("advance", {
		"request_id":"feature-019-advance", "hours":2, "snapshot_mode":"none",
	})
	if str(advance.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
		failures.append("work_shift_advance_failed")
	await _feature_frames(4)
	request_index += 1
	await _feature_place(playtest, "building_small_b", Vector2i(4, 0), request_index, failures)
	var first_shop_hour := _feature_hour(playtest)
	await _feature_frames(4)
	var tutorial_state: Dictionary = tutorial.get_state()
	var dashboard_guidance: Dictionary = dashboard.build_compact_guidance_model(dashboard.snapshot())
	var tutorial_complete := bool(tutorial.is_complete())
	if not tutorial_complete: failures.append("tutorial_not_complete")
	if _feature_handoffs.size() != 1: failures.append("handoff_count_not_one")
	if str(dashboard_guidance.get("kind", "")) != "first_quest": failures.append("first_quest_not_primary")
	if str(dashboard_guidance.get("text", "")).contains("0/100"): failures.append("premature_commercial_prompt")

	# Exercise the data-driven boundary against the live UniqueRegistry. Resetting
	# a demand bucket gives total=current with fulfilled=0, proving these checks do
	# not accidentally depend on spend or current unserved history.
	demand.reset_to_starting_state({"residential":39, "industrial":5, "commercial":14})
	var terrace_39: Dictionary = uniques.evaluate_unlock("building_postwar_terrace")
	var pub_14: Dictionary = uniques.evaluate_unlock("building_pub")
	demand.reset_to_starting_state({"residential":40, "industrial":5, "commercial":15})
	var terrace_40: Dictionary = uniques.evaluate_unlock("building_postwar_terrace")
	var pub_15: Dictionary = uniques.evaluate_unlock("building_pub")
	if bool(terrace_39.get("unlocked", true)) or not bool(terrace_40.get("unlocked", false)):
		failures.append("terrace_39_40_boundary_failed")
	if bool(pub_14.get("unlocked", true)) or not bool(pub_15.get("unlocked", false)):
		failures.append("pub_14_15_boundary_failed")

	# Use the same declared seed for 100 actual player-choice commits. Raising the
	# fixture cash only removes an irrelevant budget cap; it does not touch pool
	# membership or the session RNG.
	started = playtest.start_session({"scenario_id":"first_town/opening_balance", "seed":seed})
	if started.has("error"):
		failures.append("grass_session_start_failed")
	game_state.map.rooted_town_rules = false
	game_state.map.cash = 100000
	var grass_choices: Array = []
	for choice in playtest.get_choices().get("choices", []):
		if str(choice.get("choice_id", "")) == "grass": grass_choices = choice.get("variants", []).duplicate()
	if grass_choices != ["grass_trees", "grass_trees_tall"]:
		failures.append("grass_choice_membership_failed")
	var concrete_grass: Array[String] = []
	var grass_counts := {"grass":0, "grass_trees":0, "grass_trees_tall":0}
	var grass_index := 0
	for x in range(-8, 8):
		for z in range(-8, 8):
			if grass_index >= 100: break
			var outcome: Dictionary = playtest.handle_command("place", {
				"request_id":"feature-019-grass-%03d" % grass_index,
				"choice_id":"grass", "anchor":{"x":x, "z":z}, "snapshot_mode":"none",
			})
			if str(outcome.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
				failures.append("grass_commit_%03d:%s" % [grass_index, str(outcome.get("reason", ""))])
			else:
				var concrete := str(outcome.get("details", {}).get("building_id", ""))
				concrete_grass.append(concrete)
				grass_counts[concrete] = int(grass_counts.get(concrete, 0)) + 1
			grass_index += 1
		if grass_index >= 100: break
	if concrete_grass.size() != 100 or int(grass_counts.grass) != 0 \
			or int(grass_counts.grass_trees) <= 0 or int(grass_counts.grass_trees_tall) <= 0:
		failures.append("grass_seeded_commits_failed")

	if game_events.tutorial_opening_completed.is_connected(handoff_callback):
		game_events.tutorial_opening_completed.disconnect(handoff_callback)
	return {
		"success":failures.is_empty(), "seed":seed,
		"tutorial":{
			"after_nine":after_nine, "after_ten":after_ten,
			"rooted_road_completion_hour":after_ten.absolute_hour,
			"rooted_road_completion_count":after_ten.rooted_road_count,
			"first_home_hour":first_home_hour, "first_shop_hour":first_shop_hour,
			"adjacency_direction":adjacency_direction,
			"complete":tutorial_complete, "handoff_count":_feature_handoffs.size(),
			"handoff":tutorial_state.get("completion_handoff", {}).duplicate(true),
			"dashboard_guidance":dashboard_guidance,
			"state_hash":_feature_hash(_feature_canonical(tutorial_state)),
		},
		"unique_boundaries":{
			"postwar_terrace":{"below":_feature_unlock_record(terrace_39), "at":_feature_unlock_record(terrace_40)},
			"pub":{"below":_feature_unlock_record(pub_14), "at":_feature_unlock_record(pub_15)},
		},
		"grass_pool":{
			"choice_id":"grass", "palette_variants":grass_choices,
			"selection_count":concrete_grass.size(), "counts":grass_counts,
			"selection_hash":_feature_hash(",".join(concrete_grass)),
			"first_twenty":concrete_grass.slice(0, 20),
		},
		"failures":failures,
	}

func _feature_place(playtest: Node, building_id: String, anchor: Vector2i,
		request_index: int, failures: Array[String]) -> Dictionary:
	var outcome: Dictionary = playtest.handle_command("place", {
		"request_id":"feature-019-place-%03d" % request_index,
		"building_id":building_id, "anchor":{"x":anchor.x, "z":anchor.y},
		"snapshot_mode":"none",
	})
	if str(outcome.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
		failures.append("place_%s_%d_%d:%s" % [building_id, anchor.x, anchor.y, str(outcome.get("reason", ""))])
	await _feature_frames(3)
	return outcome

func _feature_unlock_record(value: Dictionary) -> Dictionary:
	return {"current":value.get("current", -1), "threshold":value.get("threshold", -1),
		"unlocked":value.get("unlocked", false), "reasons":value.get("reasons", []).duplicate()}

func _feature_hour(playtest: Node) -> int:
	return int(playtest.get_snapshot(true).get("simulation", {}).get("absolute_hour", -1))

func _on_feature_handoff(payload: Dictionary) -> void:
	_feature_handoffs.append(payload.duplicate(true))

func _feature_frames(count: int) -> void:
	for _frame in count: await process_frame

func _feature_hash(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()

func _feature_canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys(); keys.sort_custom(func(a, b): return str(a) < str(b))
		var pairs: Array[String] = []
		for key in keys: pairs.append("%s:%s" % [JSON.stringify(str(key)), _feature_canonical(value[key])])
		return "{%s}" % ",".join(pairs)
	if value is Array:
		var items: Array[String] = []
		for item in value: items.append(_feature_canonical(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)

func _arg_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

func _has_arg(argument: String) -> bool:
	return argument in OS.get_cmdline_user_args()

func _safe_output(path: String) -> bool:
	var allowed_validation_root := (
		path.begins_with("res://specs/014-opening-balance-playtest/validation/")
		or path.begins_with("res://specs/019-opening-playtest-polish/validation/")
	)
	return allowed_validation_root and path.ends_with(".json") and not path.contains("..")

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
