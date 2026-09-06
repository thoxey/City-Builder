extends PluginBase

## Population system.
## Spawns people per residential building equal to BuildingProfile.capacity.
##
## Community owns resident purpose and exact destination. This plugin only projects
## that intent through the existing person/car presentation pools.
##
## Short distances (≤ WALK_THRESHOLD tiles) → walk along placed tiles.
## Long distances → walk 1 tile to road → CarManager civilian car → walk last mile.

const PEOPLE_PER_BUILDING := 2      # fallback when BuildingProfile is missing
const WALK_THRESHOLD      := 6
const SIDEWALK_OFFSET     := 0.38   # how far from road centre people walk (left of direction)
const SPAWN_STAGGER       := 1.2
const CAR_RETRY_INTERVAL  := 0.5
const WALK_HEIGHT         := 0.1

const PERSON_MODEL_PATH := "res://models/Meshy_AI_Bluecoat_Guard_0403170555/Meshy_AI_Bluecoat_Guard_0403170555_texture.glb"
const PERSON_SCALE      := 0.12
const PERSON_MODEL_ROT_Y := 0.0
const MAX_PERSON_INSTANCES := 512

enum PersonState { IDLE, WALKING_TO_ROAD, IN_CAR, WALKING_TO_DEST }

# ── DI ────────────────────────────────────────────────────────────────────────

var _road_network: PluginBase
var _car_manager:  PluginBase
var _day_night:    PluginBase
var _community:    PluginBase

func get_plugin_name() -> String: return "People"
func get_dependencies() -> Array[String]: return ["RoadNetwork", "CarManager", "DayNight", "Community"]

func inject(deps: Dictionary) -> void:
	_road_network = deps.get("RoadNetwork")
	_car_manager  = deps.get("CarManager")
	_day_night    = deps.get("DayNight")
	_community    = deps.get("Community")

# ── MultiMesh pool ────────────────────────────────────────────────────────────

var _mm:           MultiMeshInstance3D
var _free_indices: Array[int] = []
var _ground_y:     float      = 0.0

# ── People state ──────────────────────────────────────────────────────────────

var _people:  Array[PersonSlot] = []
var _resident_index: Dictionary = {}
var _home:    Dictionary = {}   # PersonSlot → Vector3i  (current base tile)
var _origin:  Dictionary = {}   # PersonSlot → Vector3i  (fixed spawn tile)
var _dest:    Dictionary = {}   # PersonSlot → Vector3i
var _state:   Dictionary = {}   # PersonSlot → PersonState
var _timer:   Dictionary = {}   # PersonSlot → float

var _journey_by_person: Dictionary = {}   # PersonSlot → int journey_id
var _person_by_journey: Dictionary = {}   # int journey_id → PersonSlot

var _current_hour: float = 0.0
var _walk_route_threshold: int = WALK_THRESHOLD
var _plan_key_by_journey: Dictionary = {}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	_load_walk_threshold()
	_setup_multimesh()
	_car_manager.journey_completed.connect(_on_journey_completed)
	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	GameEvents.community_resident_arrived.connect(_on_resident_arrived)
	GameEvents.community_resident_departed.connect(_on_resident_departed)
	GameEvents.community_resident_rehomed.connect(_on_resident_rehomed)
	_day_night.hour_changed.connect(_on_hour)
	_rebuild()

func _load_walk_threshold() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/community/balance.json"))
	if parsed is Dictionary:
		_walk_route_threshold = int(parsed.get("civilian_walk_route_threshold", WALK_THRESHOLD))

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
	var residential_count := _get_tiles_by_category("residential").size() if GameState.gridmap else 0
	print("[People] %d people across %d residential buildings" % [
		_people.size(), residential_count])

func _clear_people() -> void:
	for person: PersonSlot in _people:
		if person.state == PersonSlot.VisualState.IN_CAR:
			var jid: int = _journey_by_person.get(person, -1)
			if jid >= 0:
				_car_manager.cancel_journey(jid)
		if _mm and _mm.multimesh:
			_mm.multimesh.set_instance_transform(person.slot_index, _hidden_transform())
		_free_indices.append(person.slot_index)
	_people.clear()
	_resident_index.clear()
	_home.clear()
	_origin.clear()
	_dest.clear()
	_state.clear()
	_timer.clear()
	_journey_by_person.clear()
	_person_by_journey.clear()

