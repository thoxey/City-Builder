extends SceneTree

const RUN_COUNT := 3
const SCENARIO_EVIDENCE := "res://specs/006-connected-first-town-loop/validation/rebalance-last-run.json"
const REPORT_PATH := "res://specs/009-performance-foundation/validation/playthrough-report.json"
const EXPECTED_HASH := "4440de04356f95a80c7219dba3718825de1cc1b258adae28a61b7cf735fb2942"
const MAX_SCENARIO_USEC := 45_000_000
const MAX_HOUR_USEC := 500_000

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var suite_started := Time.get_ticks_usec()
	var runs: Array = []
	var failures: Array[String] = []
	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	for run_index in RUN_COUNT:
		var child_output: Array = []
		var started := Time.get_ticks_usec()
		var exit_code := OS.execute(executable, [
			"--headless", "--path", project_path,
			"--log-file", "/tmp/city-builder-performance-playthrough-%d.log" % (run_index + 1),
			"-s", "res://scripts/run_town_rebalance.gd",
		], child_output, true, false)
		var outer_elapsed := Time.get_ticks_usec() - started
		var evidence := _read_json(SCENARIO_EVIDENCE)
		var performance: Dictionary = evidence.get("performance", {})
		var summary: Dictionary = evidence.get("final_summary", {})
		var criteria: Dictionary = evidence.get("criteria", {})
		var run_failures: Array[String] = []
		_check(exit_code == 0, "child_exit_%d" % exit_code, run_failures)
		_check(bool(evidence.get("success", false)), "scenario_failed", run_failures)
		_check(String(summary.get("state_hash", "")) == EXPECTED_HASH, "state_hash_changed", run_failures)
		_check(int(performance.get("scenario_elapsed_usec", MAX_SCENARIO_USEC + 1)) <= MAX_SCENARIO_USEC, "scenario_over_45_seconds", run_failures)
		_check(int(performance.get("max_hour_usec", MAX_HOUR_USEC + 1)) <= MAX_HOUR_USEC, "hour_over_500_milliseconds", run_failures)
		_check(int(criteria.get("meaningful_placements", 0)) >= 60, "insufficient_building_variety", run_failures)
		_check(float(criteria.get("success_rate", 0.0)) >= 0.9, "construction_success_rate", run_failures)
		_check(criteria.get("rooted_failures", []).is_empty(), "unrooted_functional_building", run_failures)
		var run_record := {
			"run": run_index + 1,
			"seed": evidence.get("seed", 0),
			"success": run_failures.is_empty(),
			"failures": run_failures,
			"outer_elapsed_usec": outer_elapsed,
			"scenario_elapsed_usec": performance.get("scenario_elapsed_usec", 0),
			"max_hour_usec": performance.get("max_hour_usec", 0),
			"max_migration_usec": performance.get("max_migration_usec", 0),
			"total_tick_usec": performance.get("total_tick_usec", 0),
			"profiled_snapshot_usec": performance.get("profiled_snapshot_usec", -1),
			"route_cache": performance.get("route_cache", {}),
			"state_hash": summary.get("state_hash", ""),
			"residents": summary.get("population", {}).get("current", 0),
			"total_buildings": summary.get("building_manifest", []).size(),
			"road_cells": summary.get("road_cell_count", 0),
			"meaningful_placements": criteria.get("meaningful_placements", 0),
			"meaningful_attempts": criteria.get("meaningful_attempts", 0),
			"categories": criteria.get("categories", {}),
		}
		runs.append(run_record)
		for failure in run_failures:
			failures.append("run_%d:%s" % [run_index + 1, failure])
		print("PERFORMANCE_PLAYTHROUGH run=%d success=%s scenario_s=%.3f max_hour_ms=%.3f hash=%s" % [
			run_index + 1, run_failures.is_empty(),
			float(performance.get("scenario_elapsed_usec", 0)) / 1_000_000.0,
			float(performance.get("max_hour_usec", 0)) / 1000.0,
			String(summary.get("state_hash", "")),
		])
	var report := {
		"schema_version": 1,
		"scenario_id": "first_town/rebalance",
		"run_count": RUN_COUNT,
		"all_passed": failures.is_empty(),
		"failures": failures,
		"gates": {"max_scenario_usec":MAX_SCENARIO_USEC, "max_hour_usec":MAX_HOUR_USEC, "expected_hash":EXPECTED_HASH},
		"total_elapsed_usec": Time.get_ticks_usec() - suite_started,
		"runs": runs,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ", true) + "\n")
	else:
		failures.append("report_write_failed")
	print("PERFORMANCE_PLAYTHROUGHS success=%s runs=%d failures=%s" % [failures.is_empty(), runs.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _check(condition: bool, failure: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(failure)
