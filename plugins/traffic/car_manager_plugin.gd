extends PluginBase

## CarManager — owns all active car journeys across all vehicle types.
##
## Uses one MultiMeshInstance3D per car type for GPU-instanced rendering.
## Callers pass building tiles; road-stop resolution happens internally.
##
## Tile reservation:
##   _reserved: Vector3i → { journey_id → {"dir": Vector2i, "slot": int} }
##   • Opposite non-zero directions share freely (different physical lanes).
##   • Same direction: up to MAX_LANE_SLOTS cars (bumper-to-bumper).
##   • Perpendicular or zero-direction always conflict.
##
## Deadlock prevention:
##   Each car's reroute threshold is staggered by journey_id so jammed cars
##   break out one at a time.  After MAX_REROUTES consecutive failures the car
##   gives up and completes silently rather than blocking forever.
##
## Usage:
##   var jid := _car_manager.request_journey(origin_tile, [dest_tile, ...], CarSlot.CarType.CIVILIAN)
##   _car_manager.journey_completed.connect(func(jid, tile, pos): ...)

const CONGESTION_PENALTY := 8.0   # pathfinding cost multiplier for occupied tiles
const REROUTE_WAIT       := 1.5   # base seconds blocked before rerouting
const REROUTE_JITTER     := 0.7   # per-car stagger range (avoids thundering herd)
const MAX_REROUTES       := 5     # give up after this many consecutive reroutes
const BUMPER_SPACING     := 0.4   # world-space gap between stacked cars
const MAX_LANE_SLOTS     := 2     # cars per lane per tile

# ── Car type definitions ───────────────────────────────────────────────────────

const _TYPE_DEFS: Dictionary = {
	CarSlot.CarType.CIVILIAN: {
		"mesh_path": "res://models/Meshy_AI_Car_0403170715/Meshy_AI_Car_0403170715_texture.glb",
		"scale": 0.15, "rot_y": 270.0, "speed": 3.0, "max": 256
	},
	CarSlot.CarType.POLICE: {
		"mesh_path": "res://models/Meshy_AI_Mini_Police_Cruiser_0403205957/Meshy_AI_Mini_Police_Cruiser_0403205957_texture.glb",
		"scale": 0.15, "rot_y": 270.0, "speed": 4.0, "max": 32
	},
	CarSlot.CarType.AMBULANCE: {
		# TODO: swap in a dedicated ambulance model
		"mesh_path": "res://models/Meshy_AI_Mini_Police_Cruiser_0403205957/Meshy_AI_Mini_Police_Cruiser_0403205957_texture.glb",
		"scale": 0.15, "rot_y": 270.0, "speed": 5.0, "max": 32
	},
}

# ── Per-type pool ──────────────────────────────────────────────────────────────

class TypePool:
	var mminstance:   MultiMeshInstance3D
	var ground_y:     float      = 0.0
	var free_indices: Array[int] = []

var _pools: Dictionary = {}

# ── Journey state ──────────────────────────────────────────────────────────────

var _active:       Dictionary = {}   # journey_id → CarSlot
var _next_id:      int        = 0
var _pending_done: Dictionary = {}   # journey_id → {"tile": Vector3i, "pos": Vector3}

## Tile reservation: Vector3i → { journey_id → {"dir": Vector2i, "slot": int} }
var _reserved: Dictionary = {}

# ── Signals ───────────────────────────────────────────────────────────────────

signal journey_completed(journey_id: int, arrived_road_tile: Vector3i, exit_pos: Vector3)

# ── DI ────────────────────────────────────────────────────────────────────────

func get_plugin_name() -> String: return "CarManager"
func get_dependencies() -> Array[String]: return ["RoadNetwork"]

var _road_network: PluginBase

func inject(deps: Dictionary) -> void:
	_road_network = deps.get("RoadNetwork")

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _plugin_ready() -> void:
	for car_type: int in _TYPE_DEFS:
		_setup_pool(car_type, _TYPE_DEFS[car_type])
	GameEvents.structure_placed.connect(func(_a, _b, _c): _cancel_all())
	GameEvents.structure_demolished.connect(func(_a): _cancel_all())
	GameEvents.map_loaded.connect(func(_a): _cancel_all())

func _setup_pool(car_type: int, def: Dictionary) -> void:
	var pool  := TypePool.new()
	var max_n: int   = def.get("max", 64)
	var scale: float = def.get("scale", 1.0)
	var mesh := _mesh_from_glb(def.mesh_path)
	pool.ground_y = (-mesh.get_aabb().position.y * scale) if mesh else 0.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count   = max_n
	mm.mesh             = mesh if mesh else _fallback_mesh()
	for i in max_n:
		mm.set_instance_transform(i, _hidden_transform())
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	pool.mminstance = mmi
	for i in max_n:
		pool.free_indices.append(i)
	_pools[car_type] = pool