func _spawn_people() -> void:
	if _community and _community.has_method("get_civilian_intents"):
		var records: Array = _community.get_civilian_intents()
		var stagger := 0
		for record: Dictionary in records:
			if stagger >= MAX_PERSON_INSTANCES or _free_indices.is_empty():
				break
			var home_value: Variant = CommunityConstants.coordinate(record.get("home_anchor"))
			if home_value == null:
				continue
			_spawn_person(Vector3i(home_value.x, 0, home_value.y), stagger,
				int(record.get("resident_seed", record.get("seed", record.get("resident_id", 1)))),
				int(record.get("resident_id", -1)))
			var person: PersonSlot = _people.back()
			person.intent = record.duplicate(true)
			_reconcile_person(person, record)
			stagger += 1
		return
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
			_spawn_person(tile, stagger, hash([tile.x, tile.z, i]))
			stagger += 1

func _spawn_person(tile: Vector3i, stagger: int, seed: int, resident_id: int = -1) -> void:
	var presentation := seeded_presentation(seed, int(_current_hour), "home")
	var offset: Vector2 = presentation["spawn_offset"]
	var person := PersonSlot.new()
	person.slot_index = _free_indices.pop_back()
	person.current_tile = tile
	person.position = Vector3(tile.x + offset.x, WALK_HEIGHT, tile.z + offset.y)
	person.visible = true
	person.resident_id = resident_id
	person.resident_seed = seed
	person.home_anchor = Vector2i(tile.x, tile.z)
	person.current_place = person.home_anchor
	person.destination_anchor = person.home_anchor
	person.departure_offset = stagger * SPAWN_STAGGER + float(presentation["departure_offset"])
	person.state = PersonSlot.VisualState.AT_HOME
	_people.append(person)
	if resident_id >= 0:
		_resident_index[resident_id] = person
	_home[person] = tile
	_origin[person] = tile
	_state[person] = PersonState.IDLE
	_timer[person] = person.departure_offset

static func seeded_presentation(seed: int, absolute_hour: int, purpose: String) -> Dictionary:
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = seed
	var context_rng := RandomNumberGenerator.new()
	context_rng.seed = seed ^ (absolute_hour * 1103515245) ^ purpose.hash()
	return {
		"spawn_offset": Vector2(spawn_rng.randf_range(-0.25, 0.25), spawn_rng.randf_range(-0.25, 0.25)),
		"departure_offset": context_rng.randf_range(0.0, SPAWN_STAGGER),
	}

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_revalidate_stale_plans()
	var ordered: Array[PersonSlot] = _people.duplicate()
	ordered.sort_custom(func(a, b): return a.resident_id < b.resident_id)
	for person: PersonSlot in ordered:
		match person.state:
			PersonSlot.VisualState.WALKING_TO_STOP:
				_advance_person(person, delta)
				if person._waypoints.is_empty():
					_begin_car_journey(person)
			PersonSlot.VisualState.WAITING_FOR_CAR:
				person.car_retry_remaining = maxf(0.0, person.car_retry_remaining - delta)
				if is_zero_approx(person.car_retry_remaining):
					_begin_car_journey(person)
			PersonSlot.VisualState.IN_CAR:
				pass   # driven by _on_journey_completed signal
			PersonSlot.VisualState.WALKING_ROUTE, PersonSlot.VisualState.WALKING_FROM_STOP:
				_advance_person(person, delta)
				if person._waypoints.is_empty():
					_arrive_for_intent(person)

	_update_multimesh(delta)

# ── Hour events ───────────────────────────────────────────────────────────────

func _on_hour(hour: float) -> void:
	_current_hour = hour
	_reconcile_all()

