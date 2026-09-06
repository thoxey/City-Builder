extends GutTest

const CarManagerPlugin := preload("res://plugins/traffic/car_manager_plugin.gd")
const Fixtures := preload("res://test/unit/traffic/car_manager_test_fixtures.gd")
const CIVILIAN := CarSlot.CarType.CIVILIAN
const EXPECTED_VARIANTS := 31
const EXPECTED_CAPACITY := 256
const PALETTE_PATH := "res://models/city-vehicles/city_vehicles_pallete.png"

class ClaimFailureManager:
	extends "res://plugins/traffic/car_manager_plugin.gd"
	func _tile_is_clear(_tile: Vector3i, _jid: int, _entry_dir: Vector2i) -> bool:
		return true
	func _claim_tile(_tile: Vector3i, _jid: int, _entry_dir: Vector2i,
			_phase := "current") -> int:
		return -1

func _real_pool_manager() -> Node:
	var manager := CarManagerPlugin.new()
	manager._setup_pool(CIVILIAN, CarManagerPlugin._TYPE_DEFS[CIVILIAN])
	return manager

func test_variant_multimeshes_partition_the_existing_capacity() -> void:
	var manager := _real_pool_manager()
	var pool: Variant = manager._pools[CIVILIAN]
	var physical_capacity := 0
	var largest_variant_capacity := 0
	for mmi: MultiMeshInstance3D in pool.variants:
		physical_capacity += mmi.multimesh.instance_count
		largest_variant_capacity = maxi(largest_variant_capacity,
			mmi.multimesh.instance_count)

	assert_eq(pool.variants.size(), EXPECTED_VARIANTS)
	assert_eq(pool.variant_paths.size(), EXPECTED_VARIANTS)
	assert_eq(pool.free_indices.size(), EXPECTED_CAPACITY)
	assert_eq(pool.slot_variant_indices.size(), EXPECTED_CAPACITY)
	assert_eq(pool.slot_local_indices.size(), EXPECTED_CAPACITY)
	assert_eq(physical_capacity, EXPECTED_CAPACITY,
		"variants must partition, not multiply, the logical car pool")
	assert_eq(largest_variant_capacity, 9)
	manager.free()

func test_curated_models_merge_body_and_wheels_and_share_one_palette() -> void:
	var manager := _real_pool_manager()
	var pool: Variant = manager._pools[CIVILIAN]
	var model_scale := float(CarManagerPlugin._TYPE_DEFS[CIVILIAN]["scale"])
	var texture_instances: Dictionary = {}
	for variant_index in pool.variants.size():
		var mesh: Mesh = pool.variants[variant_index].multimesh.mesh
		assert_not_null(mesh, pool.variant_paths[variant_index])
		assert_eq(mesh.get_surface_count(), 1,
			"body and wheels should be merged into one instanced surface")
		assert_eq(_vertex_count(mesh),
			_source_vertex_count(manager, pool.variant_paths[variant_index]),
			"merged mesh must retain every body and wheel vertex")
		var bounds := mesh.get_aabb()
		var furthest_z := maxf(absf(bounds.position.z),
			absf(bounds.position.z + bounds.size.z))
		assert_lte(furthest_z * model_scale + CarManagerPlugin.QUEUE_OFFSET, 0.501,
			"vehicle should remain within its claimed road tile")
		var material := mesh.surface_get_material(0) as BaseMaterial3D
		assert_not_null(material, pool.variant_paths[variant_index])
		assert_not_null(material.albedo_texture, pool.variant_paths[variant_index])
		assert_eq(material.albedo_texture.resource_path, PALETTE_PATH,
			pool.variant_paths[variant_index])
		texture_instances[material.albedo_texture.get_instance_id()] = true
	assert_eq(texture_instances.size(), 1,
		"all vehicle variants should retain one shared palette texture instance")
	manager.free()

func test_visual_slot_selection_is_varied_stable_and_without_replacement() -> void:
	var first_manager := CarManagerPlugin.new()
	var second_manager := CarManagerPlugin.new()
	var first_pool := CarManagerPlugin.TypePool.new()
	var second_pool := CarManagerPlugin.TypePool.new()
	for slot_index in 64:
		first_pool.free_indices.append(slot_index)
		second_pool.free_indices.append(slot_index)
	var first_sequence: Array[int] = []
	var second_sequence: Array[int] = []
	for journey_id in 32:
		first_sequence.append(first_manager._take_pool_slot(first_pool, journey_id))
		second_sequence.append(second_manager._take_pool_slot(second_pool, journey_id))

	assert_eq(first_sequence, second_sequence,
		"visual choice must not make deterministic traffic replays drift")
	assert_eq(_unique_count(first_sequence), first_sequence.size())
	assert_ne(first_sequence, range(32), "spawn visuals should not follow pool order")
	first_manager.free()
	second_manager.free()

func test_a_spawn_wave_uses_many_different_vehicle_models() -> void:
	var manager := _real_pool_manager()
	var pool: Variant = manager._pools[CIVILIAN]
	var chosen_variants: Dictionary = {}
	for journey_id in 32:
		var slot_index := int(manager._take_pool_slot(pool, journey_id))
		chosen_variants[pool.slot_variant_indices[slot_index]] = true
	assert_gt(chosen_variants.size(), 10)
	manager.free()

