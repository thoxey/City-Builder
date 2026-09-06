extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

func test_persistent_exact_spacing_overlap_is_diagnosed() -> void:
	var plugin := PeoplePlugin.new()
	plugin._pedestrian_spacing = [
		{"resident_id":1,"from_tile":{"x":0,"y":0,"z":0},"to_tile":{"x":1,"y":0,"z":0},
			"display_position":{"x":0.5,"y":0.1,"z":0.38}},
		{"resident_id":2,"from_tile":{"x":0,"y":0,"z":0},"to_tile":{"x":1,"y":0,"z":0},
			"display_position":{"x":0.5,"y":0.1,"z":0.38}},
	]
	var snapshot: Dictionary = plugin.get_civilian_snapshot()
	assert_has(snapshot["violations"].map(func(row): return row["code"]),
		"persistent_pedestrian_overlap")
	plugin.free()

func test_full_clear_discards_all_spacing_state() -> void:
	var plugin := PeoplePlugin.new()
	plugin._pedestrian_spacing = [{"resident_id":1}]
	plugin._clear_people()
	assert_true(plugin.get_pedestrian_spacing_snapshot().is_empty())
	plugin.free()