func _reconcile_all() -> void:
	if not _community or not _community.has_method("get_civilian_intents"):
		return
	for intent: Dictionary in _community.get_civilian_intents():
		var person: PersonSlot = _resident_index.get(int(intent.get("resident_id", -1)))
		if person:
			_reconcile_person(person, intent)

func _reconcile_person(person: PersonSlot, intent: Dictionary) -> void:
	var destination_value: Variant = CommunityConstants.coordinate(intent.get("destination_anchor"))
	var revision := int(intent.get("assignment_revision", 0))
	var purpose := String(intent.get("purpose", "home"))
	var unchanged: bool = person.purpose == purpose and person.destination_anchor == destination_value \
		and bool(person.intent.get("reachable", true)) == bool(intent.get("reachable", true))
	person.intent = intent.duplicate(true)
	person.intent_revision = revision
	person.purpose = purpose
	person.destination_anchor = destination_value
	if destination_value == null:
		_cancel_person_journey(person)
		person.state = PersonSlot.VisualState.UNHOUSED
		person.blocked_reason = String(intent.get("blocked_reason", "resident_unhoused"))
		return
	if unchanged:
		return
	person.departure_offset = float(seeded_presentation(person.resident_seed,
		int(intent.get("absolute_hour", _current_hour)), purpose)["departure_offset"])
	person.blocked_reason = ""
	person.car_retry_remaining = 0.0
	_cancel_person_journey(person)
	if person.current_place == destination_value:
		_arrive_for_intent(person)
		return
	_begin_journey(person, Vector3i(destination_value.x, 0, destination_value.y))

func _cancel_person_journey(person: PersonSlot) -> void:
	if person.journey_id >= 0 and _car_manager:
		_car_manager.cancel_journey(person.journey_id)
		_person_by_journey.erase(person.journey_id)
	_journey_by_person.erase(person)
	person.journey_id = -1
	person.visible = true
	person._waypoints.clear()
	person._waypoint_tiles.clear()

# ── Incremental event reconciliation ─────────────────────────────────────────

func _on_structure_placed(_position: Vector3i, _structure_index: int, _orientation: int) -> void:
	# New topology cannot invalidate a route already being executed. Community's
	# assignment revision decides whether any authoritative intent changed.
	_reconcile_all()

func _on_structure_demolished(position: Vector3i) -> void:
	_reconcile_all()
	_revalidate_stale_plans(position, true)

func _on_map_loaded(_map: Variant) -> void:
	_rebuild()

func reconstruct_from_authority() -> void:
	_rebuild()

func _on_resident_arrived(_resident_id: int, _home_anchor: Vector2i) -> void:
	_sync_roster()

func _on_resident_departed(_resident_id: int, _reason: String) -> void:
	_sync_roster()

func _on_resident_rehomed(resident_id: int, home_anchor: Vector2i) -> void:
	var person: PersonSlot = _resident_index.get(resident_id)
	if person:
		var old_home: Variant = person.home_anchor
		person.home_anchor = home_anchor
		if person.current_place == old_home:
			person.current_place = home_anchor
	_sync_roster()

func _sync_roster() -> void:
	if not _community or not _community.has_method("get_civilian_intents"):
		return
	var intents: Array = _community.get_civilian_intents()
	intents.sort_custom(func(a, b): return int(a.get("resident_id", -1)) < int(b.get("resident_id", -1)))
	var desired: Dictionary = {}
	for intent: Dictionary in intents:
		if desired.size() >= MAX_PERSON_INSTANCES:
			break
		if CommunityConstants.coordinate(intent.get("home_anchor")) != null:
			desired[int(intent.get("resident_id", -1))] = intent
	var existing_ids: Array = _resident_index.keys()
	existing_ids.sort()
	for resident_id in existing_ids:
		if not desired.has(resident_id):
			_remove_person(_resident_index[resident_id])
	for resident_id in desired:
		var intent: Dictionary = desired[resident_id]
		var person: PersonSlot = _resident_index.get(resident_id)
		if person:
			_reconcile_person(person, intent)
		elif not _free_indices.is_empty():
			var home: Vector2i = CommunityConstants.coordinate(intent.get("home_anchor"))
			_spawn_person(Vector3i(home.x, 0, home.y), _people.size(),
				int(intent.get("resident_seed", resident_id)), resident_id)
			person = _people.back()
			person.intent = intent.duplicate(true)
			_reconcile_person(person, intent)

