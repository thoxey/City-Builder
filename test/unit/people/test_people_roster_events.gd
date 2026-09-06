extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

class CommunityDouble extends PluginBase:
	var intents: Array[Dictionary] = []
	func get_civilian_intents(_include_unhoused := true) -> Array: return intents.duplicate(true)
	func get_civilian_intent(id: int) -> Dictionary:
		for intent in intents:
			if int(intent["resident_id"]) == id: return intent.duplicate(true)
		return {}

class CarDouble extends PluginBase:
	var cancelled: Array[int] = []
	func cancel_journey(jid: int) -> void: cancelled.append(jid)

func _intent(id: int, home: Vector2i) -> Dictionary:
	return {"resident_id":id,"resident_seed":id * 7,"home_anchor":{"x":home.x,"z":home.y},"destination_anchor":{"x":home.x,"z":home.y},"purpose":"home","assignment_revision":1,"absolute_hour":8,"reachable":true}

func _plugin(intents: Array[Dictionary]) -> Node:
	var plugin := PeoplePlugin.new(); var community := CommunityDouble.new(); community.intents = intents
	plugin._community = community; plugin._car_manager = CarDouble.new()
	for index in 512: plugin._free_indices.append(index)
	return plugin

func _free_plugin(plugin: Node) -> void:
	plugin._community.free(); plugin._car_manager.free(); plugin.free()

func test_arrival_departure_and_rehome_are_targeted() -> void:
	var plugin := _plugin([_intent(1,Vector2i.ZERO),_intent(2,Vector2i(2,0))])
	plugin._on_resident_arrived(1, Vector2i.ZERO); plugin._on_resident_arrived(2, Vector2i(2,0))
	assert_eq(plugin._people.size(), 2)
	var first: PersonSlot = plugin._resident_index[1]; first.journey_id = 41
	plugin._community.intents.assign([_intent(1,Vector2i.ZERO),_intent(2,Vector2i(3,0))])
	plugin._on_resident_rehomed(2, Vector2i(3,0)); assert_eq(plugin._resident_index[2].home_anchor, Vector2i(3,0))
	plugin._community.intents.assign([_intent(2,Vector2i(3,0))])
	plugin._on_resident_departed(1, "test"); assert_false(plugin._resident_index.has(1)); assert_true(plugin._resident_index.has(2)); assert_has(plugin._car_manager.cancelled, 41)
	_free_plugin(plugin)

func test_cap_selection_and_map_load_reconstruct_from_authority() -> void:
	var intents: Array[Dictionary] = []
	for id in range(1, 515): intents.append(_intent(id, Vector2i(id,0)))
	var plugin := _plugin(intents); plugin._on_map_loaded(null)
	assert_eq(plugin._people.size(), 512); assert_true(plugin._resident_index.has(1)); assert_false(plugin._resident_index.has(514))
	assert_eq(plugin._people[0].current_place, plugin._people[0].home_anchor)
	_free_plugin(plugin)
