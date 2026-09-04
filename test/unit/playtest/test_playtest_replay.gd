extends GutTest

const ReplayRunnerCls := preload("res://test/scenarios/run_replay.gd")

func test_repeated_scenario_actions_produce_equivalent_hashes() -> void:
	var actions := [{"kind": "advance", "params": {"request_id": "a", "hours": 24}}]
	var first: Dictionary = ReplayRunnerCls.run(FakeReplay.new(), "fresh_city", 77, actions)
	var second: Dictionary = ReplayRunnerCls.run(FakeReplay.new(), "fresh_city", 77, actions)
	assert_eq(first["final_snapshot"]["state_hash"], second["final_snapshot"]["state_hash"])
	assert_eq(first["trace"], second["trace"])

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
	func get_snapshot() -> Dictionary: return {"state_hash": str(seed) + ":" + str(hours)}
