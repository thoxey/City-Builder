extends GutTest

const CarManagerPlugin := preload("res://plugins/traffic/car_manager_plugin.gd")

func _slot(jid: int, path: Array[Vector3i]) -> CarSlot:
	var slot := CarSlot.new(); slot.journey_id = jid; slot.car_type = CarSlot.CarType.CIVILIAN
	slot.slot_index = jid; slot.route = path.duplicate(); slot.current_tile = path.front()
	return slot

func _manager() -> Node:
	var manager := CarManagerPlugin.new(); var pool := CarManagerPlugin.TypePool.new()
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.instance_count = 8
	pool.mminstance = MultiMeshInstance3D.new(); pool.mminstance.multimesh = mm; manager._pools = {CarSlot.CarType.CIVILIAN:pool}
	return manager

func test_targeted_cancellation_preserves_unaffected_journey_and_reservation() -> void:
	var manager := _manager(); var affected := _slot(1,[Vector3i.ZERO,Vector3i(1,0,0)]); var safe := _slot(2,[Vector3i(5,0,0),Vector3i(6,0,0)])
	manager._active = {1:affected,2:safe}; manager._reserved = {Vector3i.ZERO:{1:{"dir":Vector2i.RIGHT,"slot":0}},Vector3i(5,0,0):{2:{"dir":Vector2i.RIGHT,"slot":0}}}
	manager._on_structure_demolished(Vector3i(1,0,0))
	assert_false(manager._active.has(1)); assert_true(manager._active.has(2)); assert_true(manager._reserved.has(Vector3i(5,0,0)))
	manager._pools[CarSlot.CarType.CIVILIAN].mminstance.free(); manager.free()

func test_map_load_remains_full_cancellation_boundary() -> void:
	var manager := _manager(); manager._active = {1:_slot(1,[Vector3i.ZERO,Vector3i(1,0,0)]),2:_slot(2,[Vector3i(5,0,0),Vector3i(6,0,0)])}
	manager._on_map_loaded(null); assert_true(manager._active.is_empty()); assert_true(manager._reserved.is_empty())
	manager._pools[CarSlot.CarType.CIVILIAN].mminstance.free(); manager.free()
