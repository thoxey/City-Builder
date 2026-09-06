extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")
const Fixtures := preload("res://test/unit/people/people_test_fixtures.gd")

func _person(id := 7, home := Vector2i.ZERO) -> PersonSlot:
	var person := PersonSlot.new()
	person.resident_id = id
	person.resident_seed = id * 97
	person.home_anchor = home
	person.current_place = home
	person.current_tile = Vector3i(home.x, 0, home.y)
	person.position = Vector3(home.x, 0.1, home.y)
	return person

func test_exact_work_activity_and_home_intents_are_reconciled() -> void:
	var plugin := PeoplePlugin.new()
	var person := _person()
	plugin._reconcile_person(person, Fixtures.intent(7, Vector2i.ZERO, Vector2i(4, 0), "work", 2, 8))
	assert_eq(person.purpose, "work")
	assert_eq(person.destination_anchor, Vector2i(4, 0))
	plugin._reconcile_person(person, Fixtures.intent(7, Vector2i.ZERO, Vector2i(2, 0), "activity", 3, 18))
	assert_eq(person.purpose, "activity")
	assert_eq(person.destination_anchor, Vector2i(2, 0))
	plugin._reconcile_person(person, Fixtures.intent(7, Vector2i.ZERO, Vector2i.ZERO, "home", 4, 23))
	assert_eq(person.purpose, "home")
	assert_eq(person.destination_anchor, Vector2i.ZERO)
	plugin.free()

func test_arrival_updates_current_place_but_never_home() -> void:
	var plugin := PeoplePlugin.new()
	var person := _person(7, Vector2i(1, 1))
	person.destination_anchor = Vector2i(8, 1)
	person.purpose = "work"
	plugin._arrive_for_intent(person)
	assert_eq(person.current_place, Vector2i(8, 1))
	assert_eq(person.home_anchor, Vector2i(1, 1))
	assert_eq(person.state, PersonSlot.VisualState.AT_DESTINATION)
	plugin.free()

func test_matching_arrived_intent_dwells_without_realtime_timer() -> void:
	var plugin := PeoplePlugin.new()
	var person := _person()
	person.current_place = Vector2i(4, 0)
	person.destination_anchor = Vector2i(4, 0)
	person.purpose = "work"
	person.state = PersonSlot.VisualState.AT_DESTINATION
	plugin._reconcile_person(person, Fixtures.intent(7, Vector2i.ZERO, Vector2i(4, 0), "work", 8, 9))
	assert_eq(person.state, PersonSlot.VisualState.AT_DESTINATION)
	assert_true(person._waypoints.is_empty())
	plugin.free()
