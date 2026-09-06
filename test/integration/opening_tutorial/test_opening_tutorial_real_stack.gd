extends GutTest

const RESULT_PREFIX := "OPENING_TUTORIAL_RESULT "
const EXPECTED_RECEIPTS := [
	"opening.adjacent_home_observed",
	"opening.first_home_placed",
	"opening.first_shop_placed",
	"opening.home_improved",
	"opening.nature_established",
	"opening.rooted_roads_connected",
	"opening.town_hall_placed",
	"opening.work_participation_confirmed",
	"opening.workplace_established",
]


func test_real_stack_scenario_isolated_process_completes_and_recovers() -> void:
	# Main initializes process-lifetime singleton plugins. A child process keeps
	# this real-stack proof from contaminating later GUT save/load scripts.
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--log-file", "/tmp/city-builder-opening-tutorial-integration-child.log",
		"-s", "res://scripts/run_opening_tutorial_scenario.gd",
	], output, true)
	assert_eq(exit_code, 0, "child scenario must exit successfully")
	var result := _extract_result("\n".join(output))
	assert_false(result.is_empty(), "child scenario must print its result record")
	assert_true(bool(result.get("success", false)))
	assert_eq(result.get("receipts", []), EXPECTED_RECEIPTS)
	assert_eq(int(result.get("handoff_count", 0)), 1)
	assert_lt(int(result.get("adjacency_home_delta", 0)), 0)
	assert_gt(int(result.get("repair_home_delta", 0)), 0)
	assert_true(bool(result.get("verification", {}).get("early_action_reconciled", false)))
	assert_true(bool(result.get("verification", {}).get("duplicate_reconcile_idempotent", false)))
	assert_true(bool(result.get("verification", {}).get("demolition_non_regression", false)))
	assert_true(bool(result.get("verification", {}).get("cold_load_parity", false)))
	assert_true(bool(result.get("verification", {}).get("legacy_grass_identity", false)))
	assert_true(bool(result.get("verification", {}).get("legacy_grass_inspection_demolition", false)))
	for event_id in [
		"tutorial_opening_beauty_homes",
		"tutorial_opening_home_adjacency",
		"tutorial_opening_work_participation",
		"tutorial_opening_complete",
	]:
		assert_eq(int(result.get("event_counts", {}).get(event_id, 0)), 1, event_id)


func _extract_result(output: String) -> Dictionary:
	for line in output.split("\n"):
		if line.begins_with(RESULT_PREFIX):
			var parsed: Variant = JSON.parse_string(line.trim_prefix(RESULT_PREFIX))
			return parsed if parsed is Dictionary else {}
	return {}
