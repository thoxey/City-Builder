extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")
const CatalogPlugin := preload("res://plugins/building_catalog/building_catalog_plugin.gd")

class CommunityDouble extends "res://plugins/community/community_plugin.gd":
	func _route_to_source(_resident: CommunityResident, _source_id: int) -> Dictionary:
		return {"reachable":true,"distance":3,"reason":""}

class ClockDouble extends PluginBase:
	var hour := 17
	func current_hour() -> int: return hour
	func get_absolute_hour() -> int: return hour

func test_existing_pub_visit_and_same_hour_theatre_change_are_authoritative() -> void:
	var saved_map := GameState.map; var saved_structures := GameState.structures; var saved_registry := GameState.building_registry
	GameState.map = DataMap.new(); GameState.map.community_schema_version = 1
	var catalog := CatalogPlugin.new(); catalog.ensure_loaded(); GameState.structures = catalog.get_all()
	GameState.building_registry = {
		1:{"anchor":Vector2i.ZERO,"structure":catalog.get_item_index("building_small_a"),"cells":[Vector2i.ZERO]},
		2:{"anchor":Vector2i(3,0),"structure":catalog.get_item_index("building_pub"),"cells":[Vector2i(3,0)]},
		3:{"anchor":Vector2i(6,0),"structure":catalog.get_item_index("building_theatre"),"cells":[Vector2i(6,0)]},
	}
	var plugin := CommunityDouble.new(); var clock := ClockDouble.new(); plugin._catalog = catalog; plugin._clock = clock
	var resident := CommunityResident.new(); resident.resident_id = 1; resident.home_anchor = Vector2i.ZERO
	for quality in CommunityConstants.QUALITIES: resident.quality_importance[quality] = 0.25
	plugin._residents = {1:resident}
	plugin._assign_residents(plugin._source_records(17),17,true)
	assert_eq(plugin.get_civilian_intent(1)["purpose"],"activity")
	assert_eq(plugin.get_civilian_intent(1)["destination_building_id"],"building_pub")
	var before := plugin.get_assignment_revision(); assert_true(plugin.set_programme(Vector2i(6,0),"community_use")); assert_gt(plugin.get_assignment_revision(),before)
	clock.free(); plugin.free(); catalog.free(); GameState.map = saved_map; GameState.structures = saved_structures; GameState.building_registry = saved_registry
