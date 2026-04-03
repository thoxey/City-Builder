extends PluginBase
## Traffic plugin — builds a road graph and drives car proxies along it.
## Registered as an autoload; no scene editing required.

const CAR_COUNT := 5

## Road graph: tile position → array of connected neighbour tile positions
var _graph: Dictionary = {}
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
			# Dead end or tile removed — teleport to a random road tile
			var tiles := _graph.keys()
			if tiles.is_empty():
				return
			var tile: Vector3i = tiles[randi() % tiles.size()]
			car.place_at(tile, _tile_centre(tile))
		else:
			var next: Vector3i = neighbors[randi() % neighbors.size()]
			car.travel_to(next, _tile_centre(next))

# ── Helpers ──────────────────────────────────────────────────────────────────

func _tile_centre(tile: Vector3i) -> Vector3:
	return Vector3(tile.x + 0.5, 0.65, tile.z + 0.5)

func _road_meta_for(structure_index: int) -> RoadMetadata:
	if structure_index < 0 or structure_index >= GameState.structures.size():
		return null
	for m in GameState.structures[structure_index].metadata:
		if m is RoadMetadata:
			return m
	return null
