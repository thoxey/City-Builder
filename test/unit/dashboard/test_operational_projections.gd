extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

class OperationalCommunity extends "res://plugins/community/community_plugin.gd":
	var diagnostics := 0
	func get_resident_records(_include_effects: bool = true) -> Array:
		diagnostics += 1
		return []

func test_community_operational_projection_never_builds_resident_diagnostics() -> void:
	var community := OperationalCommunity.new()
	for resident_id in 8:
		var resident := CommunityResident.new()
		resident.resident_id = resident_id + 1
		community._add_resident(resident)
	var projection: Dictionary = community.get_operational_snapshot()
	assert_eq(projection.population, 8)
	assert_eq(community.diagnostics, 0)
	projection.population = 999
	assert_eq(community.get_operational_snapshot().population, 8)
	community.free()
