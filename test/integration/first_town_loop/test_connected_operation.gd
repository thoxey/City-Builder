extends GutTest

const EVIDENCE_PATH := "res://specs/006-connected-first-town-loop/validation/last-run.json"

func test_full_stack_roadless_connected_and_bridge_states_are_frozen() -> void:
	var evidence := _json(EVIDENCE_PATH)
	assert_true(evidence.get("success", false), "run scripts/run_first_town_loop.gd to refresh full-stack evidence")
	var observations: Dictionary = evidence.get("observations", {})
	var roadless: Dictionary = observations.get("roadless", {})
	var connected: Dictionary = observations.get("connected", {})
	var disconnected: Dictionary = observations.get("disconnected", {})
	assert_eq(_fulfilled(roadless), 0)
	assert_eq(int(roadless.get("economy", {}).get("industrial_output", -1)), 0)
	assert_eq(_reason(roadless), "no_road_access")
	assert_eq(_fulfilled(connected), 1)
	assert_eq(int(connected.get("economy", {}).get("industrial_output", 0)), 1)
	assert_gt(int(connected.get("economy", {}).get("last_hourly_income", 0)), 0)
	assert_eq(int(connected.get("connectivity", {}).get("road_cell_count", 0)), 2)
	assert_eq(_fulfilled(disconnected), 0)
	assert_eq(int(disconnected.get("economy", {}).get("industrial_output", -1)), 0)
	assert_eq(int(disconnected.get("economy", {}).get("last_hourly_income", -1)), 0)
	assert_eq(int(disconnected.get("absolute_hour", -2)), int(connected.get("absolute_hour", 0)) + 1)

func test_connected_trace_records_road_spend_and_cumulative_income() -> void:
	var connected: Dictionary = _json(EVIDENCE_PATH).get("observations", {}).get("connected", {})
	var ledger: Dictionary = connected.get("economy", {}).get("ledger", {})
	assert_eq(int(ledger.get("spend_by_category", {}).get("road", 0)), 4)
	assert_gt(int(ledger.get("cumulative_income", 0)), 0)

func _fulfilled(observation: Dictionary) -> int:
	for record in observation.get("operation", []):
		if String(record.get("building_id", "")) == "building_garage":
			return int(record.get("fulfilled", -1))
	return -1

func _reason(observation: Dictionary) -> String:
	for record in observation.get("operation", []):
		if String(record.get("building_id", "")) == "building_garage":
			return String(record.get("primary_reason", ""))
	return "missing"

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
