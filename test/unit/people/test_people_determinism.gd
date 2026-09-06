extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

func test_seeded_spawn_offset_and_departure_order_are_repeatable() -> void:
	var first := []
	var second := []
	for id in [9, 2, 5, 1]:
		first.append(PeoplePlugin.seeded_presentation(id * 101, 8, "work"))
	for id in [9, 2, 5, 1]:
		second.append(PeoplePlugin.seeded_presentation(id * 101, 8, "work"))
	assert_eq(first, second)
	assert_ne(first[0]["spawn_offset"], first[1]["spawn_offset"])

func test_absolute_hour_or_purpose_changes_jitter_without_global_rng() -> void:
	var morning: Dictionary = PeoplePlugin.seeded_presentation(707, 8, "work")
	var evening: Dictionary = PeoplePlugin.seeded_presentation(707, 18, "activity")
	assert_ne(morning["departure_offset"], evening["departure_offset"])