func _remove_person(person: PersonSlot) -> void:
	_cancel_person_journey(person)
	if _mm and _mm.multimesh:
		_mm.multimesh.set_instance_transform(person.slot_index, _hidden_transform())
	if person.slot_index >= 0 and person.slot_index not in _free_indices:
		_free_indices.append(person.slot_index)
	_people.erase(person)
	_resident_index.erase(person.resident_id)
	_home.erase(person); _origin.erase(person); _dest.erase(person); _state.erase(person); _timer.erase(person)

func _plan_depends_on(person: PersonSlot, cell: Vector3i) -> bool:
	if person.journey_plan.is_empty(): return false
	if person.journey_plan.get("origin_stop") == cell or person.journey_plan.get("destination_stop") == cell:
		return true
	return cell in person.journey_plan.get("road_path_vectors", [])

func _revalidate_stale_plans(changed_cell: Variant = null, force_affected := false) -> void:
	if not _road_network or not _road_network.has_method("get_revision"):
		return
	var road_revision := int(_road_network.get_revision())
	var ordered: Array[PersonSlot] = _people.duplicate()
	ordered.sort_custom(func(a, b): return a.resident_id < b.resident_id)
	for person in ordered:
		if person.journey_plan.is_empty() or person.destination_anchor == null:
			continue
		var affected: bool = changed_cell is Vector3i and _plan_depends_on(person, changed_cell)
		if force_affected and not affected:
			continue
		if not affected and person.journey_revision == road_revision:
			continue
		var origin: Vector2i = person.current_place if person.current_place != null else person.home_anchor
		var resolved: Dictionary = _road_network.resolve_civilian_route(origin, person.destination_anchor)
		if not bool(resolved.get("ok", false)):
			_cancel_person_journey(person)
			_block(person, String(resolved.get("blocked_reason", "route_invalidated")))
			continue
		var new_path: Array[Vector3i] = []
		for record in resolved.get("road_path", []):
			var route_cell: Variant = _record_to_cell(record)
			if route_cell != null: new_path.append(route_cell)
		var same_route: bool = new_path == person.journey_plan.get("road_path_vectors", []) \
			and _record_to_cell(resolved.get("origin_stop")) == person.journey_plan.get("origin_stop") \
			and _record_to_cell(resolved.get("destination_stop")) == person.journey_plan.get("destination_stop")
		if same_route:
			person.journey_revision = road_revision
			person.journey_plan["road_revision"] = road_revision
			if person.journey_id >= 0 and _car_manager and _car_manager.has_method("refresh_resolved_journey_revision"):
				_car_manager.refresh_resolved_journey_revision(person.journey_id, person.plan_key, road_revision)
		else:
			_cancel_person_journey(person)
			_plan_journey(person)

# ── Journey logic ─────────────────────────────────────────────────────────────

func _begin_journey(person: PersonSlot, dest_tile: Vector3i) -> void:
	_dest[person] = dest_tile
	_plan_journey(person)

