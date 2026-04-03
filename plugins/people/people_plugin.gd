extends PluginBase

## Population system: fills buildings with people, gives them journeys.
## Short distances (≤ WALK_THRESHOLD tiles) → walk directly.
## Long distances → walk to road → invisible car → walk from road to destination.

const PEOPLE_PER_BUILDING := 2
const WALK_THRESHOLD      := 6      # Manhattan tiles; above this → drive
const DEST_WAIT_MIN       := 4.0
const DEST_WAIT_MAX       := 10.0
const BASE_DRIVE_SPEED    := 3.0
const SPAWN_STAGGER       := 1.2    # seconds between each person's first departure
const WALK_HEIGHT         := 0.1

const PERSON_MODEL_PATH   := "res://models/Meshy_AI_Bluecoat_Guard_0403153240_texture.glb"
const PERSON_SCALE        := 0.12   # adjust once model dimensions are confirmed
const PERSON_MODEL_Y      := 0.0    # local Y offset inside model node — tune to taste
const PERSON_MODEL_ROT_Y  := 0.0    # rotate model if it faces the wrong way at rest

enum PersonState {
	IDLE,             # waiting at current building (home or destination)
	WALKING_TO_ROAD,  # heading to adjacent road tile before car journey
	IN_CAR,           # hidden inside car; car is navigating to dest road tile
	WALKING_TO_DEST,  # on foot to destination building (short trip or post-car)
}

# Road graph (rebuilt alongside buildings on every map change)
var _road_graph: Dictionary = {}      # Vector3i → Array[Vector3i]
# Building data
var _building_tiles: Array[Vector3i] = []
var _building_stops: Dictionary = {}  # building_tile → Array[Vector3i] adjacent road tiles

# People
var _people: Array[PersonProxy] = []
# Per-person dictionaries  (keyed by PersonProxy instance)
var _home: Dictionary = {}            # → Vector3i  current "home" (swaps each trip)
var _dest: Dictionary = {}            # → Vector3i  current destination building tile
var _state: Dictionary = {}           # → PersonState
var _timer: Dictionary = {}           # → float      idle wait countdown
var _car: Dictionary = {}             # → CarProxy   set while IN_CAR

# Cached packed scene so we only load once per rebuild
var _person_packed: PackedScene = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_rebuild()

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_clear_people()
	_build_road_graph()
	_find_buildings()
	_person_packed = load(PERSON_MODEL_PATH) as PackedScene
	if not _person_packed:
		push_warning("[People] model not found: %s — using capsule fallback" % PERSON_MODEL_PATH)
	_spawn_people()
	print("[People] buildings: %d | people: %d | road graph tiles: %d" % [
		_building_tiles.size(), _people.size(), _road_graph.size()])

func _build_road_graph() -> void:
	_road_graph.clear()
	for cell in GameState.gridmap.get_used_cells():
		var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(cell))
		if not road_meta:
			continue
		var orientation := GameState.gridmap.get_cell_item_orientation(cell)
		var conns := road_meta.get_world_connections(orientation, GameState.gridmap)
		var neighbors: Array[Vector3i] = []
		for conn in conns:
			var nb: Vector3i = Vector3i(cell.x + conn.x, 0, cell.z + conn.y)
			if _connects_back(nb, Vector2i(-conn.x, -conn.y)):
				neighbors.append(nb)
		_road_graph[cell] = neighbors

func _connects_back(tile: Vector3i, from_dir: Vector2i) -> bool:
	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(tile))
	if not road_meta:
		return false
	var orientation := GameState.gridmap.get_cell_item_orientation(tile)
	return from_dir in road_meta.get_world_connections(orientation, GameState.gridmap)

func _find_buildings() -> void:
	_building_tiles.clear()
	_building_stops.clear()
	for cell in GameState.gridmap.get_used_cells():
		if not _is_building(GameState.gridmap.get_cell_item(cell)):
			continue
		_building_tiles.append(cell)
		var stops: Array[Vector3i] = []
		for offset: Vector3i in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
			var nb: Vector3i = cell + offset
			if _road_graph.has(nb):
				stops.append(nb)
		_building_stops[cell] = stops

# ── Spawn ─────────────────────────────────────────────────────────────────────

func _clear_people() -> void:
	for p in _people:
		var c: CarProxy = _car.get(p)
		if is_instance_valid(c):
			c.queue_free()
		p.queue_free()
	_people.clear()
	_home.clear()
	_dest.clear()
	_state.clear()
	_timer.clear()
	_car.clear()

func _spawn_people() -> void:
	if _building_tiles.is_empty():
		return
	var stagger_index := 0
	for building_tile in _building_tiles:
		for i in PEOPLE_PER_BUILDING:
			var person := PersonProxy.new()
			person._model = _make_model(person)
			add_child(person)
			# Slight XZ jitter so people at the same building don't overlap
			var jitter := Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
			person.place_at(building_tile, Vector3(building_tile.x, WALK_HEIGHT, building_tile.z) + jitter)
			_people.append(person)
			_home[person] = building_tile
			_state[person] = PersonState.IDLE
			_timer[person] = stagger_index * SPAWN_STAGGER + randf_range(0.0, SPAWN_STAGGER)
			stagger_index += 1

