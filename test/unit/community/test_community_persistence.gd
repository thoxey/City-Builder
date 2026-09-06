extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

class FakeResidential extends PluginBase:
	var slots: Array = []
	func get_housing_slots() -> Array: return slots.duplicate(true)

func _plugin(slots: Array = []) -> CommunityPlugin:
	var plugin := CommunityPlugin.new()
	var residential := FakeResidential.new()
	residential.slots = slots
	plugin._residential = residential
	plugin._balance = {
		"personality_generation_version": 1, "resident_snapshot_limit": 500,
		"effect_snapshot_limit": 12, "sensitivity_min": 0.75, "sensitivity_max": 1.25,
	}
	plugin._cohorts = []
	plugin._generator = CommunityPersonalityGenerator.new([])
	return plugin

func test_persist_and_load_preserve_resident_identity_and_counters() -> void:
	GameState.map = DataMap.new()
	GameState.map.community_schema_version = 1
	var first := _plugin()
	var resident := CommunityResident.new()
	resident.resident_id = 12
	resident.seed = 44
	resident.home_anchor = Vector2i(2, 3)
	resident.below_departure_hours = 7
	resident.current_qualities = {"opportunity": 52.0, "liveability": 63.25, "beauty": 56.5, "belonging": 54.75}
	resident.target_qualities = {"opportunity": 54.0, "liveability": 66.0, "beauty": 58.0, "belonging": 57.0}
	resident.composite_happiness = 56.625
	first._residents[12] = resident
	first._migration = {"arrivals": 2, "departures": 1, "rejections": 3, "last_day": 4}
	first._persist()
	var second := _plugin()
	second._on_map_loaded(GameState.map)
	assert_eq(second.get_population(), 1)
	assert_eq(second._residents[12].home_anchor, Vector2i(2, 3))
	assert_eq(second._residents[12].below_departure_hours, 7)
	assert_eq(second._residents[12].current_qualities, resident.current_qualities)
	assert_eq(second._residents[12].target_qualities, resident.target_qualities)
	assert_eq(second._residents[12].composite_happiness, resident.composite_happiness)
	assert_eq(second._migration["arrivals"], 2)
	first._residential.free(); second._residential.free()
	first.free(); second.free()

func test_legacy_map_seeds_each_housing_slot_once() -> void:
	GameState.map = DataMap.new()
	GameState.map.community_schema_version = 0
	var plugin := _plugin([
		{"anchor": Vector2i.ZERO, "slot": 0},
		{"anchor": Vector2i.ZERO, "slot": 1},
	])
	plugin._on_map_loaded(GameState.map)
	assert_eq(plugin.get_population(), 2)
	assert_eq(GameState.map.community_schema_version, 1)
	plugin._on_map_loaded(GameState.map)
	assert_eq(plugin.get_population(), 2, "migration must not seed twice")
	plugin._residential.free(); plugin.free()

func test_fresh_map_reset_clears_records_and_rng_state() -> void:
	var map := DataMap.new()
	map.community_schema_version = 1
	map.community_residents = []
	map.community_rng_seed = 77
	map.community_rng_state = 0
	GameState.map = map
	var plugin := _plugin()
	plugin._residents[1] = CommunityResident.new()
	plugin._on_map_loaded(map)
	assert_eq(plugin.get_population(), 0)
	assert_eq(plugin._rng.seed, 77)
	plugin._residential.free(); plugin.free()

func test_save_resource_excludes_transient_civilian_projection_fields() -> void:
	var map := DataMap.new()
	var properties := map.get_property_list().map(func(property): return String(property["name"]))
	for transient_name in ["resident_binding","civilian_intent","journey_plan","proxy_position","journey_id","lane_reservations","civilian_simulation","violations"]:
		assert_does_not_have(properties, transient_name)
