extends PluginBase

const CAR_COUNT      := 5
const LANE_OFFSET    := 0.2
const WAIT_MIN       := 1.0
const WAIT_MAX       := 3.0
const BASE_SPEED     := 3.0   # tiles/sec at speed_limit 30
const SPAWN_STAGGER  := 0.6

var _graph: Dictionary = {}             # Vector3i → Array[Vector3i]
var _building_stops: Array[Vector3i] = [] # road tiles adjacent to buildings
var _cars: Array[CarProxy] = []
var _car_paths: Dictionary = {}   # CarProxy → Array[Vector3i] (for reference/occupancy)
var _car_timers: Dictionary = {}  # CarProxy → float (destination wait)

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_rebuild()

# ── Build ────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_build_graph()
	_find_building_stops()
	_respawn_cars()
	print("[Traffic] graph tiles: %d | building stops: %d | cars: %d" % [_graph.size(), _building_stops.size(), _cars.size()])

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

func _find_building_stops() -> void:
	_building_stops.clear()
	for cell in GameState.gridmap.get_used_cells():
		if not _is_building(GameState.gridmap.get_cell_item(cell)):
			continue
		for offset: Vector3i in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
			var nb: Vector3i = cell + offset
			if _graph.has(nb) and not nb in _building_stops:
				_building_stops.append(nb)

# ── Cars ─────────────────────────────────────────────────────────────────────

func _respawn_cars() -> void:
	for car in _cars:
		car.queue_free()
	_cars.clear()
	_car_paths.clear()
	_car_timers.clear()

	var tiles := _graph.keys()
	if tiles.is_empty():
		return

	for i in min(CAR_COUNT, tiles.size()):
		var tile: Vector3i = tiles[randi() % tiles.size()]
		var car := _make_car()
		add_child(car)
		car.place_at(tile, _lane_position(tile, Vector2i.ZERO))
		_cars.append(car)
		# Stagger: offset each car's first departure so they don't all move in sync
		_car_timers[car] = i * SPAWN_STAGGER + randf() * SPAWN_STAGGER

const CAR_MODEL_PATH := "res://models/Meshy_AI_Car_0403120940_texture.glb"
const CAR_SCALE      := 0.15  # car is 2m tall; scale to ~0.3 units to fit road tiles

func _make_car() -> CarProxy:
	var car := CarProxy.new()
	var packed := load(CAR_MODEL_PATH) as PackedScene
	if packed:
		print("[Traffic] car model loaded OK")
		var model := packed.instantiate()
		model.scale = Vector3.ONE * CAR_SCALE
		model.position.y = -0.095
		model.rotation_degrees.y = 270.0
		car.add_child(model)
	else:
		print("[Traffic] WARNING: car model failed to load — using fallback sphere (%s)" % CAR_MODEL_PATH)
		var sphere := SphereMesh.new()
		sphere.radius = 0.075
		sphere.height = 0.15
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		car.add_child(mi)
	return car

func _assign_journey(car: CarProxy) -> void:
	if _building_stops.is_empty():
		return

	var candidates: Array = []
	for s in _building_stops:
		if s != car.current_tile:
			candidates.append(s)
	if candidates.is_empty():
		return

	var goal: Vector3i = candidates[randi() % candidates.size()]
	var path := Pathfinder.find_path(_graph, car.current_tile, goal, _edge_cost,
			func(a: Vector3i, b: Vector3i) -> float: return Pathfinder.manhattan(a, b))

	if path.size() <= 1:
		_car_timers[car] = 1.0
		return

	path.remove_at(0)

	# Build world positions for the full path
	var positions: Array[Vector3] = []
	for i in path.size():
		var tile: Vector3i = path[i]
		var dir := Vector2i(
			tile.x - (car.current_tile.x if i == 0 else (path[i-1] as Vector3i).x),
			tile.z - (car.current_tile.z if i == 0 else (path[i-1] as Vector3i).z))
		positions.append(_lane_position(tile, dir))

	# Speed from first tile's road metadata
	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(path[0]))
	car.speed = BASE_SPEED * (float(road_meta.speed_limit) / 30.0) if road_meta else BASE_SPEED

	_car_paths[car] = path
	car.set_path(path, positions)

# ── Process ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	for car in _cars:
		if _car_timers.has(car):
			_car_timers[car] -= delta
			if _car_timers[car] <= 0.0:
				_car_timers.erase(car)
				_assign_journey(car)
			continue

		if car.is_path_empty():
			_car_timers[car] = randf_range(WAIT_MIN, WAIT_MAX)

# ── Pathfinding cost ─────────────────────────────────────────────────────────

## Edge cost function passed to Pathfinder.
## Uses speed_limit from RoadMetadata so faster roads are preferred.
## Swap this out to change routing behaviour (e.g. penalise congestion).
func _edge_cost(_from: Vector3i, to: Vector3i) -> float:
	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(to))
	if not road_meta:
		return 1.0
	return 30.0 / float(road_meta.speed_limit)  # 30mph road = cost 1.0; faster = cheaper

# ── Lane helpers ─────────────────────────────────────────────────────────────

func _lane_position(tile: Vector3i, dir: Vector2i) -> Vector3:
	var base := Vector3(tile.x, 0.1, tile.z)
	if dir == Vector2i.ZERO:
		return base
	var left := Vector3(dir.y, 0.0, -dir.x).normalized() * LANE_OFFSET
	return base + left

func _lane_occupied(tile: Vector3i, dir: Vector2i, exclude: CarProxy) -> bool:
	for car in _cars:
		if car == exclude:
			continue
		if car.current_tile == tile and car.travel_dir == dir:
			return true
	return false

# ── Metadata helpers ─────────────────────────────────────────────────────────

func _road_meta_for(sid: int) -> RoadMetadata:
	if sid < 0 or sid >= GameState.structures.size():
		return null
	for m in GameState.structures[sid].metadata:
		if m is RoadMetadata:
			return m
	return null

func _is_building(sid: int) -> bool:
	if sid < 0 or sid >= GameState.structures.size():
		return false
	for m in GameState.structures[sid].metadata:
		if m is BuildingMetadata:
			return true
	return false
