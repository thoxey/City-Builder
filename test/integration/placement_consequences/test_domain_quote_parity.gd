extends GutTest

const CommunityPluginCls := preload("res://plugins/community/community_plugin.gd")
const AttractivenessPluginCls := preload("res://plugins/attractiveness/attractiveness_plugin.gd")

var saved_map: DataMap
var saved_structures: Array[Structure]
var saved_cells: Dictionary
var saved_registry: Dictionary
var saved_next_id: int

func before_each() -> void:
	saved_map = GameState.map
	saved_structures = GameState.structures
	saved_cells = GameState.cell_to_building.duplicate(true)
	saved_registry = GameState.building_registry.duplicate(true)
	saved_next_id = GameState._next_building_id
	GameState.map = DataMap.new()
	GameState.cell_to_building = {}
	GameState.building_registry = {}
	GameState._next_building_id = 2

func after_each() -> void:
	GameState.map = saved_map
	GameState.structures = saved_structures
	GameState.cell_to_building = saved_cells
	GameState.building_registry = saved_registry
	GameState._next_building_id = saved_next_id

func test_community_exact_quote_matches_committed_before_after_totals() -> void:
	var home: Structure = _home_structure()
	var nature: Structure = _community_structure(5.0, 2)
	GameState.structures = [home, nature]
	GameState.building_registry[1] = {"anchor":Vector2i.ZERO,"structure":0,"orientation":0,"cells":[Vector2i.ZERO]}
	GameState.cell_to_building[Vector2i.ZERO] = 1
	var plugin: Node = CommunityPluginCls.new()
	add_child_autofree(plugin)
	plugin._catalog = autofree(StubCatalog.new(["home", "nature"], ["homes", "nature"]))
	plugin._clock = autofree(StubClock.new())
	plugin._balance = {"town_hall_proximity":{}}
	plugin._residents[1] = CommunityTestFixtures.resident(1, Vector2i.ZERO)
	var resident_before: Dictionary = plugin._residents[1].to_dict(true)
	var registry_before: Dictionary = GameState.building_registry.duplicate(true)
	var totals_before: Dictionary = plugin.get_effect_totals_snapshot()
	var quote: Dictionary = plugin.quote_placement_consequences(1, Vector2i(1, 0))
	assert_eq(GameState.building_registry, registry_before, "quote cannot insert the candidate")
	assert_eq(plugin._residents[1].to_dict(true), resident_before, "quote cannot update resident targets/effects")
	GameState.building_registry[2] = {"anchor":Vector2i(1,0),"structure":1,"orientation":0,"cells":[Vector2i(1,0)]}
	GameState.cell_to_building[Vector2i(1,0)] = 2
	var totals_after: Dictionary = plugin.get_effect_totals_snapshot()
	for quality in CommunityConstants.QUALITIES:
		assert_almost_eq(float(quote.quality_deltas[quality]), float(totals_after[quality]) - float(totals_before[quality]), 0.0001, quality)
	assert_eq(quote.affected_resident_count, 1)
	assert_eq(quote.certainty, "exact")

func test_attractiveness_quote_matches_committed_recompute() -> void:
	var home: Structure = _home_structure()
	var park: Structure = _attractiveness_structure()
	GameState.structures = [home, park]
	GameState.building_registry[1] = {"anchor":Vector2i.ZERO,"structure":0,"orientation":0,"cells":[Vector2i.ZERO]}
	GameState.cell_to_building[Vector2i.ZERO] = 1
	var plugin: Node = AttractivenessPluginCls.new()
	add_child_autofree(plugin)
	plugin._catalog = autofree(StubCatalog.new(["home", "park"], ["homes", "nature"]))
	plugin._buildable = autofree(StubBuildable.new([Vector2i.ZERO, Vector2i(1,0), Vector2i(2,0)]))
	plugin._recompute_emitters_from_registry()
	plugin._recompute()
	var before: int = plugin.city_score()
	var quote: Dictionary = plugin.quote_placement_consequences(1, Vector2i(1,0), [Vector2i(1,0)])
	GameState.building_registry[2] = {"anchor":Vector2i(1,0),"structure":1,"orientation":0,"cells":[Vector2i(1,0)]}
	GameState.cell_to_building[Vector2i(1,0)] = 2
	plugin._recompute_emitters_from_registry()
	plugin._recompute()
	assert_eq(quote.city_delta, plugin.city_score() - before)
	assert_eq(quote.city_delta, 12)
	assert_eq(quote.affected_tile_count, 2)

