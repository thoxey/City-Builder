extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

class FakeResidential extends PluginBase:
	var slots: Array = []
	func get_housing_slots() -> Array: return slots

class FakeClock extends PluginBase:
	var absolute := 0
	func current_hour() -> int: return absolute % 24
	func get_absolute_hour() -> int: return absolute

class CountingMigrationCommunity extends "res://plugins/community/community_plugin.gd":
	var source_calls := 0
	var quoted_source_counts: Array[int] = []
	var free_slots: Array = [{"anchor": Vector2i.ZERO, "slot": 0}]
	func _source_records(_hour: int) -> Array:
		source_calls += 1
		return []
	func _free_housing_slots() -> Array:
		return free_slots
	func _new_resident(resident_id: int, _forced_cohort: String = "", _explicit_seed: int = 0) -> CommunityResident:
		var resident := CommunityResident.new()
		resident.resident_id = resident_id
		return resident
	func quote_migration(_candidate: CommunityResident, context: Dictionary = {}) -> Dictionary:
		quoted_source_counts.append(context.get("base_sources", []).size())
		return {"ok": false, "reason": "below_threshold"}

class SummaryCommunity extends "res://plugins/community/community_plugin.gd":
	var snapshot_calls := 0
	func get_snapshot(_compact: bool = false) -> Dictionary:
		snapshot_calls += 1
		return {"average_qualities": {}}

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

func test_daily_batch_builds_one_shared_authored_day() -> void:
	var saved_map := GameState.map
	GameState.map = DataMap.new()
	GameState.map.community_next_resident_id = 1
	var plugin := CountingMigrationCommunity.new()
	plugin._balance = {"candidate_batch_size": 4}
	plugin.free_slots.clear()
	for slot_index in 512:
		plugin.free_slots.append({"anchor": Vector2i(slot_index / 16, 0), "slot": slot_index % 16})
	plugin._run_daily_migration()
	assert_eq(plugin.source_calls, 1)
	assert_eq(plugin.quoted_source_counts, [0, 0, 0, 0], "the one mocked catalogue is shared without 24 hourly copies")
	plugin.free()
	GameState.map = saved_map

func test_full_capacity_skips_daily_source_catalogue_work() -> void:
	var saved_map := GameState.map
	GameState.map = DataMap.new()
	var plugin := CountingMigrationCommunity.new()
	plugin._balance = {"candidate_batch_size": 4}
	plugin.free_slots.clear()
	plugin._run_daily_migration()
	assert_eq(plugin.source_calls, 0)
	assert_eq(plugin.quoted_source_counts, [0, 0, 0, 0])
	assert_eq(plugin._migration["rejections"], 4)
	plugin.free()
	GameState.map = saved_map

func test_hourly_summary_does_not_construct_diagnostic_snapshot() -> void:
	var plugin := SummaryCommunity.new()
	plugin._emit_summary()
	assert_eq(plugin.snapshot_calls, 0)
	plugin.free()
