extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

class FakeResidential extends PluginBase:
	var slots: Array = []
	func get_housing_slots() -> Array: return slots

class FakeClock extends PluginBase:
	var absolute := 0
	func current_hour() -> int: return absolute % 24
	func get_absolute_hour() -> int: return absolute

func test_500_residents_for_168_exact_hours_under_ten_seconds() -> void:
	var saved_map := GameState.map
	var saved_structures := GameState.structures
	var saved_registry := GameState.building_registry
	GameState.map = DataMap.new()
	GameState.map.community_schema_version = 1
	GameState.structures = []
	GameState.building_registry = {}
	var residential := FakeResidential.new()
	for id in 500: residential.slots.append({"anchor": Vector2i(id / 10, id % 10), "slot": 0})
	var clock := FakeClock.new()
	var plugin := CommunityPlugin.new()
	plugin._residential = residential
	plugin._clock = clock
	plugin._balance = {
		"quality_baseline": 50.0, "hourly_response_rate": 0.1,
		"migration_hour": 6, "migration_threshold": 60.0, "candidate_batch_size": 4,
		"departure_threshold": 30.0, "departure_grace_hours": 24, "relocation_grace_hours": 24,
		"resident_snapshot_limit": 500, "effect_snapshot_limit": 12, "personality_generation_version": 1,
	}
	plugin._generator = CommunityPersonalityGenerator.new([])
	for id in 500:
		var resident := CommunityResident.new()
		resident.resident_id = id + 1
		resident.home_anchor = Vector2i(id / 10, id % 10)
		plugin._residents[id + 1] = resident
	var started := Time.get_ticks_usec()
	for hour in 168:
		clock.absolute = hour + 1
		plugin._on_hour(float(clock.current_hour()))
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	print("COMMUNITY_SIM_PERF residents=500 hours=168 elapsed_s=%.4f" % elapsed)
	assert_lt(elapsed, 10.0, "500 residents × 168 hours took %.4fs" % elapsed)
	assert_eq(plugin.get_population(), 500)
	plugin.free(); clock.free(); residential.free()
	GameState.map = saved_map
	GameState.structures = saved_structures
	GameState.building_registry = saved_registry