func _plan_journey(person: PersonSlot) -> void:
	if _road_network == null or not _road_network.has_method("resolve_civilian_route"):
		_block(person, "road_network_unavailable")
		return
	var origin: Vector2i = person.current_place if person.current_place != null else person.home_anchor
	var destination: Vector2i = person.destination_anchor
	var resolved: Dictionary = _road_network.resolve_civilian_route(origin, destination)
	if not bool(resolved.get("ok", false)):
		_block(person, String(resolved.get("blocked_reason", "disconnected")))
		return
	var path: Array[Vector3i] = []
	for record in resolved.get("road_path", []):
		var cell: Variant = _record_to_cell(record)
		if cell != null: path.append(cell)
	var origin_stop: Vector3i = _record_to_cell(resolved.get("origin_stop"))
	var destination_stop: Vector3i = _record_to_cell(resolved.get("destination_stop"))
	var mode := "walk" if int(resolved.get("route_distance", 0)) <= _walk_route_threshold else "car"
	var key_payload := {
		"resident_id":person.resident_id, "intent_revision":person.intent_revision,
		"origin":{"x":origin.x,"z":origin.y}, "destination":{"x":destination.x,"z":destination.y},
		"mode":mode, "road_revision":int(resolved.get("road_revision", 0)), "path":resolved.get("road_path", []),
	}
	person.plan_key = JSON.stringify(key_payload).sha256_text()
	person.journey_revision = int(resolved.get("road_revision", 0))
	person.mode = mode
	person.journey_plan = resolved.duplicate(true)
	person.journey_plan["plan_key"] = person.plan_key
	person.journey_plan["mode"] = mode
	person.journey_plan["origin_stop"] = origin_stop
	person.journey_plan["destination_stop"] = destination_stop
	person.journey_plan["road_path_vectors"] = path.duplicate()
	person.blocked_reason = ""
	if mode == "walk":
		_set_walk_waypoints(person, path, destination)
		person.state = PersonSlot.VisualState.WALKING_ROUTE
	else:
		_set_walk_waypoints(person, [origin_stop], Vector2i(origin_stop.x, origin_stop.z))
		person.state = PersonSlot.VisualState.WALKING_TO_STOP

func _block(person: PersonSlot, reason: String) -> void:
	person.state = PersonSlot.VisualState.BLOCKED
	person.blocked_reason = reason
	person._waypoints.clear()
	person._waypoint_tiles.clear()

func _set_walk_waypoints(person: PersonSlot, path: Array[Vector3i], destination: Vector2i) -> void:
	var cells: Array[Vector3i] = path.duplicate()
	var destination_cell := Vector3i(destination.x, 0, destination.y)
	if cells.is_empty() or cells.back() != destination_cell:
		cells.append(destination_cell)
	var positions: Array[Vector3] = []
	for cell in cells:
		positions.append(Vector3(cell.x, WALK_HEIGHT, cell.z))
	person._waypoints.assign(positions)
	person._waypoint_tiles.assign(cells)

func _begin_car_journey(person: PersonSlot) -> void:
	if person.journey_plan.is_empty():
		_block(person, "route_invalidated")
		return
	var jid: int = _car_manager.request_resolved_journey(person.resident_id,
		person.journey_plan["origin_stop"], person.journey_plan["destination_stop"],
		person.journey_plan["road_path_vectors"], person.journey_revision,
		person.plan_key, CarSlot.CarType.CIVILIAN)
	if jid < 0:
		person.state = PersonSlot.VisualState.WAITING_FOR_CAR
		person.blocked_reason = "car_pool_full"
		person.car_retry_remaining = CAR_RETRY_INTERVAL
		return
	_journey_by_person[person] = jid
	_person_by_journey[jid]    = person
	_plan_key_by_journey[jid] = person.plan_key
	person.visible = false
	person.state = PersonSlot.VisualState.IN_CAR
	person.journey_id = jid
	person.car_retry_remaining = 0.0

func _on_journey_completed(jid: int, arrived_road_tile: Vector3i, exit_pos: Vector3) -> void:
	var person: PersonSlot = _person_by_journey.get(jid)
	if not person:
		return
	var completed_key := String(_plan_key_by_journey.get(jid, ""))
	_plan_key_by_journey.erase(jid)
	_person_by_journey.erase(jid)
	_journey_by_person.erase(person)
	person.journey_id = -1
	if completed_key != person.plan_key:
		person.visible = true
		_block(person, "route_invalidated")
		return

	person.current_tile = arrived_road_tile
	person.position     = Vector3(exit_pos.x, WALK_HEIGHT, exit_pos.z)
	person.visible      = true
	var destination: Vector2i = person.destination_anchor
	_set_walk_waypoints(person, [], destination)
	person.state = PersonSlot.VisualState.WALKING_FROM_STOP

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
	person.state = PersonSlot.VisualState.WALKING_ROUTE
	person.mode = "walk"

func _is_road_tile(tile: Vector3i) -> bool:
	var sid: int = GameState.gridmap.get_cell_item(tile)
	return _road_network.road_meta_for(sid) != null

