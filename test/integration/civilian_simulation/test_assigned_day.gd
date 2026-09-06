extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")
const Fixtures := preload("res://test/unit/people/people_test_fixtures.gd")

func test_full_day_preserves_binding_and_exact_destinations() -> void:
	var plugin := PeoplePlugin.new()
	var person := PersonSlot.new()
	person.resident_id = 101
	person.resident_seed = 8101
	person.home_anchor = Vector2i.ZERO
	person.current_place = Vector2i.ZERO
	person.current_tile = Vector3i.ZERO
	plugin._people = [person]
	plugin._resident_index = {101: person}
	var trace := []
	for intent in [
		Fixtures.intent(101, Vector2i.ZERO, Vector2i(7, 0), "work", 2, 8),
		Fixtures.intent(101, Vector2i.ZERO, Vector2i(4, 1), "activity", 3, 18),
		Fixtures.intent(101, Vector2i.ZERO, Vector2i.ZERO, "home", 4, 23),
	]:
		plugin._reconcile_person(person, intent)
		trace.append({"id":person.resident_id, "purpose":person.purpose, "destination":person.destination_anchor})
	assert_eq(trace, [
		{"id":101, "purpose":"work", "destination":Vector2i(7, 0)},
		{"id":101, "purpose":"activity", "destination":Vector2i(4, 1)},
		{"id":101, "purpose":"home", "destination":Vector2i.ZERO},
	])
	assert_eq(person.home_anchor, Vector2i.ZERO)
	plugin.free()