func _cancel_all() -> void:
	for jid: int in _active.keys():
		_release_silent(_active[jid])
	_active.clear()
	_reserved.clear()
	_pending_done.clear()

# ── Public API ────────────────────────────────────────────────────────────────

## Spawn a car at origin_tile and drive through route (ordered building tiles).
## loop=true → route restarts after last destination (patrol cars).
## Returns journey_id ≥ 0, or -1 on failure.
func request_journey(origin_tile: Vector3i, route: Array[Vector3i],
		car_type: int, loop: bool = false) -> int:
	var pool: TypePool = _pools.get(car_type)
	if not pool or pool.free_indices.is_empty():
		push_warning("[CarManager] pool full for type %d" % car_type)
		return -1
	if route.is_empty():
		push_warning("[CarManager] empty route from %s" % str(origin_tile))
		return -1
	var origin_stops: Array[Vector3i] = _road_network.get_stops_for_building(origin_tile)
	if origin_stops.is_empty():
		push_warning("[CarManager] no road access at %s" % str(origin_tile))
		return -1

	var def: Dictionary = _TYPE_DEFS[car_type]
	var slot := CarSlot.new()
	slot.journey_id   = _next_id
	_next_id         += 1
	slot.car_type     = car_type
	slot.route        = route.duplicate()
	slot.loop         = loop
	slot.speed        = def.get("speed", 3.0)
	slot.slot_index   = pool.free_indices.pop_back()
	slot.current_tile = origin_stops[0]
	slot.position     = _road_network.get_lane_position(origin_stops[0], Vector2i.ZERO)
	_claim_tile(slot.current_tile, slot.journey_id, Vector2i.ZERO)

	_active[slot.journey_id] = slot
	_pathfind_next(slot)
	return slot.journey_id

func cancel_journey(journey_id: int) -> void:
	var slot: CarSlot = _active.get(journey_id)
	if not slot:
		return
	_release_silent(slot)
	_active.erase(journey_id)

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	for jid: int in _active:
		if jid in _pending_done:
			continue
		var slot: CarSlot = _active[jid]
		_advance(slot, delta)
		if not jid in _pending_done:
			_write_transform(slot)

	for jid: int in _pending_done:
		var data: Dictionary = _pending_done[jid]
		_active.erase(jid)
		journey_completed.emit(jid, data["tile"], data["pos"])
	_pending_done.clear()

# ── Movement ──────────────────────────────────────────────────────────────────

func _advance(slot: CarSlot, delta: float) -> void:
	if slot._waypoints.is_empty():
		return

	var next_tile: Vector3i = slot._waypoint_tiles[0]
	var entry_dir: Vector2i = Vector2i(
		next_tile.x - slot.current_tile.x,
		next_tile.z - slot.current_tile.z)

	# ── Blocked? ──────────────────────────────────────────────────────────────
	if not _tile_is_clear(next_tile, slot.journey_id, entry_dir):
		slot.waiting   = true
		slot.wait_time += delta
		# Stagger reroute time per car to break deadlocks one at a time
		var threshold: float = REROUTE_WAIT + fmod(slot.journey_id * 0.31, REROUTE_JITTER)
		if slot.wait_time >= threshold:
			slot.wait_time = 0.0
			slot.reroute_count += 1
			if slot.reroute_count > MAX_REROUTES:
				# Truly stuck — give up gracefully rather than blocking forever
				_complete(slot)
				return
			slot._waypoints.clear()
			slot._waypoint_tiles.clear()
			_pathfind_next(slot)
		return

	# ── Clear to move ─────────────────────────────────────────────────────────
	slot.waiting   = false
	slot.wait_time = 0.0
	_claim_tile(next_tile, slot.journey_id, entry_dir)

	var target: Vector3 = slot._waypoints[0]
	var dist:   float   = slot.position.distance_to(target)
	var step:   float   = slot.speed * delta

	# Update rotation progress for this segment
	if slot._seg_total_dist > 0.001:
		slot._seg_progress = clampf(1.0 - dist / slot._seg_total_dist, 0.0, 1.0)

	if step >= dist:
		_release_tile(slot.current_tile, slot.journey_id)
		slot.position     = target
		slot.current_tile = next_tile
		# Read back lane slot — may have been promoted while in transit
		var claims: Dictionary = _reserved.get(next_tile, {})
		if claims.has(slot.journey_id):
			slot.lane_slot = claims[slot.journey_id]["slot"]
		slot._waypoints.pop_front()
		slot._waypoint_tiles.pop_front()
		slot.reroute_count = 0   # successfully moved a tile — reset counter
		# Begin the next rotation segment
		if not slot._waypoints.is_empty():
			var nn_tile  := slot._waypoint_tiles[0]
			var new_dir  := Vector2i(nn_tile.x - next_tile.x, nn_tile.z - next_tile.z)
			slot.travel_dir       = new_dir
			slot._seg_start_basis = slot._seg_end_basis   # arrived facing _seg_end
			slot._seg_end_basis   = _dir_to_basis(new_dir)
			slot._seg_total_dist  = slot.position.distance_to(slot._waypoints[0])
			slot._seg_progress    = 0.0
		if slot._waypoints.is_empty():
			_on_segment_done(slot)
	else:
		slot.position += slot.position.direction_to(target) * step

