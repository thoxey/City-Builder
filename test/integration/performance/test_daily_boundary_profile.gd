extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")
const DayNightPlugin := preload("res://plugins/day_night/day_night_plugin.gd")

class FakeResidential extends PluginBase:
	var slots: Array = []
	func get_housing_slots() -> Array: return slots.duplicate(true)

var _saved_map: DataMap
var _saved_structures: Array[Structure]
var _saved_registry: Dictionary

func before_each() -> void:
	_saved_map = GameState.map
	_saved_structures = GameState.structures
	_saved_registry = GameState.building_registry
	GameState.map = DataMap.new()
	GameState.map.community_schema_version = 1
	GameState.structures = []
	GameState.building_registry = {}

func after_each() -> void:
	GameState.map = _saved_map
	GameState.structures = _saved_structures
	GameState.building_registry = _saved_registry

func test_profiled_five_to_six_boundary_runs_real_migration_batch_without_stall() -> void:
	var clock := DayNightPlugin.new()
	clock._time = 5.0 / 24.0
	clock._last_hour = 5
	var residential := FakeResidential.new()
	for index in 60:
		residential.slots.append({"anchor":Vector2i(index, 0), "slot":0})
	var community := CommunityPlugin.new()
	community._clock = clock
	community._residential = residential
	community._balance = {
		"quality_baseline":50.0,"hourly_response_rate":0.1,"migration_hour":6,
		"migration_threshold":60.0,"candidate_batch_size":20,"departure_threshold":30.0,
		"departure_grace_hours":24,"relocation_grace_hours":24,"resident_snapshot_limit":500,
		"effect_snapshot_limit":12,"personality_generation_version":1,
	}
	community._generator = CommunityPersonalityGenerator.new([])
	for index in 50:
		var resident := CommunityResident.new()
		resident.resident_id = index + 1
		resident.home_anchor = Vector2i(index, 0)
		community._residents[resident.resident_id] = resident
	clock.hour_changed.connect(community._on_hour)
	var outcome: Dictionary = clock.advance_hours(1, true)
	var performance: Dictionary = outcome["details"]["performance"]
	assert_eq(clock.current_hour(), 6)
	assert_eq(performance["hour_timings"].size(), 1)
	assert_true(performance["hour_timings"][0]["migration_boundary"])
	assert_lt(performance["max_hour_usec"], 500_000)
	assert_eq(community.get_population(), 50)
	assert_eq(community._migration["rejections"], 20)
	community.free()
	residential.free()
	clock.free()
