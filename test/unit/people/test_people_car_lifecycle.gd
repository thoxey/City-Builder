extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

class CarDouble extends PluginBase:
	signal journey_started(journey_id: int, origin_stop: Vector3i, position: Vector3)
	signal journey_completed(journey_id: int, arrived_road_tile: Vector3i, exit_pos: Vector3)
	var next_id := 20
	var cancelled: Array[int] = []
	func request_resolved_journey(_resident_id: int, _origin: Vector3i,
			_destination: Vector3i, _path: Array, _revision: int,
			_key: String, _type := 0) -> int:
		var result := next_id
		next_id += 1
		return result
	func cancel_journey(journey_id: int) -> void:
		cancelled.append(journey_id)

func _person() -> PersonSlot:
	var person := PersonSlot.new()
	person.resident_id = 7
	person.plan_key = "plan-7"
	person.journey_revision = 3
	person.state = PersonSlot.VisualState.WALKING_TO_STOP
	person.visible = true
	person.journey_plan = {
		"origin_stop": Vector3i.ZERO,
		"destination_stop": Vector3i(2, 0, 0),
		"road_path_vectors": [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(2, 0, 0)],
	}
	return person

func _plugin() -> Node:
	var plugin := PeoplePlugin.new()
	plugin._car_manager = CarDouble.new()
	plugin._car_manager.journey_started.connect(Callable(plugin, "_on_journey_started"))
	return plugin

func _free_plugin(plugin: Node) -> void:
	plugin._car_manager.free()
	plugin.free()

func test_accepted_pending_journey_keeps_resident_visible_until_started() -> void:
	var plugin := _plugin()
	var person := _person()
	plugin._begin_car_journey(person)
	assert_eq(person.journey_id, 20)
	assert_eq(person.state, PersonSlot.VisualState.WAITING_FOR_CAR)
	assert_true(person.visible)
	plugin._car_manager.journey_started.emit(20, Vector3i.ZERO, Vector3(0, 0.1, 0))
	assert_eq(person.state, PersonSlot.VisualState.IN_CAR)
	assert_false(person.visible)
	_free_plugin(plugin)

func test_cancelling_waiting_journey_removes_the_same_pending_identity() -> void:
	var plugin := _plugin()
	var person := _person()
	plugin._begin_car_journey(person)
	plugin._cancel_person_journey(person)
	assert_eq(plugin._car_manager.cancelled, [20])
	assert_eq(person.journey_id, -1)
	assert_true(person.visible)
	_free_plugin(plugin)

func test_late_start_for_superseded_plan_is_ignored_and_cancelled() -> void:
	var plugin := _plugin()
	var person := _person()
	plugin._begin_car_journey(person)
	person.plan_key = "replacement-plan"
	plugin._car_manager.journey_started.emit(20, Vector3i.ZERO, Vector3.ZERO)
	assert_true(person.visible)
	assert_ne(person.state, PersonSlot.VisualState.IN_CAR)
	assert_has(plugin._car_manager.cancelled, 20)
	_free_plugin(plugin)
