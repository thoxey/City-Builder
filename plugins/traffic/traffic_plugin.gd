extends PluginBase

const CAR_COUNT      := 5
const LANE_OFFSET    := 0.2
const WAIT_MIN       := 1.0
const WAIT_MAX       := 3.0
const BASE_SPEED     := 3.0   # tiles/sec at speed_limit 30
const SPAWN_STAGGER  := 0.6

var _graph: Dictionary = {}              # Vector3i → Array[Vector3i]
var _building_tiles: Array[Vector3i] = []
var _building_stops: Array[Vector3i] = [] # flat list: road tiles adjacent to any building
var _building_road_stops: Dictionary = {} # building_tile → Array[Vector3i]
var _cars: Array[CarProxy] = []
var _car_paths: Dictionary = {}           # CarProxy → Array[Vector3i]
var _car_timers: Dictionary = {}          # CarProxy → float

func get_plugin_name() -> String: return "Traffic"
func get_dependencies() -> Array[String]: return []

# ── Public API (consumed by dependent plugins) ────────────────────────────────

func get_road_graph() -> Dictionary:
	return _graph

func get_building_tiles() -> Array[Vector3i]:
	return _building_tiles

func get_stops_for_building(tile: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var stored = _building_road_stops.get(tile)
	if stored:
		result.assign(stored)
	return result

func road_meta_for(sid: int) -> RoadMetadata:
	return _road_meta_for(sid)

func is_building_sid(sid: int) -> bool:
	return _is_building(sid)

func get_edge_cost(from: Vector3i, to: Vector3i) -> float:
	return _edge_cost(from, to)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_rebuild()

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_build_graph()
	_find_building_stops()
	_respawn_cars()
	print("[Traffic] graph tiles: %d | building stops: %d | cars: %d" % [
			_graph.size(), _building_stops.size(), _cars.size()])

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
	_building_tiles.clear()
	_building_stops.clear()
	_building_road_stops.clear()
	for cell in GameState.gridmap.get_used_cells():
		if not _is_building(GameState.gridmap.get_cell_item(cell)):
			continue
		_building_tiles.append(cell)
		var stops: Array[Vector3i] = []
		for offset: Vector3i in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
			var nb: Vector3i = cell + offset
			if _graph.has(nb):
				stops.append(nb)
				if not nb in _building_stops:
					_building_stops.append(nb)
		_building_road_stops[cell] = stops

# ── Cars ──────────────────────────────────────────────────────────────────────

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
		_car_timers[car] = i * SPAWN_STAGGER + randf() * SPAWN_STAGGER

const CAR_MODEL_PATH := "res://models/Meshy_AI_Car_0403170715_texture.glb"
const CAR_SCALE      := 0.15

func _make_car() -> CarProxy:
	var car := CarProxy.new()
	var packed := load(CAR_MODEL_PATH) as PackedScene
	if packed:
		var model := packed.instantiate()
		model.scale = Vector3.ONE * CAR_SCALE
		model.rotation_degrees.y = 270.0
		var mesh: Mesh = _mesh_from_scene(packed)
		model.position.y = -mesh.get_aabb().position.y * CAR_SCALE if mesh else 0.0
		car.add_child(model)
	else:
		push_warning("[Traffic] car model not found (%s)" % CAR_MODEL_PATH)
		var sphere := SphereMesh.new()
		sphere.radius = 0.075
		sphere.height = 0.15
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		car.add_child(mi)
	return car

func _mesh_from_scene(packed: PackedScene) -> Mesh:
	var state := packed.get_state()
	for i in state.get_node_count():
		if state.get_node_type(i) == "MeshInstance3D":
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i, j) == "mesh":
					return state.get_node_property_value(i, j) as Mesh
	return null

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
	var path := Pathfinder.find_path(_graph, car.current_tile, goal,
			func(f: Vector3i, t: Vector3i) -> float: return _edge_cost(f, t),
			func(a: Vector3i, b: Vector3i) -> float: return Pathfinder.manhattan(a, b))

	if path.size() <= 1:
		_car_timers[car] = 1.0
		return

	path.remove_at(0)

	var positions: Array[Vector3] = []
	for i in path.size():
		var tile: Vector3i = path[i]
		var dir := Vector2i(
			tile.x - (car.current_tile.x if i == 0 else (path[i - 1] as Vector3i).x),
			tile.z - (car.current_tile.z if i == 0 else (path[i - 1] as Vector3i).z))
		positions.append(_lane_position(tile, dir))

	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(path[0]))
	car.speed = BASE_SPEED * (float(road_meta.speed_limit) / 30.0) if road_meta else BASE_SPEED

	_car_paths[car] = path
	car.set_path(path, positions)

# ── Process ───────────────────────────────────────────────────────────────────

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

# ── Edge cost ─────────────────────────────────────────────────────────────────

## Cost to traverse one road tile. Faster roads = cheaper.
## Used by both this plugin's cars and any injected dependent (e.g. People).
func _edge_cost(_from: Vector3i, to: Vector3i) -> float:
	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(to))
	if not road_meta:
		return 1.0
	return 30.0 / float(road_meta.speed_limit)

# ── Lane helpers ──────────────────────────────────────────────────────────────

func _lane_position(tile: Vector3i, dir: Vector2i) -> Vector3:
	var base := Vector3(tile.x, 0.1, tile.z)
	if dir == Vector2i.ZERO:
		return base
	var left := Vector3(dir.y, 0.0, -dir.x).normalized() * LANE_OFFSET
	return base + left

# ── Metadata helpers ──────────────────────────────────────────────────────────

func _road_meta_for(sid: int) -> RoadMetadata:
	if sid < 0 or sid >= GameState.structures.size():
		return null
	return GameState.structures[sid].find_metadata(RoadMetadata) as RoadMetadata

func _is_building(sid: int) -> bool:
	if sid < 0 or sid >= GameState.structures.size():
		return false
	return GameState.structures[sid].find_metadata(BuildingMetadata) != null
