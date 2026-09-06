extends GutTest

const PlaytestPlugin := preload("res://plugins/playtest/playtest_plugin.gd")

class ClockDouble extends PluginBase:
	func get_absolute_hour() -> int: return 8
	func current_hour() -> int: return 8
	func is_manual() -> bool: return true
class CommunityDouble extends PluginBase:
	func get_population() -> int: return 1
	func get_snapshot(_compact := false) -> Dictionary: return {"population":1}
class VisualDouble extends PluginBase:
	var value := 0
	func get_civilian_snapshot() -> Dictionary: return {"transient":value,"violations":[]}

func test_all_transient_civilian_changes_are_excluded_from_gameplay_hash() -> void:
	var plugin := PlaytestPlugin.new(); plugin._clock = ClockDouble.new(); plugin._community = CommunityDouble.new(); plugin._people = VisualDouble.new(); plugin._car_manager = VisualDouble.new()
	var before: String = plugin.get_snapshot(false)["state_hash"]
	plugin._people.value = 99; plugin._car_manager.value = 101
	assert_eq(plugin.get_snapshot(false)["state_hash"],before)
	assert_does_not_have(plugin.get_snapshot(true),"civilian_simulation")
	plugin._clock.free(); plugin._community.free(); plugin._people.free(); plugin._car_manager.free(); plugin.free()
