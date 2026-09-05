extends GutTest

const CommercialPlugin := preload("res://plugins/commercial/commercial_plugin.gd")

class FakeCityStats extends PluginBase:
	var sinks: Array = []
	func register_sink(sink) -> void: sinks.append(sink)
	func unregister_sink(sink) -> void: sinks.erase(sink)

class FakeCommunity extends PluginBase:
	var fulfilled := 0
	func get_fulfilled_activity(_anchor: Vector2i, _hour: int) -> int: return fulfilled
	func get_operation_records(_hour: int = -1) -> Array:
		return [{"anchor": {"x": 5, "z": 6}, "category": "commercial", "road_accessible": true, "reasons": [], "primary_reason": ""}]

func test_visitor_sink_requests_only_canonical_reachable_participants() -> void:
	var stats := FakeCityStats.new()
	var community := FakeCommunity.new()
	var plugin := CommercialPlugin.new()
	plugin._city_stats = stats
	plugin._community = community
	plugin._register(Vector2i(5, 6), 10, 8.0, 18.0)
	var sink = plugin._visitor_sinks[Vector2i(5, 6)]
	assert_eq(sink.tick(10.0), 0)
	community.fulfilled = 3
	assert_eq(sink.tick(10.0), 3)
	assert_eq(sink.tick(22.0), 0)
	plugin.free(); community.free(); stats.free()

func test_operation_projection_reports_schedule_capacity_and_activity() -> void:
	var stats := FakeCityStats.new()
	var community := FakeCommunity.new()
	var plugin := CommercialPlugin.new()
	plugin._city_stats = stats
	plugin._community = community
	plugin._register(Vector2i(5, 6), 10, 8.0, 18.0)
	plugin._visitor_sinks[Vector2i(5, 6)].on_fulfilled(3, 3)
	var open_row: Dictionary = plugin.get_operation_records(10)[0]
	assert_true(open_row["road_accessible"])
	assert_true(open_row["open_now"])
	assert_eq(open_row["fulfilled"], 3)
	assert_eq(open_row["available_capacity"], 7)
	assert_eq(open_row["latest_activity"], 3)
	assert_false(plugin.get_operation_records(22)[0]["open_now"])
	plugin.free(); community.free(); stats.free()
