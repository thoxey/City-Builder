extends GutTest

const SCENARIO_PATH := "res://test/scenarios/first_patron_reachable.json"
const EVIDENCE_PATH := "res://specs/005-reachable-first-patron/validation/last-run.json"

func test_canonical_full_stack_evidence_completes_first_patron() -> void:
	var scenario := _json(SCENARIO_PATH)
	var evidence := _json(EVIDENCE_PATH)
	assert_eq(scenario.get("schema_version"), 2.0)
	assert_eq(scenario.get("seed"), 5005.0)
	assert_gt(scenario.get("actions", []).size(), 100)
	assert_true(evidence.get("success", false), "run scripts/run_first_patron_scenario.gd to refresh full-stack evidence")
	assert_eq(evidence.get("action_count"), scenario.get("actions", []).size())
	assert_lte(int(evidence.get("final", {}).get("absolute_hour", 9999)), int(scenario.get("max_hours", 0)))
	assert_eq(evidence.get("final", {}).get("progression", {}).get("patrons", {}).get("aristocrat", {}).get("state_name"), "COMPLETED")
	assert_true(evidence.get("final", {}).get("progression", {}).get("patrons", {}).get("aristocrat", {}).get("donation_applied", false))
	assert_eq(int(evidence.get("final", {}).get("land", {}).get("allowed_count", 0)), 256)

func test_required_milestones_are_unique_and_ordered() -> void:
	var scenario := _json(SCENARIO_PATH)
	var evidence := _json(EVIDENCE_PATH)
	var observed: Array = evidence.get("milestones", []).map(func(record): return record.get("milestone_id", ""))
	assert_eq(observed.size(), _set_size(observed), "milestones are emitted once")
	var cursor := 0
	for expected in scenario.get("expected_milestones", []):
		var index := observed.find(expected, cursor)
		assert_gte(index, cursor, "missing ordered milestone %s" % expected)
		cursor = index + 1

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _set_size(values: Array) -> int:
	var set := {}
	for value in values: set[value] = true
	return set.size()
