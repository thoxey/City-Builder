extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")
const CatalogPlugin := preload("res://plugins/building_catalog/building_catalog_plugin.gd")

class FakeResidential extends PluginBase:
	var slots: Array = []
	func get_housing_slots() -> Array: return slots.duplicate(true)

class FakeClock extends PluginBase:
	var hour := 21
	var absolute := 15
	func current_hour() -> int: return hour
	func get_absolute_hour() -> int: return absolute

var _saved_map: DataMap
var _saved_structures: Array[Structure]
var _saved_registry: Dictionary
var _catalog: PluginBase
var _residential: FakeResidential
var _clock: FakeClock
var _plugin: Node

func before_each() -> void:
	_saved_map = GameState.map
	_saved_structures = GameState.structures
	_saved_registry = GameState.building_registry
	GameState.map = DataMap.new()
	GameState.map.community_schema_version = 1
	_catalog = CatalogPlugin.new()
	_catalog.ensure_loaded()
	GameState.structures = _catalog.get_all()
	GameState.building_registry = {}
	_residential = FakeResidential.new()
	_residential.slots = [{"anchor": Vector2i.ZERO, "slot": 0}, {"anchor": Vector2i.ZERO, "slot": 1}]
	_clock = FakeClock.new()
	_plugin = CommunityPlugin.new()
	_plugin._catalog = _catalog
	_plugin._residential = _residential
	_plugin._clock = _clock
	_plugin._load_authored_data()

func after_each() -> void:
	_plugin.free()
	_clock.free()
	_residential.free()
	_catalog.free()
	GameState.map = _saved_map
	GameState.structures = _saved_structures
	GameState.building_registry = _saved_registry

func _place(internal_id: int, building_id: String, anchor: Vector2i) -> void:
	GameState.building_registry[internal_id] = {
		"anchor": anchor,
		"structure": _catalog.get_item_index(building_id),
		"orientation": 0,
		"cells": [anchor],
	}

func test_park_and_nightclub_produce_separate_benefit_and_nuisance_effects() -> void:
	_place(1, "building_duck_pond", Vector2i(1, 0))
	_place(2, "building_nightclub", Vector2i(2, 0))
	var resident := CommunityResident.new()
	resident.resident_id = 1
	resident.home_anchor = Vector2i.ZERO
	for quality in CommunityConstants.QUALITIES:
		resident.manifestation_weights[quality] = {"identity": 0.1, "freedom": 0.8, "care": 0.1}
	_plugin._residents = {1: resident}
	var sources: Array = _plugin._source_records(21)
	_plugin._assign_activities(sources)
	var evaluated := CommunityEffectEvaluator.evaluate(resident, sources, {"hour": 21})
	var ids: Array = []
	for effect in evaluated["effects"]: ids.append(effect["effect_id"])
	assert_has(ids, "accessible_recreation")
	assert_has(ids, "shared_greenery")
	assert_has(ids, "compatible_crowd")
	assert_has(ids, "late_music_noise")
	assert_gt(evaluated["totals"]["belonging"], 0.0)
	assert_lt(evaluated["totals"]["liveability"], 0.0)

func test_theatre_programme_changes_identity_and_freedom_response() -> void:
	_place(1, "building_theatre", Vector2i.ZERO)
	var identity := CommunityResident.new()
	identity.resident_id = 1; identity.home_anchor = Vector2i.ZERO
	var freedom := CommunityResident.new()
	freedom.resident_id = 2; freedom.home_anchor = Vector2i.ZERO
	for quality in CommunityConstants.QUALITIES:
		identity.manifestation_weights[quality] = {"identity": 0.8, "freedom": 0.1, "care": 0.1}
		freedom.manifestation_weights[quality] = {"identity": 0.1, "freedom": 0.8, "care": 0.1}
	_plugin._residents = {1: identity, 2: freedom}
	GameState.map.community_programmes["0,0"] = "plays"
	var plays: Array = _plugin._source_records(20)
	_plugin._assign_activities(plays)
	var identity_plays: float = float(CommunityEffectEvaluator.evaluate(identity, plays, {"hour": 20})["totals"]["belonging"])
	var freedom_plays: float = float(CommunityEffectEvaluator.evaluate(freedom, plays, {"hour": 20})["totals"]["belonging"])
	GameState.map.community_programmes["0,0"] = "rock_nights"
	var rock: Array = _plugin._source_records(20)
	_plugin._assign_activities(rock)
	var identity_rock: float = float(CommunityEffectEvaluator.evaluate(identity, rock, {"hour": 20})["totals"]["belonging"])
	var freedom_rock: float = float(CommunityEffectEvaluator.evaluate(freedom, rock, {"hour": 20})["totals"]["belonging"])
	assert_gt(identity_plays, freedom_plays)
	assert_gt(freedom_rock, identity_rock)

func test_snapshot_is_bounded_and_compact_omits_residents() -> void:
	for id in 510:
		var resident := CommunityResident.new()
		resident.resident_id = id + 1
		_plugin._residents[id + 1] = resident
	assert_eq(_plugin.get_snapshot(false)["residents"].size(), 500)
	assert_does_not_have(_plugin.get_snapshot(true), "residents")
	assert_eq(_plugin.get_snapshot(true)["population"], 510)

func test_authored_matched_layout_clears_migration_threshold() -> void:
	_place(1, "building_small_a", Vector2i.ZERO)
	_place(2, "building_duck_pond", Vector2i(1, 0))
	_place(3, "building_nightclub", Vector2i(2, 0))
	var candidate := CommunityResident.new()
	candidate.resident_id = 1
	var quote: Dictionary = _plugin.quote_migration(candidate)
	assert_true(quote.get("ok", false), "authored home + amenity layout should support growth")
	assert_gte(float(quote.get("predicted_happiness", 0.0)), 60.0)
