extends GutTest

const PlaytestPlugin := preload("res://plugins/playtest/playtest_plugin.gd")

class ClockDouble extends PluginBase:
	func get_absolute_hour() -> int: return 8
	func current_hour() -> int: return 8
	func is_manual() -> bool: return true
class CommunityDouble extends PluginBase:
	func get_population() -> int: return 1
	func get_snapshot(_compact := false) -> Dictionary: return {"population":1}
class PeopleDouble extends PluginBase:
	var value := 1
	func get_civilian_snapshot() -> Dictionary:
		return {"pedestrian_spacing":[{"resident_id":value}],"violations":[]}
class CarDouble extends PluginBase:
	var value := 1
	func get_civilian_snapshot() -> Dictionary: return {"violations":[]}
	func get_traffic_flow_snapshot(spacing: Array = []) -> Dictionary:
		return {"schema_version":1,"pending_departure_count":value,
			"active_car_count":0,"waiting_car_count":0,"pending_departures":[],
			"active_journeys":[],"tile_occupancy":[],"pedestrian_spacing":spacing.duplicate(true),
			"violations":[]}

func _plugin() -> Node:
	var plugin := PlaytestPlugin.new()
	plugin._clock = ClockDouble.new()
	plugin._community = CommunityDouble.new()
	plugin._people = PeopleDouble.new()
	plugin._car_manager = CarDouble.new()
	return plugin

func _free_plugin(plugin: Node) -> void:
	plugin._clock.free(); plugin._community.free(); plugin._people.free()
	plugin._car_manager.free(); plugin.free()

func test_traffic_flow_is_appended_after_hash_and_uses_people_spacing() -> void:
	var plugin := _plugin()
	var before: Dictionary = plugin.get_snapshot(false)
	assert_has(before["civilian_simulation"], "traffic_flow")
	assert_eq(before["civilian_simulation"]["traffic_flow"]["pedestrian_spacing"],
		[{"resident_id":1}])
	plugin._people.value = 2
	plugin._car_manager.value = 2
	var after: Dictionary = plugin.get_snapshot(false)
	assert_eq(before["state_hash"], after["state_hash"])
	assert_ne(before["civilian_simulation"]["traffic_flow"],
		after["civilian_simulation"]["traffic_flow"])
	_free_plugin(plugin)

func test_compact_snapshot_omits_traffic_and_no_public_command_was_added() -> void:
	var plugin := _plugin()
	assert_does_not_have(plugin.get_snapshot(true), "civilian_simulation")
	assert_eq(plugin.handle_command("get_traffic_flow", {})["error"]["reason"], "internal_error")
	_free_plugin(plugin)
