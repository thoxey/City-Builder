extends SceneTree

func _initialize() -> void:
	call_deferred("_profile")

func _profile() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for _i in 12: await process_frame
	var ui = root.get_node("PluginManager").get_plugin("PlayerUI")
	var before_nodes := _node_count(ui)
	var started := Time.get_ticks_usec()
	ui.open_build_menu()
	var cold_ms := float(Time.get_ticks_usec() - started) / 1000.0
	ui._radial.close_menu()
	started = Time.get_ticks_usec()
	for _i in 100:
		ui.open_build_menu(); ui._radial.close_menu()
	var warm_ms := float(Time.get_ticks_usec() - started) / 100000.0
	ui.open_build_menu()
	started = Time.get_ticks_usec()
	for _i in 1000: ui._radial.move_focus(1)
	var navigation_ms := float(Time.get_ticks_usec() - started) / 1000000.0
	started = Time.get_ticks_usec()
	for _i in 100: ui._refresh_model()
	var refresh_ms := float(Time.get_ticks_usec() - started) / 100000.0
	var node_delta := _node_count(ui) - before_nodes
	print("RADIAL_UI_PERF cold_open_ms=%.3f warm_open_ms=%.3f navigation_ms=%.3f refresh_ms=%.3f node_delta=%d" % [cold_ms, warm_ms, navigation_ms, refresh_ms, node_delta])
	quit()

func _node_count(node: Node) -> int:
	var result := 1
	for child in node.get_children(): result += _node_count(child)
	return result
