extends PluginBase

## Medical facility plugin.
## On each in-game hour, spawns one response vehicle per medical facility.
## Each patrol picks 4 random building tiles, drives to each in sequence,
## returns to the facility's nearest road tile, then despawns.

# TODO: Replace with a dedicated medical/ambulance vehicle model when available.
const PATROL_MODEL_PATH := "res://models/Meshy_AI_Mini_Police_Cruiser_0403205957/Meshy_AI_Mini_Police_Cruiser_0403205957_texture.glb"
const CAR_SCALE        := 0.15
const PATROL_SPEED     := 4.0
const PATROL_STOPS     := 4      # buildings visited per patrol

func get_plugin_name() -> String: return "Medical"
func get_dependencies() -> Array[String]: return ["Traffic", "DayNight"]

var _traffic:   PluginBase
var _day_night: PluginBase

func inject(deps: Dictionary) -> void:
	_traffic   = deps.get("Traffic")
	_day_night = deps.get("DayNight")

# ── State ─────────────────────────────────────────────────────────────────────

var _facility_tiles: Array[Vector3i] = []
var _patrols: Array[CarProxy] = []
var _car_packed: PackedScene = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_car_packed = load(PATROL_MODEL_PATH) as PackedScene
	if not _car_packed:
		push_warning("[Medical] vehicle model not found: %s" % PATROL_MODEL_PATH)

	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_day_night.hour_changed.connect(_on_hour)
	_rebuild()

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_facility_tiles.clear()
	for cell in GameState.gridmap.get_used_cells():
		var sid: int = GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size():
			continue
		if GameState.structures[sid].find_metadata(MedicalMetadata) != null:
			_facility_tiles.append(cell)
	print("[Medical] %d facility(ies) found" % _facility_tiles.size())

# ── Hour tick ─────────────────────────────────────────────────────────────────

func _on_hour(_hour: float) -> void:
	for facility in _facility_tiles:
		_spawn_patrol(facility)

# ── Patrol ────────────────────────────────────────────────────────────────────

func _spawn_patrol(facility_tile: Vector3i) -> void:
	var graph: Dictionary = _traffic.get_road_graph()
	var building_tiles: Array[Vector3i] = _traffic.get_building_tiles()
	if building_tiles.size() < 2:
		return

	var facility_stops: Array[Vector3i] = _traffic.get_stops_for_building(facility_tile)
	if facility_stops.is_empty():
		return
	var home_road: Vector3i = facility_stops[0]

	var candidates: Array[Vector3i] = []
	for t in building_tiles:
		if t != facility_tile:
			var stops: Array[Vector3i] = _traffic.get_stops_for_building(t)
			if not stops.is_empty():
				candidates.append(t)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var targets: Array[Vector3i] = candidates.slice(0, mini(PATROL_STOPS, candidates.size()))

	var waypoints: Array[Vector3i] = [home_road]
	for t in targets:
		var stops: Array[Vector3i] = _traffic.get_stops_for_building(t)
		waypoints.append(stops[0])
	waypoints.append(home_road)

	var full_path: Array[Vector3i] = []
	var full_pos: Array[Vector3] = []
	for i in waypoints.size() - 1:
		var seg: Array = Pathfinder.find_path(
			graph, waypoints[i], waypoints[i + 1],
			func(f: Vector3i, t: Vector3i) -> float: return _traffic.get_edge_cost(f, t),
			func(a: Vector3i, b: Vector3i) -> float: return Pathfinder.manhattan(a, b))
		if seg.size() <= 1:
			return
		if full_path.is_empty():
			for tile: Vector3i in seg:
				full_path.append(tile)
				full_pos.append(Vector3(tile.x, 0.1, tile.z))
		else:
			for j in range(1, seg.size()):
				var tile: Vector3i = seg[j]
				full_path.append(tile)
				full_pos.append(Vector3(tile.x, 0.1, tile.z))

	if full_path.size() <= 1:
		return

	full_path.remove_at(0)
	full_pos.remove_at(0)

	var car := _make_patrol_car()
	add_child(car)
	car.place_at(home_road, Vector3(home_road.x, 0.1, home_road.z))
	car.speed = PATROL_SPEED
	car.set_path(full_path, full_pos)
	_patrols.append(car)

# ── Process ───────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var i := _patrols.size() - 1
	while i >= 0:
		var car: CarProxy = _patrols[i]
		if not is_instance_valid(car) or car.is_path_empty():
			if is_instance_valid(car):
				car.queue_free()
			_patrols.remove_at(i)
		i -= 1

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_patrol_car() -> CarProxy:
	var car := CarProxy.new()
	if _car_packed:
		var model := _car_packed.instantiate() as Node3D
		model.scale = Vector3.ONE * CAR_SCALE
		model.rotation_degrees.y = 270.0
		var mesh: Mesh = _mesh_from_scene(_car_packed)
		model.position.y = -mesh.get_aabb().position.y * CAR_SCALE if mesh else 0.0
		car.add_child(model)
	else:
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