func test_replacement_quote_models_canonical_home_removal() -> void:
	var home: Structure = _home_structure()
	home.metadata.append(CommunityEffectProfile.from_dict({"effects":[{
		"effect_id":"secure_home","quality":"liveability","manifestation":"neutral",
		"amount":4.0,"scope":"resident","stacking_group":"secure_home",
	}]}))
	var nature: Structure = _community_structure(5.0, 2)
	GameState.structures = [home, nature]
	GameState.building_registry[1] = {"anchor":Vector2i.ZERO,"structure":0,"orientation":0,"cells":[Vector2i.ZERO]}
	GameState.cell_to_building[Vector2i.ZERO] = 1
	var plugin: Node = CommunityPluginCls.new()
	add_child_autofree(plugin)
	plugin._catalog = autofree(StubCatalog.new(["home", "nature"], ["homes", "nature"]))
	plugin._clock = autofree(StubClock.new())
	plugin._balance = {"town_hall_proximity":{}}
	plugin._residents[1] = CommunityTestFixtures.resident(1, Vector2i.ZERO)
	var before: Dictionary = plugin.get_effect_totals_snapshot()
	var quote: Dictionary = plugin.quote_placement_consequences(1, Vector2i.ZERO, [1])
	GameState.building_registry.erase(1)
	GameState.building_registry[2] = {"anchor":Vector2i.ZERO,"structure":1,"orientation":0,"cells":[Vector2i.ZERO]}
	plugin._residents[1].home_anchor = null
	var after: Dictionary = plugin.get_effect_totals_snapshot()
	assert_almost_eq(float(quote.quality_deltas.liveability), float(after.liveability) - float(before.liveability), 0.0001)
	assert_eq(quote.quality_deltas.liveability, -4.0)
	assert_true(quote.affected_residents[0].home_removed)

func test_representative_large_town_quote_median_is_bounded() -> void:
	var home: Structure = _home_structure()
	var source: Structure = _community_structure(2.0, 2)
	GameState.structures = [home, source]
	for i in 135:
		var anchor: Vector2i = Vector2i(i % 15, i / 15)
		GameState.building_registry[i + 1] = {"anchor":anchor,"structure":1,"orientation":0,"cells":[anchor]}
		GameState.cell_to_building[anchor] = i + 1
	GameState._next_building_id = 136
	var plugin: Node = CommunityPluginCls.new()
	add_child_autofree(plugin)
	plugin._catalog = autofree(StubCatalog.new(["home", "nature"], ["homes", "nature"]))
	plugin._clock = autofree(StubClock.new())
	plugin._balance = {"town_hall_proximity":{}}
	for i in 500:
		plugin._residents[i + 1] = CommunityTestFixtures.resident(i + 1, Vector2i(i % 25, i / 25))
	var samples: Array[int] = []
	for _i in 11:
		var started: int = Time.get_ticks_usec()
		plugin.quote_placement_consequences(1, Vector2i(7, 7))
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	var median_ms: float = float(samples[samples.size() / 2]) / 1000.0
	print("[PlacementConsequencesBenchmark] residents=500 sources=135 median_ms=%.3f max_ms=%.3f" % [median_ms, float(samples[-1]) / 1000.0])
	assert_lt(median_ms, 16.0, "500 residents / 135 sources median quote budget")

func _home_structure() -> Structure:
	var structure := Structure.new()
	var profile := BuildingProfile.new()
	profile.category = "residential"
	profile.active_start = 0
	profile.active_end = 0
	structure.metadata = [profile]
	return structure

func _community_structure(amount: float, radius: int) -> Structure:
	var structure := Structure.new()
	structure.metadata = [CommunityEffectProfile.from_dict({"effects":[{
		"effect_id":"local_beauty","quality":"beauty","manifestation":"neutral",
		"amount":amount,"scope":"local","radius":radius,"stacking_group":"green",
	}]})]
	return structure

func _attractiveness_structure() -> Structure:
	var structure := Structure.new()
	var profile := AttractivenessProfile.new()
	profile.base = 2
	profile.residential = 10
	profile.radius = 1
	structure.metadata = [profile]
	return structure

class StubClock extends PluginBase:
	func get_plugin_name() -> String: return "StubClock"
	func current_hour() -> float: return 12.0

class StubCatalog extends PluginBase:
	var ids: Array[String] = []
	var categories: Array[String] = []
	func _init(source_ids: Array[String], source_categories: Array[String]) -> void: ids = source_ids; categories = source_categories
	func get_plugin_name() -> String: return "StubCatalog"
	func get_id_by_index(index: int) -> String: return ids[index] if index >= 0 and index < ids.size() else ""
	func get_summary_by_index(index: int) -> Dictionary: return {"category":categories[index],"community_role":""}

class StubBuildable extends PluginBase:
	var cells: Array = []
	func _init(source: Array) -> void: cells = source.duplicate()
	func get_plugin_name() -> String: return "StubBuildable"
	func allowed_cells() -> Array: return cells.duplicate()
