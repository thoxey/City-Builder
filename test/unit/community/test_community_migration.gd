extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

class FakeResidential extends PluginBase:
	var slots: Array = []
	func get_housing_slots() -> Array: return slots.duplicate(true)

func _plugin_with_slots(slots: Array) -> CommunityPlugin:
	var plugin := CommunityPlugin.new()
	var residential := FakeResidential.new()
	residential.slots = slots
	plugin._residential = residential
	plugin._balance = {
		"quality_baseline": 50.0, "migration_threshold": 40.0,
		"departure_threshold": 30.0, "departure_grace_hours": 24,
		"relocation_grace_hours": 24, "resident_snapshot_limit": 500,
		"effect_snapshot_limit": 12, "personality_generation_version": 1,
	}
	plugin._generator = CommunityPersonalityGenerator.new([])
	plugin._rng.seed = 1
	GameState.map = DataMap.new()
	GameState.map.community_schema_version = 1
	GameState.structures = []
	GameState.building_registry = {}
	return plugin

func test_quote_is_non_mutating_and_uses_canonical_home_tie_break() -> void:
	var plugin := _plugin_with_slots([
		{"anchor": Vector2i(4, 0), "slot": 0},
		{"anchor": Vector2i(-2, 1), "slot": 0},
	])
	var candidate := CommunityResident.new()
	candidate.resident_id = 9
	var before := candidate.to_dict()
	var quote := plugin.quote_migration(candidate)
	assert_true(quote["ok"])
	assert_eq(quote["home_anchor"], {"x": -2, "z": 1})
	assert_eq(candidate.to_dict(), before, "migration quote must not mutate candidate")
	plugin._residential.free()
	plugin.free()

func test_no_capacity_and_below_threshold_reject_without_arrival() -> void:
	var plugin := _plugin_with_slots([])
	var candidate := CommunityResident.new()
	assert_eq(plugin.quote_migration(candidate)["reason"], "no_capacity")
	plugin._residential.slots = [{"anchor": Vector2i.ZERO, "slot": 0}]
	plugin._balance["migration_threshold"] = 60.0
	var quote := plugin.quote_migration(candidate)
	assert_false(quote["ok"])
	assert_eq(quote["reason"], "below_threshold")
	assert_eq(plugin.get_population(), 0)
	plugin._residential.free()
	plugin.free()

func test_departure_requires_full_consecutive_grace_period() -> void:
	var plugin := _plugin_with_slots([{"anchor": Vector2i.ZERO, "slot": 0}])
	var resident := CommunityResident.new()
	resident.resident_id = 1
	resident.home_anchor = Vector2i.ZERO
	resident.composite_happiness = 20.0
	plugin._residents[1] = resident
	for _hour in 23: plugin._evaluate_departures()
	assert_eq(plugin.get_population(), 1)
	plugin._evaluate_departures()
	assert_eq(plugin.get_population(), 0)
	plugin._residential.free()
	plugin.free()

func test_recovery_resets_departure_counter() -> void:
	var plugin := _plugin_with_slots([{"anchor": Vector2i.ZERO, "slot": 0}])
	var resident := CommunityResident.new()
	resident.resident_id = 1
	resident.home_anchor = Vector2i.ZERO
	resident.composite_happiness = 20.0
	plugin._residents[1] = resident
	for _hour in 12: plugin._evaluate_departures()
	resident.composite_happiness = 40.0
	plugin._evaluate_departures()
	assert_eq(resident.below_departure_hours, 0)
	plugin._residential.free()
	plugin.free()
