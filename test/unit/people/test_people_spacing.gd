extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

func _walker(resident_id: int, from: Vector3i, to: Vector3i,
		progress: float) -> PersonSlot:
	var person := PersonSlot.new()
	person.resident_id = resident_id
	person.current_tile = from
	person.position = Vector3(from).lerp(Vector3(to), progress) + Vector3(0, 0.1, 0)
	person.display_position = person.position
	person.visible = true
	person.state = PersonSlot.VisualState.WALKING_ROUTE
	person.home_anchor = Vector2i(from.x, from.z)
	person.current_place = person.home_anchor
	person.destination_anchor = Vector2i(to.x, to.z)
	person.intent = {"resident_id":resident_id,"destination_anchor":{"x":to.x,"z":to.z}}
	person.journey_plan = {"road_path_vectors":[from,to]}
	person._waypoint_tiles = [to]
	person._waypoints = [Vector3(to.x, 0.1, to.z)]
	return person

func test_equal_progress_walkers_receive_stable_distinct_bounded_offsets() -> void:
	var plugin := PeoplePlugin.new()
	plugin._people = [_walker(9,Vector3i.ZERO,Vector3i(1,0,0),0.4),
		_walker(2,Vector3i.ZERO,Vector3i(1,0,0),0.4),
		_walker(5,Vector3i.ZERO,Vector3i(1,0,0),0.4)]
	plugin._apply_pedestrian_spacing()
	var rows: Array = plugin.get_pedestrian_spacing_snapshot()
	assert_eq(rows.map(func(row): return row["resident_id"]), [2,5,9])
	var positions: Array = rows.map(func(row): return row["display_position"])
	assert_eq(positions.duplicate().reduce(func(unique, value): return unique if value in unique else unique + [value], []).size(), 3)
	for position: Dictionary in positions:
		assert_between(float(position["x"]), 0.0, 1.0)
		assert_lte(absf(float(position["z"])), 0.5)
	plugin.free()

func test_same_direction_followers_do_not_pass_the_minimum_gap() -> void:
	var plugin := PeoplePlugin.new()
	plugin._people = [_walker(1,Vector3i.ZERO,Vector3i(1,0,0),0.8),
		_walker(2,Vector3i.ZERO,Vector3i(1,0,0),0.78)]
	plugin._apply_pedestrian_spacing()
	var rows: Array = plugin.get_pedestrian_spacing_snapshot()
	assert_gte(float(rows[0]["limited_progress"]) - float(rows[1]["limited_progress"]),
		0.16)
	plugin.free()

func test_opposite_directions_use_opposite_pavement_relative_positions() -> void:
	var plugin := PeoplePlugin.new()
	plugin._people = [_walker(1,Vector3i.ZERO,Vector3i(1,0,0),0.5),
		_walker(2,Vector3i(1,0,0),Vector3i.ZERO,0.5)]
	plugin._apply_pedestrian_spacing()
	var rows: Array = plugin.get_pedestrian_spacing_snapshot()
	assert_ne(rows[0]["display_position"], rows[1]["display_position"])
	assert_lt(float(rows[0]["display_position"]["z"]) *
		float(rows[1]["display_position"]["z"]), 0.0)
	plugin.free()

func test_spacing_changes_only_transient_display_fields() -> void:
	var plugin := PeoplePlugin.new()
	var person := _walker(4,Vector3i.ZERO,Vector3i(1,0,0),0.5)
	plugin._people = [person]
	var authority := {
		"intent":person.intent.duplicate(true), "plan":person.journey_plan.duplicate(true),
		"waypoints":person._waypoint_tiles.duplicate(), "current_place":person.current_place,
		"destination":person.destination_anchor,
	}
	plugin._apply_pedestrian_spacing()
	assert_eq(person.intent, authority["intent"])
	assert_eq(person.journey_plan, authority["plan"])
	assert_eq(person._waypoint_tiles, authority["waypoints"])
	assert_eq(person.current_place, authority["current_place"])
	assert_eq(person.destination_anchor, authority["destination"])
	plugin.free()

func test_spacing_projection_is_byte_stable_for_identical_inputs() -> void:
	var traces: Array = []
	for _repeat in 2:
		var plugin := PeoplePlugin.new()
		plugin._people = [_walker(7,Vector3i.ZERO,Vector3i(1,0,0),0.6),
			_walker(3,Vector3i.ZERO,Vector3i(1,0,0),0.6)]
		plugin._apply_pedestrian_spacing()
		traces.append(JSON.stringify(plugin.get_pedestrian_spacing_snapshot()))
		plugin.free()
	assert_eq(traces[0], traces[1])
