extends SceneTree

const RUN_COUNT := 3
const FIXTURE_PATH := "res://test/fixtures/performance/transactional_reference_town.json"
const REPORT_PATH := "res://specs/015-transactional-performance/validation/benchmark-headless.json"
const MAX_SCENARIO_USEC := 35_000_000
const P95_HOUR_USEC := 16_700
const MAX_HOUR_USEC := 33_300

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var suite_started := Time.get_ticks_usec()
	var fixture := _read_json(FIXTURE_PATH)
	var expected: Dictionary = fixture.get("expected", {})
	var runs: Array = []
	var failures: Array[String] = []
	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	for run_index in RUN_COUNT:
		var evidence_path := "/tmp/city-builder-transactional-performance-%d.json" % (run_index + 1)
		var child_output: Array = []
		var started := Time.get_ticks_usec()
		var exit_code := OS.execute("/usr/bin/env", [
			"CITY_BUILDER_REBALANCE_EVIDENCE_PATH=%s" % evidence_path,
			executable, "--headless", "--path", project_path,
			"--log-file", "/tmp/city-builder-transactional-performance-%d.log" % (run_index + 1),
			"-s", "res://scripts/run_town_rebalance.gd",
		], child_output, true, false)
		var outer_elapsed := Time.get_ticks_usec() - started
		var evidence := _read_json(evidence_path)
		var performance: Dictionary = evidence.get("performance", {})
		var summary: Dictionary = evidence.get("final_summary", {})
		var criteria: Dictionary = evidence.get("criteria", {})
		var transaction: Dictionary = evidence.get("transaction", {})
		var run_failures: Array[String] = []
		_check(exit_code == 0, "child_exit_%d" % exit_code, run_failures)
		_check(bool(evidence.get("success", false)), "scenario_failed", run_failures)
		_check(String(summary.get("state_hash", "")) == String(expected.get("state_hash", "")), "state_hash_changed", run_failures)
		_check(int(performance.get("scenario_elapsed_usec", MAX_SCENARIO_USEC + 1)) <= MAX_SCENARIO_USEC, "scenario_over_35_seconds", run_failures)
		_check(int(performance.get("p95_hour_usec", P95_HOUR_USEC + 1)) <= P95_HOUR_USEC, "hour_p95_over_16_7_milliseconds", run_failures)
		_check(int(performance.get("max_hour_usec", MAX_HOUR_USEC + 1)) <= MAX_HOUR_USEC, "hour_max_over_33_3_milliseconds", run_failures)
		_check(summary.get("building_manifest", []).size() == int(expected.get("buildings", -1)), "building_count_changed", run_failures)
		_check(int(summary.get("population", {}).get("current", -1)) == int(expected.get("residents", -2)), "resident_count_changed", run_failures)
		_check(int(criteria.get("meaningful_placements", 0)) >= int(expected.get("meaningful_placements", 60)), "insufficient_building_variety", run_failures)
		_check(not String(transaction.get("ledger_hash", "")).is_empty(), "ledger_hash_missing", run_failures)
		var run_record := {
			"run":run_index + 1, "seed":evidence.get("seed", 0), "success":run_failures.is_empty(), "failures":run_failures,
			"outer_elapsed_usec":outer_elapsed, "scenario_elapsed_usec":performance.get("scenario_elapsed_usec", 0),
			"hour_total":{"sample_count":performance.get("hour_sample_count", 0), "median_usec":performance.get("median_hour_usec", 0),
				"p95_usec":performance.get("p95_hour_usec", 0), "max_usec":performance.get("max_hour_usec", 0),
				"max_migration_usec":performance.get("max_migration_usec", 0)},
			"community_boundaries":performance.get("community_boundaries", {}),
			"state_hash":summary.get("state_hash", ""), "ledger_hash":transaction.get("ledger_hash", ""),
			"workload":{"buildings":summary.get("building_manifest", []).size(), "residents":summary.get("population", {}).get("current", 0),
				"road_cells":summary.get("road_cell_count", 0), "hours":performance.get("hour_sample_count", 0),
				"meaningful_placements":criteria.get("meaningful_placements", 0)},
		}
		runs.append(run_record)
		for failure in run_failures: failures.append("run_%d:%s" % [run_index + 1, failure])
		print("PERFORMANCE_PLAYTHROUGH run=%d success=%s scenario_s=%.3f p95_hour_ms=%.3f max_hour_ms=%.3f" % [run_index + 1,
			run_failures.is_empty(), float(performance.get("scenario_elapsed_usec", 0)) / 1_000_000.0,
			float(performance.get("p95_hour_usec", 0)) / 1000.0, float(performance.get("max_hour_usec", 0)) / 1000.0])
	var hashes_match := _same_field(runs, "state_hash")
	var ledgers_match := _same_field(runs, "ledger_hash")
	if not hashes_match: failures.append("equivalent_runs:state_hash_mismatch")
	if not ledgers_match: failures.append("equivalent_runs:ledger_hash_mismatch")
	var report := {
		"schema_version":2, "workload_id":fixture.get("workload_id", ""), "scenario_id":fixture.get("scenario_id", ""),
		"run_count":RUN_COUNT, "all_passed":failures.is_empty(), "failures":failures,
		"environment":{"engine_version":Engine.get_version_info().string, "build_mode":"debug" if OS.is_debug_build() else "release",
			"platform":OS.get_name(), "renderer":RenderingServer.get_current_rendering_method()},
		"percentile_rule":"nearest-rank ceil(p*n), one-based", "exclusions":["scene load", "explicit diagnostic capture"],
		"gates":{"scenario_each_run_usec":MAX_SCENARIO_USEC, "hour_p95_usec":P95_HOUR_USEC, "hour_max_usec":MAX_HOUR_USEC,
			"expected_state_hash":expected.get("state_hash", "")},
		"equivalence":{"state_hashes_match":hashes_match, "ledger_hashes_match":ledgers_match},
		"reproduce_command":"Godot --headless --path %s -s res://scripts/run_performance_playthroughs.gd" % project_path,
		"total_elapsed_usec":Time.get_ticks_usec() - suite_started, "runs":runs,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "  ", true) + "\n")
	else: failures.append("report_write_failed")
	print("PERFORMANCE_PLAYTHROUGHS success=%s runs=%d failures=%s" % [failures.is_empty(), runs.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _same_field(runs: Array, field: String) -> bool:
	if runs.is_empty() or String(runs[0].get(field, "")).is_empty(): return false
	var expected := String(runs[0][field])
	return runs.all(func(row): return String(row.get(field, "")) == expected)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _check(condition: bool, failure: String, failures: Array[String]) -> void:
	if not condition: failures.append(failure)
