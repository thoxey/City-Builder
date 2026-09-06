extends "res://test/unit/builder/test_builder_commands.gd"

const RoadNetwork := preload("res://plugins/traffic/road_network_plugin.gd")

func test_incremental_place_and_demolish_match_full_topology_rebuild() -> void:
	GameState.gridmap = builder.gridmap
	var roads = RoadNetwork.new()
	GameEvents.authoritative_change_committed.connect(roads._on_authoritative_change)
	roads._rebuild()
	assert_eq(builder.try_place_building("road", Vector2i.ZERO).status,
		PlaytestActionResult.STATUS_APPLIED)
	assert_eq(builder.try_place_building("road", Vector2i(1, 0)).status,
		PlaytestActionResult.STATUS_APPLIED)
	var incremental: Dictionary = roads.get_connectivity_snapshot()
	roads._rebuild()
	var rebuilt: Dictionary = roads.get_connectivity_snapshot()
	incremental.erase("revision")
	rebuilt.erase("revision")
	assert_eq(incremental, rebuilt)
	assert_eq(builder.try_demolish_cell(Vector2i(1, 0)).status,
		PlaytestActionResult.STATUS_APPLIED)
	incremental = roads.get_connectivity_snapshot()
	roads._rebuild()
	rebuilt = roads.get_connectivity_snapshot()
	incremental.erase("revision")
	rebuilt.erase("revision")
	assert_eq(incremental, rebuilt)
	GameEvents.authoritative_change_committed.disconnect(roads._on_authoritative_change)
	roads.free()
	GameState.gridmap = null