func _on_segment_done(slot: CarSlot) -> void:
	slot.route_index += 1
	if slot.route_index >= slot.route.size():
		if slot.loop:
			slot.route_index = 0
		else:
			_complete(slot)
			return
	_pathfind_next(slot)

func _complete(slot: CarSlot) -> void:
	_release_tile(slot.current_tile, slot.journey_id)
	_pools[slot.car_type].free_indices.append(slot.slot_index)
	_hide_slot(slot)
	_pending_done[slot.journey_id] = {"tile": slot.current_tile, "pos": slot.position}

func _release_silent(slot: CarSlot) -> void:
	for tile: Vector3i in _reserved.keys():
		if _reserved[tile].has(slot.journey_id):
			_release_tile(tile, slot.journey_id)
	var pool: TypePool = _pools.get(slot.car_type)
	if pool:
		pool.free_indices.append(slot.slot_index)
	_hide_slot(slot)

# ── Pathfinding ───────────────────────────────────────────────────────────────

func _pathfind_next(slot: CarSlot) -> void:
	var dest_building: Vector3i = slot.route[slot.route_index]
	var dest_stops: Array[Vector3i] = _road_network.get_stops_for_building(dest_building)
	if dest_stops.is_empty():
		push_warning("[CarManager] no road stop for %s — skipping" % str(dest_building))
		_skip_or_complete(slot)
		return

	var goal: Vector3i = dest_stops[0]
	if goal == slot.current_tile:
		_on_segment_done(slot)
		return

	var path: Array[Vector3i] = Pathfinder.find_path(
		_road_network.get_road_graph(), slot.current_tile, goal,
		func(f: Vector3i, t: Vector3i) -> float:
			var base: float = _road_network.get_edge_cost(f, t)
			var dir: Vector2i = Vector2i(t.x - f.x, t.z - f.z)
			return base * CONGESTION_PENALTY if not _tile_is_clear(t, slot.journey_id, dir) else base,
		func(a: Vector3i, b: Vector3i) -> float: return Pathfinder.manhattan(a, b))

	if path.size() <= 1:
		push_warning("[CarManager] no path %s → %s" % [str(slot.current_tile), str(goal)])
		_skip_or_complete(slot)
		return

	path.remove_at(0)
	var positions: Array[Vector3] = []
	var prev: Vector3i = slot.current_tile
	for tile: Vector3i in path:
		var dir := Vector2i(tile.x - prev.x, tile.z - prev.z)
		positions.append(_road_network.get_lane_position(tile, dir))
		prev = tile
	slot._waypoints.assign(positions)
	slot._waypoint_tiles.assign(path)

	if not slot._waypoints.is_empty():
		var first_tile := slot._waypoint_tiles[0]
		var first_dir  := Vector2i(
			first_tile.x - slot.current_tile.x,
			first_tile.z - slot.current_tile.z)
		var new_basis := _dir_to_basis(first_dir)
		if slot.travel_dir == Vector2i.ZERO:
			# First ever path — snap directly to correct orientation, no spin-up
			slot._seg_start_basis = new_basis
			slot._seg_end_basis   = new_basis
		else:
			# Reroute or next segment — carry current visual heading as start
			slot._seg_start_basis = slot._seg_start_basis.slerp(
				slot._seg_end_basis, slot._seg_progress)
			slot._seg_end_basis = new_basis
		slot.travel_dir      = first_dir
		slot._seg_total_dist = slot.position.distance_to(slot._waypoints[0])
		slot._seg_progress   = 0.0
		# Re-claim current tile in the correct lane now direction is known
		if slot.travel_dir != Vector2i.ZERO:
			_release_tile(slot.current_tile, slot.journey_id)
			var assigned := _claim_tile(slot.current_tile, slot.journey_id, slot.travel_dir)
			slot.lane_slot = assigned
			slot.position  = _road_network.get_lane_position(slot.current_tile, slot.travel_dir)

