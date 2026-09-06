extends GutTest

const Agent := preload("res://scripts/opening_balance_agent.gd")

func test_endpoint_requires_lifetime_total_and_unlocked_gate() -> void:
	var config := {"endpoint_building_id":"building_postwar_midblock", "endpoint_total_homes":75}
	var snapshot := _snapshot(75, true)
	assert_true(Agent.endpoint_reached(snapshot, config))
	snapshot["demand"]["residential"]["total"] = 74.9
	assert_false(Agent.endpoint_reached(snapshot, config))
	snapshot = _snapshot(75, false)
	assert_false(Agent.endpoint_reached(snapshot, config))

func test_state_delta_reports_hours_resources_demand_and_beauty() -> void:
	var before := Agent.state_slice(_snapshot(25, false, 2, 1000, 200))
	var after := Agent.state_slice(_snapshot(26, false, 3, 990, 190))
	var delta := Agent.state_delta(before, after)
	assert_eq(delta.hours, 1)
	assert_eq(delta.cash, -10.0)
	assert_eq(delta.beauty, -10.0)
	assert_eq(delta.demand.residential.total, 1.0)

func test_wait_blockers_explain_endpoint_and_current_total() -> void:
	var config := {"endpoint_building_id":"building_postwar_midblock", "endpoint_total_homes":75}
	var choices := [{"variants":["building_postwar_midblock"], "available":false, "reasons":["below_demand_threshold"]}]
	var blockers := Agent.wait_blockers(_snapshot(42, false), choices, config)
	assert_has(blockers, "endpoint:below_demand_threshold")
	assert_has(blockers, "residential_total:42.0/75.0")

func test_summary_counts_only_explicit_one_hour_waits() -> void:
	var records := [
		_record("advance", 1, ["residential_total:25.0/75.0"]),
		_record("place", 0, []),
		_record("advance", 1, ["residential_total:26.0/75.0"]),
	]
	var summary := Agent.summarize(records, _snapshot(27, false, 2), {"beauty_floor":200, "endpoint_building_id":"building_postwar_midblock", "endpoint_total_homes":75})
	assert_eq(summary.idle_hours, 2)
	assert_eq(summary.action_count, 3)
	assert_eq(summary.wait_spans.size(), 2)
	assert_eq(summary.wait_spans[0].hours, 1)
	assert_eq(summary.wait_spans[1].hours, 1)
	assert_eq(summary.minimum_after_floor_established, 200)
	assert_eq(summary.resource_constraints["residential_total:25.0/75.0"], 1)

func _snapshot(homes_total: float, unlocked: bool, hour := 0, cash := 1000, beauty := 200) -> Dictionary:
	return {"sequence":hour, "simulation":{"absolute_hour":hour}, "economy":{"cash":cash},
		"attractiveness":{"total":beauty}, "demand":{
			"residential":{"total":homes_total,"fulfilled":0.0,"unserved":homes_total},
			"industrial":{"total":5.0,"fulfilled":0.0,"unserved":5.0},
			"commercial":{"total":5.0,"fulfilled":0.0,"unserved":5.0}},
		"buildings":[], "progression":{"story_buildings":{"building_postwar_midblock":{"unlocked":unlocked,"reasons":[] if unlocked else ["below_demand_threshold"]}}},
		"available_choice_count":1, "state_hash":"h%d" % hour}

func _record(kind: String, hours: int, blockers: Array) -> Dictionary:
	return {"index":0, "decision":kind, "absolute_hour":hours, "blockers":blockers,
		"outcome":{"status":"applied"}, "delta":{"hours":hours,"cash":0.0,"beauty":0.0,"buildings":0,
			"demand":{"residential":{"total":float(hours),"fulfilled":0.0,"unserved":float(hours)},
				"industrial":{"total":0.0,"fulfilled":0.0,"unserved":0.0},
				"commercial":{"total":0.0,"fulfilled":0.0,"unserved":0.0}}},
		"before":{"absolute_hour":0, "beauty":200}, "after":{"absolute_hour":hours, "beauty":200}}
