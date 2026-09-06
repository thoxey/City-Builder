extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

func _person(id: int) -> PersonSlot:
	var person := PersonSlot.new()
	person.resident_id = id
	person.home_anchor = Vector2i(id, 0)
	person.current_place = person.home_anchor
	person.destination_anchor = person.home_anchor
	return person

func test_processing_order_is_built_once_and_maintained_on_lifecycle_changes() -> void:
	var plugin := PeoplePlugin.new()
	var third := _person(3); var first := _person(1); var second := _person(2)
	plugin._people.assign([third, first, second])
	plugin._resident_index = {3:third, 1:first, 2:second}
	plugin._ensure_processing_order()
	assert_eq(plugin._processing_order.map(func(person): return person.resident_id), [1, 2, 3])
	var identity := plugin._processing_order
	plugin._ensure_processing_order()
	assert_same(plugin._processing_order, identity, "unchanged frames reuse maintained order")
	plugin._remove_person(second)
	assert_eq(plugin._processing_order.map(func(person): return person.resident_id), [1, 3])
	plugin.free()

func test_movement_tier_is_stable_and_passive_states_are_event_driven() -> void:
	var plugin := PeoplePlugin.new()
	var third := _person(3); var first := _person(1); var second := _person(2)
	first.state = PersonSlot.VisualState.WALKING_ROUTE
	third.state = PersonSlot.VisualState.WALKING_TO_STOP
	plugin._people.assign([third, first, second])
	plugin._resident_index = {3:third, 1:first, 2:second}
	plugin._ensure_processing_order()
	plugin._ensure_movement_order()
	assert_eq(plugin._movement_order.map(func(person): return person.resident_id), [1, 3])
	plugin._set_person_state(first, PersonSlot.VisualState.WAITING_FOR_CAR)
	plugin._ensure_movement_order()
	assert_eq(plugin._movement_order.map(func(person): return person.resident_id), [3])
	plugin._set_person_state(second, PersonSlot.VisualState.WALKING_FROM_STOP)
	plugin._ensure_movement_order()
	assert_eq(plugin._movement_order.map(func(person): return person.resident_id), [2, 3])
	plugin.free()
