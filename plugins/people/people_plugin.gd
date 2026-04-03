extends PluginBase

## Population system: fills buildings with people, gives them journeys.
## Short distances (≤ WALK_THRESHOLD tiles) → walk directly.
## Long distances → walk to road → invisible car → walk from road to destination.
## Depends on Traffic for road graph, building data, and edge costs.

const PEOPLE_PER_BUILDING := 2
const WALK_THRESHOLD      := 6      # Manhattan tiles; above this → drive
const DEST_WAIT_MIN       := 4.0
const DEST_WAIT_MAX       := 10.0
const BASE_DRIVE_SPEED    := 3.0
const SPAWN_STAGGER       := 1.2
const WALK_HEIGHT         := 0.1

const PERSON_MODEL_PATH   := "res://models/Meshy_AI_Bluecoat_Guard_0403170555_texture.glb"
const PERSON_SCALE        := 0.12   # adjust once model dimensions are confirmed
const PERSON_MODEL_Y      := 0.0    # local Y offset inside model node — tune to taste
const PERSON_MODEL_ROT_Y  := 0.0    # rotate model if it faces the wrong way at rest

enum PersonState {
	IDLE,             # waiting at current building (home or destination)
	WALKING_TO_ROAD,  # heading to adjacent road tile before car journey
	IN_CAR,           # hidden inside car; car is navigating to dest road tile
	WALKING_TO_DEST,  # on foot to destination building (short trip or post-car)
}

# ── DI ────────────────────────────────────────────────────────────────────────

var _traffic: PluginBase  # injected — call via duck typing

func get_plugin_name() -> String: return "People"
func get_dependencies() -> Array[String]: return ["Traffic"]
func inject(deps: Dictionary) -> void:
	_traffic = deps.get("Traffic")

# ── State ─────────────────────────────────────────────────────────────────────

var _people: Array[PersonProxy] = []
var _home: Dictionary = {}    # PersonProxy → Vector3i
var _dest: Dictionary = {}    # PersonProxy → Vector3i
var _state: Dictionary = {}   # PersonProxy → PersonState
var _timer: Dictionary = {}   # PersonProxy → float
var _car: Dictionary = {}     # PersonProxy → CarProxy

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
	_person_packed = load(PERSON_MODEL_PATH) as PackedScene
	if not _person_packed:
		push_warning("[People] model not found: %s — using capsule fallback" % PERSON_MODEL_PATH)
	_spawn_people()
	print("[People] %d people across %d buildings" % [
			_people.size(), _traffic.get_building_tiles().size()])

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
	var building_tiles: Array[Vector3i] = _traffic.get_building_tiles()
	if building_tiles.is_empty():
		return
	var stagger_index := 0
	for building_tile in building_tiles:
		for i in PEOPLE_PER_BUILDING:
			var person := PersonProxy.new()
			person._model = _make_model(person)
			add_child(person)
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
		model.rotation_degrees.y = PERSON_MODEL_ROT_Y
		var mesh: Mesh = _mesh_from_scene(_person_packed)
		model.position.y = -mesh.get_aabb().position.y * PERSON_SCALE if mesh else PERSON_MODEL_Y
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
	var building_tiles: Array[Vector3i] = _traffic.get_building_tiles()

	var candidates: Array[Vector3i] = []
	for t in building_tiles:
		if t != home_tile:
			candidates.append(t)
	if candidates.is_empty():
		_timer[person] = randf_range(DEST_WAIT_MIN, DEST_WAIT_MAX)
		return

	var dest_tile: Vector3i = candidates[randi() % candidates.size()]
	_dest[person] = dest_tile

	var dist: int = abs(dest_tile.x - home_tile.x) + abs(dest_tile.z - home_tile.z)
	var home_stops: Array[Vector3i] = _traffic.get_stops_for_building(home_tile)
	var dest_stops: Array[Vector3i] = _traffic.get_stops_for_building(dest_tile)
	var can_drive: bool = dist > WALK_THRESHOLD and not home_stops.is_empty() and not dest_stops.is_empty()

	if can_drive:
		var road_tile: Vector3i = home_stops[0]
		person.walk_to([road_tile], [Vector3(road_tile.x, WALK_HEIGHT, road_tile.z)])
		_state[person] = PersonState.WALKING_TO_ROAD
	else:
		person.walk_to([dest_tile], [Vector3(dest_tile.x, WALK_HEIGHT, dest_tile.z)])
		_state[person] = PersonState.WALKING_TO_DEST

func _begin_car_journey(person: PersonProxy) -> void:
	var dest_tile: Vector3i = _dest[person]
	var dest_stops: Array[Vector3i] = _traffic.get_stops_for_building(dest_tile)
	if dest_stops.is_empty():
		_abort_to_idle(person)
		return

	var start_road: Vector3i = person.current_tile
	var goal_road: Vector3i = dest_stops[0]
	var graph: Dictionary = _traffic.get_road_graph()

	var path := Pathfinder.find_path(graph, start_road, goal_road,
			func(f: Vector3i, t: Vector3i) -> float: return _traffic.get_edge_cost(f, t),
			func(a: Vector3i, b: Vector3i) -> float: return Pathfinder.manhattan(a, b))
	if path.size() <= 1:
		_abort_to_idle(person)
		return

	path.remove_at(0)
	var positions: Array[Vector3] = []
	for tile: Vector3i in path:
		positions.append(Vector3(tile.x, WALK_HEIGHT, tile.z))

	var car := CarProxy.new()
	var mi := MeshInstance3D.new()  # no visible mesh — person is the actor while driving
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
		var dest_tile: Vector3i = _dest[person]
		var stops: Array[Vector3i] = _traffic.get_stops_for_building(dest_tile)
		road_tile = stops[0] if not stops.is_empty() else dest_tile
	_car.erase(person)

	var dest_tile: Vector3i = _dest[person]
	person.place_at(road_tile, Vector3(road_tile.x, WALK_HEIGHT, road_tile.z))
	person.set_model_visible(true)
	person.walk_to([dest_tile], [Vector3(dest_tile.x, WALK_HEIGHT, dest_tile.z)])
	_state[person] = PersonState.WALKING_TO_DEST

func _arrive_at_dest(person: PersonProxy) -> void:
	# Swap home/dest so the next journey goes the other way
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

func _mesh_from_scene(packed: PackedScene) -> Mesh:
	var state := packed.get_state()
	for i in state.get_node_count():
		if state.get_node_type(i) == "MeshInstance3D":
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i, j) == "mesh":
					return state.get_node_property_value(i, j) as Mesh
	return null
