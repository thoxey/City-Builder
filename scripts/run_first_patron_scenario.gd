extends SceneTree

const SCENARIO_PATH := "res://test/scenarios/first_patron_reachable.json"
const EVIDENCE_PATH := "res://specs/005-reachable-first-patron/validation/last-run.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12:
		await process_frame
	var scenario := _read_json(SCENARIO_PATH)
	var playtest = root.get_node("PluginManager").get_plugin("Playtest")
	if scenario.is_empty() or playtest == null:
		_fail("scenario_or_playtest_unavailable", {})
		return
	var scenario_id := String(scenario.get("scenario_id", "first_patron_reachable"))
	var seed := int(scenario.get("seed", 5005))
	var started: Dictionary = playtest.start_session({"scenario_id": scenario_id, "seed": seed})
	if started.has("error"):
		_fail("session_start_failed", started)
		return

	var action_records: Array = []
	var failures: Array[String] = []
	for raw_action in scenario.get("actions", []):
		var action: Dictionary = raw_action
		var kind := String(action.get("kind", ""))
		var params: Dictionary = action.get("params", {})
		var outcome: Dictionary = playtest.handle_command(kind, params)
		var expected_status := String(action.get("expected_status", PlaytestActionResult.STATUS_APPLIED))
		var status := String(outcome.get("status", "error"))
		action_records.append({
			"kind": kind,
			"request_id": String(params.get("request_id", "")),
			"status": status,
			"reason": outcome.get("reason"),
			"sequence": int(outcome.get("sequence", -1)),
			"state_hash": String(outcome.get("snapshot", {}).get("state_hash", "")),
		})
		if status != expected_status:
			failures.append("%s expected %s, got %s (%s)" % [
				String(params.get("request_id", kind)), expected_status, status,
				String(outcome.get("reason", "no_reason")),
			])
			break
		var expected_reason := String(action.get("expected_reason", ""))
		if not expected_reason.is_empty() and String(outcome.get("reason", "")) != expected_reason:
			failures.append("%s expected reason %s, got %s" % [
				String(params.get("request_id", kind)), expected_reason, String(outcome.get("reason", "")),
			])
			break

	var final_snapshot: Dictionary = playtest.get_snapshot()
	var milestone_records: Array = playtest.get_progression_milestones()
	var milestone_ids: Array[String] = []
	for record in milestone_records:
		milestone_ids.append(String(record.get("milestone_id", "")))
	var expected_milestones: Array = scenario.get("expected_milestones", [])
	if not _is_ordered_subsequence(expected_milestones, milestone_ids):
		failures.append("Expected ordered milestones %s; observed %s" % [expected_milestones, milestone_ids])
	for condition in scenario.get("success_conditions", []):
		var actual: Variant = _path_value(final_snapshot, String(condition.get("path", "")))
		if actual != condition.get("equals"):
			failures.append("%s expected %s, got %s" % [condition.get("path", ""), condition.get("equals"), actual])
	var absolute_hour := int(final_snapshot.get("simulation", {}).get("absolute_hour", 0))
	if absolute_hour > int(scenario.get("max_hours", 3000)):
		failures.append("Scenario used %d hours; maximum is %d" % [absolute_hour, int(scenario.get("max_hours", 3000))])

	var evidence := {
		"schema_version": int(scenario.get("schema_version", 2)),
		"scenario_id": scenario_id,
		"seed": seed,
		"success": failures.is_empty(),
		"failures": failures,
		"action_count": action_records.size(),
		"actions": action_records,
		"milestones": milestone_records,
		"final": {
			"absolute_hour": absolute_hour,
			"state_hash": final_snapshot.get("state_hash", ""),
			"population": final_snapshot.get("population", {}).duplicate(true),
			"demand": final_snapshot.get("demand", {}).duplicate(true),
			"land": final_snapshot.get("land", {}).duplicate(true),
			"progression": final_snapshot.get("progression", {}).duplicate(true),
		},
	}
	_write_json(_requested_evidence_path(), evidence)
	print("FIRST_PATRON_SCENARIO success=%s actions=%d hours=%d population=%d land=%d hash=%s" % [
		failures.is_empty(), action_records.size(), absolute_hour,
		int(final_snapshot.get("population", {}).get("current", 0)),
		int(final_snapshot.get("land", {}).get("allowed_count", 0)),
		String(final_snapshot.get("state_hash", "")),
	])
	if failures.is_empty():
		quit()
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _requested_evidence_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-path="):
			var path := argument.trim_prefix("--evidence-path=")
			# Determinism runs may retain separate evidence files, but stay inside
			# this feature's validation directory.
			if path.begins_with("res://specs/005-reachable-first-patron/validation/") and path.ends_with(".json") and not path.contains(".."):
				return path
	return EVIDENCE_PATH

func _write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write scenario evidence to %s" % path)
		return
	file.store_string(JSON.stringify(value, "  ", true) + "\n")
	file.close()

func _path_value(value: Variant, path: String) -> Variant:
	var current: Variant = value
	for segment in path.split("."):
		if not current is Dictionary or not current.has(segment):
			return null
		current = current[segment]
	return current

func _is_ordered_subsequence(expected: Array, actual: Array[String]) -> bool:
	var cursor := 0
	for expected_id in expected:
		var found := false
		while cursor < actual.size():
			var actual_id := actual[cursor]
			cursor += 1
			if actual_id == String(expected_id):
				found = true
				break
		if not found:
			return false
	return true

func _fail(reason: String, details: Dictionary) -> void:
	push_error("FIRST_PATRON_SCENARIO %s %s" % [reason, details])
	quit(1)
