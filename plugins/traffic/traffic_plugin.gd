extends PluginBase

const CAR_COUNT := 5

var _graph: Dictionary = {}  # Vector3i → Array[Vector3i]
var _cars: Array[CarProxy] = []

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_rebuild()

# ── Graph ────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_build_graph()
	_respawn_cars()

func _build_graph() -> void:
	_graph.clear()
	for cell in GameState.gridmap.get_used_cells():
		var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(cell))
		if not road_meta:
			continue
		var orientation := GameState.gridmap.get_cell_item_orientation(cell)
		var conns := road_meta.get_world_connections(orientation, GameState.gridmap)
		var neighbors: Array[Vector3i] = []
		for conn in conns:
			var nb := Vector3i(cell.x + conn.x, 0, cell.z + conn.y)
			if _connects_back(nb, Vector2i(-conn.x, -conn.y)):
				neighbors.append(nb)
		_graph[cell] = neighbors

func _connects_back(tile: Vector3i, from_dir: Vector2i) -> bool:
	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(tile))
	if not road_meta:
		return false
	var orientation := GameState.gridmap.get_cell_item_orientation(tile)
	return from_dir in road_meta.get_world_connections(orientation, GameState.gridmap)

# ── Cars ─────────────────────────────────────────────────────────────────────

func _respawn_cars() -> void:
	for car in _cars:
		car.queue_free()
	_cars.clear()

	var tiles := _graph.keys()
	if tiles.is_empty():
		return

	for i in min(CAR_COUNT, tiles.size()):
		var tile: Vector3i = tiles[randi() % tiles.size()]
		var car := _make_car()
		add_child(car)
		car.place_at(tile, _tile_centre(tile))
		_cars.append(car)

func _make_car() -> CarProxy:
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.30

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.25, 0.1)

	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat

	var car := CarProxy.new()
	car.add_child(mi)
	return car

func _process(_delta: float) -> void:
	for car in _cars:
		if not car.is_arrived():
			continue

		var neighbors: Array = _graph.get(car.current_tile, [])
		if neighbors.is_empty():
			var tiles := _graph.keys()
			if tiles.is_empty():
				return
			var tile: Vector3i = tiles[randi() % tiles.size()]
			car.place_at(tile, _tile_centre(tile))
			return

		var next := _choose_next(car, neighbors)
		car.travel_to(next, _tile_centre(next))

func _choose_next(car: CarProxy, neighbors: Array) -> Vector3i:
	# 1. Prefer continuing straight
	if car.travel_dir != Vector2i.ZERO:
		var straight := Vector3i(
			car.current_tile.x + car.travel_dir.x,
			0,
			car.current_tile.z + car.travel_dir.y)
		if straight in neighbors:
			return straight

	# 2. Avoid U-turn if other options exist
	var back := Vector3i(
		car.current_tile.x - car.travel_dir.x,
		0,
		car.current_tile.z - car.travel_dir.y)
	var forward: Array = []
	for n in neighbors:
		if n != back:
			forward.append(n)

	var pool := forward if not forward.is_empty() else neighbors
	return pool[randi() % pool.size()]

# ── Helpers ──────────────────────────────────────────────────────────────────

func _tile_centre(tile: Vector3i) -> Vector3:
	return Vector3(tile.x, 0.65, tile.z)

func _road_meta_for(structure_index: int) -> RoadMetadata:
	if structure_index < 0 or structure_index >= GameState.structures.size():
		return null
	for m in GameState.structures[structure_index].metadata:
		if m is RoadMetadata:
			return m
	return null
