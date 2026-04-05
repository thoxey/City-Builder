extends PluginBase

## Population system.
## Spawns people per residential building equal to BuildingProfile.capacity.
##
## Journey logic:
##   • Hour  8 → rush: all idle residents head to a workplace
##   • Hours 17–22 → trickle: ~35% of idle people head to commercial each hour
##   • Hour 23 → last orders: idle people not at origin head home
##   • Otherwise → random destination after idle timer
##
## Short distances (≤ WALK_THRESHOLD tiles) → walk along placed tiles.
## Long distances → walk 1 tile to road → CarManager civilian car → walk last mile.

const PEOPLE_PER_BUILDING := 2      # fallback when BuildingProfile is missing
const WALK_THRESHOLD      := 6
const SIDEWALK_OFFSET     := 0.38   # how far from road centre people walk (left of direction)
const DEST_WAIT_MIN       := 4.0
const DEST_WAIT_MAX       := 10.0
const SPAWN_STAGGER       := 1.2
const WALK_HEIGHT         := 0.1
const COMMERCIAL_TRICKLE  := 0.35

const PERSON_MODEL_PATH := "res://models/Meshy_AI_Bluecoat_Guard_0403170555/Meshy_AI_Bluecoat_Guard_0403170555_texture.glb"
const PERSON_SCALE      := 0.12
const PERSON_MODEL_ROT_Y := 0.0
const MAX_PERSON_INSTANCES := 512

enum PersonState { IDLE, WALKING_TO_ROAD, IN_CAR, WALKING_TO_DEST }

# ── DI ────────────────────────────────────────────────────────────────────────

var _road_network: PluginBase
var _car_manager:  PluginBase
var _day_night:    PluginBase

func get_plugin_name() -> String: return "People"
func get_dependencies() -> Array[String]: return ["RoadNetwork", "CarManager", "DayNight"]

func inject(deps: Dictionary) -> void:
	_road_network = deps.get("RoadNetwork")
	_car_manager  = deps.get("CarManager")
	_day_night    = deps.get("DayNight")

# ── MultiMesh pool ────────────────────────────────────────────────────────────

var _mm:           MultiMeshInstance3D
var _free_indices: Array[int] = []
var _ground_y:     float      = 0.0

# ── People state ──────────────────────────────────────────────────────────────

var _people:  Array[PersonSlot] = []
var _home:    Dictionary = {}   # PersonSlot → Vector3i  (current base tile)
var _origin:  Dictionary = {}   # PersonSlot → Vector3i  (fixed spawn tile)
var _dest:    Dictionary = {}   # PersonSlot → Vector3i
var _state:   Dictionary = {}   # PersonSlot → PersonState
var _timer:   Dictionary = {}   # PersonSlot → float

var _journey_by_person: Dictionary = {}   # PersonSlot → int journey_id
var _person_by_journey: Dictionary = {}   # int journey_id → PersonSlot

var _current_hour: float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_setup_multimesh()
	_car_manager.journey_completed.connect(_on_journey_completed)
	GameEvents.structure_placed.connect(func(_a, _b, _c): _rebuild())
	GameEvents.structure_demolished.connect(func(_a): _rebuild())
	GameEvents.map_loaded.connect(func(_a): _rebuild())
	_day_night.hour_changed.connect(_on_hour)
	_rebuild()

func _setup_multimesh() -> void:
	var mesh := _mesh_from_glb(PERSON_MODEL_PATH)
	_ground_y = (-mesh.get_aabb().position.y * PERSON_SCALE) if mesh else 0.0

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = MAX_PERSON_INSTANCES
	mm.mesh = mesh if mesh else _fallback_mesh()

	for i in MAX_PERSON_INSTANCES:
		mm.set_instance_transform(i, _hidden_transform())
		_free_indices.append(i)

	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	add_child(_mm)

	if not mesh:
		push_warning("[People] model not found: %s — using capsule fallback" % PERSON_MODEL_PATH)

# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	_clear_people()
	_spawn_people()
	print("[People] %d people across %d residential buildings" % [
			_people.size(), _get_tiles_by_category("residential").size()])

func _clear_people() -> void:
	for person: PersonSlot in _people:
		if _state.get(person) == PersonState.IN_CAR:
			var jid: int = _journey_by_person.get(person, -1)
			if jid >= 0:
				_car_manager.cancel_journey(jid)
		_mm.multimesh.set_instance_transform(person.slot_index, _hidden_transform())
		_free_indices.append(person.slot_index)
	_people.clear()
	_home.clear()
	_origin.clear()
	_dest.clear()
	_state.clear()
	_timer.clear()
	_journey_by_person.clear()
	_person_by_journey.clear()

