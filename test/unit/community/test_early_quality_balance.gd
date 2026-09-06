extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")
const CatalogPlugin := preload("res://plugins/building_catalog/building_catalog_plugin.gd")

var _saved_map: DataMap
var _saved_structures: Array[Structure]
var _saved_registry: Dictionary
var _catalog: PluginBase
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
	_plugin = CommunityPlugin.new()
	_plugin._catalog = _catalog
	_plugin._load_authored_data()

func after_each() -> void:
	_plugin.free()
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

func _resident(resident_id: int, home: Vector2i) -> CommunityResident:
	var resident := CommunityResident.new()
	resident.resident_id = resident_id
	resident.home_anchor = home
	for quality in CommunityConstants.QUALITIES:
		resident.manifestation_weights[quality] = {"identity": 1.0 / 3.0, "freedom": 1.0 / 3.0, "care": 1.0 / 3.0}
	return resident

func _converge(resident: CommunityResident, sources: Array, hour: int = 12) -> Dictionary:
	var evaluated := CommunityEffectEvaluator.evaluate(resident, sources, {"hour": hour})
	for _step in 24:
		CommunityEffectEvaluator.update_qualities(resident, evaluated, 50.0, 0.1)
	return evaluated

func test_ordinary_mixed_early_town_improves_liveability_beauty_and_belonging() -> void:
	_place(1, "building_small_a", Vector2i.ZERO)
	_place(2, "building_small_c", Vector2i(0, 1))
	_place(3, "building_small_d", Vector2i(1, 0))
	_place(4, "building_nature_patch", Vector2i(2, 0))
	_place(5, "building_small_b", Vector2i(1, 1))
	_place(6, "building_town_hall", Vector2i(4, 0))
	var sources: Array = _plugin._source_records(12)
	var residents := [_resident(1, Vector2i.ZERO), _resident(2, Vector2i(0, 1)), _resident(3, Vector2i(1, 0))]
	# One resident's ordinary daytime activity is the local shop; the unique civic
	# heart and nearby nature still reach all three homes independently.
	for source in sources:
		if source["building_id"] == "building_small_b":
			source["participants"] = [1]
	var averages := {"liveability": 0.0, "beauty": 0.0, "belonging": 0.0}
	for resident in residents:
		_converge(resident, sources)
		for quality in averages:
			averages[quality] += float(resident.current_qualities[quality]) / float(residents.size())
	for quality in averages:
		assert_gt(float(averages[quality]), 50.0, "%s should improve in an ordinary mixed opening town" % quality)
	assert_gt(float(averages["liveability"]), 60.0)
	assert_gt(float(averages["beauty"]), 53.5)
	assert_gt(float(averages["belonging"]), 53.0)

func test_poor_industry_adjacency_reduces_relevant_qualities_with_clear_reasons() -> void:
	_place(1, "building_small_a", Vector2i.ZERO)
	_place(2, "building_garage", Vector2i(1, 0))
	var resident := _resident(1, Vector2i.ZERO)
	resident.sensitivities["noise"] = 1.0
	var poor: Dictionary = _converge(resident, _plugin._source_records(12))
	var negative_ids: Array = poor["effects"].filter(func(effect): return float(effect["applied_amount"]) < 0.0).map(func(effect): return effect["effect_id"])
	# Keep the same buildings but move industry beyond its local nuisance radius:
	# ordinary spatial separation must be enough to recover both affected scores.
	_place(2, "building_garage", Vector2i(3, 0))
	var separated: Dictionary = _converge(_resident(1, Vector2i.ZERO), _plugin._source_records(12))

	assert_has(negative_ids, "garage_noise")
	assert_has(negative_ids, "garage_visual")
	assert_lt(float(poor["totals"]["liveability"]), 20.0, "noise offsets part of secure-home liveability")
	assert_lt(float(poor["totals"]["beauty"]), 0.0, "industrial clutter can lower beauty below baseline")
	assert_gt(float(separated["totals"]["liveability"]), float(poor["totals"]["liveability"]))
	assert_gt(float(separated["totals"]["beauty"]), float(poor["totals"]["beauty"]))
	for effect in poor["effects"]:
		if effect["effect_id"] in ["garage_noise", "garage_visual"]:
			assert_false(String(effect["reason"]).is_empty())

func test_repeated_identical_nature_patches_stop_after_175_percent() -> void:
	var resident := _resident(1, Vector2i.ZERO)
	var effect := CommunityEffectProfile.normalize_effect({
		"effect_id": "wild_greenery", "quality": "beauty", "manifestation": "neutral",
		"amount": 6.0, "scope": "local", "radius": 10,
		"stacking_group": "wild_greenery", "reason": "A familiar patch of wild landscape",
	})
	var sources := []
	for index in 5:
		sources.append({"building_id": "building_nature_patch", "anchor": Vector2i(index, 0), "active": true, "effects": [effect]})
	var evaluated := CommunityEffectEvaluator.evaluate(resident, sources)

	assert_almost_eq(float(evaluated["totals"]["beauty"]), 10.5, 0.0001)
	assert_eq(evaluated["effects"].map(func(row): return row["stacking_multiplier"]), [1.0, 0.5, 0.25, 0.0, 0.0])

func test_authored_early_belonging_sources_match_measured_tuning() -> void:
	_place(1, "building_town_hall", Vector2i.ZERO)
	_place(2, "building_small_b", Vector2i(1, 0))
	var sources: Array = _plugin._source_records(12)
	var hall: Dictionary = sources.filter(func(source): return source["building_id"] == "building_town_hall")[0]
	var shop: Dictionary = sources.filter(func(source): return source["building_id"] == "building_small_b")[0]
	assert_eq(hall["effects"][0]["amount"], 4.0)
	assert_eq(hall["effects"][0]["radius"], 5)
	assert_eq(shop["effects"].filter(func(effect): return effect["effect_id"] == "high_street_encounter")[0]["amount"], 4.0)
