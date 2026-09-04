class_name PlaytestReplayRunner
extends RefCounted

static func run(plugin: Object, scenario_id: String, seed: int, actions: Array) -> Dictionary:
	var started: Dictionary = plugin.start_session({"scenario_id": scenario_id, "seed": seed})
	if started.has("error"):
		return started
	var outcomes: Array = []
	for action: Dictionary in actions:
		outcomes.append(plugin.handle_command(action.get("kind", ""), action.get("params", {})))
	return {
		"scenario_id": scenario_id,
		"seed": seed,
		"outcomes": outcomes,
		"trace": plugin.get_trace(),
		"final_snapshot": plugin.get_snapshot(),
	}