func _spawn_people() -> void:
	var residential := _get_tiles_by_category("residential")
	if residential.is_empty():
		return
	var stagger := 0
	for tile: Vector3i in residential:
		var sid: int = GameState.gridmap.get_cell_item(tile)
		var profile: BuildingProfile = GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		var count: int = profile.capacity if profile else PEOPLE_PER_BUILDING
		for i in count:
			if _free_indices.is_empty():
				push_warning("[People] person pool exhausted!")
				return
			var person := PersonSlot.new()
			person.slot_index   = _free_indices.pop_back()
			person.current_tile = tile
			person.position     = Vector3(tile.x, WALK_HEIGHT, tile.z) + \
					Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
			person.visible = true
			_people.append(person)
			_home[person]   = tile
			_origin[person] = tile
			_state[person]  = PersonState.IDLE
			_timer[person]  = stagger * SPAWN_STAGGER + randf_range(0.0, SPAWN_STAGGER)
			stagger += 1

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	for person: PersonSlot in _people:
		match _state[person]:
			PersonState.IDLE:
				_timer[person] -= delta
				if _timer[person] <= 0.0:
					_assign_journey(person)

			PersonState.WALKING_TO_ROAD:
				_advance_person(person, delta)
				if person._waypoints.is_empty():
					_begin_car_journey(person)

			PersonState.IN_CAR:
				pass   # driven by _on_journey_completed signal

			PersonState.WALKING_TO_DEST:
				_advance_person(person, delta)
				if person._waypoints.is_empty():
					_arrive_at_dest(person)

	_update_multimesh(delta)

# ── Hour events ───────────────────────────────────────────────────────────────

func _on_hour(hour: float) -> void:
	_current_hour = hour
	var h := int(hour)

	if h == 8:
		var workplaces := _get_tiles_by_category("workplace")
		if not workplaces.is_empty():
			for person: PersonSlot in _people:
				if _state[person] == PersonState.IDLE:
					var dest: Vector3i = workplaces[randi() % workplaces.size()]
					if dest != _home[person]:
						_begin_journey(person, dest)

	elif h >= 17 and h <= 22:
		var commercial := _get_tiles_by_category("commercial")
		if not commercial.is_empty():
			for person: PersonSlot in _people:
				if _state[person] == PersonState.IDLE and randf() < COMMERCIAL_TRICKLE:
					var dest: Vector3i = commercial[randi() % commercial.size()]
					if dest != _home[person]:
						_begin_journey(person, dest)

	elif h == 23:
		for person: PersonSlot in _people:
			if _state[person] == PersonState.IDLE:
				var origin: Vector3i = _origin[person]
				if origin != _home[person]:
					_begin_journey(person, origin)

# ── Journey logic ─────────────────────────────────────────────────────────────

func _assign_journey(person: PersonSlot) -> void:
	var home_tile: Vector3i = _home[person]
	var h := int(_current_hour)

	var preferred: Array[Vector3i]
	if h >= 8 and h < 17:
		preferred = _get_tiles_by_category("workplace")
	elif h >= 17 and h <= 22:
		preferred = _get_tiles_by_category("commercial")
	else:
		preferred = _get_tiles_by_category("residential")

	var candidates: Array[Vector3i] = []
	for t: Vector3i in preferred:
		if t != home_tile:
			candidates.append(t)

	if candidates.is_empty():
		for t: Vector3i in _road_network.get_building_tiles():
			if t != home_tile:
				candidates.append(t)

	if candidates.is_empty():
		_timer[person] = randf_range(DEST_WAIT_MIN, DEST_WAIT_MAX)
		return

	_begin_journey(person, candidates[randi() % candidates.size()])

func _begin_journey(person: PersonSlot, dest_tile: Vector3i) -> void:
	var home_tile: Vector3i = _home[person]
	_dest[person] = dest_tile

	var dist: int = abs(dest_tile.x - home_tile.x) + abs(dest_tile.z - home_tile.z)
	var home_stops: Array[Vector3i] = _road_network.get_stops_for_building(home_tile)
	var dest_stops: Array[Vector3i] = _road_network.get_stops_for_building(dest_tile)
	var can_drive: bool = dist > WALK_THRESHOLD and not home_stops.is_empty() and not dest_stops.is_empty()

	if can_drive:
		# Walk 1 tile to the nearest road stop first, then hand off to CarManager
		var road_tile: Vector3i = home_stops[0]
		person._waypoints      = [Vector3(road_tile.x, WALK_HEIGHT, road_tile.z)]
		person._waypoint_tiles = [road_tile]
		_state[person] = PersonState.WALKING_TO_ROAD
	else:
		_start_walk(person, home_tile, dest_tile)

func _begin_car_journey(person: PersonSlot) -> void:
	var home_tile: Vector3i = _home[person]
	var dest_tile: Vector3i = _dest[person]
	var route: Array[Vector3i] = [dest_tile]
	var jid: int = _car_manager.request_journey(home_tile, route, CarSlot.CarType.CIVILIAN)
	if jid < 0:
		# Pool full — walk instead
		_start_walk(person, person.current_tile, dest_tile)
		return
	_journey_by_person[person] = jid
	_person_by_journey[jid]    = person
	person.visible = false
	_state[person] = PersonState.IN_CAR