func _skip_or_complete(slot: CarSlot) -> void:
	slot.route_index += 1
	if slot.route_index < slot.route.size():
		_pathfind_next(slot)
	else:
		_complete(slot)

# ── Tile reservation ──────────────────────────────────────────────────────────

func _tile_is_clear(tile: Vector3i, jid: int, entry_dir: Vector2i) -> bool:
	var claims: Dictionary = _reserved.get(tile, {})
	var same_dir_count := 0
	for existing_jid: int in claims:
		if existing_jid == jid:
			continue
		var entry: Dictionary  = claims[existing_jid]
		var existing_dir: Vector2i = entry["dir"]
		if entry_dir != Vector2i.ZERO and existing_dir != Vector2i.ZERO \
				and existing_dir == -entry_dir:
			continue   # opposite lane — no conflict
		if existing_dir == entry_dir:
			same_dir_count += 1
			if same_dir_count >= MAX_LANE_SLOTS:
				return false
			continue
		return false   # perpendicular or zero — conflict
	return true

## Returns the assigned lane slot (0 or 1).
func _claim_tile(tile: Vector3i, jid: int, entry_dir: Vector2i) -> int:
	if not _reserved.has(tile):
		_reserved[tile] = {}
	var taken: Array[int] = []
	for existing_jid: int in _reserved[tile]:
		if existing_jid == jid:
			continue
		var entry: Dictionary = _reserved[tile][existing_jid]
		if entry["dir"] == entry_dir:
			taken.append(entry["slot"])
	var lane_slot := 0
	while lane_slot in taken:
		lane_slot += 1
	_reserved[tile][jid] = {"dir": entry_dir, "slot": lane_slot}
	return lane_slot

func _release_tile(tile: Vector3i, jid: int) -> void:
	if not _reserved.has(tile):
		return
	var released_slot := -1
	var released_dir  := Vector2i.ZERO
	if _reserved[tile].has(jid):
		released_slot = _reserved[tile][jid]["slot"]
		released_dir  = _reserved[tile][jid]["dir"]
	_reserved[tile].erase(jid)
	# Promote every car in the same lane that was behind the departing car
	if released_slot >= 0:
		for existing_jid: int in _reserved[tile]:
			var entry: Dictionary = _reserved[tile][existing_jid]
			if entry["dir"] == released_dir and entry["slot"] > released_slot:
				_reserved[tile][existing_jid]["slot"] -= 1
				if _active.has(existing_jid):
					_active[existing_jid].lane_slot = _reserved[tile][existing_jid]["slot"]
	if _reserved[tile].is_empty():
		_reserved.erase(tile)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _dir_to_basis(dir: Vector2i) -> Basis:
	if dir == Vector2i.ZERO:
		return Basis.IDENTITY
	return Basis.looking_at(Vector3(float(dir.x), 0.0, float(dir.y)))

func _write_transform(slot: CarSlot) -> void:
	var def:   Dictionary = _TYPE_DEFS[slot.car_type]
	var pool:  TypePool   = _pools[slot.car_type]
	var display_basis := slot._seg_start_basis.slerp(slot._seg_end_basis,
			minf(slot._seg_progress * 2.0, 1.0))
	var rot    := Basis(Vector3.UP, deg_to_rad(def.get("rot_y", 0.0)))
	var scale: float = def.get("scale", 1.0)
	var final_basis := display_basis * rot * Basis().scaled(Vector3.ONE * scale)
	var world_pos   := slot.position + Vector3(0.0, pool.ground_y, 0.0)
	if slot.lane_slot > 0 and slot.travel_dir != Vector2i.ZERO:
		var fwd := Vector3(float(slot.travel_dir.x), 0.0, float(slot.travel_dir.y)).normalized()
		world_pos -= fwd * (BUMPER_SPACING * slot.lane_slot)
	pool.mminstance.multimesh.set_instance_transform(
		slot.slot_index, Transform3D(final_basis, world_pos))

func _hide_slot(slot: CarSlot) -> void:
	var pool: TypePool = _pools.get(slot.car_type)
	if pool:
		pool.mminstance.multimesh.set_instance_transform(slot.slot_index, _hidden_transform())

func _hidden_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, -9999.0, 0.0))

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
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	return sphere
