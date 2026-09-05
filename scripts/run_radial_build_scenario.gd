extends SceneTree

const ReplayRunner := preload("res://test/scenarios/run_replay.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for _i in 12: await process_frame
	var playtest = root.get_node("PluginManager").get_plugin("Playtest")
	var actions := [
		{"kind":"place", "params":{"request_id":"home", "building_id":"residential_t1", "anchor":{"x":-3,"z":-3}}},
		{"kind":"place", "params":{"request_id":"work", "building_id":"industrial_t1", "anchor":{"x":-1,"z":-3}}},
		{"kind":"place", "params":{"request_id":"shop", "building_id":"commercial_t1", "anchor":{"x":1,"z":-3}}},
		{"kind":"advance", "params":{"request_id":"two-days", "hours":48}},
	]
	var result: Dictionary = ReplayRunner.run(playtest, "early_city_baseline", 404, actions)
	var statuses: Array = result.get("outcomes", []).map(func(row): return row.get("status", "error"))
	print("RADIAL_BUILD_SCENARIO statuses=%s sequence=%d hash=%s output=%s" % [statuses, result.get("trace", []).size() - 1, result.get("final_snapshot", {}).get("state_hash", ""), result.get("final_snapshot", {}).get("economy", {}).get("industrial_output", 0)])
	if statuses.any(func(status): return status != "applied"):
		push_error("radial_build_scenario_failed")
		quit(1)
	else:
		quit()