func _on_journey_completed(jid: int, arrived_road_tile: Vector3i, exit_pos: Vector3) -> void:
	var person: PersonSlot = _person_by_journey.get(jid)
	if not person:
		return
	_person_by_journey.erase(jid)
	_journey_by_person.erase(person)

	person.current_tile = arrived_road_tile
	person.position     = Vector3(exit_pos.x, WALK_HEIGHT, exit_pos.z)
	person.visible      = true
	_start_walk(person, arrived_road_tile, _dest[person])

func _start_walk(person: PersonSlot, from_tile: Vector3i, to_tile: Vector3i) -> void:
	var path := _walk_path(from_tile, to_tile)
	var positions: Array[Vector3] = []
	for i in path.size():
		var t: Vector3i = path[i]
		var pos := Vector3(t.x, WALK_HEIGHT, t.z)
		# On road tiles: walk along the left edge (UK pavement side)
		if _is_road_tile(t):
			var prev: Vector3i = path[i - 1] if i > 0 else from_tile
			var dx := t.x - prev.x
			var dz := t.z - prev.z
			if dx != 0 or dz != 0:
				var left := Vector3(-float(dz), 0.0, float(dx)).normalized() * SIDEWALK_OFFSET
				pos += left
		positions.append(pos)
	person._waypoints.assign(positions)
	person._waypoint_tiles.assign(path)
	_state[person] = PersonState.WALKING_TO_DEST

func _is_road_tile(tile: Vector3i) -> bool:
	var sid: int = GameState.gridmap.get_cell_item(tile)
	return _road_network.road_meta_for(sid) != null

func _arrive_at_dest(person: PersonSlot) -> void:
	var old_home: Vector3i = _home[person]
	_home[person] = _dest[person]
	_dest[person] = old_home
	_state[person] = PersonState.IDLE
	_timer[person] = randf_range(DEST_WAIT_MIN, DEST_WAIT_MAX)

func _abort_to_idle(person: PersonSlot) -> void:
	person.visible = true
	_journey_by_person.erase(person)
	_state[person] = PersonState.IDLE
	_timer[person] = randf_range(DEST_WAIT_MIN, DEST_WAIT_MAX)

# ── Person movement ───────────────────────────────────────────────────────────

func _advance_person(person: PersonSlot, delta: float) -> void:
	if person._waypoints.is_empty():
		return
	var target: Vector3 = person._waypoints[0]
	var step:   float   = PersonSlot.WALK_SPEED * delta
	var dist:   float   = person.position.distance_to(target)

	var d := target - person.position
	d.y = 0.0
	if d.length_squared() > 0.001:
		person._facing = person._facing.slerp(Basis.looking_at(d.normalized()), delta * PersonSlot.ROT_SPEED)

	if step >= dist:
		person.position     = target
		person.current_tile = person._waypoint_tiles[0]
		person._waypoints.pop_front()
		person._waypoint_tiles.pop_front()
	else:
		person.position += person.position.direction_to(target) * step

func _update_multimesh(delta: float) -> void:
	for person: PersonSlot in _people:
		if not person.visible:
			_mm.multimesh.set_instance_transform(person.slot_index, _hidden_transform())
			continue
		var walking: bool = not person._waypoints.is_empty()
		if walking:
			person._bob_time += delta * PersonSlot.BOB_FREQ * TAU
		else:
			person._bob_time = 0.0
		var bob_y: float = sin(person._bob_time) * PersonSlot.BOB_HEIGHT if walking else 0.0
		var world_pos := person.position + Vector3(0.0, bob_y + _ground_y, 0.0)
		var rot    := Basis(Vector3.UP, deg_to_rad(PERSON_MODEL_ROT_Y))
		var scaled := person._facing * rot * Basis().scaled(Vector3.ONE * PERSON_SCALE)
		_mm.multimesh.set_instance_transform(person.slot_index, Transform3D(scaled, world_pos))

# ── Walk pathfinding ──────────────────────────────────────────────────────────

func _walk_path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	if from == to:
		return []
	var path: Array[Vector3i] = Pathfinder.find_path(
		_road_network.get_walk_graph(), from, to,
		func(_f: Vector3i, _t: Vector3i) -> float: return 1.0,
		func(a: Vector3i, b: Vector3i) -> float: return Pathfinder.manhattan(a, b))
	if path.size() > 1:
		path.remove_at(0)
		return path
	return [to]   # no connected path — direct fallback

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_tiles_by_category(category: String) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for cell: Vector3i in GameState.gridmap.get_used_cells():
		var sid: int = GameState.gridmap.get_cell_item(cell)
		if sid < 0 or sid >= GameState.structures.size():
			continue
		var profile: BuildingProfile = GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if profile and profile.category == category:
			result.append(cell)
	return result

func _mesh_from_glb(path: String) -> Mesh:
	var packed := load(path) as PackedScene
	if not packed:
		return null
	var state := packed.get_state()
	for i in state.get_node_count():
		if state.get_node_type(i) == "MeshInstance3D":
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i, j) == "mesh":
					return state.get_node_property_value(i, j) as Mesh
	return null

func _fallback_mesh() -> Mesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.18
	return mesh

func _hidden_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, -9999.0, 0.0))