func _arrive_for_intent(person: PersonSlot) -> void:
	if person.destination_anchor == null: return
	person.current_place = person.destination_anchor
	person.current_tile = Vector3i(person.destination_anchor.x, 0, person.destination_anchor.y)
	person.state = PersonSlot.VisualState.AT_HOME if person.purpose == "home" else PersonSlot.VisualState.AT_DESTINATION
	person.blocked_reason = ""
	person.visible = true

func _arrive_at_dest(person: PersonSlot) -> void:
	_arrive_for_intent(person)

func _abort_to_idle(person: PersonSlot) -> void:
	person.visible = true
	_journey_by_person.erase(person)
	person.state = PersonSlot.VisualState.BLOCKED
	person.blocked_reason = "route_invalidated"

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
	if _mm == null or _mm.multimesh == null:
		return
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
	return []

func _record_to_cell(value: Variant) -> Variant:
	if value is Vector3i: return value
	if value is Dictionary and value.has("x") and value.has("z"):
		return Vector3i(int(value["x"]), int(value.get("y", 0)), int(value["z"]))
	return null

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

func get_civilian_snapshot() -> Dictionary:
	var rows: Array = []
	var violations: Array = []
	var seen: Dictionary = {}
	var counts_by_state: Dictionary = {}
	var counts_by_purpose: Dictionary = {}
	var blocked_by_reason: Dictionary = {}
	var intents_by_id: Dictionary = {}
	var cars_by_journey: Dictionary = {}
	var car_snapshot: Dictionary = _car_manager.get_civilian_snapshot() if _car_manager and _car_manager.has_method("get_civilian_snapshot") else {}
	for car: Dictionary in car_snapshot.get("journeys", []):
		cars_by_journey[int(car.get("journey_id", -1))] = car
	var intents: Array = _community.get_civilian_intents() if _community and _community.has_method("get_civilian_intents") else []
	for intent: Dictionary in intents:
		intents_by_id[int(intent.get("resident_id", -1))] = intent
	for person: PersonSlot in _people:
		var resident_id := person.resident_id
		if seen.has(resident_id):
			violations.append({"resident_id": resident_id, "code": "duplicate_resident_binding"})
		seen[resident_id] = true
		var intent: Dictionary = person.intent if not person.intent.is_empty() else intents_by_id.get(resident_id, {})
		if resident_id < 0 or (not intents_by_id.is_empty() and not intents_by_id.has(resident_id)):
			violations.append({"resident_id": resident_id, "code": "orphan_proxy"})
		var state_name := String(PersonSlot.STATE_NAMES.get(person.state, "blocked"))
		counts_by_state[state_name] = int(counts_by_state.get(state_name, 0)) + 1
		counts_by_purpose[person.purpose] = int(counts_by_purpose.get(person.purpose, 0)) + 1
		if not person.blocked_reason.is_empty():
			blocked_by_reason[person.blocked_reason] = int(blocked_by_reason.get(person.blocked_reason, 0)) + 1
		var authoritative_destination: Variant = intent.get("destination_anchor")
		var visible_destination: Variant = _anchor_record(person.destination_anchor)
		if not intent.is_empty() and String(intent.get("purpose", "")) != person.purpose:
			violations.append({"resident_id": resident_id, "code": "intent_purpose_mismatch"})
		if not intent.is_empty() and authoritative_destination != visible_destination:
			violations.append({"resident_id": resident_id, "code": "intent_destination_mismatch"})
		if not bool(intent.get("reachable", true)) and person.state in [PersonSlot.VisualState.WALKING_TO_STOP, PersonSlot.VisualState.WALKING_ROUTE, PersonSlot.VisualState.IN_CAR, PersonSlot.VisualState.WALKING_FROM_STOP]:
			violations.append({"resident_id": resident_id, "code": "unreachable_journey_started"})
		var travelling := person.state in [PersonSlot.VisualState.WALKING_TO_STOP, PersonSlot.VisualState.WAITING_FOR_CAR, PersonSlot.VisualState.IN_CAR, PersonSlot.VisualState.WALKING_FROM_STOP, PersonSlot.VisualState.WALKING_ROUTE]
		var allowed_waypoints: Array = person.journey_plan.get("road_path_vectors", []).duplicate()
		if person.destination_anchor != null: allowed_waypoints.append(Vector3i(person.destination_anchor.x, 0, person.destination_anchor.y))
		for waypoint in person._waypoint_tiles:
			if waypoint not in allowed_waypoints:
				violations.append({"resident_id":resident_id,"code":"invalid_waypoint_cell"})
				break
		var current_road_revision := int(_road_network.get_revision()) if _road_network and _road_network.has_method("get_revision") else person.journey_revision
		if travelling and person.journey_revision != current_road_revision:
			violations.append({"resident_id":resident_id,"code":"stale_route_revision"})
		if person.state == PersonSlot.VisualState.IN_CAR:
			var car: Dictionary = cars_by_journey.get(person.journey_id, {})
			if car.is_empty() or int(car.get("resident_id", -1)) != resident_id or String(car.get("plan_key", "")) != person.plan_key:
				violations.append({"resident_id":resident_id,"code":"missing_car_binding"})
				violations.append({"resident_id":resident_id,"code":"unexpected_car_cancellation"})
		if travelling and person.journey_plan.is_empty():
			violations.append({"resident_id":resident_id,"code":"unexpected_proxy_reset"})
		for code in person.diagnostic_faults:
			violations.append({"resident_id":resident_id,"code":code})
		rows.append({
			"resident_id": resident_id,
			"home_anchor": _anchor_record(person.home_anchor),
			"current_place": _anchor_record(person.current_place),
			"authoritative_purpose": String(intent.get("purpose", person.purpose)),
			"authoritative_destination": authoritative_destination,
			"visible_destination": visible_destination,
			"state": state_name,
			"mode": person.mode,
			"route_distance": int(person.journey_plan.get("route_distance", 0)),
			"route_revision": person.journey_revision,
			"journey_id": null if person.journey_id < 0 else person.journey_id,
			"waiting": person.state == PersonSlot.VisualState.WAITING_FOR_CAR,
			"blocked_reason": person.blocked_reason,
			"plan_key": person.plan_key,
			"waypoint_cells": person._waypoint_tiles.map(func(cell): return _cell_record(cell)),
		})
	var expected_ids: Array = intents_by_id.keys(); expected_ids.sort()
	for index in mini(expected_ids.size(), MAX_PERSON_INSTANCES):
		var expected_id: int = expected_ids[index]
		if not seen.has(expected_id) and intents_by_id[expected_id].get("home_anchor") != null:
			violations.append({"resident_id":expected_id,"code":"missing_visible_proxy_within_cap"})
	rows.sort_custom(func(a, b): return a["resident_id"] < b["resident_id"])
	violations.sort_custom(func(a, b):
		return a["resident_id"] < b["resident_id"] if a["resident_id"] != b["resident_id"] else a["code"] < b["code"])
	return {
		"schema_version": 1,
		"simulated_resident_count": intents.size(),
		"visible_count": rows.size(),
		"proxy_cap": MAX_PERSON_INSTANCES,
		"assignment_revision": int(_community.get_assignment_revision()) if _community and _community.has_method("get_assignment_revision") else 0,
		"road_revision": int(_road_network.get_revision()) if _road_network and _road_network.has_method("get_revision") else 0,
		"counts_by_state": counts_by_state,
		"counts_by_purpose": counts_by_purpose,
		"blocked_by_reason": blocked_by_reason,
		"residents": rows.duplicate(true),
		"violations": violations.duplicate(true),
	}

func _anchor_record(value: Variant) -> Variant:
	if value == null: return null
	if value is Vector2i: return {"x": value.x, "z": value.y}
	if value is Vector3i: return {"x": value.x, "z": value.z}
	if value is Dictionary: return value.duplicate(true)
	return null

func _cell_record(cell: Vector3i) -> Dictionary:
	return {"x": cell.x, "y": cell.y, "z": cell.z}