func test_release_returns_the_exact_variant_slot_to_the_logical_pool() -> void:
	var manager := _real_pool_manager()
	var pool: Variant = manager._pools[CIVILIAN]
	var slot := CarSlot.new()
	slot.car_type = CIVILIAN
	slot.slot_index = manager._take_pool_slot(pool, 42)
	slot.position = Vector3(2.0, 0.0, 3.0)
	var variant_index: int = pool.slot_variant_indices[slot.slot_index]
	var local_index: int = pool.slot_local_indices[slot.slot_index]
	var multimesh: MultiMesh = pool.variants[variant_index].multimesh

	manager._write_transform(slot)
	manager._release_silent(slot)
	assert_eq(pool.free_indices.size(), EXPECTED_CAPACITY)
	assert_has(pool.free_indices, slot.slot_index)
	assert_eq(pool.variants[variant_index].multimesh, multimesh)
	assert_eq(pool.slot_local_indices[slot.slot_index], local_index)
	manager.free()

func test_failed_immediate_claim_returns_its_randomized_slot_once() -> void:
	var manager := Fixtures.manager(8)
	var pool: Variant = manager._pools[CIVILIAN]
	var origin := Vector3i.ZERO
	manager._reserved[origin] = {
		900: {"dir": Vector2i.RIGHT, "slot": 0},
		901: {"dir": Vector2i.RIGHT, "slot": 1},
	}
	var route: Array[Vector3i] = [Vector3i(1, 0, 0)]

	var result := int(manager.request_journey(origin, route, CIVILIAN))
	assert_eq(result, -1)
	assert_eq(pool.free_indices.size(), 8)
	assert_eq(_unique_count(pool.free_indices), 8)
	assert_true(manager._active.is_empty())
	Fixtures.free_manager(manager)

func test_failed_pending_claim_keeps_request_and_returns_its_slot_once() -> void:
	var manager := ClaimFailureManager.new()
	manager._road_network = Fixtures.RoadDouble.new()
	var pool := CarManagerPlugin.TypePool.new()
	pool.free_indices.assign([0, 1])
	manager._pools = {CIVILIAN: pool}
	var path: Array[Vector3i] = [Vector3i.ZERO, Vector3i(1, 0, 0)]
	var journey_id := Fixtures.request(manager, 44, path)

	manager._process(0.0)
	var snapshot: Dictionary = manager.get_traffic_flow_snapshot()
	assert_eq(snapshot["active_car_count"], 0)
	assert_eq(snapshot["pending_departure_count"], 1)
	assert_eq(snapshot["pending_departures"][0]["journey_id"], journey_id)
	assert_eq(snapshot["pending_departures"][0]["waiting_reason"], "origin_capacity")
	assert_eq(pool.free_indices.size(), 2)
	assert_eq(_unique_count(pool.free_indices), 2)
	Fixtures.free_manager(manager)

func test_map_reset_restores_every_active_variant_slot_and_clears_pending() -> void:
	var manager := _real_pool_manager()
	var pool: Variant = manager._pools[CIVILIAN]
	manager._road_network = Fixtures.RoadDouble.new()
	for journey_id in range(100, 103):
		var slot := CarSlot.new()
		slot.journey_id = journey_id
		slot.car_type = CIVILIAN
		slot.slot_index = manager._take_pool_slot(pool, journey_id)
		manager._active[journey_id] = slot
	var path: Array[Vector3i] = [Vector3i.ZERO, Vector3i(1, 0, 0)]
	Fixtures.request(manager, 55, path)
	assert_eq(pool.free_indices.size(), EXPECTED_CAPACITY - 3)

	manager._on_map_loaded(null)
	assert_eq(pool.free_indices.size(), EXPECTED_CAPACITY)
	assert_eq(_unique_count(pool.free_indices), EXPECTED_CAPACITY)
	assert_true(manager._active.is_empty())
	assert_true(manager._pending.is_empty())
	assert_true(manager._pending_by_origin.is_empty())
	manager._road_network.free()
	manager.free()

func test_map_reset_restores_fresh_visual_allocator_sequence() -> void:
	var manager := _real_pool_manager()
	var pool: Variant = manager._pools[CIVILIAN]
	var fresh_sequence: Array[int] = []
	for journey_id in 32:
		var slot := CarSlot.new()
		slot.journey_id = journey_id
		slot.car_type = CIVILIAN
		slot.slot_index = manager._take_pool_slot(pool, journey_id)
		fresh_sequence.append(slot.slot_index)
		manager._active[journey_id] = slot

	manager._cancel_all()
	var reset_sequence: Array[int] = []
	for journey_id in 32:
		reset_sequence.append(manager._take_pool_slot(pool, journey_id))
	assert_eq(reset_sequence, fresh_sequence,
		"a map reset should replay the same vehicle variant sequence as a fresh map")
	manager._cancel_all()
	manager.free()

func _unique_count(values: Array[int]) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	return unique.size()

func _source_vertex_count(manager: Node, path: String) -> int:
	var packed := load(path) as PackedScene
	var root := packed.instantiate()
	var parts: Array[Dictionary] = []
	manager._collect_mesh_parts(root, Transform3D.IDENTITY, parts)
	var count := 0
	for part: Dictionary in parts:
		count += _vertex_count(part["mesh"])
	root.free()
	return count

func _vertex_count(mesh: Mesh) -> int:
	var count := 0
	for surface_index in mesh.get_surface_count():
		count += mesh.surface_get_array_len(surface_index)
	return count
