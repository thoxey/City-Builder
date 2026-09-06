extends GutTest

const PeopleReconciliationTest := preload("res://test/unit/people/test_people_reconciliation.gd")
const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

func test_unrelated_edit_preserves_everything_and_route_removal_is_targeted() -> void:
	var fixtures := PeopleReconciliationTest.new(); var plugin := PeoplePlugin.new()
	plugin._road_network = PeopleReconciliationTest.RouteDouble.new(); plugin._car_manager = PeopleReconciliationTest.CarDouble.new()
	var affected := fixtures._person(1,[Vector3i.ZERO,Vector3i(1,0,0)]); var safe := fixtures._person(2,[Vector3i(5,0,0),Vector3i(6,0,0)])
	plugin._people = [affected,safe]; plugin._resident_index = {1:affected,2:safe}; plugin._journey_by_person = {affected:11,safe:12}; plugin._person_by_journey = {11:affected,12:safe}
	plugin._on_structure_placed(Vector3i(20,0,20),0,0)
	assert_eq([affected.plan_key,safe.plan_key],["plan-1","plan-2"]); assert_eq([affected.journey_id,safe.journey_id],[11,12])
	plugin._on_structure_demolished(Vector3i(1,0,0))
	assert_eq(affected.state,PersonSlot.VisualState.BLOCKED); assert_eq(safe.journey_id,12); assert_eq(safe.plan_key,"plan-2")
	plugin._road_network.free(); plugin._car_manager.free(); plugin.free(); fixtures.free()
