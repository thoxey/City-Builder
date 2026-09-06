extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

func _walker(resident_id: int) -> PersonSlot:
	var person := PersonSlot.new()
	person.resident_id = resident_id
	person.current_tile = Vector3i.ZERO
	person.position = Vector3(0.45, 0.1, 0.0)
	person.visible = true
	person.state = PersonSlot.VisualState.WALKING_ROUTE
	person.home_anchor = Vector2i.ZERO
	person.current_place = Vector2i.ZERO
	person.destination_anchor = Vector2i(1,0)
	person._waypoint_tiles = [Vector3i(1,0,0)]
	person._waypoints = [Vector3(1,0.1,0)]
	return person

func test_grouped_walkers_replay_distinct_without_authority_changes() -> void:
	var traces: Array[String] = []
	for _repeat in 10:
		var plugin := PeoplePlugin.new()
		for resident_id in [8,3,5,1]:
			plugin._people.append(_walker(resident_id))
		var authoritative_destinations := plugin._people.map(
			func(person): return person.destination_anchor)
		plugin._apply_pedestrian_spacing()
		var rows: Array = plugin.get_pedestrian_spacing_snapshot()
		assert_eq(rows.size(), 4)
		assert_eq(rows.map(func(row): return row["display_position"]).duplicate().reduce(
			func(unique, value): return unique if value in unique else unique + [value], []).size(), 4)
		assert_eq(plugin._people.map(func(person): return person.destination_anchor),
			authoritative_destinations)
		traces.append(JSON.stringify(rows))
		plugin.free()
	assert_eq(traces.duplicate().reduce(func(unique, value): return unique if value in unique else unique + [value], []).size(), 1)
