extends GutTest

const PlaytestPlugin := preload("res://plugins/playtest/playtest_plugin.gd")

class ClockDouble extends PluginBase:
	func get_absolute_hour() -> int: return 8
	func current_hour() -> int: return 8
	func is_manual() -> bool: return true

class CommunityDouble extends PluginBase:
	func get_population() -> int: return 1
	func get_snapshot(_compact := false) -> Dictionary: return {"population":1}

class CivilianDouble extends PluginBase:
	var progress := 0
	var violations: Array = []
	func get_civilian_snapshot() -> Dictionary: return {"progress":progress,"violations":violations.duplicate(true)}

var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()

func after_each() -> void:
	GameState.map = _saved_map

func _plugin() -> Node:
	var plugin := PlaytestPlugin.new()
	plugin._clock = ClockDouble.new()
	plugin._community = CommunityDouble.new()
	plugin._people = CivilianDouble.new()
	plugin._car_manager = CivilianDouble.new()
	return plugin

func test_civilians_append_after_hash_and_visual_progress_does_not_change_hash() -> void:
	var plugin := _plugin()
	var before: Dictionary = plugin.get_snapshot(false)
	plugin._people.progress = 99
	var after: Dictionary = plugin.get_snapshot(false)
	assert_has(after, "civilian_simulation")
	assert_eq(before["state_hash"], after["state_hash"])
	plugin._clock.free(); plugin._community.free(); plugin._people.free(); plugin._car_manager.free(); plugin.free()

func test_compact_snapshot_omits_civilians() -> void:
	var plugin := _plugin()
	assert_does_not_have(plugin.get_snapshot(true), "civilian_simulation")
	plugin._clock.free(); plugin._community.free(); plugin._people.free(); plugin._car_manager.free(); plugin.free()

func test_no_seventh_public_visual_step_command() -> void:
	var plugin := _plugin()
	assert_eq(plugin.handle_command("step_visual_time", {})["error"]["reason"], "internal_error")
	plugin._clock.free(); plugin._community.free(); plugin._people.free(); plugin._car_manager.free(); plugin.free()

func test_all_required_fault_codes_are_projected_in_stable_order() -> void:
	var plugin := _plugin()
	var codes := ["duplicate_resident_binding","intent_destination_mismatch","unreachable_journey_started",
		"invalid_waypoint_cell","stale_route_revision","missing_car_binding","unexpected_proxy_reset","unexpected_car_cancellation"]
	plugin._people.violations = codes.map(func(code): return {"resident_id":2,"code":code})
	var projected: Array = plugin.get_snapshot(false)["civilian_simulation"]["violations"]
	var expected := codes.duplicate(); expected.sort()
	assert_eq(projected.map(func(row): return row["code"]), expected)
	plugin._clock.free(); plugin._community.free(); plugin._people.free(); plugin._car_manager.free(); plugin.free()
