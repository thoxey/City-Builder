extends GutTest

const ReplayRunnerCls := preload("res://test/scenarios/run_replay.gd")

func test_repeated_scenario_actions_produce_equivalent_hashes() -> void:
	var actions := [{"kind": "advance", "params": {"request_id": "a", "hours": 24}}]
	var first: Dictionary = ReplayRunnerCls.run(FakeReplay.new(), "fresh_city", 77, actions)
	var second: Dictionary = ReplayRunnerCls.run(FakeReplay.new(), "fresh_city", 77, actions)
	assert_eq(first["final_snapshot"]["state_hash"], second["final_snapshot"]["state_hash"])
	assert_eq(first["trace"], second["trace"])

func test_profile_and_snapshot_observability_do_not_change_final_state() -> void:
	var normal_actions := [{"kind": "advance", "params": {
		"request_id": "normal", "hours": 48,
	}}]
	var profiled_actions := [{"kind": "advance", "params": {
		"request_id": "profiled", "hours": 48, "profile": true, "snapshot_mode": "none",
	}}]
	var normal: Dictionary = ReplayRunnerCls.run(FakeReplay.new(), "fresh_city", 6066, normal_actions)
	var profiled: Dictionary = ReplayRunnerCls.run(FakeReplay.new(), "fresh_city", 6066, profiled_actions)
	assert_eq(profiled["final_snapshot"]["state_hash"], normal["final_snapshot"]["state_hash"])
	assert_eq(profiled["final_snapshot"]["hours"], normal["final_snapshot"]["hours"])

class FakeReplay extends RefCounted:
	var seed := 0
	var hours := 0
	var trace: Array = []
	func start_session(params: Dictionary) -> Dictionary:
		seed = params["seed"]
		return {"session": {"status": "ready"}}
	func handle_command(kind: String, params: Dictionary) -> Dictionary:
		hours += int(params.get("hours", 0))
		var outcome := {"kind": kind, "hours": hours, "state_hash": str(seed) + ":" + str(hours)}
		trace.append(outcome)
		return outcome
	func get_trace() -> Array: return trace.duplicate(true)
	func get_snapshot() -> Dictionary: return {"state_hash": str(seed) + ":" + str(hours), "hours": hours}
