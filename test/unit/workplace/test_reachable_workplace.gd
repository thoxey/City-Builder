extends GutTest

const WorkplacePlugin := preload("res://plugins/workplace/workplace_plugin.gd")

class FakeCityStats extends PluginBase:
	var sources: Array = []
	var sinks: Array = []
	func register_source(source) -> void: sources.append(source)
	func register_sink(sink) -> void: sinks.append(sink)
	func unregister_source(source) -> void: sources.erase(source)
	func unregister_sink(sink) -> void: sinks.erase(sink)

class FakeCommunity extends PluginBase:
	var fulfilled := 0
	func get_fulfilled_workplace(_anchor: Vector2i, _hour: int) -> int: return fulfilled
	func get_operation_records(_hour: int = -1) -> Array:
		return [{"anchor": {"x": 2, "z": 3}, "category": "industrial", "road_accessible": false, "reasons": ["no_road_access"], "primary_reason": "no_road_access"}]

func test_sink_and_output_follow_canonical_reachable_assignments() -> void:
	var stats := FakeCityStats.new()
	var community := FakeCommunity.new()
	var plugin := WorkplacePlugin.new()
	plugin._city_stats = stats
	plugin._community = community
	plugin._register(Vector2i(2, 3), 10, 8.0, 18.0)
	var sink = plugin._worker_sinks[Vector2i(2, 3)]
	assert_eq(sink.tick(10.0), 0)
	community.fulfilled = 4
	assert_eq(sink.tick(10.0), 4)
	sink.on_fulfilled(4, 4)
	assert_eq(plugin.get_total_output(), 4)
	assert_eq(sink.tick(20.0), 0)
	plugin.free(); community.free(); stats.free()

func test_operation_projection_merges_canonical_reason_and_latest_contribution() -> void:
	var stats := FakeCityStats.new()
	var community := FakeCommunity.new()
	var plugin := WorkplacePlugin.new()
	plugin._city_stats = stats
	plugin._community = community
	plugin._register(Vector2i(2, 3), 10, 8.0, 18.0)
	plugin._worker_sinks[Vector2i(2, 3)].on_fulfilled(4, 4)
	var row: Dictionary = plugin.get_operation_records(10)[0]
	assert_false(row["road_accessible"])
	assert_eq(row["primary_reason"], "no_road_access")
	assert_eq(row["reasons"], ["no_road_access"])
	assert_true(row["open_now"])
	assert_eq(row["fulfilled"], 4)
	assert_eq(row["available_capacity"], 6)
	assert_eq(row["latest_output"], 4)
	plugin.free(); community.free(); stats.free()