func _make_model(parent: PersonProxy) -> Node3D:
	if _person_packed:
		var model := _person_packed.instantiate() as Node3D
		model.scale = Vector3.ONE * PERSON_SCALE
		model.position.y = PERSON_MODEL_Y
		model.rotation_degrees.y = PERSON_MODEL_ROT_Y
		parent.add_child(model)
		return model
	else:
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.05
		mesh.height = 0.18
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position.y = 0.09
		parent.add_child(mi)
		return mi

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	for person in _people:
		match _state[person]:
			PersonState.IDLE:
				_timer[person] -= delta
				if _timer[person] <= 0.0:
					_assign_journey(person)

			PersonState.WALKING_TO_ROAD:
				if not person.is_walking():
					_begin_car_journey(person)

			PersonState.IN_CAR:
				var car: CarProxy = _car.get(person)
				if not is_instance_valid(car) or car.is_path_empty():
					_end_car_journey(person)

			PersonState.WALKING_TO_DEST:
				if not person.is_walking():
					_arrive_at_dest(person)

# ── Journey logic ─────────────────────────────────────────────────────────────

func _assign_journey(person: PersonProxy) -> void:
	var home_tile: Vector3i = _home[person]
	var candidates: Array[Vector3i] = []
	for t in _building_tiles:
		if t != home_tile:
			candidates.append(t)
	if candidates.is_empty():
		_timer[person] = randf_range(DEST_WAIT_MIN, DEST_WAIT_MAX)
		return

	var dest_tile: Vector3i = candidates[randi() % candidates.size()]
	_dest[person] = dest_tile

	var dist: int = abs(dest_tile.x - home_tile.x) + abs(dest_tile.z - home_tile.z)
	var home_stops: Array = _building_stops.get(home_tile, [])
	var dest_stops: Array = _building_stops.get(dest_tile, [])
	var can_drive: bool = dist > WALK_THRESHOLD and not home_stops.is_empty() and not dest_stops.is_empty() and not home_stops.is_empty() and not dest_stops.is_empty()

	if can_drive:
		# Walk to nearest road tile, then drive
		var road_tile: Vector3i = home_stops[0]
		person.walk_to([road_tile], [Vector3(road_tile.x, WALK_HEIGHT, road_tile.z)])
		_state[person] = PersonState.WALKING_TO_ROAD
	else:
		# Walk directly to destination
		person.walk_to([dest_tile], [Vector3(dest_tile.x, WALK_HEIGHT, dest_tile.z)])
		_state[person] = PersonState.WALKING_TO_DEST

func _begin_car_journey(person: PersonProxy) -> void:
	var dest_tile: Vector3i = _dest[person]
	var dest_stops: Array = _building_stops.get(dest_tile, [])
	if dest_stops.is_empty():
		_abort_to_idle(person)
		return

	var start_road: Vector3i = person.current_tile
	var goal_road: Vector3i = dest_stops[0]
	var path := Pathfinder.find_path(_road_graph, start_road, goal_road, _edge_cost,
			func(a: Vector3i, b: Vector3i) -> float: return Pathfinder.manhattan(a, b))
	if path.size() <= 1:
		_abort_to_idle(person)
		return

	path.remove_at(0)  # car starts here, waypoints are the remainder

	var positions: Array[Vector3] = []
	for tile: Vector3i in path:
		positions.append(Vector3(tile.x, WALK_HEIGHT, tile.z))

	# Invisible car carries the person's tile progress
	var car := CarProxy.new()
	var mi := MeshInstance3D.new()  # no mesh — person is the visible actor while driving
	car.add_child(mi)
	add_child(car)
	car.place_at(start_road, Vector3(start_road.x, WALK_HEIGHT, start_road.z))
	car.speed = BASE_DRIVE_SPEED
	car.set_path(path, positions)

	_car[person] = car
	person.set_model_visible(false)
	_state[person] = PersonState.IN_CAR

func _end_car_journey(person: PersonProxy) -> void:
	var car: CarProxy = _car.get(person)
	var road_tile: Vector3i
	if is_instance_valid(car):
		road_tile = car.current_tile
		car.queue_free()
	else:
		# Car was somehow freed — land person at destination stop if possible
		var dest_tile: Vector3i = _dest[person]
		var stops: Array = _building_stops.get(dest_tile, [])
		road_tile = stops[0] if not stops.is_empty() else dest_tile
	_car.erase(person)

	var dest_tile: Vector3i = _dest[person]
	person.place_at(road_tile, Vector3(road_tile.x, WALK_HEIGHT, road_tile.z))
	person.set_model_visible(true)
	person.walk_to([dest_tile], [Vector3(dest_tile.x, WALK_HEIGHT, dest_tile.z)])
	_state[person] = PersonState.WALKING_TO_DEST

func _arrive_at_dest(person: PersonProxy) -> void:
	# Arrived — swap home/dest and wait before next journey
	var old_home: Vector3i = _home[person]
	_home[person] = _dest[person]
	_dest[person] = old_home
	_state[person] = PersonState.IDLE
	_timer[person] = randf_range(DEST_WAIT_MIN, DEST_WAIT_MAX)

func _abort_to_idle(person: PersonProxy) -> void:
	_car.erase(person)
	person.set_model_visible(true)
	_state[person] = PersonState.IDLE
	_timer[person] = randf_range(DEST_WAIT_MIN, DEST_WAIT_MAX)

# ── Cost function ─────────────────────────────────────────────────────────────

func _edge_cost(_from: Vector3i, to: Vector3i) -> float:
	var road_meta := _road_meta_for(GameState.gridmap.get_cell_item(to))
	if not road_meta:
		return 1.0
	return 30.0 / float(road_meta.speed_limit)

# ── Metadata helpers ──────────────────────────────────────────────────────────

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
