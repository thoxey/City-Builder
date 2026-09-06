extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

class CommunityDouble extends "res://plugins/community/community_plugin.gd":
	var route_connected := true
	func _route_to_source(_resident_value: CommunityResident, _source_id: int) -> Dictionary:
		return {"reachable":route_connected,"distance":3}

class RoadDouble extends PluginBase:
	var connected := true
	func get_revision() -> int: return 1
	func get_route_between_buildings(_origin: int, _destination: int) -> Dictionary:
		return {"reachable":connected,"distance":3,"reason":"" if connected else "isolated_road_component"}

class ClockDouble extends PluginBase:
	var hour := 20
	func current_hour() -> int: return hour
	func get_absolute_hour() -> int: return hour

func _resident(id: int) -> CommunityResident:
	var resident := CommunityResident.new(); resident.resident_id = id; resident.home_anchor = Vector2i.ZERO
	for quality in CommunityConstants.QUALITIES: resident.quality_importance[quality] = 0.25
	return resident

func _source(capacity: int) -> Dictionary:
	return {"internal_id":2,"building_id":"venue","anchor":Vector2i(3,0),"active":true,"category":"commercial","capacity":capacity,"participants":[],"effects":[{"effect_id":"visit","quality":"belonging","manifestation":"care","amount":1.0,"scope":"participant","capacity":capacity,"schedule":{"start":18,"end":2},"stacking_group":"visit","reason":"Visited"}]}

func test_connected_capacity_is_respected_and_disconnected_gets_none() -> void:
	var plugin := CommunityDouble.new(); var roads := RoadDouble.new(); plugin._road_network = roads; plugin._clock = ClockDouble.new()
	plugin._residents = {1:_resident(1),2:_resident(2),3:_resident(3)}
	var sources: Array = [_source(2)]; plugin._assign_residents(sources,20,true)
	assert_eq(sources[0]["participants"].size(),2)
	plugin.route_connected = false; plugin._assign_residents(sources,20,true); assert_true(sources[0]["participants"].is_empty())
	plugin._clock.free(); roads.free(); plugin.free()
