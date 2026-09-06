extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

class FakeClock extends PluginBase:
	var absolute_hour := 8
	func current_hour() -> int: return absolute_hour % 24
	func get_absolute_hour() -> int: return absolute_hour

func _resident(id: int, home: Vector2i, seed: int) -> CommunityResident:
	var resident := CommunityResident.new()
	resident.resident_id = id
	resident.home_anchor = home
	resident.seed = seed
	return resident

func test_intents_are_stably_ordered_and_detached() -> void:
	var plugin := CommunityPlugin.new()
	plugin._clock = FakeClock.new()
	plugin._residents = {9: _resident(9, Vector2i(9, 0), 99), 2: _resident(2, Vector2i(2, 0), 22)}
	var intents: Array = plugin.get_civilian_intents()
	assert_eq(intents.map(func(row): return row["resident_id"]), [2, 9])
	intents[0]["home_anchor"]["x"] = 500
	assert_eq(plugin.get_civilian_intent(2)["home_anchor"], {"x": 2, "z": 0})
	plugin._clock.free()
	plugin.free()

func test_work_precedes_activity_and_home_is_fallback() -> void:
	var plugin := CommunityPlugin.new()
	plugin._clock = FakeClock.new()
	var resident := _resident(3, Vector2i.ZERO, 33)
	resident.activity_assignment = {"purpose":"activity", "anchor":{"x":4,"z":0}, "building_id":"pub", "route_distance":4}
	resident.work_assignment = {"purpose":"work", "anchor":{"x":7,"z":0}, "building_id":"garage", "route_distance":7}
	plugin._residents = {3: resident}
	assert_eq(plugin.get_civilian_intent(3)["purpose"], "work")
	resident.work_assignment = null
	assert_eq(plugin.get_civilian_intent(3)["purpose"], "activity")
	resident.activity_assignment = null
	assert_eq(plugin.get_civilian_intent(3)["purpose"], "home")
	plugin._clock.free()
	plugin.free()

func test_invalidation_is_monotonic_even_within_same_hour() -> void:
	var plugin := CommunityPlugin.new()
	var before: int = plugin.get_assignment_revision()
	plugin._invalidate_assignments()
	var after_first: int = plugin.get_assignment_revision()
	plugin._invalidate_assignments()
	assert_gt(after_first, before)
	assert_gt(plugin.get_assignment_revision(), after_first)
	plugin.free()

func test_cached_hour_consumes_changed_assignment_ids_once() -> void:
	var plugin := CommunityPlugin.new()
	plugin._clock = FakeClock.new()
	plugin.compiled_evaluator_enabled = false
	plugin._balance = {"migration_hour": 6, "quality_baseline": 50.0, "hourly_response_rate": 0.1}
	plugin._migration = {"last_day": 0}
	plugin._changed_assignment_resident_ids.assign([7, 9])
	var cache_key := plugin._assignment_fast_key(8)
	plugin._assignment_prepared_hour_key = cache_key
	plugin._hour_source_cache_key = cache_key
	plugin._hour_source_cache = []
	plugin._on_hour(8.0)
	assert_eq(plugin.get_changed_civilian_ids(), [], "a cached hour must not replay the previous assignment delta")
	plugin._clock.free()
	plugin.free()
